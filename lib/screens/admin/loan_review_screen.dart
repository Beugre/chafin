import 'package:flutter/material.dart';

class LoanReviewScreen extends StatelessWidget {
  final String loanId;

  const LoanReviewScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Révision du prêt')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rate_review, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Révision du prêt',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('ID: $loanId'),
            const SizedBox(height: 8),
            const Text('Interface en cours de développement'),
          ],
        ),
      ),
    );
  }
}
