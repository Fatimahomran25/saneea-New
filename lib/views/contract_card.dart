import 'package:flutter/material.dart';

import '../models/contract_model.dart';

class ContractCard extends StatelessWidget {
  final String title;
  final String summary;
  final String otherPartyName;
  final String status;
  final String deadline;
  final String amount;
  final bool hasChat;
  final Color accentColor;
  final Color statusBackgroundColor;
  final Color statusTextColor;
  final VoidCallback? onTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onDelete;

  const ContractCard({
    super.key,
    required this.title,
    required this.summary,
    required this.otherPartyName,
    required this.status,
    required this.deadline,
    this.amount = '',
    this.hasChat = false,
    this.accentColor = _primary,
    this.statusBackgroundColor = const Color(0xFFF1F3F4),
    this.statusTextColor = Colors.black54,
    this.onTap,
    this.onChatTap,
    this.onDelete,
  });

  factory ContractCard.fromContract({
    required GeneratedContract contract,
    VoidCallback? onTap,
    VoidCallback? onChatTap,
    VoidCallback? onDelete,
  }) {
    final accentColor = _accentColorFor(contract);
    final statusColors = _statusColorsFor(contract.contractStatus);
    final deleteAction = contract.canDelete ? onDelete : null;
    final hasChat =
        contract.chatId != null && contract.chatId!.trim().isNotEmpty;

    return ContractCard(
      title: contract.title,
      summary: contract.previewText,
      otherPartyName: contract.otherUserName,
      status: contract.statusLabel,
      deadline: contract.deadlineText,
      amount: contract.amountLabel == '-' ? '' : contract.amountLabel,
      hasChat: hasChat,
      accentColor: accentColor,
      statusBackgroundColor: statusColors.background,
      statusTextColor: statusColors.text,
      onTap: onTap,
      onChatTap: onChatTap,
      onDelete: deleteAction,
    );
  }

  static const Color _primary = Color(0xFF5A3E9E);

  static Color _accentColorFor(GeneratedContract contract) {
    switch (contract.group) {
      case ContractStatusGroup.ongoing:
        return contract.contractStatus == 'approved'
            ? const Color(0xFF2E7D32)
            : _primary;
      case ContractStatusGroup.terminated:
        return const Color(0xFFC75A5A);
      case ContractStatusGroup.past:
        return const Color(0xFFEF8F25);
    }
  }

  static _StatusColors _statusColorsFor(String contractStatus) {
    switch (contractStatus) {
      case 'approved':
      case 'ongoing':
        return const _StatusColors(
          background: Color(0xFFE8F5E9),
          text: Color(0xFF2E7D32),
        );
      case 'completed':
      case 'past':
        return const _StatusColors(
          background: Color(0xFFEFF3F6),
          text: Color(0xFF546E7A),
        );
      case 'terminated':
        return const _StatusColors(
          background: Color(0xFFFFEBEE),
          text: Color(0xFFC75A5A),
        );
      case 'termination_pending':
      case 'pending_approval':
        return const _StatusColors(
          background: Color(0xFFFFF4E5),
          text: Color(0xFFEF6C00),
        );
      case 'rejected':
        return const _StatusColors(
          background: Color(0xFFFFEBEE),
          text: Color(0xFFC75A5A),
        );
      case 'edited':
        return const _StatusColors(
          background: Color(0xFFEEE8FB),
          text: _primary,
        );
      default:
        return const _StatusColors(
          background: Color(0xFFF1F3F4),
          text: Colors.black54,
        );
    }
  }

  Widget _buildChatButton() {
    final isEnabled = hasChat && onChatTap != null;
    final backgroundColor = isEnabled
        ? accentColor.withOpacity(0.12)
        : const Color(0xFFF1F3F4);
    final iconColor = isEnabled ? accentColor : Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChatTap,
        borderRadius: BorderRadius.circular(17),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: backgroundColor,
          child: Icon(Icons.chat_bubble_outline, color: iconColor, size: 18),
        ),
      ),
    );
  }

  Widget _buildDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$label: ${value.isEmpty ? '-' : value}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: statusBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: statusTextColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMoreMenu() {
    if (onDelete == null) return const SizedBox.shrink();

    return _ContractOptionsMenu(onDelete: onDelete!);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFAFE),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9E2F4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 16,
                top: 0,
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatusChip(),
                                if (onDelete != null) ...[
                                  const SizedBox(width: 2),
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: _buildMoreMenu(),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      summary.isEmpty
                          ? 'No contract summary available.'
                          : summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (amount.trim().isNotEmpty)
                          _buildDetail(
                            icon: Icons.payments_outlined,
                            label: 'Payment',
                            value: amount,
                          ),
                        _buildDetail(
                          icon: Icons.calendar_today_outlined,
                          label: 'Deadline',
                          value: deadline,
                        ),
                        _buildDetail(
                          icon: Icons.person_outline,
                          label: 'With',
                          value: otherPartyName,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherPartyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildChatButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusColors {
  final Color background;
  final Color text;

  const _StatusColors({required this.background, required this.text});
}

class _ContractOptionsMenu extends StatefulWidget {
  final VoidCallback onDelete;

  const _ContractOptionsMenu({required this.onDelete});

  @override
  State<_ContractOptionsMenu> createState() => _ContractOptionsMenuState();
}

class _ContractOptionsMenuState extends State<_ContractOptionsMenu> {
  bool _isOpen = false;

  void _setOpen(bool value) {
    if (!mounted) return;
    setState(() => _isOpen = value);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      padding: EdgeInsets.zero,
      color: Colors.white,
      elevation: 4,
      enableFeedback: true,
      onOpened: () => _setOpen(true),
      onCanceled: () => _setOpen(false),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        _setOpen(false);
        if (value == 'delete') {
          widget.onDelete();
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem<String>(
            value: 'delete',
            height: 40,
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Color(0xFF9B6670), size: 18),
                SizedBox(width: 10),
                Text(
                  'Delete Contract',
                  style: TextStyle(
                    color: Color(0xFF7A4E58),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: AnimatedScale(
        scale: _isOpen ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isOpen ? const Color(0xFFF1ECFA) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isOpen ? const Color(0xFFE3D9F2) : Colors.transparent,
            ),
          ),
          child: Icon(
            Icons.more_vert_rounded,
            color: _isOpen ? const Color(0xFF5A3E9E) : const Color(0xFF8C849C),
            size: 20,
          ),
        ),
      ),
    );
  }
}
