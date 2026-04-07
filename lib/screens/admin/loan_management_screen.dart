import 'package:flutter/material.dart';

class LoanManagementScreen extends StatelessWidget {
  const LoanManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des prêts')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Gestion des prêts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Interface en cours de développement'),
          ],
        ),
      ),
    );
  }
}
