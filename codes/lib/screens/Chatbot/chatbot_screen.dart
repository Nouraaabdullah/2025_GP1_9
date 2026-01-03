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
  final FocusNode _inputFocusNode = FocusNode();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  // Backend URL (FastAPI default from your code)
static const String _backendBaseUrl = 'http://10.0.2.2:8080';


  // Your backend API key
  static const String _backendApiKey = 'localdev-123';

  // Suggested questions (balance removed, new question added)
  final List<String> _suggestedQuestions = const [
    "What is my top spending category?",
    "The effects of item purchase",
  ];

  // --------- Build history payload ----------
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

  // Handle tapping on suggested questions
  void _onSuggestedTap(String q) {
    if (q == "The effects of item purchase") {
      const prefix = "Can I buy an item worth ";
      setState(() {
        _controller.text = prefix;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      });
      FocusScope.of(context).requestFocus(_inputFocusNode);
    } else {
      _sendMessage(q);
    }
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

      // NO bottomNavigationBar – input lives inside the body at the bottom
      body: SafeArea(
        top: true,
        bottom: false, // allow it to touch the absolute bottom
        child: Column(
          children: [
            Expanded(child: isEmpty ? _buildWelcomeScreen() : _buildChatView()),

            if (isEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom:
                      18, // <-- This adds space between questions & input bar
                ),
                child: _buildSuggestedQuestionsRow(),
              ),

            // Always at the very bottom
            _buildMessageInput(),
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

  // Horizontal suggested questions row on main background
  Widget _buildSuggestedQuestionsRow() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final q = _suggestedQuestions[index];
          return GestureDetector(
            onTap: () => _onSuggestedTap(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF252346),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: Text(
                  q,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          );
        },
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

  // Input bar that now touches the bottom
  Widget _buildMessageInput() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1A1834)),
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 15,
        bottom: 20, // ← lift the bar up by 6px
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _inputFocusNode,
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
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
