import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';

class BoundingBox extends StatelessWidget {
  final List<dynamic> value;
  final int previewH;
  final int previewW;
  final double screenH;
  final double screenW;
  const BoundingBox({
    Key? key,
    required this.value,
    required this.previewH,
    required this.previewW,
    required this.screenH,
    required this.screenW,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> _renderBox() {
      return value.map((re) {
        var _x = re["rect"]["x"];
        var _w = re["rect"]["w"];
        var _y = re["rect"]["y"];
        var _h = re["rect"]["h"];
        var scaleW, scaleH, x, y, w, h;

        if (screenH / screenW > previewH / previewW) {
          scaleW = screenH / previewH * previewW;
          scaleH = screenH;

          var difW = (scaleW - screenW) / scaleW;
          x = (_x - difW / 2) * scaleW;
          w = _w * scaleW;
          if (_x < difW / 2) w -= (difW / 2 - _x) * scaleW;
          y = _y * scaleH;
          h = _h * scaleH;
        } else {
          scaleH = screenW / previewW * previewH;
          scaleW = screenW;
          var difH = (scaleH - screenH) / scaleH;
          x = _x * scaleW;
          w = _w * scaleW;
          y = (_y - difH / 2) * scaleH;
          h = _h * scaleH;
          if (_y < difH / 2) h -= (difH / 2 - _y) * scaleH;
        }
        return Positioned(
            left: math.max(0, x),
            top: math.max(0, y),
            width: w,
            height: h,
            child: Container(
              padding: EdgeInsets.only(top: 5.0, left: 5.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Color.fromRGBO(37, 213, 253, 1.0),
                  width: 3.0,
                ),
              ),
              child: Text(
                "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: Color.fromRGBO(37, 213, 253, 1.0),
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ));
      }).toList();
    }

    return Stack(
      children: _renderBox(),
    );
  }
}

typedef void Callback(List<dynamic> list, int h, int w);

class CameraFeed extends StatefulWidget {
  const CameraFeed(this.cameras, this.setRecognitions, {Key? key})
      : super(key: key);

  final List<CameraDescription> cameras;
  final Callback setRecognitions;

  @override
  _CameraFeedState createState() => _CameraFeedState();
}

class _CameraFeedState extends State<CameraFeed> {
  late CameraController cameraController;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();

    print(widget.cameras);
    if (widget.cameras == null || widget.cameras.length < 1) {
      print('No Camera Found');
    } else {
      cameraController =
          new CameraController(widget.cameras[0], ResolutionPreset.high);
      cameraController.initialize().then((value) {
        if (!mounted) {
          return;
        }
        setState(() {});
        cameraController.startImageStream((image) {
          if (!isDetecting) {
            isDetecting = true;
            Tflite.detectObjectOnFrame(
              bytesList: image.planes.map((plane) {
                return plane.bytes;
              }).toList(),
              model: "SSDMobileNet",
              imageHeight: image.height,
              imageWidth: image.width,
              imageMean: 127.5,
              imageStd: 127.5,
              numResultsPerClass: 1,
              threshold: 0.4,
            ).then((recognitions) {
              widget.setRecognitions(recognitions!, image.height, image.width);
              isDetecting = false;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cameraController == null || !cameraController.value.isInitialized) {
      return Container();
    }

    var tmp = MediaQuery.of(context).size;
    var screenH = math.max(tmp.height, tmp.width);
    var screenW = math.min(tmp.height, tmp.width);
    tmp = cameraController.value.previewSize!;
    var previewH = math.max(tmp.height, tmp.width);
    var previewW = math.min(tmp.height, tmp.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;

    return OverflowBox(
      maxHeight:
          screenRatio > previewRatio ? screenH : screenW / previewW * previewH,
      maxWidth:
          screenRatio > previewRatio ? screenH / previewH * previewW : screenW,
      child: CameraPreview(cameraController),
    );
  }
}

class LiveFeed extends StatefulWidget {
  final List<CameraDescription> cameras;
  LiveFeed(this.cameras);
  @override
  _LiveFeedState createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed> {
  List<dynamic> _recognitions = [];
  int _imageHeight = 0;
  int _imageWidth = 0;
  initCameras() async {}
  loadTfModel() async {
    await Tflite.loadModel(
      model: "assets/models/ssd_mobilenet.tflite",
      labels: "assets/models/labels.txt",
    );
  }

  /* 
  The set recognitions function assigns the values of recognitions, imageHeight and width to the variables defined here as callback
  */
  setRecognitions(recognitions, imageHeight, imageWidth) {
    setState(() {
      _recognitions = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  void initState() {
    super.initState();
    loadTfModel();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text("Real Time Object Detection"),
      ),
      body: Stack(
        children: <Widget>[
          CameraFeed(widget.cameras, setRecognitions),
          BoundingBox(
            value: _recognitions == null ? [] : _recognitions,
            previewH: math.max(_imageHeight, _imageWidth),
            previewW: math.min(_imageHeight, _imageWidth),
            screenH: screen.height,
            screenW: screen.width,
          ),
        ],
      ),
    );
  }
}
