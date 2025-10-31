import 'package:flutter/material.dart';

class LogoutPage extends StatelessWidget {
  const LogoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logout Page'),
        backgroundColor: Colors.blueAccent,
      ),
      body: const Center(
        child: Text('You have logged out.', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
