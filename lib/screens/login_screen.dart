import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 uid 가져오기 위해 필요
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  Future<void> _login() async {
    try {
      await _authService.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      // 로그인 성공 → uid 가져오기
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Firestore에서 역할(role) 불러오기
      final role = await _authService.getUserRole(uid);

      if (role == '시각장애인') {
        Navigator.pushReplacementNamed(context, '/blind_home');
      } else if (role == '보호자') {
        Navigator.pushReplacementNamed(context, '/guardian_home');
      } else {
        // 예외: 역할이 비정상일 경우
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('잘못된 사용자 역할입니다.')),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('로그인'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: const Text('회원가입하러 가기'),
            )
          ],
        ),
      ),
    );
  }
}
