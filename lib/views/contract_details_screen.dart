import 'package:flutter/material.dart';

import '../controlles/contracts_controller.dart';
import '../models/contract_model.dart';

class ContractDetailsScreen extends StatefulWidget {
  final GeneratedContract contract;
  final bool readOnlyMode;

  const ContractDetailsScreen({
    super.key,
    required this.contract,
    this.readOnlyMode = false,
  });

  @override
  State<ContractDetailsScreen> createState() => _ContractDetailsScreenState();
}

class _ContractDetailsScreenState extends State<ContractDetailsScreen> {
  static const Color _primary = Color(0xFF5A3E9E);

  final ContractsController _controller = ContractsController();
  bool _isDeleting = false;

  GeneratedContract get contract => widget.contract;

  Color get _statusColor {
    switch (contract.contractStatus) {
      case 'approved':
      case 'ongoing':
        return const Color(0xFF2E7D32);
      case 'completed':
      case 'past':
        return const Color(0xFF546E7A);
      case 'terminated':
      case 'rejected':
        return const Color(0xFFC75A5A);
      case 'pending_approval':
      case 'termination_pending':
        return const Color(0xFFEF6C00);
      default:
        return _primary;
    }
  }

  Widget _buildStatusChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E2F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.trim().isEmpty ? '-' : value.trim(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalItem({
    required String label,
    required bool approved,
  }) {
    return Row(
      children: [
        Icon(
          approved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          color: approved ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '$label ${approved ? 'approved' : 'pending'}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildContractText() {
    final text = contract.fullContractText.trim();

    if (text.isEmpty) {
      return const Text(
        'Full contract text is not available for this contract.',
        style: TextStyle(color: Colors.black54, height: 1.4),
      );
    }

    return SelectableText(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 13.5,
        height: 1.45,
      ),
    );
  }

  Future<void> _deleteContract() async {
    if (!contract.canDelete) {
      _showSnackBar('Ongoing contracts cannot be deleted.');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Contract'),
          content: const Text(
            'Are you sure you want to delete this contract?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFC75A5A)),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _controller.deleteContract(contract);
      if (!mounted) return;
      Navigator.pop(context, contract.contractId);
      messenger.showSnackBar(const SnackBar(content: Text('Contract deleted.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _showSnackBar(_deleteErrorMessage(e));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _deleteErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    final normalized = message.toLowerCase();

    if (message == 'Contract ID is missing.' ||
        message == 'Contract not found.' ||
        message == 'Ongoing contracts cannot be deleted.' ||
        message == 'You are not allowed to delete this contract.' ||
        message == 'No logged in user found.') {
      return message;
    }

    if (normalized.contains('permission-denied') ||
        normalized.contains('permission denied')) {
      return 'You are not allowed to delete this contract.';
    }

    if (normalized.contains('unavailable') ||
        normalized.contains('network') ||
        normalized.contains('deadline-exceeded')) {
      return 'Check your connection and try again.';
    }

    return 'Failed to delete contract. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final showTerminationStatus =
        contract.contractStatus == 'terminated' ||
        contract.contractStatus == 'termination_pending' ||
        contract.terminationRequested;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Contract Details'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
          actions: [
          if (!widget.readOnlyMode && contract.canDelete)
            IconButton(
              tooltip: 'Delete contract',
              onPressed: _isDeleting ? null : _deleteContract,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 700
                ? 620.0
                : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F2FB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  contract.title,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildStatusChip(contract.statusLabel),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            contract.previewText,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      title: 'Overview',
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: 'Client',
                          value: contract.clientName,
                        ),
                        _buildInfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Freelancer',
                          value: contract.freelancerName,
                        ),
                        _buildInfoRow(
                          icon: Icons.verified_outlined,
                          label: 'Status',
                          value: contract.statusLabel,
                        ),
                        _buildInfoRow(
                          icon: Icons.edit_calendar_outlined,
                          label: 'Created date',
                          value: contract.createdAtText,
                        ),
                        _buildInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Deadline',
                          value: contract.deadlineText,
                        ),
                        _buildInfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Amount',
                          value: contract.amountLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      title: 'Approval Status',
                      children: [
                        _buildApprovalItem(
                          label: 'Client',
                          approved: contract.clientApproved,
                        ),
                        const SizedBox(height: 10),
                        _buildApprovalItem(
                          label: 'Freelancer',
                          approved: contract.freelancerApproved,
                        ),
                      ],
                    ),
                    if (showTerminationStatus) ...[
                      const SizedBox(height: 14),
                      _buildSection(
                        title: 'Termination Status',
                        children: [
                          Text(
                            contract.terminationStatusLabel.isEmpty
                                ? '-'
                                : contract.terminationStatusLabel,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildSection(
                      title: 'Contract Text',
                      children: [_buildContractText()],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
