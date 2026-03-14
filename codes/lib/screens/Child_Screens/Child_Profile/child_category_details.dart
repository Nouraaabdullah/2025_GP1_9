import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'child_profile.dart';

// ════════════════════════════════════════════════
//  CHILD CATEGORY DETAIL PAGE
// ════════════════════════════════════════════════
class ChildCategoryDetailPage
    extends
        StatefulWidget {
  final KidCategory category;

  const ChildCategoryDetailPage({
    super.key,
    required this.category,
  });

  @override
  State<
    ChildCategoryDetailPage
  >
  createState() => _ChildCategoryDetailPageState();
}

class _ChildCategoryDetailPageState
    extends
        State<
          ChildCategoryDetailPage
        >
    with
        TickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  static const _kText = Color(
    0xFF2D1B69,
  );
  static const _kTextSoft = Color(
    0xFF7C6FA0,
  );
  static const _kPurple = Color(
    0xFF8B5CF6,
  );
  static const _kPurpleDark = Color(
    0xFF6D28D9,
  );

  bool _isEditing = false;
  bool _saving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _limitCtrl;
  late String _selectedEmoji;
  late Color _selectedColor;

  late AnimationController _pulseController;
  late Animation<
    double
  >
  _pulseAnimation;
  late AnimationController _slideController;
  late Animation<
    Offset
  >
  _slideAnimation;

  final List<
    String
  >
  _emojiOptions = [
    '🍕',
    '🎮',
    '📚',
    '🎨',
    '⚽',
    '🎵',
    '🎬',
    '👕',
    '🍔',
    '🚀',
    '🌟',
    '🎁',
    '🏆',
    '🎭',
    '🍦',
    '🎪',
    '🦋',
    '🌈',
    '🎸',
    '🏄',
    '🎯',
    '🧩',
    '🦄',
    '🎠',
  ];

  final List<
    Color
  >
  _colorOptions = [
    const Color(
      0xFF8B5CF6,
    ),
    const Color(
      0xFF6D28D9,
    ),
    const Color(
      0xFFF472B6,
    ),
    const Color(
      0xFF34D399,
    ),
    const Color(
      0xFF60A5FA,
    ),
    const Color(
      0xFFFBBF24,
    ),
    const Color(
      0xFFFB923C,
    ),
    const Color(
      0xFFFF6B6B,
    ),
    const Color(
      0xFFA78BFA,
    ),
    const Color(
      0xFF2DD4BF,
    ),
    const Color(
      0xFFE879F9,
    ),
    const Color(
      0xFF4ADE80,
    ),
  ];

  Color
  _softFor(
    Color c,
  ) => Color.alphaBlend(
    c.withOpacity(
      0.15,
    ),
    Colors.white,
  );

  String _colorToHex(
    Color color,
  ) {
    final a = color.alpha
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final r = color.red
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final g = color.green
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final b = color.blue
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    return '#$a$r$g$b'.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.category.name,
    );
    _limitCtrl = TextEditingController(
      text: widget.category.limit.toStringAsFixed(
        0,
      ),
    );
    _selectedEmoji = widget.category.emoji;
    _selectedColor = widget.category.color;

    _pulseController =
        AnimationController(
          vsync: this,
          duration: const Duration(
            milliseconds: 1600,
          ),
        )..repeat(
          reverse: true,
        );

    _pulseAnimation =
        Tween<
              double
            >(
              begin: 1.0,
              end: 1.06,
            )
            .animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 400,
      ),
    );

    _slideAnimation =
        Tween<
              Offset
            >(
              begin: const Offset(
                0,
                0.15,
              ),
              end: Offset.zero,
            )
            .animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOutCubic,
              ),
            );

    _slideController.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  double get _pct {
    final lim =
        double.tryParse(
          _limitCtrl.text,
        ) ??
        widget.category.limit;
    return lim >
            0
        ? (widget.category.spent /
                  lim)
              .clamp(
                0.0,
                1.0,
              )
        : 0.0;
  }

  bool get _isAlmost =>
      _pct >
      0.85;
  bool get _isOverHalf =>
      _pct >
      0.5;

  Color get _statusColor => _isAlmost
      ? const Color(
          0xFFFC8181,
        )
      : _isOverHalf
      ? const Color(
          0xFFFBBF24,
        )
      : _selectedColor;

  String get _statusLabel => _isAlmost
      ? 'Almost full! 😬'
      : _isOverHalf
      ? 'Halfway there 🙂'
      : 'Looking good! 🎉';

  void _toggleEdit() {
    if (_saving) return;

    setState(
      () {
        if (_isEditing) {
          _nameCtrl.text = widget.category.name;
          _limitCtrl.text = widget.category.limit.toStringAsFixed(
            0,
          );
          _selectedEmoji = widget.category.emoji;
          _selectedColor = widget.category.color;
        }
        _isEditing = !_isEditing;
      },
    );
  }

  Future<
    void
  >
  _saveChanges() async {
    final newName = _nameCtrl.text.trim();
    final newLimit =
        double.tryParse(
          _limitCtrl.text.trim(),
        ) ??
        widget.category.limit;

    if (newName.isEmpty) {
      _showSnack(
        'Please give your category a name! 😊',
      );
      return;
    }

    if (newLimit <=
        0) {
      _showSnack(
        'Limit must be more than 0 SAR 💰',
      );
      return;
    }

    setState(
      () => _saving = true,
    );

    try {
      final iconColorHex = _colorToHex(
        _selectedColor,
      );

      await _sb
          .from(
            'Category',
          )
          .update(
            {
              'name': newName,
              'monthly_limit': newLimit,
              'icon': _selectedEmoji,
              'icon_color': iconColorHex,
            },
          )
          .eq(
            'category_id',
            widget.category.categoryId,
          );

      if (!mounted) return;

      Navigator.pop(
        context,
        KidCategory(
          categoryId: widget.category.categoryId,
          name: newName,
          emoji: _selectedEmoji,
          spent: widget.category.spent,
          limit: newLimit,
          color: _selectedColor,
          softColor: _softFor(
            _selectedColor,
          ),
          iconName: _selectedEmoji,
          iconColorHex: iconColorHex,
        ),
      );
    } catch (
      e
    ) {
      if (!mounted) return;
      _showSnack(
        'Failed to save changes: $e',
      );
      setState(
        () => _saving = false,
      );
    }
  }

  void _showSnack(
    String msg,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _selectedColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
      ),
    );
  }

  void _showEmojiSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (
            _,
          ) => StatefulBuilder(
            builder:
                (
                  ctx,
                  setSheet,
                ) => Container(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 12,
                    bottom:
                        MediaQuery.of(
                          ctx,
                        ).viewInsets.bottom +
                        24,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(
                        28,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(
                            bottom: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE2D9F3,
                            ),
                            borderRadius: BorderRadius.circular(
                              4,
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'Pick an Icon 🎭',
                        style: TextStyle(
                          fontFamily: 'Fredoka One',
                          fontSize: 20,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Tap any icon to choose it',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextSoft,
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _emojiOptions.map(
                          (
                            e,
                          ) {
                            final isSel =
                                e ==
                                _selectedEmoji;
                            return GestureDetector(
                              onTap: () {
                                setState(
                                  () => _selectedEmoji = e,
                                );
                                Navigator.pop(
                                  ctx,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(
                                  milliseconds: 180,
                                ),
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? _softFor(
                                          _selectedColor,
                                        )
                                      : const Color(
                                          0xFFF5F3FF,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    16,
                                  ),
                                  border: Border.all(
                                    color: isSel
                                        ? _selectedColor
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: _selectedColor.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(
                                              0,
                                              3,
                                            ),
                                          ),
                                        ]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  e,
                                  style: TextStyle(
                                    fontSize: isSel
                                        ? 28
                                        : 22,
                                  ),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _showColorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (
            _,
          ) => StatefulBuilder(
            builder:
                (
                  ctx,
                  setSheet,
                ) => Container(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    36,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(
                        28,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(
                            bottom: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE2D9F3,
                            ),
                            borderRadius: BorderRadius.circular(
                              4,
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'Pick a Color 🎨',
                        style: TextStyle(
                          fontFamily: 'Fredoka One',
                          fontSize: 20,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Changes the card color everywhere',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextSoft,
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: _colorOptions.map(
                          (
                            c,
                          ) {
                            final isSel =
                                c.value ==
                                _selectedColor.value;
                            return GestureDetector(
                              onTap: () {
                                setState(
                                  () => _selectedColor = c,
                                );
                                setSheet(
                                  () {},
                                );
                                Future.delayed(
                                  const Duration(
                                    milliseconds: 200,
                                  ),
                                  () => Navigator.pop(
                                    ctx,
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(
                                  milliseconds: 200,
                                ),
                                width: isSel
                                    ? 58
                                    : 50,
                                height: isSel
                                    ? 58
                                    : 50,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: c.withOpacity(
                                        isSel
                                            ? 0.65
                                            : 0.25,
                                      ),
                                      blurRadius: isSel
                                          ? 18
                                          : 6,
                                      offset: const Offset(
                                        0,
                                        4,
                                      ),
                                    ),
                                  ],
                                ),
                                child: isSel
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final saveTapEnabled = !_saving;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [
              0.0,
              0.45,
              1.0,
            ],
            colors: [
              Color(
                0xFFD4B3F5,
              ),
              Color(
                0xFFB8D4F8,
              ),
              Color(
                0xFFF7B8D4,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      40,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 12,
                        ),
                        _buildHeroCard(),
                        const SizedBox(
                          height: 20,
                        ),
                        _buildProgressCard(),
                        const SizedBox(
                          height: 20,
                        ),
                        _buildSettingsCard(),
                        if (_isEditing) ...[
                          const SizedBox(
                            height: 28,
                          ),
                          IgnorePointer(
                            ignoring: !saveTapEnabled,
                            child: _buildSaveButton(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        0,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _saving
                ? null
                : () => Navigator.pop(
                    context,
                  ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(
                  0.7,
                ),
                borderRadius: BorderRadius.circular(
                  14,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      0.06,
                    ),
                    blurRadius: 8,
                    offset: const Offset(
                      0,
                      2,
                    ),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _kText,
                size: 18,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          const Expanded(
            child: Text(
              'Category Details',
              style: TextStyle(
                fontFamily: 'Fredoka One',
                fontSize: 22,
                color: _kText,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleEdit,
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 250,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: _isEditing
                    ? const LinearGradient(
                        colors: [
                          Color(
                            0xFFFC8181,
                          ),
                          Color(
                            0xFFE53E3E,
                          ),
                        ],
                      )
                    : const LinearGradient(
                        colors: [
                          Color(
                            0xFF8B5CF6,
                          ),
                          Color(
                            0xFF6D28D9,
                          ),
                        ],
                      ),
                borderRadius: BorderRadius.circular(
                  20,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isEditing
                                ? const Color(
                                    0xFFE53E3E,
                                  )
                                : _kPurpleDark)
                            .withOpacity(
                              0.35,
                            ),
                    blurRadius: 12,
                    offset: const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isEditing
                        ? Icons.close_rounded
                        : Icons.edit_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    _isEditing
                        ? 'Cancel'
                        : 'Edit',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 350,
      ),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _selectedColor.withOpacity(
              0.85,
            ),
            _selectedColor,
          ],
        ),
        borderRadius: BorderRadius.circular(
          32,
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withOpacity(
              0.4,
            ),
            blurRadius: 28,
            offset: const Offset(
              0,
              10,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isEditing) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _showColorSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        0.25,
                      ),
                      borderRadius: BorderRadius.circular(
                        20,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(
                          0.45,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  0.15,
                                ),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        const Text(
                          '🎨  Change Color',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
          ],
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onTap: _isEditing
                  ? _showEmojiSheet
                  : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        0.25,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(
                            0.3,
                          ),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedEmoji,
                      style: const TextStyle(
                        fontSize: 44,
                      ),
                    ),
                  ),
                  if (_isEditing)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.12,
                            ),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: _selectedColor,
                        size: 15,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          _isEditing
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.25,
                    ),
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(
                        0.5,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _nameCtrl,
                    textAlign: TextAlign.center,
                    onChanged:
                        (
                          _,
                        ) => setState(
                          () {},
                        ),
                    style: const TextStyle(
                      fontFamily: 'Fredoka One',
                      fontSize: 24,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      hintText: 'Category name...',
                      hintStyle: TextStyle(
                        fontFamily: 'Fredoka One',
                        fontSize: 22,
                        color: Colors.white.withOpacity(
                          0.5,
                        ),
                      ),
                    ),
                  ),
                )
              : Text(
                  _nameCtrl.text.trim().isEmpty
                      ? widget.category.name
                      : _nameCtrl.text,
                  style: const TextStyle(
                    fontFamily: 'Fredoka One',
                    fontSize: 28,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
          const SizedBox(
            height: 10,
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.22,
              ),
              borderRadius: BorderRadius.circular(
                20,
              ),
            ),
            child: Text(
              _statusLabel,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final lim =
        double.tryParse(
          _limitCtrl.text,
        ) ??
        widget.category.limit;
    final pct =
        lim >
            0
        ? (widget.category.spent /
                  lim)
              .clamp(
                0.0,
                1.0,
              )
        : 0.0;
    final pctInt =
        (pct *
                100)
            .toStringAsFixed(
              0,
            );
    final remaining =
        (lim -
                widget.category.spent)
            .clamp(
              0.0,
              double.infinity,
            );

    return Container(
      padding: const EdgeInsets.all(
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          28,
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withOpacity(
              0.12,
            ),
            blurRadius: 20,
            offset: const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spending Overview',
                style: TextStyle(
                  fontFamily: 'Fredoka One',
                  fontSize: 18,
                  color: _kText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _softFor(
                    _selectedColor,
                  ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: Text(
                  '$pctInt%',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: _isAlmost
                        ? const Color(
                            0xFFE53E3E,
                          )
                        : _selectedColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          Stack(
            children: [
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: _softFor(
                    _selectedColor,
                  ),
                  borderRadius: BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 600,
                ),
                curve: Curves.easeOutCubic,
                height: 16,
                width:
                    (MediaQuery.of(
                          context,
                        ).size.width -
                        84) *
                    pct,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _statusColor.withOpacity(
                        0.7,
                      ),
                      _statusColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    10,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _statusColor.withOpacity(
                        0.4,
                      ),
                      blurRadius: 6,
                      offset: const Offset(
                        0,
                        2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  label: 'Spent',
                  value: '${widget.category.spent.toStringAsFixed(2)} SAR',
                  color: _selectedColor,
                  soft: _softFor(
                    _selectedColor,
                  ),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: _buildStatChip(
                  label: 'Limit',
                  value: '${lim.toStringAsFixed(2)} SAR',
                  color: _kPurple,
                  soft: const Color(
                    0xFFEDE9FE,
                  ),
                  icon: Icons.flag_rounded,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: _buildStatChip(
                  label: 'Left',
                  value: '${remaining.toStringAsFixed(2)} SAR',
                  color: const Color(
                    0xFF34D399,
                  ),
                  soft: const Color(
                    0xFFD1FAE5,
                  ),
                  icon: Icons.savings_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required Color soft,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _kText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 300,
      ),
      padding: const EdgeInsets.all(
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          28,
        ),
        border: _isEditing
            ? Border.all(
                color: _kPurple.withOpacity(
                  0.4,
                ),
                width: 2,
              )
            : Border.all(
                color: Colors.transparent,
                width: 2,
              ),
        boxShadow: [
          BoxShadow(
            color:
                (_isEditing
                        ? _kPurple
                        : Colors.black)
                    .withOpacity(
                      0.08,
                    ),
            blurRadius: 20,
            offset: const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFEDE9FE,
                  ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: _kPurple,
                  size: 18,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Text(
                'Category Settings',
                style: TextStyle(
                  fontFamily: 'Fredoka One',
                  fontSize: 18,
                  color: _kText,
                ),
              ),
              if (_isEditing) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFEDE9FE,
                    ),
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Text(
                    'Editing ✏️',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: _kPurple,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          const Text(
            'Monthly Limit (SAR)',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          AnimatedContainer(
            duration: const Duration(
              milliseconds: 250,
            ),
            decoration: BoxDecoration(
              color: _isEditing
                  ? const Color(
                      0xFFEDE9FE,
                    )
                  : const Color(
                      0xFFF5F3FF,
                    ),
              borderRadius: BorderRadius.circular(
                16,
              ),
              border: Border.all(
                color: _isEditing
                    ? _kPurple.withOpacity(
                        0.5,
                      )
                    : const Color(
                        0xFFEDE9FE,
                      ),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _limitCtrl,
              enabled: _isEditing,
              onChanged:
                  (
                    _,
                  ) => setState(
                    () {},
                  ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(
                    r'^\d+\.?\d{0,2}',
                  ),
                ),
              ],
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _kText,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 50',
                hintStyle: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: _kTextSoft.withOpacity(
                    0.6,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                prefixIcon: const Icon(
                  Icons.flag_rounded,
                  color: _kPurple,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saving
          ? null
          : _saveChanges,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 18,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _selectedColor.withOpacity(
                0.85,
              ),
              _selectedColor,
            ],
          ),
          borderRadius: BorderRadius.circular(
            22,
          ),
          boxShadow: [
            BoxShadow(
              color: _selectedColor.withOpacity(
                0.45,
              ),
              blurRadius: 18,
              offset: const Offset(
                0,
                6,
              ),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_saving) ...[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Text(
                'Saving...',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
            ] else ...[
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(
                width: 10,
              ),
              const Text(
                'Save Changes! 🎉',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
