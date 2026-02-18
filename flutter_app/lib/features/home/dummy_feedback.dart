import 'package:flutter/material.dart';

class DummyFeedbackPage extends StatelessWidget {
  const DummyFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback (Placeholder)'), backgroundColor: const Color(0xFF0A66FF)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.feedback_outlined, size: 72, color: Color(0xFF0A66FF)),
            const SizedBox(height: 16),
            const Text('Feedback page placeholder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This is a temporary placeholder. The real Feedback page will be implemented later.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          ]),
        ),
      ),
    );
  }
}
