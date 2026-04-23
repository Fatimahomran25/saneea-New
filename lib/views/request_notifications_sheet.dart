import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/request_notifications_controller.dart';

class RequestNotificationsSheet extends StatefulWidget {
  final RequestNotificationsController controller;
  final Future<void> Function(RequestNotificationItem item) onOpen;

  const RequestNotificationsSheet({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  @override
  State<RequestNotificationsSheet> createState() =>
      _RequestNotificationsSheetState();
}

class _RequestNotificationsSheetState extends State<RequestNotificationsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hintController;
  late final Animation<Offset> _hintAnimation;

  @override
  void initState() {
    super.initState();
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _hintAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.18, 0),
    ).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );

    // Trigger the swipe hint twice, with a short pause between repetitions.
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      await _hintController.forward();
      if (!mounted) return;
      await _hintController.reverse();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await _hintController.forward();
      if (!mounted) return;
      _hintController.reverse();
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _handleNotificationTap(RequestNotificationItem item) async {
    await widget.controller.markAsRead(item.id);
    if (!mounted) return;
    await widget.onOpen(item);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.controller.markAllAsRead,
                  child: const Text('Mark all as read'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.controller.notificationsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No notifications yet.'),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = RequestNotificationItem.fromDoc(docs[index]);
                      final timeText = widget.controller.formatDateTime(
                        item.createdAt,
                      );

                      // Wrap only the first item with the swipe-hint animation.
                      Widget dismissible = Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) =>
                            widget.controller.deleteNotification(item.id),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleNotificationTap(item),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: item.isRead
                                  ? const Color(0xFFF7F7F7)
                                  : const Color(0xFFF1EBFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(
                                    0xFF5A3E9E,
                                  ).withOpacity(0.12),
                                  backgroundImage:
                                      item.senderProfileUrl.isNotEmpty
                                      ? NetworkImage(item.senderProfileUrl)
                                      : null,
                                  child: item.senderProfileUrl.isEmpty
                                      ? const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF5A3E9E),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.senderName.isEmpty
                                            ? 'User'
                                            : item.senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.actionText,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.snippet,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
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
                                      timeText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    if (!item.isRead)
                                      Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF5A3E9E),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      if (index == 0) {
                        // Stack the red delete area behind the card.
                        // SlideTransition moves only the card, so the red
                        // area is revealed on the right — just like a real swipe.
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SlideTransition(
                              position: _hintAnimation,
                              child: dismissible,
                            ),
                          ],
                        );
                      }

                      return dismissible;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
