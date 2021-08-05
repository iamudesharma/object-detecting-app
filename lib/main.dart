import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart' as Tf;

import 'camera_page.dart';
// import 'package:t';
// import 'package:tflite/tflite.dart';

late List<camera.CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await camera.availableCameras();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      title: 'Material App',
      home: Home(),
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('object Detector App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImagePage(),
                  ),
                );
              },
              child: Text('Image'),
            ),
            SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraPage(),
                  ),
                );
              },
              child: Text('Camera'),
            ),
          ],
        ),
      ),
    );
  }
}

class ImagePage extends StatefulWidget {
  const ImagePage({Key? key}) : super(key: key);

  @override
  _ImagePageState createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  File? _image;

  List _recognitions = [];
  bool _busy = true;
  double _imageWidth = 0.0;
  double _imageHeight = 0.0;
  ImagePicker picker = ImagePicker();

  @override
  void initState() {
    _busy = true;
    loadTfModel().then((value) {
      setState(() {
        _busy = false;
      });
    });
    super.initState();
  }

  Future<void> loadTfModel() async {
    await Tf.Tflite.loadModel(
      model: 'assets/models/ssd_mobilenet.tflite',
      isAsset: true,
      labels: 'assets/labels.txt',
    );
  }

  detectObject(File image) async {
    var recognitions = await Tf.Tflite.detectObjectOnImage(
      path: image.path,
      model: "SSDMobileNet",
      imageMean: 127.5,
      imageStd: 127.5,
      threshold: 0.4,
      numResultsPerClass: 10,
      asynch: true,
    );
    FileImage(image).resolve(ImageConfiguration()).addListener(
          (ImageStreamListener(
            (ImageInfo info, bool _) {
              setState(() {
                _imageWidth = info.image.width.toDouble();
                _imageHeight = info.image.height.toDouble();
              });
            },
          )),
        );
    setState(() {
      _recognitions = recognitions!;
    });
  }

  List<Widget> box(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _imageWidth / _imageHeight * screen.width;
    Color blue = Colors.blue;

    return _recognitions.map((re) {
      return Container(
        child: Positioned(
            left: re["rect"]["x"] * factorX,
            top: re["rect"]["y"] * factorY,
            width: re["rect"]["w"] * factorX,
            height: re["rect"]["h"] * factorY,
            child: ((re["confidenceInClass"] > 0.50))
                ? Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: blue, width: 3)),
                    child: Text(
                      '"${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%"',
                      style: TextStyle(
                          background: Paint()..color = blue,
                          color: Colors.white,
                          fontSize: 15),
                    ),
                  )
                : SizedBox.shrink()),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stack = [];
    stack.add(
      Positioned(
        child: _image == null
            ? Container(
                child: Column(
                  children: [
                    Text('Plese Select an Image'),
                  ],
                ),
              )
            : Container(
                child: Image.file(_image!),
              ),
      ),
    );
    stack.addAll(box(size));
    if (_busy) {
      stack.add(Center(
        child: CircularProgressIndicator(),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Object Detector'),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "Fltbtn2",
            child: Icon(Icons.camera_alt),
            onPressed: getImageFromCamera,
          ),
          SizedBox(
            width: 10,
          ),
          FloatingActionButton(
            heroTag: "Fltbtn1",
            child: Icon(Icons.photo),
            onPressed: getImageFromGallery,
          ),
        ],
      ),
      body: Container(
        alignment: Alignment.center,
        child: Stack(
          children: stack,
        ),
      ),
    );
  }

  Future getImageFromGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print('No image Selected');
      }
    });

    detectObject(_image!);
  }

  Future getImageFromCamera() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print('No Image Selected');
      }
    });
    detectObject(_image!);
  }
}

class CameraPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LiveFeed(cameras);
  }
}
