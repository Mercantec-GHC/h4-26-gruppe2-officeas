import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/tickets_bloc.dart';
import '../bloc/tickets_event.dart';
import '../bloc/tickets_state.dart';

class CreateTicketPage extends StatefulWidget {
  const CreateTicketPage({super.key});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final userId = context.read<AuthBloc>().currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Du skal være logget ind for at oprette en ticket'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    context.read<TicketsBloc>().add(
      CreateTicket(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdByUserId: userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: const Text('Create ticket'),
      body: BlocConsumer<TicketsBloc, TicketsState>(
        listener: (context, state) {
          if (state is TicketsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state is TicketCreateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ticket created'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          final loading = state is TicketsLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !loading,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    enabled: !loading,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Opret ticket'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
