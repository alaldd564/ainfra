import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEST',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'TEST'),
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
  final SpeechToText _speechToText = SpeechToText();

  String _currentActivity = 'stopped';
  int _loopCount = 0;
  bool _inTest = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    await _speechToText.initialize(onError: _onError, onStatus: _onStatus);
    setState(() {});
  }

  void _loopTest() async {
    if (!_inTest) {
      setState(() {
        _currentActivity = 'stopped';
      });
      return;
    }

    _currentActivity = 'listening';
    _loopCount++;
    _speechToText.listen(listenFor: Duration(seconds: 5));

    setState(() {});
  }

  void _onStatus(String status) async {
    if (_inTest && status == SpeechToText.doneStatus) {
      _loopTest();
    }
    setState(() {});
  }

  void _onError(SpeechRecognitionError errorNotification) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed:
                      _inTest
                          ? null
                          : () {
                            _inTest = true;
                            _loopTest();
                          },
                  child: Text('Loop test'),
                ),
              ],
            ),
            TextButton(
              onPressed:
                  _inTest
                      ? () {
                        _inTest = false;
                      }
                      : null,
              child: Text('End Test'),
            ),
            Expanded(
              child: Column(
                children: [
                  Divider(),
                  Text('Currently: $_currentActivity'),
                  Text('Loops: $_loopCount'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
