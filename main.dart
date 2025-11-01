import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:filesize/filesize.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Manager',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: FileManagerScreen(),
    );
  }
}

// Main Screen with Bottom Navigation
class FileManagerScreen extends StatefulWidget {
  @override
  _FileManagerScreenState createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  // Bottom navigation index
  int _currentIndex = 0;

  // List of files in our app
  List<File> _files = [];

  // Total storage used
  int _totalSize = 0;

  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles(); // Load files when app starts
  }

  // Get app's document directory
  Future<Directory> _getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileManagerDir = Directory('${directory.path}/FileManager');

    // Create directory if it doesn't exist
    if (!await fileManagerDir.exists()) {
      await fileManagerDir.create(recursive: true);
    }

    return fileManagerDir;
  }

  // Load all files from app directory
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await _getAppDirectory();
      final List<FileSystemEntity> entities = directory.listSync();

      _files.clear();
      _totalSize = 0;

      for (final entity in entities) {
        if (entity is File) {
          _files.add(entity);
          _totalSize += await entity.length();
        }
      }

      // Sort files by name
      _files.sort(
        (a, b) => path.basename(a.path).compareTo(path.basename(b.path)),
      );
    } catch (e) {
      print('Error loading files: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Upload file function
  Future<void> _uploadFile() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();

      if (status.isGranted || status.isLimited) {
        // Pick file
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          final File sourceFile = File(result.files.single.path!);
          final String fileName = result.files.single.name;

          // Get app directory
          final Directory appDir = await _getAppDirectory();

          // Create destination path
          final String destinationPath = '${appDir.path}/$fileName';

          // Copy file to app directory
          await sourceFile.copy(destinationPath);

          // Reload files
          await _loadFiles();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File uploaded: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage permission required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete file function
  Future<void> _deleteFile(File file) async {
    try {
      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Delete File'),
            content: Text(
              'Are you sure you want to delete ${path.basename(file.path)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await file.delete();
        await _loadFiles();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error deleting file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get file extension
  String _getFileExtension(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return extension.isEmpty ? 'file' : extension.substring(1);
  }

  // Get icon for file type
  IconData _getFileIcon(String fileName) {
    final extension = _getFileExtension(fileName);

    // Image files
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(extension)) {
      return Icons.image;
    }
    // Video files
    else if (['mp4', 'avi', 'mkv', 'mov'].contains(extension)) {
      return Icons.video_file;
    }
    // Audio files
    else if (['mp3', 'wav', 'flac', 'aac'].contains(extension)) {
      return Icons.audio_file;
    }
    // Document files
    else if (['pdf', 'doc', 'docx', 'txt'].contains(extension)) {
      return Icons.description;
    }
    // Default
    else {
      return Icons.insert_drive_file;
    }
  }

  // Files List Widget
  Widget _buildFilesList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No files uploaded',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap + button to upload files',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final fileName = path.basename(file.path);
          final fileSize = file.lengthSync();

          return ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getFileIcon(fileName), color: Colors.blue),
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              filesize(fileSize),
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteFile(file),
            ),
            onTap: () {
              // You can add file opening functionality here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File: $fileName'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Storage Calculator Widget
  Widget _buildStorageCalculator() {
    // Calculate storage by file type
    Map<String, int> storageByType = {
      'Images': 0,
      'Videos': 0,
      'Audio': 0,
      'Documents': 0,
      'Others': 0,
    };

    Map<String, int> countByType = {
      'Images': 0,
      'Videos': 0,
      'Audio': 0,
      'Documents': 0,
      'Others': 0,
    };

    for (final file in _files) {
      final fileName = path.basename(file.path);
      final extension = _getFileExtension(fileName);
      final fileSize = file.lengthSync();

      if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(extension)) {
        storageByType['Images'] = storageByType['Images']! + fileSize;
        countByType['Images'] = countByType['Images']! + 1;
      } else if (['mp4', 'avi', 'mkv', 'mov'].contains(extension)) {
        storageByType['Videos'] = storageByType['Videos']! + fileSize;
        countByType['Videos'] = countByType['Videos']! + 1;
      } else if (['mp3', 'wav', 'flac', 'aac'].contains(extension)) {
        storageByType['Audio'] = storageByType['Audio']! + fileSize;
        countByType['Audio'] = countByType['Audio']! + 1;
      } else if (['pdf', 'doc', 'docx', 'txt'].contains(extension)) {
        storageByType['Documents'] = storageByType['Documents']! + fileSize;
        countByType['Documents'] = countByType['Documents']! + 1;
      } else {
        storageByType['Others'] = storageByType['Others']! + fileSize;
        countByType['Others'] = countByType['Others']! + 1;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Total Storage Used',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    filesize(_totalSize),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_files.length} files',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Storage by Category
          Text(
            'Storage by Category',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 12),

          // Category Cards
          _buildCategoryCard(
            'Images',
            Icons.image,
            Colors.green,
            storageByType['Images']!,
            countByType['Images']!,
          ),
          _buildCategoryCard(
            'Videos',
            Icons.video_file,
            Colors.red,
            storageByType['Videos']!,
            countByType['Videos']!,
          ),
          _buildCategoryCard(
            'Audio',
            Icons.audio_file,
            Colors.orange,
            storageByType['Audio']!,
            countByType['Audio']!,
          ),
          _buildCategoryCard(
            'Documents',
            Icons.description,
            Colors.purple,
            storageByType['Documents']!,
            countByType['Documents']!,
          ),
          _buildCategoryCard(
            'Others',
            Icons.folder,
            Colors.grey,
            storageByType['Others']!,
            countByType['Others']!,
          ),
        ],
      ),
    );
  }

  // Category Card Widget
  Widget _buildCategoryCard(
    String category,
    IconData icon,
    Color color,
    int size,
    int count,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(category, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$count files'),
        trailing: Text(
          filesize(size),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File Manager'),
        centerTitle: true,
        elevation: 2,
      ),

      // Body changes based on selected tab
      body: _currentIndex == 0 ? _buildFilesList() : _buildStorageCalculator(),

      // Floating Action Button (only show on Files tab)
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _uploadFile,
              tooltip: 'Upload File',
              child: Icon(Icons.add),
            )
          : null,

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'Storage'),
        ],
      ),
    );
  }
}
