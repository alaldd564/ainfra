import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String buildTime = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  bool _autoLoginChecked = false;

  Future<void> _login() async {
    try {
      await _authService.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final role = await _authService.getUserRole(uid);

      // ✅ 자동 로그인 여부 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoLogin', _autoLoginChecked);

      if (!mounted) return;

      if (role == '시각장애인') {
        Navigator.pushReplacementNamed(context, '/blind_home');
      } else if (role == '보호자') {
        Navigator.pushReplacementNamed(context, '/guardian_home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('잘못된 사용자 역할입니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Row(
              children: [
                Checkbox(
                  value: _autoLoginChecked,
                  onChanged: (value) {
                    setState(() {
                      _autoLoginChecked = value ?? false;
                    });
                  },
                ),
                const Text('자동 로그인'),
              ],
            ),
            ElevatedButton(
              onPressed: _login,
              child: const Text('로그인'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text('회원가입하러 가기'),
            ),
            const Spacer(),
            Center(
              child: Text(
                '빌드 시각: $buildTime',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
