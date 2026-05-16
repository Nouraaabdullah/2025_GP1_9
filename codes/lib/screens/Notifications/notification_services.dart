// codes/lib/screens/Notifications/notification_services.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_model.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  Future<String?> _getProfileId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('User_Profile')
          .select('profile_id')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['profile_id']?.toString();
    } catch (e) {
      debugPrint('Error getting profile id: $e');
      return null;
    }
  }

  Future<List<NotificationModel>> fetchNotifications() async {
    try {
      final profileId = await _getProfileId();
      if (profileId == null) return [];

      final response = await _supabase
    .from('Notification')
    .select()
    .eq('profile_id', profileId)
    .inFilter('type', [
      'goal_reminder',
      'budget_alert',
      'goal_completed',
      'negative_balance',
      'child_budget_alert',
      'child_negative_balance',
    ])
    .order('created_at', ascending: false);

      return (response as List)
          .map((e) => NotificationModel.fromMap(e))
          .toList();
    } catch (e) {
      debugPrint('fetchNotifications error: $e');
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final profileId = await _getProfileId();
      if (profileId == null) return 0;

      final response = await _supabase
    .from('Notification')
    .select('id')
    .eq('profile_id', profileId)
    .eq('is_read', false)
    .inFilter('type', [
      'goal_reminder',
      'budget_alert',
      'goal_completed',
      'negative_balance',
      'child_budget_alert',
      'child_negative_balance',
    ]);

      return (response as List).length;
    } catch (e) {
      debugPrint('getUnreadCount error: $e');
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('Notification')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final profileId = await _getProfileId();
      if (profileId == null) return;

      await _supabase
          .from('Notification')
          .update({'is_read': true})
          .eq('profile_id', profileId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('markAllAsRead error: $e');
    }
  }

  Future<void> createNotification({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final profileId = await _getProfileId();
      if (profileId == null) return;

      await _supabase.from('Notification').insert({
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'profile_id': profileId,
      });
    } catch (e) {
      debugPrint('createNotification error: $e');
    }
  }

  Future<bool> notificationExistsToday({
    required String title,
    required String type,
  }) async {
    try {
      final profileId = await _getProfileId();
      if (profileId == null) return false;

      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay =
          DateTime(now.year, now.month, now.day, 23, 59, 59)
              .toIso8601String();

      final response = await _supabase
          .from('Notification')
          .select('id')
          .eq('profile_id', profileId)
          .eq('title', title)
          .eq('type', type)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);

      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('notificationExistsToday error: $e');
      return false;
    }
  }
}