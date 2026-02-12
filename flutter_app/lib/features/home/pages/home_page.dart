import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../home/feedback_page.dart';
import '../calender.dart';
import '../tickets.dart';
import '../account.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Top gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A66FF), Color(0xFF4B7CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo circle
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.business, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(user != null ? user.name : 'Guest', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => authBloc.add(LogoutRequested()),
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile / Welcome card
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage())),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.blue.shade50,
                                child: Icon(Icons.person, size: 36, color: Colors.blue.shade700),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user != null ? user.name : 'Guest', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(user != null ? user.email : '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                          child: Text('Authenticated', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackPage())),
                                          icon: const Icon(Icons.feedback_outlined, size: 18),
                                          label: const Text('Give feedback'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            Icons.schedule,
                            'Shifts',
                            'View upcoming shifts',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalenderPage())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            Icons.confirmation_number,
                            'Tickets',
                            'Open/Manage tickets',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TicketsPage())),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Placeholder for additional content or cards
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Announcements', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('More features coming soon — shifts, tickets, departments and more.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(icon, color: Colors.blue.shade700)),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
