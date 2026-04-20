import 'package:flutter/material.dart';
import 'notification_model.dart';
import 'notification_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
 final _service = NotificationService();
final _supabase = Supabase.instance.client;
RealtimeChannel? _channel;
List<NotificationModel> _notifications = [];
bool _showUnreadOnly = false;
bool _isLoading = true;
late AnimationController _fadeCtrl;
late Animation<double> _fadeAnim;

  static const Color kPurple = Color(0xFF6C5CE7);
  static const Color kPurpleLight = Color(0xFF8B7FF0);
  static const Color kBg = Color(0xFF0D0B2A);
  static const Color kSurface = Color(0xFF1A1740);
  static const Color kSurface2 = Color(0xFF201D4E);

 @override
void initState() {
  super.initState();
  _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  _load();
  _listenForNotifications();
}

  @override
void dispose() {
  if (_channel != null) {
    _supabase.removeChannel(_channel!);
  }
  _fadeCtrl.dispose();
  super.dispose();
}

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      final data = await _service.fetchNotifications();
      if (!mounted) return;

      setState(() {
        _notifications = data;
        _isLoading = false;
      });

      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
void _listenForNotifications() {
  _channel = _supabase.channel('notifications-page')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'Notification',
      callback: (payload) {
        _load();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'Notification',
      callback: (payload) {
        _load();
      },
    )
    ..subscribe();
}
  Future<void> _onTap(NotificationModel n) async {
    if (!n.isRead) {
      await _service.markAsRead(n.id);
      setState(() {
        final idx = _notifications.indexWhere((x) => x.id == n.id);
        if (idx != -1) {
          _notifications[idx] = n.copyWith(isRead: true);
        }
      });
    }

    if (!mounted || n.route == null || n.route!.isEmpty) return;

    Navigator.pushNamed(context, n.route!);
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();

    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All notifications marked as read'),
        backgroundColor: kPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  List<NotificationModel> get _filtered =>
      _showUnreadOnly
          ? _notifications.where((n) => !n.isRead).toList()
          : _notifications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          _buildHeader(),
          _buildStats(),
          _buildFilterRow(),
          Expanded(
            child: _isLoading
                ? _buildLoader()
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5A4BD1), Color(0xFF7C6FE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Row(
        children: [
          _headerBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Column(
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (_unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_unreadCount new',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
          const Spacer(),
          _headerBtn(
            icon: Icons.done_all_rounded,
            onTap: _unreadCount == 0 ? () {} : _markAllRead,
            tooltip: 'Mark all read',
          ),
        ],
      ),
    );
  }

  Widget _headerBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final total = _notifications.length;
    final unread = _unreadCount;
    final read = total - unread;

    return Container(
      color: kSurface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          _statItem('Total', '$total', Colors.white70),
          _statDivider(),
          _statItem('Unread', '$unread', kPurpleLight),
          _statDivider(),
          _statItem('Read', '$read', Colors.greenAccent.shade200),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _chip(
            'All',
            !_showUnreadOnly,
            () => setState(() => _showUnreadOnly = false),
          ),
          const SizedBox(width: 8),
          _chip(
            'Unread',
            _showUnreadOnly,
            () => setState(() => _showUnreadOnly = true),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF8B7FF0)],
                )
              : null,
          color: active ? null : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: kPurple.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withOpacity(0.45),
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: kPurple),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) return _buildEmpty();

    final Map<String, List<NotificationModel>> grouped = {};

    for (final n in items) {
      final key = _dateLabel(n.createdAt);
      grouped.putIfAbsent(key, () => []).add(n);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: kPurple,
      backgroundColor: kSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dateHeader(entry.key),
              ...entry.value.asMap().entries.map(
                    (e) => _AnimatedCard(
                      key: ValueKey(e.value.id),
                      notification: e.value,
                      index: e.key,
                      onTap: () => _onTap(e.value),
                    ),
                  ),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _dateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kPurple.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 38,
              color: kPurple.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll notify you about budgets\nand goals here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) return '$diff DAYS AGO';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _AnimatedCard extends StatefulWidget {
  final NotificationModel notification;
  final int index;
  final VoidCallback onTap;

  const _AnimatedCard({
    required super.key,
    required this.notification,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (widget.index * 60)),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _NotificationCard(
          notification: widget.notification,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  static const Color kSurface = Color(0xFF1A1740);
  static const Color kSurface2 = Color(0xFF201D4E);

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final accent = _accentColor(notification.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread ? kSurface2 : kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? accent.withOpacity(0.35)
                : Colors.white.withOpacity(0.06),
            width: isUnread ? 1 : 0.5,
          ),
          boxShadow: isUnread
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            if (isUnread)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(isUnread ? 16 : 14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(accent),
                  const SizedBox(width: 12),
                  Expanded(child: _buildContent(isUnread, accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color accent) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.3), accent.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Icon(_iconFor(notification.type), color: accent, size: 20),
    );
  }

  Widget _buildContent(bool isUnread, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  color: isUnread ? Colors.white : Colors.white.withOpacity(0.8),
                  fontSize: 13.5,
                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          notification.body,
          style: TextStyle(
            color: Colors.white.withOpacity(isUnread ? 0.65 : 0.4),
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 11,
              color: Colors.white.withOpacity(0.25),
            ),
            const SizedBox(width: 4),
            Text(
              _timeAgo(notification.createdAt),
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 11,
         ),
          ),
        ],
      ),
    ],
  );
}

  Color _accentColor(String type) {
    switch (type) {
      case 'budget':
        return const Color(0xFF6C5CE7);
      case 'goal':
        return const Color(0xFF00B894);
      case 'insight':
        return const Color(0xFFFDCB6E);
      case 'warning':
        return const Color(0xFFFF7675);
      default:
        return const Color(0xFF74B9FF);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'budget':
        return Icons.account_balance_wallet_outlined;
      case 'goal':
        return Icons.flag_outlined;
      case 'insight':
        return Icons.lightbulb_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}