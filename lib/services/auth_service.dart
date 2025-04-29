import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 추가

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 🔥 추가

  // 로그인
  Future<void> signIn(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    ).then((_) {
      // 로그인 성공 시 별도 처리 없음 (return 무시)
    }).catchError((e) {
      throw e;
    });
  }

  // 회원가입 (role 추가됨)
  Future<void> signUp(String email, String password, String role) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    ).then((userCredential) async {
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role, // 역할 저장
        'createdAt': FieldValue.serverTimestamp(),
      });
    }).catchError((e) {
      throw e;
    });
  }

  // 로그아웃
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // 🔥 추가: 로그인 후 role 가져오기
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        return (userDoc.data() as Map<String, dynamic>)['role'];
      } else {
        return null;
      }
    } catch (e) {
      print('역할(role) 가져오기 실패: $e');
      return null;
    }
  }
}
