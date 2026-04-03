import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _Question {
  final String question;
  final String answer;
  const _Question(this.question, this.answer);
}

class _Category {
  final String label;
  final IconData icon;
  final Color color;
  final List<_Question> questions;
  const _Category({
    required this.label,
    required this.icon,
    required this.color,
    required this.questions,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Content
// ─────────────────────────────────────────────────────────────────────────────
const List<_Category> _categories = [
  _Category(
    label: "Saving",
    icon: Icons.savings_rounded,
    color: Color(0xFF6896FF),
    questions: [
      _Question(
        "How can I start saving?",
        "Start small! Every time you receive money, put a little aside before spending anything else. You can also head to the Saving page in Surra, create saving goals, and set a goal name, target amount, and target date for each one. It only takes a few seconds to get started! 💰",
      ),
      _Question(
        "How much of my money should I save?",
        "There is no perfect number, but saving even a small amount regularly is better than nothing. The key is to make it a habit every single time you receive money. Check your dashboard in Surra to see how your saving is adding up over time! 📈",
      ),
      _Question(
        "How do I know if my saving is working?",
        "Head to your Saving page in Surra! You can see all your saving goals, track how much you have saved, and watch your progress bar fill up as you get closer to your goal. Seeing that bar grow is one of the best feelings! 🎉",
      ),

    ],
  ),
  _Category(
    label: "Spending",
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFFF07AB7),
    questions: [
      _Question(
        "How do I know if I am spending too much?",
        "If you keep running out of money before your next allowance, that is a sign. You can also check the Category Breakdown chart on your Surra dashboard — it shows exactly how much you have spent in each category, so you can spot where most of your money is going! 📊",
      ),
      _Question(
        "What should I think about before buying something?",
        "Ask yourself three things: Do I really need this? Do I have enough money for it without touching my savings? Will buying it slow down my goal? If the answers feel off, wait before deciding. 🤔",
      ),
      _Question(
        "How do I spend wisely?",
        "Plan what you want to spend before you spend it. In Surra, when you add a category you can set a monthly spending limit for it — that way Surra helps you stay on track automatically. Spending wisely means knowing your limits before you reach them! ✅",
      ),
      _Question(
        "What is the difference between a need and a want?",
        "A need is something you must have — like food, clothes, or school supplies. A want is something nice to have but not necessary — like a new game or a snack. Always take care of your needs first, then enjoy your wants if you still have money left! ✅",
      ),
    ],
  ),
  _Category(
    label: "Budgeting",
    icon: Icons.pie_chart_rounded,
    color: Color(0xFF8B5CF6),
    questions: [
      _Question(
        "What is a budget?",
        "A budget is a simple plan for your money. You decide ahead of time how much to save and how much to spend, so you are never caught off guard. Think of it as a map that guides every coin you have! 🗺️",
      ),
      _Question(
        "How do I make my own budget?",
        "Write down how much money you have. Then split it — some for saving, some for spending, some towards your goal. In Surra, logging every transaction helps you stick to that plan and see in real time how you are doing. ✏️",
      ),
      _Question(
        "Why do I need a budget if I don't have much money?",
        "A budget is even more important when you have less! It helps you make the most of every single coin and stops you from running out when you need money the most. 🪙",
      ),
      _Question(
        "What if I go over my budget?",
        "No stress — just look at what happened, learn from it, and adjust your plan. A budget is not about being perfect, it is about getting a little better every time. 📚",
      ),
    ],
  ),
  _Category(
    label: "Goals",
    icon: Icons.flag_rounded,
    color: Color(0xFFF39A53),
    questions: [
      _Question(
        "What is a savings goal?",
        "A savings goal is something you are working towards — like a toy, a game, or a special experience. Having a goal makes saving feel exciting instead of boring! 🎯",
      ),
      _Question(
        "How do I set a goal in Surra?",
        "Go to the Saving page and tap the + button to create a new saving goal. Give it a name, set a target amount, and pick a target date. Surra will track your progress and show you how close you are — step by step! 🚀",
      ),
      _Question(
        "What if my goal feels too far away?",
        "Break it into smaller steps. Instead of thinking about the full amount, focus on saving a little each week. Open your Saving page anytime to see how far you have already come — every small step counts! 🏆",
      ),
      _Question(
        "Can I have more than one goal?",
        "Yes! You can create multiple saving goals on the Saving page — one for each thing you are working towards. Just make sure you are adding to each one regularly so all your goals keep moving forward. ⭐",
      ),
    ],
  ),
  _Category(
    label: "Tips & Tricks",
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFAA86F7),
    questions: [
      _Question(
        "What is the best money habit I can build?",
        "Save before you spend — every single time. When you receive money, put your savings aside first, then decide what to do with the rest. This one simple habit changes everything over time! ⭐",
      ),
      _Question(
        "How can Surra help me manage my money better?",
        "Surra has everything you need! The dashboard shows your earning overview, financial trends, and a category breakdown of your spending. The Saving page lets you create goals and track progress. Tap the + button in the bottom bar to log any expense or earning. Use it every day for the best results! 📱",
      ),
      _Question(
        "How do I avoid spending on things I don't need?",
        "Before buying anything unplanned, check your dashboard first. Look at how much you have already spent this month and whether it fits your budget. Seeing the real numbers is the best way to make a smart decision! 💡",
      ),
      _Question(
        "How do I stay motivated to keep saving?",
        "Open your Saving page regularly and look at your goal progress bars. Seeing how far you have already come makes you want to keep going. Celebrate every time a bar moves forward — you are doing great! 🎉",
      ),
    ],
  ),
  _Category(
    label: "About Surra",
    icon: Icons.apps_rounded,
    color: Color(0xFF34C98A),
    questions: [
      _Question(
        "What does the Dashboard show me?",
        "The dashboard is your full money summary! At the top you can see your current balance. Below that is the Earning Overview — a chart that shows how much of your earning is left after expenses, along with your total expenses, and earnings for the selected period. Then there is Financial Trends, a bar chart comparing your expenses, and earnings over time. Finally, the Savings Over Time line chart shows how your monthly savings have changed. Switch between Weekly, Monthly, and Yearly views anytime! 📊",
      ),
      _Question(
        "What can I do on the Saving page?",
        "On the Saving page you can create saving goals, set a name, target amount, and target date for each one, and watch your progress bar fill up as you save. At the top you can see your total monthly saving and available amount. Your goals are organized into tabs — Active, Done, Missed, and Got it — so you always know where each goal stands! 🏦",
      ),
      _Question(
        "How do I log an expense or earning?",
        "To log a transaction, tap the + button in the bottom navigation bar. Select whether it is an Expense or an Earning, then enter the amount and date. If it is an expense, you can also choose an existing category or create a new custom one! Hit Log and Surra will take care of the rest!",
      ),
      _Question(
        "How do I add a new category?",
        "Go to your Profile page and tap Add Category. Give it a name, pick an icon, choose a color, and set a monthly spending limit if you want one. You can also add a category on the spot while logging a transaction by tapping the + button next to Category. Your custom category will appear every time you log! 🗂️",
      ),
      _Question(
        "What is the chatbot and how does it help?",
        "The chatbot is Surra's helpful assistant — that is me! You can browse topics like saving, spending, budgeting, goals, and how to use the app, then pick a question and I will answer it for you. Whenever you are unsure about something, just open the FAQ and I am here! 🤖",
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Typing effect widget
// ─────────────────────────────────────────────────────────────────────────────
class _TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onDone;

  const _TypingText({
    super.key,
    required this.text,
    required this.style,
    this.onDone,
  });

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText> {
  String _displayed = "";
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _typeNext();
  }

  @override
  void didUpdateWidget(_TypingText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      setState(() {
        _displayed = "";
        _index = 0;
      });
      _typeNext();
    }
  }

  void _typeNext() {
    if (!mounted || _index >= widget.text.length) {
      if (mounted && _index >= widget.text.length) {
        widget.onDone?.call();
      }
      return;
    }
    Future.delayed(const Duration(milliseconds: 18), () {
      if (!mounted) return;
      setState(() {
        _displayed += widget.text[_index];
        _index++;
      });
      _typeNext();
    });
  }

  @override
  Widget build(BuildContext context) => Text(_displayed, style: widget.style);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen states
// ─────────────────────────────────────────────────────────────────────────────
enum _ViewState { topics, questions, answer }

class ChildFAQScreen extends StatefulWidget {
  const ChildFAQScreen({super.key});

  @override
  State<ChildFAQScreen> createState() => _ChildFAQScreenState();
}

class _ChildFAQScreenState extends State<ChildFAQScreen>
    with SingleTickerProviderStateMixin {
  _ViewState _view = _ViewState.topics;
  _Category? _selectedCategory;
  _Question? _selectedQuestion;
  bool _typingDone = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateTo(_ViewState view) {
    _animController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _view = view;
        _typingDone = false;
      });
      _animController.forward();
    });
  }

