import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Privacy App',
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
      home: MyHomePage(title: 'Privacy App Home Page'),
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
  String _fileName = 'temp.aac';
  String _filePath = '';
  Future<void>? _init;
  bool isRecording = false;
  int _recordDuration = 0;
  late Timer _timer;
  bool isInitialized = false;
  final _localAuth = LocalAuthentication();
  final _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _init = _initialize();
  }

  Future<void> _initialize() async {
    var permission = await Permission.microphone.request();
    if (permission != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }

    _filePath = (await getTemporaryDirectory()).path + '/$_fileName';

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
    await _recorder.stopRecorder();

    setState(() {
      isRecording = false;
    });

    _timer.cancel();

    // Encrypt the recording
    String? keyString = await _storage.read(key: 'my_key');
    if (keyString == null) {
      print('Key not found in storage');
      return;
    }
    final keyData = base64Url.decode(keyString);
    final key = encrypt.Key(keyData);
    final iv = encrypt.IV.fromLength(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final file = File(_filePath);
    final fileBytes = file.readAsBytesSync();

    final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
    final encryptedFile = File(_filePath);
    await encryptedFile.writeAsBytes(encrypted.bytes);
  }

  Future<void> _playRecording() async {
    // Decrypt the recording
    String? keyString = await _storage.read(key: 'my_key');
    if (keyString == null) {
      print('Key not found in storage');
      return;
    }
    final keyData = base64Url.decode(keyString);
    final key = encrypt.Key(keyData);
    final iv = encrypt.IV.fromLength(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final file = File(_filePath);
    final fileBytes = file.readAsBytesSync();

    final decrypted = encrypter.decryptBytes(encrypt.Encrypted(fileBytes), iv: iv);
    final decryptedFile = File(_filePath);
    await decryptedFile.writeAsBytes(decrypted);

    await _player.startPlayer(fromURI: _filePath);
  }

  Future<void> _deleteRecording() async {
    final file = File(_filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Press the button to start recording.',
            ),
            Text(
              'Recording duration: $_recordDuration',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: isInitialized ? 
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          FloatingActionButton(
            onPressed: isInitialized && !isRecording ? _startRecording : null,
            tooltip: 'Start Recording',
            child: Icon(Icons.mic, size: 40, color: Colors.yellow),
          ),
          FloatingActionButton(
            onPressed: isInitialized && isRecording ? _stopRecording : null,
            tooltip: 'Stop Recording',
            child: Icon(Icons.stop, size: 40, color: Colors.yellow),
          ),
          FloatingActionButton(
            onPressed: isInitialized && !isRecording ? _playRecording : null,
            tooltip: 'Play Recording',
            child: Icon(Icons.play_arrow, size: 40, color: Colors.yellow),
          ),
        ],
      ) : null,
    );
  }
}
