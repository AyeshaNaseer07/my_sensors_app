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

  // ✅ FIXED: Added confirmation dialog for delete
  void _confirmDelete(File file, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Delete Attempt?'),
        content: Text(
          'Are you sure you want to delete this unauthorized attempt?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              try {
                file.deleteSync();
                Navigator.pop(context);
                _loadSelfies(); // Reload list after delete
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Attempt deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error deleting file: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unauthorized Attempts (${_selfies.length})'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSelfies,
            tooltip: 'Refresh',
          ),
          // ✅ FIXED: Added delete all button
          if (_selfies.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('🗑️ Delete All?'),
                    content: Text(
                      'Are you sure you want to delete all ${_selfies.length} attempts?\n\n'
                      'This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          try {
                            for (var file in _selfies) {
                              file.deleteSync();
                            }
                            Navigator.pop(context);
                            _loadSelfies();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ All attempts deleted successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Delete All',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Delete All',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selfies.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green.shade400,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No unauthorized attempts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Your account is secure! 🔒',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                        color: Colors.red.withOpacity(0.1),
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attempt #${index + 1}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Date: ${dateTime.day}/${dateTime.month}/${dateTime.year}',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Time: ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      // ✅ FIXED: Added error handling for corrupted images
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                        child: Image.file(
                          file,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: $error');
                            return Container(
                              color: Colors.grey[300],
                              height: 250,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      color: Colors.red,
                                      size: 50,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Image corrupted or deleted',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
                                        title: Text(
                                          'Attempt #${index + 1}',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      backgroundColor: Colors.black,
                                      body: Center(
                                        child: InteractiveViewer(
                                          child: Image.file(
                                            file,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.broken_image,
                                                          color: Colors.red,
                                                          size: 80,
                                                        ),
                                                        SizedBox(height: 20),
                                                        Text(
                                                          'Failed to load image',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                          ),
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
                              onPressed: () => _confirmDelete(file, index),
                              icon: Icon(Icons.delete),
                              label: Text('Delete'),
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