  void _pickCategory(_Category cat) {
    _selectedCategory = cat;
    _navigateTo(_ViewState.questions);
  }

  void _pickQuestion(_Question q) {
    _selectedQuestion = q;
    _navigateTo(_ViewState.answer);
  }

  void _goToTopics() => _navigateTo(_ViewState.topics);
  void _goToQuestions() => _navigateTo(_ViewState.questions);

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
                if (_view == _ViewState.answer) {
                  _goToQuestions();
                } else if (_view == _ViewState.questions) {
                  _goToTopics();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 10),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildBody(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  // ── Breadcrumb ─────────────────────────────────────────────────────────────
  Widget _buildBreadcrumb() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goToTopics,
            child: Text(
              "Topics",
              style: TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.kPurpleDark.withOpacity(0.45),
              ),
            ),
          ),
          if (_selectedCategory != null) ...[
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.kPurpleDark.withOpacity(0.35)),
            GestureDetector(
              onTap: _view == _ViewState.answer ? _goToQuestions : null,
              child: Text(
                _selectedCategory!.label,
                style: TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _view == _ViewState.answer
                      ? AppColors.kPurpleDark.withOpacity(0.45)
                      : AppColors.kPurpleDark,
                ),
              ),
            ),
          ],
          if (_view == _ViewState.answer && _selectedQuestion != null) ...[
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.kPurpleDark.withOpacity(0.35)),
            Expanded(
              child: Text(
                _selectedQuestion!.question,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.kPurpleDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Body router ────────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_view) {
      case _ViewState.topics:
        return _buildTopicList();
      case _ViewState.questions:
        return _buildQuestionList();
      case _ViewState.answer:
        return _buildAnswerView();
    }
  }

  // ── Topic list — 2-column colorful grid ───────────────────────────────────
  Widget _buildTopicList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "What would you like to learn about?",
            style: AppTextStyles.nunitoStyle(
              size: 14,
              color: AppColors.kTextSoft,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: _categories.length,
            itemBuilder: (_, i) => _buildTopicCard(_categories[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicCard(_Category cat) {
    return GestureDetector(
      onTap: () => _pickCategory(cat),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cat.color, cat.color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: cat.color.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circle top-right
            Positioned(
              top: -14,
              right: -14,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -10,
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(cat.icon, size: 22, color: Colors.white),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.label,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            "Explore",
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded,
                              size: 11,
                              color: Colors.white.withOpacity(0.8)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Question list — left accent bar style ──────────────────────────────────
  Widget _buildQuestionList() {
    final cat = _selectedCategory!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colored header banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cat.color, cat.color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: cat.color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.label,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Pick a question below",
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: cat.questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _buildQuestionTile(cat, cat.questions[i], i),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionTile(_Category cat, _Question q, int index) {
    return GestureDetector(
      onTap: () => _pickQuestion(q),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cat.color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left color accent bar
            Container(
              width: 5,
              height: 58,
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Number badge
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: cat.color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  q.question,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kPurpleDark,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: cat.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Answer view — chatbot style ────────────────────────────────────────────
  Widget _buildAnswerView() {
    final cat = _selectedCategory!;
    final q = _selectedQuestion!;

    return Column(
      children: [
        // ── Chat messages area ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [

              // ── User message (question) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cat.color, cat.color.withOpacity(0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cat.color.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        q.question,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // User avatar
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cat.color.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(Icons.person_rounded,
                        size: 18, color: cat.color),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Bot typing indicator then answer ──
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Bot avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cat.color, cat.color.withOpacity(0.65)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cat.color.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 8),

                  // Bot bubble
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Surra",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: cat.color,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _TypingText(
                            key: ValueKey(q.question),
                            text: q.answer,
                            onDone: () {
                              if (mounted)
                                setState(() => _typingDone = true);
                            },
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.65,
                              color: AppColors.kText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Bottom action bar ──
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: _typingDone ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !_typingDone,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "What would you like to do next?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kTextSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // More Questions — full width
                  GestureDetector(
                    onTap: _goToQuestions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cat.color, cat.color.withOpacity(0.75)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cat.color.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child:  Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "More ${cat.label} Questions",
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                GestureDetector(
                  onTap: _goToTopics,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cat.color.withOpacity(0.22),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 14,
                          color: cat.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Back to all topics",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: cat.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Triangle painter for speech bubble pointer ────────────────────────────────
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}