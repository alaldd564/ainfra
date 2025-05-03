/*
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('네이버 지도'),
    ),
    body: Stack(
      children: [
        if (_currentLocation != null)
          NaverMap(
            onMapReady: _onMapReady,
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _currentLocation!,
                zoom: 16,
              ),
              locationButtonEnable: true,
            ),
          )
        else
          const Center(child: CircularProgressIndicator()),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('지도 위 버튼 클릭됨')),
                );
              },
              child: const Text('지도 위 버튼'),
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('하단 바 버튼 클릭됨')),
          );
        },
        child: const Text('하단 바 버튼'),
      ),
    ),
  );
}
*/