import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriHelp Bot',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.grey[850],
      ),
      home: ChatScreen(),
    );
  }
}

class Message {
  final String content;
  final bool isUserMessage;
  final DateTime timestamp;
  final String? imageBase64;

  Message({
    required this.content,
    required this.isUserMessage,
    required this.timestamp,
    this.imageBase64,
  });
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  Future<void> _pickImage() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Image Source"),
          actions: [
            TextButton(
              child: Text("Camera"),
              onPressed: () async {
                Navigator.of(context).pop();
                final pickedFile =
                    await _picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  await _handlePickedImage(pickedFile);
                }
              },
            ),
            TextButton(
              child: Text("Gallery"),
              onPressed: () async {
                Navigator.of(context).pop();
                final pickedFile =
                    await _picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  await _handlePickedImage(pickedFile);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePickedImage(XFile pickedFile) async {
    final file = File(pickedFile.path);
    final fileName = file.uri.pathSegments.last;
    final now = DateTime.now();

    // Convert the image to base64
    final base64Image = base64Encode(await file.readAsBytes());
    print('File path: ${pickedFile.path}');

// Construct the Base64 data string (without data URL prefix)
    final imageData =
        'data:image/jpeg;base64,$base64Image'; // Ensure the prefix matches the server's expectation

    // Update the UI with the new message
    setState(() {
      _messages.add(Message(
        content: base64Image,
        isUserMessage: true,
        timestamp: now,
        imageBase64: base64Image,
      ));
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });

    // Create a multipart request
    final uri = Uri.parse('https://app.lohar.pk/upload_image');
    final request = http.MultipartRequest('POST', uri);

    // Attach the Base64 image data as a field
    request.fields['image'] = imageData;
    request.fields['name'] = fileName;
    // Send the request
    // Send the request and get the response
    final streamedResponse = await request.send();

    // Convert the streamed response to a regular response
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      print(responseData);
      // final responseData = "Bot Response when Image";
      setState(() {
        _messages.add(Message(
          content: responseData['rag_result'],
          // content: responseData,
          isUserMessage: false,
          timestamp: DateTime.now(),
        ));
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    } else {
      Fluttertoast.showToast(
            msg: response.body,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
      print(response.body);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.isNotEmpty) {
      final now = DateTime.now();
      setState(() {
        _messages.add(Message(
          content: text,
          isUserMessage: true,
          timestamp: now,
        ));
        _messages.sort(
            (a, b) => a.timestamp.compareTo(b.timestamp)); // Sort by timestamp
        _messageController.clear();
      });

      final response = await http.post(
        Uri.parse('https://app.lohar.pk/get'),
        body: {'msg': text}, // Form data format
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      if (response.statusCode == 200) {
        final responseData = response.body;
        // final responseData = "Bot Respnse When Text";

        setState(() {
          _messages.add(Message(
            content: responseData,
            isUserMessage: false,
            timestamp: DateTime.now(),
          ));
          _messages.sort((a, b) =>
              a.timestamp.compareTo(b.timestamp)); // Sort by timestamp
        });
        _scrollToBottom();
      } else {
        Fluttertoast.showToast(
            msg: response.body,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
        print(response.body);
      }
    }
  }

  Widget _buildMessage(Message message) {
    final time =
        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    // Calculate maxWidth as 70% of the screen width
    final maxWidth = MediaQuery.of(context).size.width * 0.7;

    if (message.isUserMessage) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: EdgeInsets.all(8.0),
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.imageBase64 != null)
                  Image.memory(
                    base64Decode(message.imageBase64!),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                if (message.imageBase64 == null)
                  Text(
                    message.content,
                    style: TextStyle(color: Colors.white),
                    softWrap: true,
                  ),
                SizedBox(height: 5),
                Text(time, style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
          CircleAvatar(
            backgroundImage: AssetImage('assets/user.png'),
            radius: 20,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          CircleAvatar(
            backgroundImage: AssetImage('assets/bot1.png'),
            radius: 20,
          ),
          Container(
            padding: EdgeInsets.all(8.0),
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(color: Colors.white),
                  softWrap: true,
                ),
                SizedBox(height: 5),
                Text(time,
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ],
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                
                CircleAvatar(
                  radius: 20, // Adjust size as needed
                  backgroundImage: AssetImage(
                      'assets/bot1.png'), // Replace with your image path
                  backgroundColor: Colors.transparent,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green, // Online status color
                      
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 10), // Space between avatar and text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NutriGuide',
                  style: TextStyle(fontSize: 18), // Main text style
                ),
                Text(
                  'Ask me anything',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70, // Small text color
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.attach_file),
            onPressed: _pickImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                // Convert Message to Widget
                final message = _messages[index];
                return _buildMessage(message);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
