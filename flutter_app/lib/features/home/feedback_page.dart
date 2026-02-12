import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/feedback_service.dart';
import '../../data/models/feedback_model.dart';
import '../../features/auth/bloc/auth_bloc.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _messageController = TextEditingController();
  int _rating = 5;
  final _service = FeedbackService();
  
  bool _loading = false;

  // Feedback list
  List<FeedbackModel> _items = [];
  bool _fetching = true;
  String? _fetchError;

  Future<void> submitFeedback() async {
    setState(() => _loading = true);

    try {
      // 🔐 1️⃣ Hent JWT fra AuthBloc
      final authBloc = context.read<AuthBloc>();
      final jwt = authBloc.currentToken;

      if (jwt == null) {
        throw Exception('User not authenticated');
      }

      // 📝 2️⃣ Lav feedback
      final feedback = FeedbackModel(
        message: _messageController.text,
        rating: _rating,
      );

      // 🚀 3️⃣ Send feedback MED JWT
      await _service.createFeedback(
        feedback: feedback,
        jwt: jwt,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted successfully')),
      );

      _messageController.clear();
      // Refresh list after successful submit
      await _loadFeedback();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit feedback: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _fetching = true;
      _fetchError = null;
    });
    try {
      final list = await _service.getAllFeedback();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _fetchError = e.toString());
    } finally {
      setState(() => _fetching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your Feedback',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Rating:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rating,
                  items: List.generate(5, (index) => index + 1)
                      .map(
                        (rating) => DropdownMenuItem(
                          value: rating,
                          child: Text(rating.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _rating = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : submitFeedback,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Submit'),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // Feedback list
            Expanded(
              child: _fetching
                  ? const Center(child: CircularProgressIndicator())
                  : _fetchError != null
                      ? Center(child: Text('Failed to load feedback: $_fetchError'))
                      : _items.isEmpty
                          ? Center(child: Text('No feedback yet', style: TextStyle(color: Colors.grey.shade600)))
                          : ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final f = _items[index];
                                return Material(
                                  elevation: 1,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListTile(
                                    title: Text(f.message ?? ''),
                                    subtitle: Text('Rating: ${f.rating}'),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
