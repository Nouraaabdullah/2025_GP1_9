import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared_profile_data.dart';

class SetupExpensesScreen
    extends
        StatefulWidget {
  const SetupExpensesScreen({
    super.key,
  });

  @override
  State<
    SetupExpensesScreen
  >
  createState() => _SetupExpensesScreenState();
}

class _SetupExpensesScreenState
    extends
        State<
          SetupExpensesScreen
        > {
  bool loading = false;
  bool _dueDateConfirmed = false;

  final List<
    Map<
      String,
      dynamic
    >
  >
  expenses = [
    {
      'name': TextEditingController(),
      'amount': TextEditingController(),
      'dueDate': null,
      'category': null,
      'customCategory': TextEditingController(),
      'errors':
          <
            String,
            String?
          >{
            'name': null,
            'amount': null,
            'dueDate': null,
            'category': null,
            'customCategory': null,
          },
    },
  ];

  //────────────────────────────────────────────
  // Add new expense
  //────────────────────────────────────────────
  void addExpenseField() {
    setState(
      () {
        expenses.add(
          {
            'name': TextEditingController(),
            'amount': TextEditingController(),
            'dueDate': null,
            'category': null,
            'customCategory': TextEditingController(),
            'errors':
                <
                  String,
                  String?
                >{
                  'name': null,
                  'amount': null,
                  'dueDate': null,
                  'category': null,
                  'customCategory': null,
                },
          },
        );
      },
    );
  }

  //────────────────────────────────────────────
  // Input Validation (Required fields)
  //────────────────────────────────────────────
  bool _validateFields() {
    bool isValid = true;

    for (var e in expenses) {
      final errors =
          e['errors']
              as Map<
                String,
                String?
              >;
      errors.updateAll(
        (
          key,
          value,
        ) => null,
      );

      final hasAnyInput =
          e['name'].text.trim().isNotEmpty ||
          e['amount'].text.trim().isNotEmpty ||
          e['dueDate'] !=
              null ||
          e['category'] !=
              null ||
          e['customCategory'].text.trim().isNotEmpty;

      // 🔹 Completely empty row → ignore (since fixed expenses are optional)
      if (!hasAnyInput) {
        continue;
      }

      // 🔹 Name REQUIRED
      if (e['name'].text.trim().isEmpty) {
        errors['name'] = "Required";
        isValid = false;
      }

      // 🔹 Amount REQUIRED + must be numeric
      final amountText = e['amount'].text.trim();
      if (amountText.isEmpty) {
        errors['amount'] = "Required";
        isValid = false;
      } else if (double.tryParse(
            amountText,
          ) ==
          null) {
        errors['amount'] = "Enter numbers only";
        isValid = false;
      }

      // 🔹 Category REQUIRED
      if (e['category'] ==
          null) {
        errors['category'] = "Required";
        isValid = false;
      }

      // 🔹 Custom category name REQUIRED when category == 'Custom'
      if (e['category'] ==
              'Custom' &&
          e['customCategory'].text.trim().isEmpty) {
        errors['customCategory'] = "Enter name";
        isValid = false;
      }

      // 🔹 Due date (payday) REQUIRED and must be 1–31
      final due = e['dueDate'];
      if (due ==
          null) {
        errors['dueDate'] = "Required";
        isValid = false;
      } else if (due <
              1 ||
          due >
              31) {
        errors['dueDate'] = "Enter a valid day (1–31)";
        isValid = false;
      }
    }

    setState(
      () {},
    );
    return isValid;
  }

  //────────────────────────────────────────────
  // Due-date WARNING detection
  //────────────────────────────────────────────
  bool _hasDueDateWarnings(
    List expenses,
  ) {
    for (var e in expenses) {
      final due = e['dueDate'];
      if (due ==
          null)
        return true;
      if (due <
              1 ||
          due >
              31)
        return true;
    }
    return false;
  }

  //────────────────────────────────────────────
  // Due-date WARNING dialog
  //────────────────────────────────────────────
  Future<
    bool
  >
  _showDueDateWarningDialog() async {
    return await showDialog<
          bool
        >(
          context: context,
          builder:
              (
                _,
              ) => AlertDialog(
                backgroundColor: const Color(
                  0xFF1D1B32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    16,
                  ),
                ),
                title: const Text(
                  "⚠️ Invalid Due Date",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text(
                  "Some expenses have missing or invalid due dates.\n"
                  "Do you want to continue?",
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      false,
                    ),
                    child: const Text(
                      "Fix",
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      true,
                    ),
                    child: const Text(
                      "Continue",
                      style: TextStyle(
                        color: Color(
                          0xFF7959F5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  //────────────────────────────────────────────
  // Due-Date CONFIRMATION dialog (first-time lock)
  //────────────────────────────────────────────
  Future<
    bool
  >
  _confirmDueDateLock(
    BuildContext context,
  ) async {
    return await showDialog<
          bool
        >(
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
                  'Confirm Due Date',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text(
                  'Once you set the due date for this month, you cannot change it until the next month.',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                      ctx,
                      false,
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
                    onPressed: () => Navigator.pop(
                      ctx,
                      true,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  //────────────────────────────────────────────
  // LOCAL SAVE (final)
  //────────────────────────────────────────────
  Future<
    void
  >
  saveLocalExpenses() async {
    // 1) Validate inline fields first
    if (!_validateFields()) return;

    // 2) Collect only rows where *something* is filled
    final filledExpenses = expenses
        .where(
          (
            e,
          ) =>
              e['name'].text.trim().isNotEmpty ||
              e['amount'].text.trim().isNotEmpty ||
              e['dueDate'] !=
                  null ||
              e['category'] !=
                  null ||
              e['customCategory'].text.trim().isNotEmpty,
        )
        .toList();

    // 3) If NOTHING is filled → user is skipping this step (optional)
    if (filledExpenses.isEmpty) {
      ProfileData.fixedExpenses = [];
      Navigator.pushNamed(
        context,
        '/setupBalance',
      );
      return;
    }

    // 4) First-time due date lock confirmation (only if there is data)
    if (!_dueDateConfirmed) {
      final confirmed = await _confirmDueDateLock(
        context,
      );
      if (!confirmed) return;
      _dueDateConfirmed = true;
    }

    // 5) Show due-date warning if some due dates are missing/invalid
    if (_hasDueDateWarnings(
      filledExpenses,
    )) {
      final proceed = await _showDueDateWarningDialog();
      if (!proceed) return;
    }

    // 6) Save to ProfileData
    ProfileData.fixedExpenses = filledExpenses.map(
      (
        e,
      ) {
        final categoryName =
            e['category'] ==
                'Custom'
            ? e['customCategory'].text.trim()
            : e['category'];

        return {
          'name': e['name'].text.trim(),
          'amount':
              double.tryParse(
                e['amount'].text.trim(),
              ) ??
              0.0,
          'dueDate': e['dueDate'],
          'category': categoryName,
        };
      },
    ).toList();

    // 7) Go to next step
    Navigator.pushNamed(
      context,
      '/setupBalance',
    );
  }

  //────────────────────────────────────────────
  // Error text widget
  //────────────────────────────────────────────
  Widget
  _errorText(
    String text,
  ) => Padding(
    padding: const EdgeInsets.only(
      top: 4,
      left: 4,
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
      ),
    ),
  );

  //────────────────────────────────────────────
  // Expense Card UI
  //────────────────────────────────────────────
  Widget buildExpenseCard(
    int index,
  ) {
    final expense = expenses[index];
    final errors =
        expense['errors']
            as Map<
              String,
              String?
            >;

    return Card(
      color: const Color(
        0xFF2A2550,
      ),
      margin: const EdgeInsets.only(
        bottom: 20,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          16,
        ),
        side: BorderSide(
          color:
              const Color(
                0xFF7959F5,
              ).withOpacity(
                0.3,
              ),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Expense ${index + 1}",
                  style: const TextStyle(
                    color: Color(
                      0xFFB8A8FF,
                    ),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (index >
                    0)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => setState(
                      () => expenses.removeAt(
                        index,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),

            const Text(
              "What is this expense for?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            TextField(
              controller: expense['name'],
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: _inputDecoration(
                'e.g., Rent, Phone bill, Gym',
              ),
            ),
            if (errors['name'] !=
                null)
              _errorText(
                errors['name']!,
              ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "How much does it cost each month?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            TextField(
              controller: expense['amount'],
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: _inputDecoration(
                'Amount in SAR (e.g., 300)',
              ),
            ),
            if (errors['amount'] !=
                null)
              _errorText(
                errors['amount']!,
              ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "Which category does this belong to?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 6,
            ),

            DropdownButtonFormField<
              String
            >(
              value: expense['category'],
              dropdownColor: const Color(
                0xFF2A2550,
              ),
              style: const TextStyle(
                color: Colors.white,
              ),
              iconEnabledColor: const Color(
                0xFFB8A8FF,
              ),
              decoration:
                  _inputDecoration(
                    '',
                  ).copyWith(
                    hintText: null,
                  ),
              hint: const Text(
                'Select a category',
                style: TextStyle(
                  color: Color(
                    0xFFB0AFC5,
                  ),
                ),
              ),
              items: [
                ...ProfileData.categories.map(
                  (
                    c,
                  ) {
                    final name =
                        c['name']
                            as String? ??
                        '';
                    return DropdownMenuItem(
                      value: name,
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ).toList(),
                const DropdownMenuItem(
                  value: 'Custom',
                  child: Text(
                    "Custom Category",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              onChanged:
                  (
                    value,
                  ) => setState(
                    () => expense['category'] = value,
                  ),
            ),
            if (errors['category'] !=
                null)
              _errorText(
                errors['category']!,
              ),
            const SizedBox(
              height: 12,
            ),

            if (expense['category'] ==
                'Custom') ...[
              const Text(
                "Enter your custom category name:",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              TextField(
                controller: expense['customCategory'],
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: _inputDecoration(
                  "e.g., Kids, Pets, Subscriptions",
                ),
              ),
              if (errors['customCategory'] !=
                  null)
                _errorText(
                  errors['customCategory']!,
                ),
              const SizedBox(
                height: 20,
              ),
            ],

            const Text(
              "When is this expense due each month?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 6,
            ),

            TextField(
              controller: TextEditingController(
                text:
                    expense['dueDate']?.toString() ??
                    '',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                  2,
                ),
              ],
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: _inputDecoration(
                'Enter a day (1–31)',
              ),
              onChanged:
                  (
                    val,
                  ) {
                    final number = int.tryParse(
                      val,
                    );
                    setState(
                      () {
                        if (number !=
                                null &&
                            number >=
                                1 &&
                            number <=
                                31) {
                          expense['dueDate'] = number;
                          errors['dueDate'] = null;
                        } else {
                          expense['dueDate'] = null;
                          errors['dueDate'] = "Enter a valid day (1–31)";
                        }
                      },
                    );
                  },
            ),
            if (errors['dueDate'] !=
                null)
              _errorText(
                errors['dueDate']!,
              ),
          ],
        ),
      ),
    );
  }

  //────────────────────────────────────────────
  // Input Decoration
  //────────────────────────────────────────────
  InputDecoration _inputDecoration(
    String hint,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(
          0xFFB0AFC5,
        ),
      ),
      filled: true,
      fillColor: const Color(
        0xFF1F1B3A,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          12,
        ),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(
            0.2,
          ),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(
            12,
          ),
        ),
        borderSide: BorderSide(
          color: Color(
            0xFF7959F5,
          ),
          width: 2,
        ),
      ),
    );
  }

  //────────────────────────────────────────────
  // MAIN UI
  //────────────────────────────────────────────
  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF1D1B32,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: Colors.white12,
                  ),
                  Container(
                    height: 4,
                    width:
                        MediaQuery.of(
                          context,
                        ).size.width *
                        0.85,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(
                            0xFF7959F5,
                          ),
                          Color(
                            0xFFA27CFF,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 28,
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(
                        0xFF7959F5,
                      ).withOpacity(
                        0.15,
                      ),
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
                ),
                child: const Text(
                  "STEP 5 OF 6",
                  style: TextStyle(
                    color: Color(
                      0xFFB8A8FF,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              const Text(
                "Fixed Expenses",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 8,
              ),

              const Text(
                "Add your regular monthly expenses, due dates, and categories (optional).",
                style: TextStyle(
                  color: Color(
                    0xFFB3B3C7,
                  ),
                  fontSize: 15,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder:
                      (
                        _,
                        i,
                      ) => buildExpenseCard(
                        i,
                      ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: addExpenseField,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(
                      0xFFB8A8FF,
                    ),
                  ),
                  label: const Text(
                    "Add another expense",
                    style: TextStyle(
                      color: Color(
                        0xFFB8A8FF,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(
                            0.3,
                          ),
                        ),
                        foregroundColor: Colors.white,
                        backgroundColor:
                            const Color(
                              0xFF2E2C4A,
                            ).withOpacity(
                              0.5,
                            ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      child: const Text(
                        "Back",
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF7959F5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            12,
                          ),
                        ),
                        elevation: 6,
                        shadowColor:
                            const Color(
                              0xFF7959F5,
                            ).withOpacity(
                              0.4,
                            ),
                      ),
                      onPressed: loading
                          ? null
                          : () async {
                              await saveLocalExpenses();
                            },

                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Continue",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
