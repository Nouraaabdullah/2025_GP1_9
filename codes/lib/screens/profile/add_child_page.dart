import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/utils/auth_helpers.dart';
import 'package:uuid/uuid.dart';

class AddChildPage
    extends
        StatefulWidget {
  const AddChildPage({
    super.key,
  });

  @override
  State<
    AddChildPage
  >
  createState() => _AddChildPageState();
}

class _AddChildPageState
    extends
        State<
          AddChildPage
        > {
  final _formKey =
      GlobalKey<
        FormState
      >();
  final _usernameController = TextEditingController();
  final _sb = Supabase.instance.client;

  bool _loading = false;

  Future<
    String
  >
  _getGuardianId() async {
    final profileId = await getProfileId(
      context,
    );
    if (profileId ==
        null) {
      throw Exception(
        'User not authenticated',
      );
    }
    return profileId;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<
    void
  >
  _showSuccessDialog({
    required String message,
  }) async {
    await showDialog<
      void
    >(
      context: context,
      barrierDismissible: true,
      builder:
          (
            ctx,
          ) {
            return Dialog(
              backgroundColor: const Color(
                0xFF141427,
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  40,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  32,
                  24,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF1F1F33,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(
                              0.6,
                            ),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.greenAccent,
                          width: 3,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_outline,
                          color: Colors.greenAccent,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    const Text(
                      'Done!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(
                      height: 28,
                    ),
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(
                          ctx,
                        ).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF704EF4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              999,
                            ),
                          ),
                          elevation: 16,
                          shadowColor:
                              const Color(
                                0xFF704EF4,
                              ).withOpacity(
                                0.7,
                              ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();

    showDialog(
      context: context,
      builder:
          (
            ctx,
          ) => AlertDialog(
            backgroundColor: const Color(
              0xFF2B2B48,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
            title: const Text(
              'Confirm Child Account',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Are you sure you want to add "$username" as a child account?',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  ctx,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF704EF4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    ctx,
                  );
                  _saveChild();
                },
                child: const Text(
                  'Add Child',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<
    void
  >
  _saveChild() async {
    setState(
      () => _loading = true,
    );

    try {
      final guardianProfileId = await _getGuardianId();
      final username = _usernameController.text.trim();

      final guardianProfile = await _sb
          .from(
            'User_Profile',
          )
          .select(
            'user_id, email',
          )
          .eq(
            'profile_id',
            guardianProfileId,
          )
          .maybeSingle();

      if (guardianProfile ==
              null ||
          guardianProfile['user_id'] ==
              null ||
          guardianProfile['email'] ==
              null) {
        throw Exception(
          'Guardian record not found.',
        );
      }

      final guardianUserId = guardianProfile['user_id'].toString();
      final guardianEmail = guardianProfile['email'].toString();

      final existing = await _sb
          .from(
            'Child_Guardian',
          )
          .select(
            'child_id',
          )
          .eq(
            'guardian_id',
            guardianUserId,
          )
          .ilike(
            'user_name',
            username,
          )
          .maybeSingle();

      if (existing !=
          null) {
        _showError(
          'This child username already exists.',
        );
        return;
      }

      final childProfileId = const Uuid().v4();
      final childUserId = const Uuid().v4();

      await _sb
          .from(
            'User_Profile',
          )
          .insert(
            {
              'profile_id': childProfileId,
              'user_id': childUserId,
              'email': guardianEmail,
              'current_balance': 0,
              'user_type': 'child',
            },
          );

      await _sb
          .from(
            'Child_Guardian',
          )
          .insert(
            {
              'child_id': childProfileId,
              'guardian_id': guardianUserId,
              'user_name': username,
            },
          );

      if (mounted) {
        await _showSuccessDialog(
          message: 'Child account added successfully.',
        );
      }

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } catch (
      e
    ) {
      debugPrint(
        'Error adding child: $e',
      );
      if (mounted) {
        _showError(
          'Error adding child: $e',
        );
      }
    } finally {
      if (mounted)
        setState(
          () => _loading = false,
        );
    }
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(
            18,
          ),
        ),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _rounded({
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          18,
        ),
        color: Colors.white,
      ),
      child: child,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final size = MediaQuery.of(
      context,
    ).size;

    return Scaffold(
      backgroundColor: const Color(
        0xFF1F1F33,
      ),
      body: Stack(
        children: [
          Container(
            height: 230,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(
                0xFF704EF4,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(
                  40,
                ),
                bottomRight: Radius.circular(
                  40,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(
                  context,
                ),
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Container(
                width: size.width,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF2B2B48,
                  ),
                  borderRadius: BorderRadius.circular(
                    28,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  32,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Child Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const Text(
                        'Create a child profile by adding a username.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      const _FieldLabel(
                        'Child Username',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      _rounded(
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: _inputDecoration().copyWith(
                            hintText: 'Enter child username',
                            prefixIcon: const Icon(
                              Icons.child_care,
                            ),
                          ),
                          validator:
                              (
                                value,
                              ) {
                                final v =
                                    value?.trim() ??
                                    '';
                                if (v.isEmpty) {
                                  return 'Please enter child username';
                                }
                                if (v.length <
                                    3) {
                                  return 'Username must be at least 3 characters';
                                }
                                return null;
                              },
                        ),
                      ),
                      const SizedBox(
                        height: 32,
                      ),
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF704EF4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  72,
                                ),
                              ),
                              elevation: 10,
                              shadowColor: const Color(
                                0xFF704EF4,
                              ),
                            ),
                            onPressed: _loading
                                ? null
                                : _showConfirmationDialog,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Add Child',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
        ],
      ),
    );
  }
}

class _FieldLabel
    extends
        StatelessWidget {
  final String text;
  const _FieldLabel(
    this.text, {
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
