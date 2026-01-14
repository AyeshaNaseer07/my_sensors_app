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

  @override
  void initState() {
    super.initState();
    _loadSelfies();
  }

  Future<void> _loadSelfies() async {
    try {
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
        });
      }
    } catch (e) {
      debugPrint('Error loading selfies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'View Unauthorized Attempts',
            onPressed: () {
              Navigator.pushNamed(context, '/attempts');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.home, size: 80, color: Colors.blue),
              onPressed: () {},
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Home Screen!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/attempts');
              },
              icon: const Icon(Icons.remove_red_eye),
              label: Text('View Unauthorized Attempts (${_selfies.length})'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
