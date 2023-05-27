import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Recording App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Voice Recording Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _player;
  String _folderName = 'MyAppFolder';
  String _fileName = 'temp2.wav';
  String _filePath = '';
  Future<void>? _init;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _init = _initialize();
  }

  Future<void> _initialize() async {
    final appDocumentsDirectory =
        await path_provider.getApplicationDocumentsDirectory();
    final folder = Directory('${appDocumentsDirectory.path}/$_folderName');
    if (!folder.existsSync()) {
      folder.createSync();
    }
    _filePath = '${folder.path}/$_fileName';

    // Request storage permission
    if (await Permission.storage.request().isGranted) {
      // Permission is granted, proceed with opening recorder and player
      await _recorder.openRecorder();
      await _player.openPlayer();
    } else {
      // Permission is denied
      // TODO: Handle the case where permission is not granted
      print('Storage permission is not granted');
    }
  }

  @override
  void dispose() async {
    await _recorder.closeRecorder();
    await _player.closePlayer();
    super.dispose();
  }

  Future<void> _startRecording() async {
    await _recorder.startRecorder(toFile: _filePath);
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
  }

  Future<void> _playRecording() async {
    await _player.startPlayer(fromURI: _filePath);
  }

  void _checkFile() {
    final file = File(_filePath);
    final fileExists = file.existsSync();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('File Check Result'),
          content: Text(fileExists
              ? 'File exists at $_filePath'
              : 'File does not exist at $_filePath'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _init,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
            ),
            body: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FloatingActionButton(
                    onPressed: _startRecording,
                    tooltip: 'Start Recording',
                    child: Icon(Icons.mic),
                  ),
                  FloatingActionButton(
                    onPressed: _stopRecording,
                    tooltip: 'Stop Recording',
                    child: Icon(Icons.stop),
                  ),
                  FloatingActionButton(
                    onPressed: _playRecording,
                    tooltip: 'Play Recording',
                    child: Icon(Icons.play_arrow),
                  ),
                  ElevatedButton(
                    onPressed: _checkFile,
                    child: Text('Check File'),
                  ),
                ],
              ),
            ),
          );
        } else {
          return CircularProgressIndicator();
        }
      },
    );
  }
}
