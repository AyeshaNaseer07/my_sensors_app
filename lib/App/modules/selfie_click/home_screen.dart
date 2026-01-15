import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class HomeViewScreen extends StatefulWidget {
  const HomeViewScreen({super.key});

  @override
  State<HomeViewScreen> createState() => _HomeViewScreenState();
}

class _HomeViewScreenState extends State<HomeViewScreen> {
  List<File> _selfies = [];
  bool _isLoading = true; // ✅ FIXED: Track loading state

  @override
  void initState() {
    super.initState();
    _loadSelfies();
  }

  Future<void> _loadSelfies() async {
    try {
      setState(() {
        _isLoading = true; // ✅ FIXED: Show loading indicator
      });

      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/unauthorized_attempts');

      if (dir.existsSync()) {
        final files = dir
            .listSync()
            .where((file) => file.path.endsWith('.jpg'))
            .map((file) => File(file.path))
            .toList();

        files.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );

        setState(() {
          _selfies = files;
          _isLoading = false; // ✅ FIXED: Hide loading indicator
        });
      } else {
        setState(() {
          _selfies = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading selfies: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Added logout confirmation dialog
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔒 Logout?'),
        content: const Text(
          'Are you sure you want to logout?\n\n'
          'You will need to authenticate again to access the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/lock');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'View Unauthorized Attempts',
            onPressed: () async {
              // ✅ FIXED: Reload data when returning from attempts screen
              await Navigator.pushNamed(context, '/attempts');
              _loadSelfies();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ✅ FIXED: Better icon styling
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.shade200,
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Icon(
                            Icons.home,
                            size: 80,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Welcome to Home Screen!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ✅ FIXED: Added subtitle
                        Text(
                          'You are successfully authenticated',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 50),
                        // ✅ FIXED: Improved button layout and styling
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.shade50,
                                  Colors.red.shade100,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  size: 50,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  'Security Status',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // ✅ FIXED: Show attempt count with better formatting
                                Text(
                                  _selfies.isEmpty
                                      ? 'No unauthorized attempts detected'
                                      : '${_selfies.length} unauthorized ${_selfies.length == 1 ? 'attempt' : 'attempts'} detected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // ✅ FIXED: Reload data when returning
                                      await Navigator.pushNamed(
                                        context,
                                        '/attempts',
                                      );
                                      _loadSelfies();
                                    },
                                    icon: const Icon(Icons.remove_red_eye),
                                    label: Text(
                                      'View Attempts (${_selfies.length})',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // ✅ FIXED: Better logout button styling
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _confirmLogout,
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'Logout',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
