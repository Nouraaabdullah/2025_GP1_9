import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the logged-in user's OWN profile_id.
/// Used by: adult savings page, dashboard, profile page, etc.
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



/// Returns the logged-in CHILD's own profile_id.
/// Used by: child savings page, after child logs in.
Future<String?> getOwnChildProfileId(BuildContext context) async {
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
      .eq('user_type', 'child')
      .maybeSingle();
  if (row == null) {
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
    return null;
  }
  return row['profile_id'] as String?;
}