import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import 'email_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Obtenir ou créer une conversation pour un utilisateur
  Future<Conversation> getOrCreateConversation({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    // Chercher une conversation existante
    final query = await _firestore
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return Conversation.fromJson(query.docs.first.data());
    }

    // Créer une nouvelle conversation
    final convId = _uuid.v4();
    final conversation = Conversation(
      id: convId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
    );

    await _firestore
        .collection('conversations')
        .doc(convId)
        .set(conversation.toJson());

    return conversation;
  }

  /// Envoyer un message (utilisateur ou admin)
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole, // 'user' ou 'admin'
    required String content,
  }) async {
    final messageId = _uuid.v4();
    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      createdAt: DateTime.now(),
    );

    // Ajouter le message
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .set(message.toJson());

    // Mettre à jour la conversation (dernier message + compteur unread)
    final updateData = <String, dynamic>{
      'lastMessage': content.length > 100
          ? '${content.substring(0, 100)}...'
          : content,
      'lastMessageAt': FieldValue.serverTimestamp(),
    };

    if (senderRole == 'admin') {
      updateData['unreadByUser'] = FieldValue.increment(1);
      // Reset unread admin quand l'admin répond
      updateData['unreadByAdmin'] = 0;
    } else {
      updateData['unreadByAdmin'] = FieldValue.increment(1);
      updateData['unreadByUser'] = 0;
    }

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update(updateData);

    // Envoyer la notification email
    await _sendMessageNotificationEmail(
      conversationId: conversationId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
    );
  }

  /// Stream des messages d'une conversation (temps réel)
  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Stream de toutes les conversations (pour admin)
  Stream<List<Conversation>> getAllConversationsStream() {
    return _firestore
        .collection('conversations')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Conversation.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Stream de la conversation d'un utilisateur
  Stream<Conversation?> getUserConversationStream(String userId) {
    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty
              ? Conversation.fromJson(snapshot.docs.first.data())
              : null,
        );
  }

  /// Marquer les messages comme lus
  Future<void> markAsRead({
    required String conversationId,
    required String readerRole, // 'user' ou 'admin'
  }) async {
    // Marquer les messages de l'autre rôle comme lus
    final oppositeRole = readerRole == 'admin' ? 'user' : 'admin';
    final unreadMessages = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderRole', isEqualTo: oppositeRole)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }

    // Reset le compteur unread
    final resetField = readerRole == 'admin' ? 'unreadByAdmin' : 'unreadByUser';
    batch.update(_firestore.collection('conversations').doc(conversationId), {
      resetField: 0,
    });

    await batch.commit();
  }

  /// Compteur total de messages non lus pour les admins
  Stream<int> getTotalUnreadForAdmin() {
    return _firestore
        .collection('conversations')
        .where('unreadByAdmin', isGreaterThan: 0)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.fold<int>(
            0,
            (sum, doc) =>
                sum + ((doc.data()['unreadByAdmin'] as num?)?.toInt() ?? 0),
          ),
        );
  }

  /// Compteur de messages non lus pour un utilisateur
  Stream<int> getUnreadCountForUser(String userId) {
    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return 0;
          return (snapshot.docs.first.data()['unreadByUser'] as num?)
                  ?.toInt() ??
              0;
        });
  }

  /// Envoi d'email de notification
  Future<void> _sendMessageNotificationEmail({
    required String conversationId,
    required String senderName,
    required String senderRole,
    required String content,
  }) async {
    try {
      final convDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!convDoc.exists) return;
      final conv = convDoc.data()!;

      final preview = content.length > 150
          ? '${content.substring(0, 150)}...'
          : content;

      if (senderRole == 'user') {
        // Utilisateur → envoyer aux admins
        final adminEmails = await _getAdminEmails();
        for (final email in adminEmails) {
          await EmailService.sendEmail(
            to: email,
            subject:
                '💬 Nouveau message de ${conv['userName'] ?? 'un utilisateur'}',
            body: _buildNewMessageEmailForAdmin(
              userName: conv['userName'] ?? 'Utilisateur',
              messagePreview: preview,
            ),
          );
        }
      } else {
        // Admin → envoyer à l'utilisateur
        final userEmail = conv['userEmail'] as String?;
        if (userEmail != null) {
          await EmailService.sendEmail(
            to: userEmail,
            subject: '💬 Nouveau message de Chafin Loans',
            body: _buildNewMessageEmailForUser(
              userName: conv['userName'] ?? 'Cher client',
              messagePreview: preview,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur envoi notification chat: $e');
    }
  }

  Future<List<String>> _getAdminEmails() async {
    // Lire depuis config/adminEmails (accessible par tous les utilisateurs authentifiés)
    try {
      final configDoc = await _firestore
          .collection('config')
          .doc('adminEmails')
          .get();
      if (configDoc.exists) {
        final emails = configDoc.data()?['emails'] as List<dynamic>?;
        if (emails != null && emails.isNotEmpty) {
          return emails.cast<String>().toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Fallback: lecture config/adminEmails échouée: $e');
    }

    // Fallback: requête users (fonctionne uniquement si appelé par un admin)
    try {
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      return adminQuery.docs
          .map((doc) => doc.data()['email'] as String?)
          .where((email) => email != null)
          .cast<String>()
          .toList();
    } catch (e) {
      debugPrint('⚠️ Impossible de récupérer les emails admin: $e');
      return [];
    }
  }

  String _buildNewMessageEmailForAdmin({
    required String userName,
    required String messagePreview,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
    <div style="text-align: center; margin-bottom: 20px;">
      <h1 style="color: #0666EB; margin: 0;">Chafin Loans</h1>
    </div>
    <div style="background: linear-gradient(135deg, #0666EB, #00C2FF); padding: 20px; border-radius: 10px; margin-bottom: 20px;">
      <h2 style="color: white; margin: 0;">💬 Nouveau message</h2>
      <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0;">De: <strong>$userName</strong></p>
    </div>
    <div style="background-color: #f8f9fa; padding: 16px; border-radius: 8px; border-left: 4px solid #0666EB; margin-bottom: 20px;">
      <p style="color: #333; margin: 0; line-height: 1.6;">$messagePreview</p>
    </div>
    <div style="text-align: center;">
      <a href="https://chafin.web.app" style="background-color: #0666EB; color: white; padding: 12px 30px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: bold;">
        Répondre dans l'application
      </a>
    </div>
    <p style="color: #999; font-size: 12px; text-align: center; margin-top: 20px;">
      Chafin Loans - Messagerie sécurisée
    </p>
  </div>
</body>
</html>
''';
  }

  String _buildNewMessageEmailForUser({
    required String userName,
    required String messagePreview,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
    <div style="text-align: center; margin-bottom: 20px;">
      <h1 style="color: #0666EB; margin: 0;">Chafin Loans</h1>
    </div>
    <div style="background: linear-gradient(135deg, #00B876, #00D4AA); padding: 20px; border-radius: 10px; margin-bottom: 20px;">
      <h2 style="color: white; margin: 0;">💬 Nouveau message</h2>
      <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0;">L'équipe Chafin vous a envoyé un message</p>
    </div>
    <p style="color: #333; line-height: 1.6;">Bonjour $userName,</p>
    <div style="background-color: #f8f9fa; padding: 16px; border-radius: 8px; border-left: 4px solid #00B876; margin-bottom: 20px;">
      <p style="color: #333; margin: 0; line-height: 1.6;">$messagePreview</p>
    </div>
    <div style="text-align: center;">
      <a href="https://chafin.web.app" style="background-color: #00B876; color: white; padding: 12px 30px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: bold;">
        Consulter dans l'application
      </a>
    </div>
    <p style="color: #999; font-size: 12px; text-align: center; margin-top: 20px;">
      Chafin Loans - Messagerie sécurisée
    </p>
  </div>
</body>
</html>
''';
  }
}
