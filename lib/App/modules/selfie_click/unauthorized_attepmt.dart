import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class UnauthorizedAttemptsScreen extends StatefulWidget {
  const UnauthorizedAttemptsScreen({super.key});

  @override
  State<UnauthorizedAttemptsScreen> createState() =>
      _UnauthorizedAttemptsScreenState();
}

class _UnauthorizedAttemptsScreenState
    extends State<UnauthorizedAttemptsScreen> {
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
        title: Text('Unauthorized Attempts (${_selfies.length})'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadSelfies),
        ],
      ),
      body: _selfies.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green),
                  SizedBox(height: 20),
                  Text(
                    'No unauthorized attempts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _selfies.length,
              itemBuilder: (context, index) {
                final file = _selfies[index];
                final fileName = file.path.split('/').last;
                final timestamp = fileName
                    .replaceAll('unauthorized_', '')
                    .replaceAll('.jpg', '');

                late DateTime dateTime;
                try {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(
                    int.parse(timestamp),
                  );
                } catch (e) {
                  dateTime = file.lastModifiedSync();
                }

                return Card(
                  margin: EdgeInsets.all(10),
                  elevation: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red, // only here
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                            // bottomLeft and bottomRight default to 0
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attempt #${index + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Date: ${dateTime.day}/${dateTime.month}/${dateTime.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Time: ${dateTime.hour}:${dateTime.minute}:${dateTime.second}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Image.file(
                        file,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Scaffold(
                                      appBar: AppBar(
                                        backgroundColor: Colors.black,
                                      ),
                                      backgroundColor: Colors.black,
                                      body: Center(
                                        child: InteractiveViewer(
                                          child: Image.file(file),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.fullscreen),
                              label: Text('View'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                // Show confirmation dialog
                                bool? confirmDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Image'),
                                    content: const Text(
                                      'Are you sure you want to delete this image permanently?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          context,
                                        ).pop(false), // Cancel
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          context,
                                        ).pop(true), // Confirm
                                        child: const Text('Yes'),
                                      ),
                                    ],
                                  ),
                                );

                                // If user confirmed, delete the file
                                if (confirmDelete == true) {
                                  try {
                                    file.deleteSync();
                                    _loadSelfies(); // reload list
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'File deleted successfully',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error deleting file: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
