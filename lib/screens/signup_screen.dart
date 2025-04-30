import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  String _selectedRole = '시각장애인'; // 기본값
  final List<String> _roles = ['시각장애인', '보호자', '택시기사'];

  Future<void> _signUp() async {
    try {
      await _authService.signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
        _selectedRole,
      );

      if (!mounted) return; // ⛑ context 사용 전 mounted 체크
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 성공')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return; // ⛑ context 사용 전 mounted 체크
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const Text('역할을 선택하세요:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            ToggleButtons(
              isSelected: _roles.map((role) => role == _selectedRole).toList(),
              onPressed: (index) {
                setState(() {
                  _selectedRole = _roles[index];
                });
              },
              children: _roles
                  .map((role) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(role),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _signUp,
                child: const Text('회원가입'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
