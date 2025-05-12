import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String tmapViewType = 'com.example.ai_n_fra/tmap_view';

class TmapViewWidget extends StatefulWidget {
  final String apiKey;

  const TmapViewWidget({Key? key, required this.apiKey}) : super(key: key);

  @override
  _TmapViewWidgetState createState() => _TmapViewWidgetState();
}

class _TmapViewWidgetState extends State<TmapViewWidget> {
  MethodChannel? _channel;

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: tmapViewType,
      creationParams: <String, dynamic>{'apiKey': widget.apiKey},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) {
        _channel = MethodChannel('${tmapViewType}_$id');
        _onTmapViewCreated(id);
      },
    );
  }

  void _onTmapViewCreated(int id) {
    debugPrint('TmapPlatformView created with id: $id');
  }

}

class MapScreen extends StatelessWidget {
  final String yourTmapApiKey = "NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa";

  @override
  Widget build(BuildContext context) {
    if (yourTmapApiKey == "발급받은키(appKey)" || yourTmapApiKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Tmap Flutter Example')),
        body: Center(
          child: Text(
            'Tmap API 키를 입력해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Tmap Flutter Example')),
      body: Center(
        child: Container(
          width: double.infinity,
          height: 400,
          child: TmapViewWidget(apiKey: yourTmapApiKey),
        ),
      ),
    );
  }
}