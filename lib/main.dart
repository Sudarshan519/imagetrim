import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:get/get.dart';

class MyController extends GetxController {
  final RxList imgData = <int>[].obs;
}

const shift = (0xFF << 24);
convertYUV420toImageColor(
  dynamic data,
) async {
  var now = DateTime.now();

  final SendPort port = data[0];
  final image = data[1];
  try {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int? uvPixelStride = image.planes[1].bytesPerPixel;
    // imgLib -> Image package from https://pub.dartlang.org/packages/image

    var img = imglib.Image(height: height, width: width); // Create Image buffer

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride! * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
        // var    imgData = imglib.ImageDataFloat32.from([]]);
        // Float32List list=[];
        // list[index] = shift |
        //                 (b << 16) |
        //                 (g << 8) |
        //                 r)//= shift | (b << 16) | (g << 8) | r;
        //         img.data !=
        //     imgData;

        // Uint32List data = Uint32List.fromList([]);
        // data[index] = shift | (b << 16) | (g << 8) | r;
        // img.data != imglib.decodeImage(Uint8List.fromList(data));

        img.data!.setPixelRgb(x, y, r, g, b);
        // shift |
        //     (b << 16) |
        //     (g << 8) |
        //     r); //= shift | (b << 16) | (g << 8) | r;

        // img = imglib.copyCrop(x=img,y= 40,height= 180,width= 420, 300);

        // img = imglib.copyCrop(img, x: x, y: y, width: width, height: height);

      }
    }
    img = imglib.copyRotate(img, angle: -90);
    img = imglib.copyCrop(img, x: 40, y: 180, width: 420, height: 300);
    //  img = imglib.copyCrop(img, 40, 180, 420, 300);
    imglib.PngEncoder pngEncoder = imglib.PngEncoder(
      level: 0,
    );

    List<int> png = pngEncoder.encode(img);
    port.send(png);
    print(now);
    print(DateTime.now().difference(now).inSeconds);
    // return png;
  } catch (e) {
    print(e.toString());
  }
}

void main() {
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final MyController appController = Get.put(MyController());
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initilizeCamera();
  }

  late CameraController controller;
  bool cameraInitialized = false;
  final ReceivePort receivePort = ReceivePort();
  var imgBytes;
  var isProcessing = false;
  initilizeCamera() async {
    var cameras = await availableCameras();
    controller = CameraController(cameras[1], ResolutionPreset.low);
    await controller.initialize();
    controller.startImageStream((image) {
      convertImage(image);
    });
    cameraInitialized = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: cameraInitialized
                ? CameraPreview(controller)
                : const CircularProgressIndicator(),
          ),
          Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 100,
                width: 100,
                // color: Colors.black,
                child: (imgBytes != null)
                    // ? CameraCropped(cameraController: controller)

                    ? Image.memory(
                        imgBytes,
                        height: 100,
                        width: 100,
                        fit: BoxFit.fill,
                      )
                    : const CircularProgressIndicator(),
              )),
        ],
      ),
    );
  }

  void convertImage(image) async {
    if (isProcessing == false) {
      isProcessing = true;

      // imgBytes = null;
      // ReceivePort receivePort = ReceivePort();
      Isolate.spawn<dynamic>(
          convertYUV420toImageColor, [receivePort.sendPort, image]);
      controller.stopImageStream();
      receivePort.listen((message) {
        imgBytes = message;
        setState(() {});
      });
      // imgBytes = await convertYUV420toImageColor(image);
      // print(imgBytes);
      isProcessing = false;
    }
  }
}

class CameraCropped extends StatefulWidget {
  const CameraCropped({super.key, required this.cameraController});
  final CameraController cameraController;
  @override
  State<CameraCropped> createState() => _CameraCroppedState();
}

class _CameraCroppedState extends State<CameraCropped> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initImageStream();
  }

  initImageStream() {
    widget.cameraController.startImageStream((image) {
      print(image);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
