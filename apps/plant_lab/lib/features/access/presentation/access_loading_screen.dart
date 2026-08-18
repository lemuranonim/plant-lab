import 'package:flutter/material.dart';

class AccessLoadingScreen extends StatelessWidget {
  const AccessLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking role and site access...'),
            ],
          ),
        ),
      ),
    );
  }
}
