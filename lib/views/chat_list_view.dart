import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/chat_controller.dart';
import 'chat_view.dart';
import 'freelancer_client_profile_view.dart';
import 'freelancer_profile.dart';

class ChatListView extends StatelessWidget {
  ChatListView({super.key});

  static const Color primary = Color(0xFF5A3E9E);

  final ChatController _controller = ChatController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _controller.getMyChatsWithUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load chats: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Text('No chats yet.', style: TextStyle(fontSize: 16)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final unreadCount = (chat['unreadCount'] ?? 0) as int;
              final chatId = (chat['chatId'] ?? '').toString();
              final otherUserName = (chat['otherUserName'] ?? 'User')
                  .toString();
              final otherUserPhoto = (chat['otherUserPhoto'] ?? '')
                  .toString()
                  .trim();
              final otherUserId = (chat['otherUserId'] ?? '').toString();
              final otherUserRole = (chat['otherUserRole'] ?? '').toString();
              final lastMessage =
                  (chat['lastMessage'] ?? '').toString().trim().isEmpty
                  ? 'No messages yet'
                  : (chat['lastMessage'] ?? '').toString();

              final updatedAt = chat['updatedAt'] as DateTime?;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatView(
                        chatId: chatId,
                        otherUserName: otherUserName,
                        otherUserId: otherUserId,
                        otherUserRole: otherUserRole,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F2FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        backgroundImage: otherUserPhoto.isNotEmpty
                            ? NetworkImage(otherUserPhoto)
                            : null,
                        child: otherUserPhoto.isEmpty
                            ? const Icon(Icons.person, color: primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              otherUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(updatedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          if (unreadCount > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
