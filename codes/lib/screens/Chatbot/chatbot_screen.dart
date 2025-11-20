import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatBotScreen extends StatefulWidget {
  final String profileId; // required
  final String? userId; // optional

  const ChatBotScreen({super.key, required this.profileId, this.userId});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  // Backend URL (FastAPI default from your code)
  static const String _backendBaseUrl = 'http://127.0.0.1:8000';

  // Your backend API key
  static const String _backendApiKey = 'localdev-123';

  final List<String> _suggestedQuestions = const [
    "What is my top spending category?",
    "What is my current balance?",
  ];

  // --------- Build history payload ----------
  /// Convert local _messages into the history format expected by the backend.
  /// Maps:
  ///   sender "user" -> role "user"
  ///   sender "bot"  -> role "assistant"
  List<Map<String, String>> _buildHistoryPayload() {
    final List<Map<String, String>> history = [];
    for (final msg in _messages) {
      final sender = msg['sender'] as String?;
      final text = (msg['text'] ?? '').toString();

      if (text.trim().isEmpty) continue;

      if (sender == 'user') {
        history.add({"role": "user", "content": text});
      } else if (sender == 'bot') {
        history.add({"role": "assistant", "content": text});
      }
    }
    return history;
  }

  // --------- Call backend ----------
  Future<String> _callBackend(
    String userText,
    List<Map<String, String>> history,
  ) async {
    final uri = Uri.parse('$_backendBaseUrl/chat');
    final body = {
      "text": userText,
      "profile_id": widget.profileId,
      "user_id": widget.userId,
      "history": history,
    };

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "x-api-key": _backendApiKey,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception("Backend error ${response.statusCode}: ${response.body}");
    }
    final decoded = jsonDecode(response.body);
    return decoded["answer"]?.toString() ?? "No answer found.";
  }

  // --------- Send message ----------
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final userText = text.trim();

    // Build history BEFORE adding the new user message + "Thinking..."
    final history = _buildHistoryPayload();

    setState(() {
      _messages.add({"sender": "user", "text": userText});
      _messages.add({"sender": "bot", "text": "Thinking..."});
    });
    _controller.clear();
    _scrollToBottom();

    final int botIndex = _messages.length - 1;

    try {
      final botReply = await _callBackend(userText, history);
      setState(() {
        _messages[botIndex] = {"sender": "bot", "text": botReply};
      });
    } catch (e) {
      setState(() {
        _messages[botIndex] = {"sender": "bot", "text": "Connection error: $e"};
      });
    }

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

  // --------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bool isEmpty = _messages.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF14122B),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
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

      // Put the input at the scaffold bottom so it sits flush (no gap)
      bottomNavigationBar: SafeArea(top: false, child: _buildMessageInput()),

      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Expanded(child: isEmpty ? _buildWelcomeScreen() : _buildChatView()),
            if (isEmpty) _buildSuggestedQuestions(),
          ],
        ),
      ),
    );
  }

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
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Surra",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: _suggestedQuestions.map((q) {
          return GestureDetector(
            onTap: () => _sendMessage(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF252346),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                q,
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
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final isUser = msg["sender"] == "user";
        return _buildMessageBubble(msg["text"] ?? "", isUser);
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF252346),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFF3D3763)
                      : const Color(0xFF252346),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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
      decoration: const BoxDecoration(color: Color(0xFF1A1834)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: "Send a message.",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
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
              textInputAction: TextInputAction.send,
              onSubmitted: (text) => _sendMessage(text),
            ),
          ),
          const SizedBox(width: 10),
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
