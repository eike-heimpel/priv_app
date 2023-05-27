import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eike Builds an App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.grey[700],
        colorScheme: ColorScheme.dark(
          primary: Colors.grey[700]!,
          secondary: Colors.yellow,
          background: Colors.grey[850]!,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.grey[700],
        ),
        appBarTheme: AppBarTheme(
          color: Colors.grey[700],
        ),
        textTheme: TextTheme(
          bodyText2: TextStyle(color: Colors.white),
        ),
      ),
      home: MyHomePage(title: 'Eike`s Privacy Data Collector'),
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
  bool isRecording = false;
  int _recordDuration = 0;
  late Timer _timer;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _init = _initialize();
  }

Future<void> _initialize() async {
  final appTemporaryDirectory = await path_provider.getTemporaryDirectory();
  final folder = Directory('${appTemporaryDirectory.path}/$_folderName');
  if (!folder.existsSync()) {
    folder.createSync();
  }
  _filePath = '${folder.path}/$_fileName';

  await _recorder.openRecorder();
  await _player.openPlayer();

  setState(() {
    isInitialized = true;
  });
}


  @override
  void dispose() async {
    await _recorder.closeRecorder();
    await _player.closePlayer();
    super.dispose();
  }

  Future<void> _startRecording() async {
    print('Start Recording');
    await _recorder.startRecorder(toFile: _filePath);

    setState(() {
      isRecording = true;
      _recordDuration = 0;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      if (_recordDuration >= 60) {
        _stopRecording();
      } else {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }

Future<void> _stopRecording() async {
  print('Stop Recording');
  await _recorder.stopRecorder();

  setState(() {
    isRecording = false;
  });

  _timer.cancel();

  // Encrypt the recording
  final plainData = await File(_filePath).readAsBytes();
  final key = encrypt.Key.fromLength(32); // 256 bit key for AES-256
  final iv = encrypt.IV.fromLength(16); // 128 bit block size for AES
  final encrypter = encrypt.Encrypter(encrypt.AES(key));
  final encryptedData = encrypter.encryptBytes(plainData, iv: iv);
  
  // Write encrypted data back to file
  await File(_filePath).writeAsBytes(encryptedData.bytes);
}

Future<void> _playRecording() async {
  print('Play Recording');

  // Decrypt the recording
  final encryptedData = await File(_filePath).readAsBytes();
  final key = encrypt.Key.fromLength(32); // 256 bit key for AES-256
  final iv = encrypt.IV.fromLength(16); // 128 bit block size for AES
  final encrypter = encrypt.Encrypter(encrypt.AES(key));
  
  final encryptedFile = encrypt.Encrypted(encryptedData);
  final decryptedData = encrypter.decryptBytes(encryptedFile, iv: iv);

  // Write decrypted data to a temporary file
  final tempFile = File('$_filePath.temp');
  await tempFile.writeAsBytes(decryptedData);

  await _player.startPlayer(fromURI: tempFile.path);

  // Delete the temporary file
  await tempFile.delete();
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    isRecording
                        ? 'Recording... $_recordDuration seconds elapsed'
                        : 'Not recording',
                    style: TextStyle(color: Colors.yellow, fontSize: 20),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      FloatingActionButton(
                        heroTag: null,
                        onPressed: isInitialized && !isRecording ? _startRecording : null,
                        tooltip: 'Start Recording',
                        child: Icon(Icons.mic, size: 40, color: Colors.yellow),
                      ),
                      FloatingActionButton(
                        heroTag: null,
                        onPressed: isInitialized && isRecording ? _stopRecording : null,
                        tooltip: 'Stop Recording',
                        child: Icon(Icons.stop, size: 40, color: Colors.yellow),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      FloatingActionButton(
                        heroTag: null,
                        onPressed: isInitialized && !isRecording ? _playRecording : null,
                        tooltip: 'Play Recording',
                        child: Icon(Icons.play_arrow, size: 40, color: Colors.yellow),
                      ),
                    ],
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
