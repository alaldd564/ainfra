import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '실시간 Firestore 테스트',
      home: const FirestoreLivePage(),
    );
  }
}

class FirestoreLivePage extends StatefulWidget {
  const FirestoreLivePage({super.key});

  @override
  State<FirestoreLivePage> createState() => _FirestoreLivePageState();
}

class _FirestoreLivePageState extends State<FirestoreLivePage> {
  int _counter = 0;

  Future<void> _addData() async {
    await FirebaseFirestore.instance.collection('test').add({
      'count': _counter,
      'timestamp': Timestamp.now(),
    });
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("실시간 Firestore 업데이트")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _addData,
            child: const Text('Firestore에 추가'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('test')
                  .orderBy('timestamp', descending: true)
                  .snapshots(), // 실시간으로 수신!
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text('Count: ${data['count']}'),
                      subtitle: Text(data['timestamp']
                          .toDate()
                          .toString()
                          .substring(0, 19)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
