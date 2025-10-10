import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController incomeController = TextEditingController();
  final TextEditingController paydayController = TextEditingController();
  final TextEditingController expensesController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Stack(
          children: [
            // ===== Gradient Circles (same as login/signup) =====
            Positioned(
              left: -5,
              top: 0,
              child: Container(
                width: 440,
                height: 403,
                decoration: const BoxDecoration(
                  color: Color(0xFF1F1B52),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -279,
              top: -255,
              child: Container(
                width: 627,
                height: 627,
                decoration: const BoxDecoration(
                  color: Color(0xFF322B78),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -162,
              top: -138,
              child: Container(
                width: 393,
                height: 393,
                decoration: const BoxDecoration(
                  color: Color(0xFF4E479B),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // ===== MAIN CONTENT =====
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 120),
                    const Text(
                      'Let’s set up your profile 💰',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFCFFFF),
                        fontSize: 28,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tell us a bit about your finances so we can personalize your experience.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB6B8B8),
                        fontSize: 16,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ===== Monthly Income =====
                    _fieldLabel('Monthly Income (ر.س)'),
                    _inputField(incomeController, 'e.g. 8000'),

                    const SizedBox(height: 24),

                    // ===== Payday =====
                    _fieldLabel('Payday'),
                    _inputField(paydayController, 'e.g. 28th of every month'),

                    const SizedBox(height: 24),

                    // ===== Fixed Expenses =====
                    _fieldLabel('Fixed Monthly Expenses (ر.س)'),
                    _inputField(expensesController, 'e.g. Rent, Subscriptions'),

                    const SizedBox(height: 24),

                    // ===== Due Dates =====
                    _fieldLabel('Expense Due Dates'),
                    _inputField(dueDateController, 'e.g. 5th and 15th'),

                    const SizedBox(height: 24),

                    // ===== Current Balance =====
                    _fieldLabel('Current Balance (ر.س)'),
                    _inputField(balanceController, 'e.g. 3200'),

                    const SizedBox(height: 40),

                    // ===== Continue Button =====
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pushReplacementNamed(
                                context, '/profile'); // move to dashboard/profile
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7959F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(33),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helper widgets =====
  Widget _fieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFCFFFF),
            fontSize: 15,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2E2C4A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB6B8B8)),
          border: InputBorder.none,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please fill this field';
          }
          return null;
        },
      ),
    );
  }
}
