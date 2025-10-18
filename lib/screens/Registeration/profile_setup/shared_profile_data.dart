class ProfileData {
  // 🧍‍♀️ Basic info
  static String? userName;
  static double? currentBalance;

  // 💰 Income
  static double? monthlyIncome;
  static int? payday;

  // 🧾 Fixed Expenses (each: name, amount, dueDate)
  static List<Map<String, dynamic>> fixedExpenses = [];

  // 🏷️ Categories (each: name, limit, color, icon)
  static List<Map<String, dynamic>> categories = [
    {
      'name': 'Groceries',
      'limit': 0.0,
      'color': 0xFFFFA726,
      'icon': 'shopping_cart', // store as text for Supabase
    },
    {
      'name': 'Transport',
      'limit': 0.0,
      'color': 0xFF42A5F5,
      'icon': 'directions_car',
    },
    {
      'name': 'Education',
      'limit': 0.0,
      'color': 0xFFAB47BC,
      'icon': 'school',
    },
  ];

  // 🧩 Add a fixed expense safely from your setup_expenses_screen
  static void addFixedExpense(String name, double amount, DateTime? dueDate) {
    fixedExpenses.add({
      'name': name,
      'amount': amount,
      'dueDate': dueDate?.toIso8601String() ?? '',
    });
  }

  // 🧩 Add a custom category from your setup_categories_screen
  static void addCategory({
    required String name,
    required double limit,
    required int color,
    required String icon,
  }) {
    categories.add({
      'name': name,
      'limit': limit,
      'color': color,
      'icon': icon,
    });
  }

  // 📦 Convert to JSON format for Supabase
  static Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'current_balance': currentBalance,
      'monthly_income': monthlyIncome,
      'payday': payday,
      'fixed_expenses': fixedExpenses,
      'categories': categories,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // 🧹 Optional reset method after successful save
  static void reset() {
    userName = null;
    currentBalance = null;
    monthlyIncome = null;
    payday = null;
    fixedExpenses.clear();
    categories = [
      {
        'name': 'Groceries',
        'limit': 0.0,
        'color': 0xFFFFA726,
        'icon': 'shopping_cart',
      },
      {
        'name': 'Transport',
        'limit': 0.0,
        'color': 0xFF42A5F5,
        'icon': 'directions_car',
      },
      {
        'name': 'Education',
        'limit': 0.0,
        'color': 0xFFAB47BC,
        'icon': 'school',
      },
    ];
  }
}
