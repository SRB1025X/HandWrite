import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data'; // For Uint8List
import 'dart:convert'; // For Base64 encoding
import 'package:flutter/foundation.dart' show kIsWeb; // Platform check
import 'package:flutter/services.dart'; // For clipboard functionality
import 'package:shared_preferences/shared_preferences.dart'; // For storing API key

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handwriting Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _responseText = '';
  File? _image; // For mobile/desktop
  Uint8List? _webImage; // For web
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? '';
    });
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() {
      _apiKey = key;
    });
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _image = null;
        });
      } else {
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _image = null;
        });
      } else {
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
        });
      }
    }
  }

  Future<void> _processImage() async {
    if (_image == null && _webImage == null) return;
    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() {
        _responseText = 'API Key not set. Go to Settings.';
      });
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey!,
      );

      final imageBytes = kIsWeb ? _webImage! : await _image!.readAsBytes();

      final response = await model.generateContent([
        Content.multi([DataPart('image/jpeg', imageBytes)]),
        Content.text(
            'Extract the text from this image. Only return the detected text.'),
      ]);

      setState(() {
        _responseText = response.text ?? "No text detected!";
      });
    } catch (e, stackTrace) {
      print("Error: $e");
      print("StackTrace: $stackTrace");
      setState(() {
        _responseText = "Failed to process the image. Error: $e";
      });
    }
  }

  void _copyToClipboard() {
    if (_responseText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _responseText));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied to clipboard!')),
      );
    }
  }

  void _openSettings() {
    TextEditingController apiKeyController =
        TextEditingController(text: _apiKey);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Settings'),
          content: TextField(
            controller: apiKeyController,
            decoration: InputDecoration(labelText: 'Gemini API Key'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _saveApiKey(apiKeyController.text);
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Handwriting Detector'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add Row with both options side-by-side
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _pickImageFromGallery,
                  child: Text('Upload Image'),
                ),
                SizedBox(width: 20), // Space between buttons
                ElevatedButton(
                  onPressed: _takePhoto,
                  child: Text('Take a Photo'),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_webImage != null) Image.memory(_webImage!, height: 200),
            if (_image != null) Image.file(_image!, height: 200),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _processImage,
              child: Text('Detect Handwriting'),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _responseText.isNotEmpty
                    ? _responseText
                    : 'No content generated yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _copyToClipboard,
              child: Text('Copy to Clipboard'),
            ),
          ],
        ),
      ),
    );
  }
}
