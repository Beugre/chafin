import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'user' ou 'admin'
  final String content;
  final DateTime createdAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.read = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.now(),
      read: json['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'read': read,
    };
  }
}

class Conversation {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadByUser;
  final int unreadByAdmin;

  const Conversation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadByUser = 0,
    this.unreadByAdmin = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userEmail: json['userEmail'] as String? ?? '',
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] is Timestamp
          ? (json['lastMessageAt'] as Timestamp).toDate()
          : DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
      unreadByUser: (json['unreadByUser'] as num?)?.toInt() ?? 0,
      unreadByAdmin: (json['unreadByAdmin'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadByUser': unreadByUser,
      'unreadByAdmin': unreadByAdmin,
    };
  }
}
