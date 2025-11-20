import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupFixedCategoryScreen extends StatefulWidget {
  const SetupFixedCategoryScreen({super.key});

  @override
  State<SetupFixedCategoryScreen> createState() =>
      _SetupFixedCategoryScreenState();
}

class _SetupFixedCategoryScreenState extends State<SetupFixedCategoryScreen> {
  final List<Map<String, dynamic>> fixedCategories = [
    {
      'name': 'Groceries',
      'limit': TextEditingController(),
      'color': const Color(0xFFFFA726),
      'icon': Icons.shopping_cart,
    },
    {
      'name': 'Transport',
      'limit': TextEditingController(),
      'color': const Color(0xFF42A5F5),
      'icon': Icons.directions_car,
    },
    {
      'name': 'Utilities',
      'limit': TextEditingController(),
      'color': const Color(0xFF7E57C2),
      'icon': Icons.lightbulb,
    },
    {
      'name': 'Entertainment',
      'limit': TextEditingController(),
      'color': const Color(0xFFEC407A),
      'icon': Icons.videogame_asset,
    },
    {
      'name': 'Health',
      'limit': TextEditingController(),
      'color': const Color(0xFF66BB6A),
      'icon': Icons.favorite,
    },
    {
      'name': 'Education',
      'limit': TextEditingController(),
      'color': const Color(0xFFAB47BC),
      'icon': Icons.school,
    },
  ];

  final supabase = Supabase.instance.client;
  bool loading = false;

Future<void> saveCategoriesToSupabase() async {
  bool hasEmptyLimit =
      fixedCategories.any((c) => c['limit'].text.trim().isEmpty);
  if (hasEmptyLimit) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all category limits')),
    );
    return;
  }

  setState(() => loading = true);

  try {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("No logged-in user found.");

    // ✅ Fetch user's profile_id from User_Profile table
    final profileResponse = await supabase
        .from('User_Profile')
        .select('profile_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (profileResponse == null) {
      throw Exception("User profile not found.");
    }

    final profileId = profileResponse['profile_id'];

    // ✅ Match the correct Supabase column names
    final categoryRecords = fixedCategories.map((c) {
      return {
        'profile_id': profileId,
        'name': c['name'], // ← category name
        'type': 'Fixed',
        'monthly_limit': double.tryParse(c['limit'].text) ?? 0.0, // ← limit
        'icon': c['icon'].toString().split('.').last, // ← icon name
        'icon_color': c['color'].value.toRadixString(16), // ← color hex
        'is_archived': false,
      };
    }).toList();

    // ✅ Insert into Category table
    await supabase.from('Category').insert(categoryRecords);

    // ✅ Save locally for next setup step
    ProfileData.categories = categoryRecords;

    Navigator.pushNamed(context, '/setupCustomCategory');
  } catch (e) {
    debugPrint("❌ Error saving categories: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error saving categories: $e")),
    );
  } finally {
    setState(() => loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              Stack(
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.45,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7959F5), Color(0xFFA27CFF)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Step indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7959F5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "STEP 3 OF 6",
                  style: TextStyle(
                    color: Color(0xFFB8A8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Default Categories",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Set monthly limits for essential spending categories.",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 16),
              ),
              const SizedBox(height: 24),

              // Category inputs
              Expanded(
                child: ListView.builder(
                  itemCount: fixedCategories.length,
                  itemBuilder: (context, index) {
                    final cat = fixedCategories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Icon(cat['icon'], color: cat['color']),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat['name'],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: cat['limit'],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Limit',
                                hintStyle:
                                    const TextStyle(color: Color(0xFFB0AFC5)),
                                filled: true,
                                fillColor: const Color(0xFF2A2550),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('SAR',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side:
                            BorderSide(color: Colors.white.withOpacity(0.3)),
                        foregroundColor: Colors.white,
                        backgroundColor:
                            const Color(0xFF2E2C4A).withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Back"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7959F5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: loading ? null : saveCategoriesToSupabase,
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
