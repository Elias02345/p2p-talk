import 'package:flutter/foundation.dart';

/// In-app notification categories. The UI renders localized text from the
/// [type] (+ optional [name]/[fromId]) so notifications are language-agnostic.
enum P2PNotificationType {
  callRequest,
  contactRequest,
  contactAccepted,
  peerJoinedRoom,
  peerLeftRoom,
  connectionLost,
  reconnected,
  securityWarning,
}

class P2PNotification {
  final String id;
  final P2PNotificationType type;
  final String? name; // peer/contact name or id, for interpolation in the UI
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  bool isRead;

  P2PNotification({
    required this.id,
    required this.type,
    this.name,
    this.data,
    this.isRead = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Manages in-app notifications and notification history.
class NotificationService extends ChangeNotifier {
  final List<P2PNotification> _notifications = [];
  int _unreadCount = 0;
  int _seq = 0;

  Function(P2PNotification notification)? onNotificationReceived;

  List<P2PNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  void _add(P2PNotificationType type, {String? name, Map<String, dynamic>? data}) {
    final notification = P2PNotification(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_seq++}',
      type: type,
      name: name,
      data: data,
    );
    _notifications.insert(0, notification);
    _unreadCount++;
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
    notifyListeners();
    onNotificationReceived?.call(notification);
  }

  void notifyCallRequest(String fromId, String fromName) =>
      _add(P2PNotificationType.callRequest, name: fromName, data: {'from_id': fromId});
  void notifyContactRequest(String fromId) =>
      _add(P2PNotificationType.contactRequest, name: fromId, data: {'from_id': fromId});
  void notifyContactAccepted(String fromId) =>
      _add(P2PNotificationType.contactAccepted, name: fromId, data: {'from_id': fromId});
  void notifyPeerJoined(String username) =>
      _add(P2PNotificationType.peerJoinedRoom, name: username);
  void notifyPeerLeft(String username) =>
      _add(P2PNotificationType.peerLeftRoom, name: username);
  void notifyConnectionLost() => _add(P2PNotificationType.connectionLost);
  void notifyReconnected() => _add(P2PNotificationType.reconnected);
  void notifySecurityWarning(String peerId) =>
      _add(P2PNotificationType.securityWarning, name: peerId);

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}
