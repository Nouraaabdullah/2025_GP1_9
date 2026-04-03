import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/utils/auth_helpers.dart';

class EditChildProfilePage
    extends
        StatefulWidget {
  const EditChildProfilePage({
    super.key,
  });

  @override
  State<
    EditChildProfilePage
  >
  createState() => _EditChildProfilePageState();
}

class _EditChildProfilePageState
    extends
        State<
          EditChildProfilePage
        > {
  final _sb = Supabase.instance.client;
  final _formKey =
      GlobalKey<
        FormState
      >();
  final TextEditingController _fullNameController = TextEditingController();

  static const _kPurple = Color(
    0xFF8B5CF6,
  );
  static const _kPurpleDark = Color(
    0xFF6D28D9,
  );
  static const _kPink = Color(
    0xFFF472B6,
  );
  static const _kText = Color(
    0xFF2D1B69,
  );
  static const _kTextSoft = Color(
    0xFF7C6FA0,
  );

  static const _kidBg = LinearGradient(
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
  );

  final List<
    String
  >
  _iconOptions = const [
    '🐣',
    '🦄',
    '🐯',
    '🦊',
    '🐸',
    '🐼',
    '🦁',
    '🐧',
    '🦋',
    '🌸',
  ];

  bool _loading = true;
  bool _saving = false;

  String _selectedIcon = '⭐';

  @override
  void initState() {
    super.initState();
    _loadChildProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<
    String
  >
  _getProfileId() async {
    final profileId = await getProfileId(
      context,
    );
    if (profileId ==
        null) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (
            _,
          ) => false,
        );
      }
      throw Exception(
        'User not authenticated',
      );
    }
    return profileId;
  }

  Future<
    void
  >
  _loadChildProfile() async {
    setState(
      () => _loading = true,
    );

    try {
      final profileId = await _getProfileId();

      final profile = await _sb
          .from(
            'User_Profile',
          )
          .select(
            'full_name',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .maybeSingle();

      final relation = await _sb
          .from(
            'Child_Guardian',
          )
          .select(
            'icon',
          )
          .eq(
            'child_id',
            profileId,
          )
          .maybeSingle();

      if (!mounted) return;

      setState(
        () {
          _fullNameController.text =
              (profile?['full_name']
                      as String?)
                  ?.trim() ??
              '';
          _selectedIcon =
              (relation?['icon']
                          as String?)
                      ?.trim()
                      .isNotEmpty ==
                  true
              ? (relation!['icon']
                        as String)
                    .trim()
              : '⭐';
          _loading = false;
        },
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error loading child profile: $e',
      );
      if (!mounted) return;
      setState(
        () => _loading = false,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load profile: $e',
          ),
        ),
      );
    }
  }

  InputDecoration _inputDecoration(
    String hint,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _kTextSoft,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: Color(
            0xFFE9DDFC,
          ),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: Color(
            0xFFE9DDFC,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: _kPurple,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Future<
    void
  >
  _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(
      () => _saving = true,
    );

    try {
      final profileId = await _getProfileId();
      final fullName = _fullNameController.text.trim();

      await _sb
          .from(
            'User_Profile',
          )
          .update(
            {
              'full_name': fullName,
            },
          )
          .eq(
            'profile_id',
            profileId,
          );

      await _sb
          .from(
            'Child_Guardian',
          )
          .update(
            {
              'icon': _selectedIcon,
            },
          )
          .eq(
            'child_id',
            profileId,
          );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error saving child profile: $e',
      );

      if (!mounted) return;
      setState(
        () => _saving = false,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save changes: $e',
          ),
        ),
      );
    }
  }

  void _goLeft() {
    final currentIndex = _iconOptions.indexOf(
      _selectedIcon,
    );
    final newIndex =
        currentIndex <=
            0
        ? _iconOptions.length -
              1
        : currentIndex -
              1;

    setState(
      () {
        _selectedIcon = _iconOptions[newIndex];
      },
    );
  }

  void _goRight() {
    final currentIndex = _iconOptions.indexOf(
      _selectedIcon,
    );
    final newIndex =
        currentIndex >=
            _iconOptions.length -
                1
        ? 0
        : currentIndex +
              1;

    setState(
      () {
        _selectedIcon = _iconOptions[newIndex];
      },
    );
  }

  Widget _buildIconSelector() {
    return Column(
      children: [
        const Text(
          'Choose Your Icon',
          style: TextStyle(
            color: _kText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(
          height: 18,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ArrowButton(
              icon: Icons.chevron_left_rounded,
              onTap: _goLeft,
            ),
            const SizedBox(
              width: 18,
            ),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(
                      0xFF8B6BFF,
                    ),
                    Color(
                      0xFF6E4CF4,
                    ),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kPurpleDark.withOpacity(
                      0.28,
                    ),
                    blurRadius: 18,
                    offset: const Offset(
                      0,
                      8,
                    ),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _selectedIcon,
                style: const TextStyle(
                  fontSize: 48,
                ),
              ),
            ),
            const SizedBox(
              width: 18,
            ),
            _ArrowButton(
              icon: Icons.chevron_right_rounded,
              onTap: _goRight,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: _kidBg,
        ),
        child: SafeArea(
          bottom: false,

          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        10,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(
                              context,
                            ),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: _kText,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Edit Profile',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _kText,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 48,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 36,
                          bottom: 0,
                        ),
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                36,
                              ),
                              topRight: Radius.circular(
                                36,
                              ),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              24,
                              28,
                              24,
                              40,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildIconSelector(),
                                  const SizedBox(
                                    height: 28,
                                  ),
                                  const Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Full Name',
                                      style: TextStyle(
                                        color: _kText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  TextFormField(
                                    controller: _fullNameController,
                                    textAlign: TextAlign.center,
                                    decoration: _inputDecoration(
                                      'Enter your full name',
                                    ),
                                    validator:
                                        (
                                          value,
                                        ) {
                                          if (value ==
                                                  null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your full name';
                                          }
                                          return null;
                                        },
                                  ),
                                  const SizedBox(
                                    height: 30,
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _saving
                                          ? null
                                          : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _kPurple,
                                        disabledBackgroundColor: _kPurple.withOpacity(
                                          0.6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _saving
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ArrowButton
    extends
        StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(
            0xFFEDE9FE,
          ),
          borderRadius: BorderRadius.circular(
            14,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.05,
              ),
              blurRadius: 8,
              offset: const Offset(
                0,
                3,
              ),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(
            0xFF8B5CF6,
          ),
          size: 28,
        ),
      ),
    );
  }
}
