import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final List<String> _suggestedQuestions = [
    "Is now a good time to buy gold?",
    "How much can I spend this week?",
  ];

  // 📤 Handle picking either image or file
  Future<void> _showUploadOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1B32),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 60,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.white),
                  title: const Text('Upload an Image',
                      style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file,
                      color: Colors.white),
                  title: const Text('Upload a File',
                      style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickFile();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🖼 Pick image from gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _messages.add({
          "sender": "user",
          "text": "[Image sent]",
          "imagePath": image.path,
        });
        _messages.add({
          "sender": "bot",
          "text": "Got your image 📸 — image analysis coming soon!"
        });
      });
      _scrollToBottom();
    }
  }

  // 📄 Pick any file (pdf, docx, etc.)
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      setState(() {
        _messages.add({
          "sender": "user",
          "text": "📎 Uploaded file: ${file.name}",
        });
        _messages.add({
          "sender": "bot",
          "text": "File received! I’ll soon support file reading 📄",
        });
      });
      _scrollToBottom();
    }
  }

  // ✉ Send a text message
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({"sender": "user", "text": text});
      _messages.add({
        "sender": "bot",
        "text":
            "Gold prices are currently stable with slight upward trends. For long-term saving, buying now is fine — but for short-term profit, consider waiting for dips."
      });
    });
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = _messages.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF14122B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context), // ✅ Always goes back
        ),
        title: const Text(
          "Surra",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: isEmpty ? _buildWelcomeScreen() : _buildChatView()),
            if (isEmpty) _buildSuggestedQuestions(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  // 🌟 Welcome screen with glowing aura
  Widget _buildWelcomeScreen() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF7D5EF6),
                  blurRadius: 100,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Surra",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your financial assistant",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: _suggestedQuestions.map((question) {
          return GestureDetector(
            onTap: () => _sendMessage(question),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF252346),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                question,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg["sender"] == "user";
        final imagePath = msg["imagePath"];
        return _buildMessageBubble(msg["text"]!, isUser, imagePath: imagePath);
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, {String? imagePath}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252346),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color:
                      isUser ? const Color(0xFF3D3763) : const Color(0xFF252346),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: imagePath != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              File(imagePath),
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1834),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Row(
        children: [
          // ➕ Upload button with popup
          GestureDetector(
            onTap: _showUploadOptions,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF252346),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'Poppins',
              ),
              decoration: InputDecoration(
                hintText: "Send a message.",
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 15,
                  fontFamily: 'Poppins',
                ),
                filled: true,
                fillColor: const Color(0xFF252346),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (text) => _sendMessage(text),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7D5EF6), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
