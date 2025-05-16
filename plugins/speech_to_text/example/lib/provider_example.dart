import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_to_text_provider.dart';

void main() => runApp(const ProviderDemoApp());

class ProviderDemoApp extends StatefulWidget {
  const ProviderDemoApp({Key? key}) : super(key: key);

  @override
  State<ProviderDemoApp> createState() => _ProviderDemoAppState();
}

class _ProviderDemoAppState extends State<ProviderDemoApp> {
  final SpeechToText speech = SpeechToText();
  late SpeechToTextProvider speechProvider;

  @override
  void initState() {
    super.initState();
    speechProvider = SpeechToTextProvider(speech);
    initSpeechState();
  }

  Future<void> initSpeechState() async {
    await speechProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SpeechToTextProvider>.value(
      value: speechProvider,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Speech to Text Provider Example'),
          ),
          body: const SpeechProviderExampleWidget(),
        ),
      ),
    );
  }
}

class SpeechProviderExampleWidget extends StatefulWidget {
  const SpeechProviderExampleWidget({Key? key}) : super(key: key);

  @override
  SpeechProviderExampleWidgetState createState() =>
      SpeechProviderExampleWidgetState();
}

class SpeechProviderExampleWidgetState
    extends State<SpeechProviderExampleWidget> {
  String _currentLocaleId = '';

  void _setCurrentLocale(SpeechToTextProvider speechProvider) {
    if (speechProvider.isAvailable && _currentLocaleId.isEmpty) {
      _currentLocaleId = speechProvider.systemLocale?.localeId ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    var speechProvider = Provider.of<SpeechToTextProvider>(context);
    if (speechProvider.isNotAvailable) {
      return const Center(
        child: Text(
            'Speech recognition not available, no permission or not available on the device.'),
      );
    }
    _setCurrentLocale(speechProvider);
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Speech recognition available',
          style: TextStyle(fontSize: 22.0),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            TextButton(
              onPressed:
                  !speechProvider.isAvailable || speechProvider.isListening
                      ? null
                      : () => speechProvider.listen(
                            partialResults: true,
                            localeId: _currentLocaleId,
                          ),
              child: const Text('Start'),
            ),
            TextButton(
              onPressed: speechProvider.isListening
                  ? () => speechProvider.stop()
                  : null,
              child: const Text('Stop'),
            ),
            TextButton(
              onPressed: speechProvider.isListening
                  ? () => speechProvider.cancel()
                  : null,
              child: const Text('Cancel'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: _currentLocaleId.isNotEmpty
              ? _currentLocaleId
              : (speechProvider.locales.isNotEmpty
                  ? speechProvider.locales.first.localeId
                  : null),
          onChanged: (selectedVal) => _switchLang(selectedVal),
          items: speechProvider.locales
              .map((localeName) => DropdownMenuItem(
                    value: localeName.localeId,
                    child: Text(localeName.name),
                  ))
              .toList(),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: Text(
              speechProvider.lastResult?.recognizedWords ?? '인식된 결과 없음',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            children: <Widget>[
              const Text(
                'Error Status',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              speechProvider.hasError
                  ? Text(speechProvider.lastError!.errorMsg)
                  : const Text(''),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: speechProvider.isListening
                ? const Text(
                    "I'm listening...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                : const Text(
                    'Not listening',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  void _switchLang(String? selectedVal) {
    if (selectedVal == null) return;
    setState(() {
      _currentLocaleId = selectedVal;
    });
    debugPrint('Locale changed to: $_currentLocaleId');
  }
}
