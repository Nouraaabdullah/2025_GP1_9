import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';

class ChildFAQScreen extends StatefulWidget {
  const ChildFAQScreen({super.key});

  @override
  State<ChildFAQScreen> createState() => _ChildFAQScreenState();
}

class _ChildFAQScreenState extends State<ChildFAQScreen> {
  final PageController _faqController = PageController(
    viewportFraction: 0.23,
    initialPage: 3,
  );

  final ScrollController _chatScrollController = ScrollController();

  double _currentPage = 3;
  int _selectedIndex = 3;

  final List<Map<String, String>> _messages = [];

  final List<Map<String, String>> _faqs = const [
    {
      "q": "What is Surra?",
      "a":
          "Surra helps kids understand money, saving, and smart spending in a fun and simple way.",
    },
    {
      "q": "How can I save money?",
      "a":
          "You can save money by spending less, planning ahead, and keeping part of your money for later.",
    },
    {
      "q": "What is a budget?",
      "a":
          "A budget is a simple plan that helps you decide how much money to save and how much to spend.",
    },
    {
      "q": "Why should I save money?",
      "a":
          "Saving money helps you reach your goals and buy something important in the future.",
    },
    {
      "q": "What is spending?",
      "a": "Spending means using your money to buy things you need or want.",
    },
    {
      "q": "What is income?",
      "a": "Income is the money you receive, like allowance, rewards, or gifts.",
    },
    {
      "q": "Can I set a savings goal?",
      "a":
          "Yes. A savings goal helps you know what you are saving for and how close you are to getting it.",
    },
    {
      "q": "What happens if I spend too much?",
      "a":
          "If you spend too much, you may not have enough money left for your goals or important things.",
    },
    {
      "q": "How do I track my money?",
      "a":
          "You can track your money by writing down what you earn, what you save, and what you spend.",
    },
    {
      "q": "How can I reach my goal faster?",
      "a":
          "You can reach your goal faster by saving regularly and avoiding unnecessary spending.",
    },
  ];

  final List<List<Color>> _faqColors = const [
    [Color(0xFFC6B0FF), Color(0xFFAA86F7)],
    [Color(0xFFF07AB7), Color(0xFFD85D9F)],
    [Color(0xFFF39A53), Color(0xFFE67E32)],
    [Color(0xFF6896FF), Color(0xFF4F7DF0)],
  ];

  @override
  void initState() {
    super.initState();

    _faqController.addListener(() {
      if (!_faqController.hasClients) return;

      final page = _faqController.page ?? _selectedIndex.toDouble();

      if (!mounted) return;

      setState(() {
        _currentPage = page;
        _selectedIndex = page.round().clamp(0, _faqs.length - 1);
      });
    });
  }

  @override
  void dispose() {
    _faqController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _sendFAQ(int index) {
    final faq = _faqs[index];
    final question = faq["q"] ?? "";
    final answer = faq["a"] ?? "";

    setState(() {
      _messages.add({"sender": "user", "text": question});
      _messages.add({"sender": "bot", "text": answer});
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Color> _cardGradient(int index) {
    if (index == _selectedIndex) {
      return const [Color(0xFF6896FF), Color(0xFF4F7DF0)];
    }
    return _faqColors[index % _faqColors.length];
  }

  double _itemScale(int index) {
    final diff = (index - _currentPage).abs();
    final value = 1.0 - (diff * 0.18);
    return value.clamp(0.72, 1.0);
  }

  double _itemOpacity(int index) {
    final diff = (index - _currentPage).abs();
    final value = 1.0 - (diff * 0.28);
    return value.clamp(0.35, 1.0);
  }

  double _itemHeight(int index) {
    final diff = (index - _currentPage).abs();
    final value = 56 - (diff * 8);
    return value.clamp(42, 56);
  }

  double _itemHorizontalInset(int index) {
    final diff = (index - _currentPage).abs();
    final value = 30 + (diff * 24);
    return value.clamp(30, 72);
  }

  TextStyle _itemTextStyle(int index) {
    final diff = (index - _currentPage).abs();

    if (diff < 0.5) {
      return const TextStyle(
        fontFamily: AppTextStyles.nunito,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      );
    }

    if (diff < 1.5) {
      return const TextStyle(
        fontFamily: AppTextStyles.nunito,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      );
    }

    return TextStyle(
      fontFamily: AppTextStyles.nunito,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: Colors.white.withOpacity(0.92),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KidScaffold(
      showBack: false,
      child: Stack(
        children: [
          const KidBubbles(),

          Positioned(
            top: 10,
            left: 14,
            child: KidBackButton(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 18),
              Center(
                child: Text(
                  "Surra",
                  style: AppTextStyles.nunitoStyle(
                    size: 30,
                    color: AppColors.kPurpleDark,
                    weight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  "FAQs",
                  style: AppTextStyles.nunitoStyle(
                    size: 22,
                    color: AppColors.kPurpleDark.withOpacity(0.9),
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _messages.isEmpty ? _buildEmptyState() : _buildChatArea(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 245,
                child: PageView.builder(
                  controller: _faqController,
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _faqs.length,
                  itemBuilder: (context, index) {
                    final scale = _itemScale(index);
                    final opacity = _itemOpacity(index);
                    final height = _itemHeight(index);
                    final inset = _itemHorizontalInset(index);
                    final colors = _cardGradient(index);

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: opacity,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: inset,
                          vertical: 6,
                        ),
                        child: Transform.scale(
                          scale: scale,
                          child: GestureDetector(
                            onTap: () => _sendFAQ(index),
                            child: Container(
                              height: height,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: colors,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: index == _selectedIndex
                                    ? [
                                        BoxShadow(
                                          color: colors.first.withOpacity(0.28),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    _faqs[index]["q"] ?? "",
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _itemTextStyle(index),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Tap a question below",
              textAlign: TextAlign.center,
              style: AppTextStyles.nunitoStyle(
                size: 28,
                color: AppColors.kPurpleDark,
                weight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Pick any FAQ and Surra will answer it here.",
              textAlign: TextAlign.center,
              style: AppTextStyles.nunitoStyle(
                size: 15,
                color: AppColors.kTextSoft,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg["sender"] == "user";

        return _buildMessageBubble(
          text: msg["text"] ?? "",
          isUser: isUser,
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.kPurpleDark,
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFC6B0FF), Color(0xFFAA86F7)],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kPurpleDark.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                  color: isUser ? Colors.white : AppColors.kText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}