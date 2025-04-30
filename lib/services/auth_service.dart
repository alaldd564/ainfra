import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // debugPrint 사용

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 로그인
  Future<void> signIn(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('❌ 로그인 실패: $e');
      rethrow; // ✅ rethrow로 변경
    }
  }

  // 회원가입 (role 포함)
  Future<void> signUp(String email, String password, String role) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ Firebase Auth 계정 생성 완료');

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Firestore 저장 성공');
    } catch (e) {
      debugPrint('❌ 회원가입 중 오류 발생: $e');
      rethrow; // ✅ rethrow로 변경
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // role 가져오기
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        return (userDoc.data() as Map<String, dynamic>)['role'];
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('역할(role) 가져오기 실패: $e');
      return null;
    }
  }
}
