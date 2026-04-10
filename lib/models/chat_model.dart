import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final String clientId;
  final String freelancerId;
  final String lastMessage;
  final String requestId;
  final DateTime updatedAt;

  ChatModel({
    required this.chatId,
    required this.clientId,
    required this.freelancerId,
    required this.lastMessage,
    required this.requestId,
    required this.updatedAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      chatId: id,
      clientId: map['clientId'] ?? '',
      freelancerId: map['freelancerId'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      requestId: map['requestId'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'freelancerId': freelancerId,
      'lastMessage': lastMessage,
      'requestId': requestId,
      'updatedAt': updatedAt,
    };
  }
}
