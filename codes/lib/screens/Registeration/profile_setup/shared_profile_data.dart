class ProfileData {
  // 🧍‍♀️ Basic Info
  static String? userName;
  static double? currentBalance;

  // 💰 Incomes (each: source, amount, payday)
  static List<Map<String, dynamic>> incomes = [];

  // 🧾 Fixed Expenses (each: name, amount, dueDate, category)
  static List<Map<String, dynamic>> fixedExpenses = [];

  // 🏷️ Categories (both fixed + custom)
  static List<Map<String, dynamic>> categories = [
    {
      'name': 'Groceries',
      'limit': 0.0,
      'color': 0xFFFFA726,
      'icon': 'shopping_cart',
    },
    {
      'name': 'Transportation',
      'limit': 0.0,
      'color': 0xFF42A5F5,
      'icon': 'directions_car',
    },
    {
      'name': 'Utility',
      'limit': 0.0,
      'color': 0xFF26C6DA,
      'icon': 'bolt',
    },
    {
      'name': 'Entertainment',
      'limit': 0.0,
      'color': 0xFFEC407A,
      'icon': 'movie',
    },
    {
      'name': 'Health',
      'limit': 0.0,
      'color': 0xFF66BB6A,
      'icon': 'local_hospital',
    },
    {
      'name': 'Education',
      'limit': 0.0,
      'color': 0xFFAB47BC,
      'icon': 'school',
    },
  ];

  // 🧩 Add a new income
  static void addIncome(String source, double amount, int payday) {
    incomes.add({
      'source': source,
      'amount': amount,
      'payday': payday,
    });
  }

  // 🧾 Add a fixed expense safely from your setup_expenses_screen
  static void addFixedExpense({
    required String name,
    required double amount,
    required int dueDate,
    required String category,
  }) {
    fixedExpenses.add({
      'name': name,
      'amount': amount,
      'dueDate': dueDate,
      'category': category,
    });
  }

  // 🏷️ Add a custom category from your setup_categories_screen
  static void addCategory({
    required String name,
    required double limit,
    required int color,
    required String icon,
  }) {
    // Ensure unique color
    final exists = categories.any((cat) => cat['color'] == color);
    if (!exists) {
      categories.add({
        'name': name,
        'limit': limit,
        'color': color,
        'icon': icon,
      });
    }
  }

  // 📦 Convert to JSON format for Supabase
  static Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'current_balance': currentBalance,
      'incomes': incomes,
      'fixed_expenses': fixedExpenses,
      'categories': categories,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // 🧹 Optional reset method after successful save
  static void reset() {
    userName = null;
    currentBalance = null;
    incomes.clear();
    fixedExpenses.clear();

    // Refill the fixed categories
    categories = [
      {
        'name': 'Groceries',
        'limit': 0.0,
        'color': 0xFFFFA726,
        'icon': 'shopping_cart',
      },
      {
        'name': 'Transportation',
        'limit': 0.0,
        'color': 0xFF42A5F5,
        'icon': 'directions_car',
      },
      {
        'name': 'Utility',
        'limit': 0.0,
        'color': 0xFF26C6DA,
        'icon': 'bolt',
      },
      {
        'name': 'Entertainment',
        'limit': 0.0,
        'color': 0xFFEC407A,
        'icon': 'movie',
      },
      {
        'name': 'Health',
        'limit': 0.0,
        'color': 0xFF66BB6A,
        'icon': 'local_hospital',
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
