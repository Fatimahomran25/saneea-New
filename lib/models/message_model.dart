import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String text;
  final String type;
  final String imageUrl;
  final List<String> imageUrls;
  final String requestId;
  final String contractStatus;
  final String contractTitle;
  final String contractText;
  final List<String> contractSummary;
  final DateTime timestamp;
  final bool isRead;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.type,
    required this.imageUrl,
    required this.imageUrls,
    required this.requestId,
    required this.contractStatus,
    required this.contractTitle,
    required this.contractText,
    required this.contractSummary,
    required this.timestamp,
    required this.isRead,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      messageId: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : [],
      requestId: map['requestId'] ?? '',
      contractStatus: map['contractStatus'] ?? map['status'] ?? '',
      contractTitle: map['contractTitle'] ?? '',
      contractText: map['contractText'] ?? '',
      contractSummary: map['contractSummary'] != null
          ? List<String>.from(map['contractSummary'])
          : [],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'requestId': requestId,
      'status': contractStatus,
      'contractStatus': contractStatus,
      'contractTitle': contractTitle,
      'contractText': contractText,
      'contractSummary': contractSummary,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };
  }
}
