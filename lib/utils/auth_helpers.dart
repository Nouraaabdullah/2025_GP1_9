import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> getProfileId(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) {
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
    return null;
  }

  final row = await supabase
      .from('User_Profile')
      .select('profile_id')
      .eq('user_id', uid)
      .maybeSingle();

  return row?['profile_id'] as String?;
}
