import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/ticket_service.dart';
import '../../data/models/ticket_model.dart';
import '../auth/bloc/auth_bloc.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final _service = TicketService();
  List<TicketModel> _tickets = [];
  bool _loading = true;
  String? _error;

  String _query = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authBloc = context.read<AuthBloc>();
      final jwt = authBloc.currentToken;
      final list = await _service.getAllTickets();
      setState(() {
        _tickets = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<TicketModel> get _visibleTickets {
    return _tickets.where((t) {
      if (_filter != 'All' && t.status.toLowerCase() != _filter.toLowerCase()) return false;
      if (_query.isNotEmpty && !(t.title.toLowerCase().contains(_query.toLowerCase()) || t.description.toLowerCase().contains(_query.toLowerCase()))) return false;
      return true;
    }).toList();
  }

  Future<void> _showCreateDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<TicketModel?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create ticket'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final t = TicketModel(title: titleCtrl.text.trim(), description: descCtrl.text.trim(), status: 'OPEN');
              Navigator.pop(context, t);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != null) {
      try {
        final authBloc = context.read<AuthBloc>();
        final jwt = authBloc.currentToken;
        final userId = authBloc.currentUser?.id;
        final ticketToSend = TicketModel(
          title: created.title,
          description: created.description,
          status: created.status,
          createdByUserId: userId,
        );
        final newT = await _service.createTicket(ticket: ticketToSend, jwt: jwt);
        setState(() => _tickets.insert(0, newT));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create ticket: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        backgroundColor: const Color(0xFF0A66FF),
        actions: [IconButton(onPressed: _loadTickets, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF0A66FF),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6)]),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search tickets'),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        if (_query.isNotEmpty) IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close, color: Colors.grey))
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showCreateDialog,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6)]),
                    child: const Icon(Icons.add, color: Color(0xFF0A66FF)),
                  ),
                )
              ],
            ),
          ),

          // Filters
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: ['All', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: const Color(0xFF0A66FF),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Tickets list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : _visibleTickets.isEmpty
                          ? Center(child: Text('No tickets match your search', style: TextStyle(color: Colors.grey.shade600)))
                          : ListView.separated(
                              itemCount: _visibleTickets.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final t = _visibleTickets[index];
                                return Material(
                                  elevation: 1,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListTile(
                                    onTap: () {},
                                    leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Text(t.title.substring(0, 1))),
                                    title: Text(t.title),
                                    subtitle: Text(t.description),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _statusColor(t.status).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(t.status, style: TextStyle(color: _statusColor(t.status), fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'OPEN':
        return Colors.redAccent;
      case 'IN_PROGRESS':
        return Colors.orange.shade700;
      case 'RESOLVED':
      case 'CLOSED':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }
}
