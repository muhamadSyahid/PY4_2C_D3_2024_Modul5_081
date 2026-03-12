import 'package:flutter/material.dart';
import 'package:logbook_app_081/features/auth/login_controller.dart';
import 'package:logbook_app_081/features/auth/user_model.dart';
// import 'package:logbook_app_081/features/logbook/counter_view.dart';
import 'package:logbook_app_081/features/logbook/log_view.dart';
import 'dart:async';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isPasswordVisible = false;
  int _loginAttempts = 0;
  bool _isLocked = false;

  void _handleLogin() {
    String user = _userController.text;
    String pass = _passController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Username dan Password tidak boleh kosong!")),
      );
      return;
    }

    bool isSuccess = _controller.login(user, pass);

    if (isSuccess) {
      setState(() {
        _loginAttempts = 0;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LogView(currentUser: User.current!),
        ),
      );
    } else {
      setState(() {
        _loginAttempts++;
      });

      if (_loginAttempts >= 3) {
        setState(() {
          _isLocked = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Terlalu banyak percobaan! Login dikunci 10 detik.")),
        );

        Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _loginAttempts = 0;
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Login Gagal! Sisa percobaan: ${3 - _loginAttempts}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Login Gatekeeper")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: _passController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _isLocked ? null : _handleLogin,
                  child: const Text("Masuk")),
            ],
          ),
        ));
  }
}
