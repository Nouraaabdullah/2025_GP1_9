import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupCompleteScreen
    extends
        StatefulWidget {
  const SetupCompleteScreen({
    super.key,
  });

  @override
  State<
    SetupCompleteScreen
  >
  createState() => _SetupCompleteScreenState();
}

class _SetupCompleteScreenState
    extends
        State<
          SetupCompleteScreen
        > {
  final supabase = Supabase.instance.client;
  bool saving = false;

  Future<
    void
  >
  _submitFinalData(
    BuildContext context,
  ) async {
    if (saving) return;
    setState(
      () => saving = true,
    );

    try {
      final user = supabase.auth.currentUser;
      if (user ==
          null)
        throw Exception(
          "No logged-in user",
        );

      // ---------------------------------------
      // 1) Get profile_id
      // ---------------------------------------
      final profileResponse = await supabase
          .from(
            'User_Profile',
          )
          .select(
            'profile_id',
          )
          .eq(
            'user_id',
            user.id,
          )
          .maybeSingle();

      if (profileResponse ==
          null)
        throw Exception(
          "Profile not found",
        );
      final profileId = profileResponse['profile_id'];

      // ---------------------------------------
      // 2) Update profile (name + balance)
      // ---------------------------------------
      await supabase
          .from(
            'User_Profile',
          )
          .update(
            {
              'full_name': ProfileData.userName,
              'current_balance': ProfileData.currentBalance,
            },
          )
          .eq(
            'profile_id',
            profileId,
          );

      // ---------------------------------------
      // 3) Insert incomes
      // ---------------------------------------
      if (ProfileData.incomes.isNotEmpty) {
        final incomeRecords = ProfileData.incomes.map(
          (
            i,
          ) {
            return {
              'profile_id': profileId,
              'name': i['source'],
              'monthly_income': i['amount'],
              'payday': i['payday'],
              'is_primary':
                  i['is_primary'] ??
                  false,
            };
          },
        ).toList();

        await supabase
            .from(
              'Fixed_Income',
            )
            .insert(
              incomeRecords,
            );
      }

      // ---------------------------------------
      // 4) Insert fixed expenses WITH CATEGORY ID
      // ---------------------------------------
      if (ProfileData.fixedExpenses.isNotEmpty) {
        final expenseRecords = [];

        for (var e in ProfileData.fixedExpenses) {
          final categoryName = e['category'];

          // find category_id (limit 1 so no error)
          final categoryRows = await supabase
              .from(
                'Category',
              )
              .select(
                'category_id',
              )
              .eq(
                'name',
                categoryName,
              )
              .limit(
                1,
              );

          if (categoryRows.isEmpty) {
            throw Exception(
              "Category not found: $categoryName",
            );
          }

          final categoryId = categoryRows.first['category_id'];

          expenseRecords.add(
            {
              'profile_id': profileId,
              'name': e['name'],
              'amount': e['amount'],
              'due_date': e['dueDate'],
              'category_id': categoryId,
              'is_transacted': false,
            },
          );
        }

        await supabase
            .from(
              'Fixed_Expense',
            )
            .insert(
              expenseRecords,
            );
      }

      // ---------------------------------------
      // 5) Insert categories
      // ---------------------------------------
      if (ProfileData.categories.isNotEmpty) {
        final categoryRecords = ProfileData.categories.map(
          (
            c,
          ) {
            return {
              'profile_id': profileId,
              'name': c['name'],
              'monthly_limit':
                  c['limit'] ??
                  0.0,
              'icon': c['icon'],
              'icon_color': c['color'].toString(),
              'type':
                  c['type'] ??
                  'Custom',
              'is_archived': false,
            };
          },
        ).toList();

        await supabase
            .from(
              'Category',
            )
            .insert(
              categoryRecords,
            );
      }

      // ---------------------------------------
      // 6) Reset local temporary data
      // ---------------------------------------
      ProfileData.reset();

      // Go to profile
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/profile',
          (
            _,
          ) => false,
        );
      }
    } catch (
      e
    ) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            "Error: $e",
          ),
        ),
      );
    } finally {
      setState(
        () => saving = false,
      );
    }
  }

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
            vertical: 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(
                flex: 1,
              ),

              const Icon(
                Icons.check_circle,
                color: Color(
                  0xFF7959F5,
                ),
                size: 140,
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                "Setup Complete!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(
                height: 12,
              ),

              const Text(
                "Your financial profile has been successfully created.",
                style: TextStyle(
                  color: Color(
                    0xFFB3B3C7,
                  ),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(
                height: 40,
              ),

              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(
                        0xFFB8A8FF,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const Spacer(
                flex: 2,
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF7959F5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                onPressed: saving
                    ? null
                    : () => _submitFinalData(
                        context,
                      ),
                child: saving
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        "Go to Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              const Spacer(
                flex: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
