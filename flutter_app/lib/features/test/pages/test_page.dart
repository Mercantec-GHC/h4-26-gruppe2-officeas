import 'package:flutter/material.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Pages'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Navigation Test Page',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Click any button below to navigate to a page:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16.0),
            // Home Page
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/home');
              },
              icon: const Icon(Icons.home),
              label: const Text('Home Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
            const SizedBox(height: 12.0),
            // Calendar Page
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/calendar');
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('Calendar Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
            const SizedBox(height: 12.0),
            // Navigation Page (Weather + Infographic)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/navigation');
              },
              icon: const Icon(Icons.dashboard),
              label: const Text('Navigation Page (Weather + Info)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
            const SizedBox(height: 12.0),
            // Weather Page
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/weather');
              },
              icon: const Icon(Icons.cloud),
              label: const Text('Weather Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
            const SizedBox(height: 12.0),
            // Infographic Page
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/infographic');
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('Infographic Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
              ),
            ),
            const SizedBox(height: 12.0),
            // Login Page
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              icon: const Icon(Icons.login),
              label: const Text('Login Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
                backgroundColor: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 24.0),
            // Info section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Routes:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12.0),
                  _buildRouteItem('/home', 'Home Page'),
                  _buildRouteItem('/calendar', 'Calendar Page'),
                  _buildRouteItem('/navigation', 'Navigation Page'),
                  _buildRouteItem('/weather', 'Weather Page'),
                  _buildRouteItem('/infographic', 'Infographic Page'),
                  _buildRouteItem('/login', 'Login Page'),
                  _buildRouteItem('/test', 'Test Page (This Page)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteItem(String route, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, size: 16.0),
          const SizedBox(width: 8.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              Text(
                route,
                style: const TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
