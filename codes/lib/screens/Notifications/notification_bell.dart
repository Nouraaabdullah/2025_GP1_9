import 'package:flutter/material.dart';
import 'notification_services.dart';
import 'notifications_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  final _service = NotificationService();
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  
  @override
void initState() {
  super.initState();

  _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  _bounceAnim = Tween<double>(begin: 1.0, end: 1.3)
      .chain(CurveTween(curve: Curves.elasticOut))
      .animate(_bounceCtrl);

  _loadCount();
  _listenForNotifications();
}

  @override
void dispose() {
  if (_channel != null) {
    _supabase.removeChannel(_channel!);
  }
  _bounceCtrl.dispose();
  super.dispose();
}

  Future<void> _loadCount() async {
    final count = await _service.getUnreadCount();

    if (mounted && count != _unreadCount) {
      setState(() => _unreadCount = count);

      if (count > 0) {
        _bounceCtrl.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) =>  NotificationsPage()),
        );

        _loadCount();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 26,
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: ScaleTransition(
                scale: _bounceAnim,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7675), Color(0xFFE84393)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0D0B2A),
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _listenForNotifications() {
  _channel = _supabase.channel('notifications-bell')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'Notification',
      callback: (payload) {
        _loadCount();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'Notification',
      callback: (payload) {
        _loadCount();
      },
    )
    ..subscribe();
}
}
