import 'package:flutter/material.dart';

import '../controlles/contracts_controller.dart';
import '../models/contract_model.dart';
import 'chat_view.dart';
import 'contract_card.dart';
import 'contract_details_screen.dart';

class ContractsListScreen extends StatefulWidget {
  final String? userRole;

  const ContractsListScreen({super.key, this.userRole});

  @override
  State<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends State<ContractsListScreen> {
  static const Color _primary = Color(0xFF5A3E9E);

  final ContractsController _controller = ContractsController();
  final Set<String> _locallyDeletedContractIds = <String>{};
  int _selectedTabIndex = 0;

  static const List<_ContractsTab> _tabs = [
    _ContractsTab(label: 'Ongoing', group: ContractStatusGroup.ongoing),
    _ContractsTab(label: 'Terminated', group: ContractStatusGroup.terminated),
    _ContractsTab(label: 'Past', group: ContractStatusGroup.past),
  ];

  Map<ContractStatusGroup, List<GeneratedContract>> _groupContracts(
    List<GeneratedContract> contracts,
  ) {
    final ongoingContracts = <GeneratedContract>[];
    final terminatedContracts = <GeneratedContract>[];
    final pastContracts = <GeneratedContract>[];

    for (final contract in contracts) {
      final status = contract.contractStatus.trim().toLowerCase();
      final isExpired = contract.hasDeadlinePassed;
      final isCancelled = status == 'cancelled' || status == 'canceled';
      final isRejected = status == 'rejected';
      final isTerminated = status == 'terminated';
      final needsCurrentUserAction =
          _controller.getContractSection(contract) ==
          ContractSection.requiresAction;
      final isWorkflowPending =
          status == 'pending_approval' ||
          status == 'edited' ||
          status == 'termination_pending';
      final isApprovedContract = status == 'approved';
      final isOngoingContract = status == 'ongoing';

      if (isTerminated) {
        terminatedContracts.add(contract);
        continue;
      }

      if (isRejected || isCancelled) {
        pastContracts.add(contract);
        continue;
      }

      if (needsCurrentUserAction) {
        ongoingContracts.add(contract);
        continue;
      }

      if (isApprovedContract && isExpired) {
        pastContracts.add(contract);
        continue;
      }

      if (isExpired) {
        pastContracts.add(contract);
        continue;
      }

      if (isWorkflowPending || isApprovedContract || isOngoingContract) {
        ongoingContracts.add(contract);
        continue;
      }

      pastContracts.add(contract);
    }

    int compareByRecentActivity(GeneratedContract a, GeneratedContract b) {
      final aDate = a.sortDate ?? a.deadlineDate;
      final bDate = b.sortDate ?? b.deadlineDate;

      if (aDate == null && bDate == null) {
        return a.title.compareTo(b.title);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    }

    ongoingContracts.sort(compareByRecentActivity);
    terminatedContracts.sort(compareByRecentActivity);
    pastContracts.sort(compareByRecentActivity);

    return {
      ContractStatusGroup.ongoing: ongoingContracts,
      ContractStatusGroup.terminated: terminatedContracts,
      ContractStatusGroup.past: pastContracts,
    };
  }

  Future<void> _openContractDetails(GeneratedContract contract) async {
    final deletedContractId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractDetailsScreen(contract: contract),
      ),
    );

    if (!mounted || deletedContractId == null || deletedContractId.isEmpty) {
      return;
    }

    setState(() {
      _locallyDeletedContractIds.add(deletedContractId);
    });
  }

  Future<void> _confirmDeleteContract(GeneratedContract contract) async {
    if (!contract.canDelete) {
      _showSnackBar('Ongoing contracts cannot be deleted.');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Contract'),
          content: const Text('Are you sure you want to delete this contract?'),
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

    try {
      await _controller.deleteContract(contract);
      if (!mounted) return;
      setState(() {
        _locallyDeletedContractIds.add(contract.contractId);
      });
      _showSnackBar('Contract deleted.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(_deleteErrorMessage(e));
    }
  }

  List<GeneratedContract> _visibleContracts(List<GeneratedContract> contracts) {
    if (_locallyDeletedContractIds.isEmpty) return contracts;

    return contracts.where((contract) {
      return !_locallyDeletedContractIds.contains(contract.contractId);
    }).toList();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Widget _buildEmptyState(String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: _primary.withOpacity(0.10),
              child: const Icon(
                Icons.description_outlined,
                color: _primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No $label contracts',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsList({
    required String emptyLabel,
    required List<GeneratedContract> contracts,
  }) {
    if (contracts.isEmpty) {
      return _buildEmptyState(emptyLabel);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: contracts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final contract = contracts[index];
        final chatId = contract.chatId?.trim() ?? '';
        return ContractCard.fromContract(
          contract: contract,
          onTap: () => _openContractDetails(contract),
          onChatTap: chatId.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatView(
                        chatId: chatId,
                        otherUserName: contract.otherUserName,
                        otherUserId: contract.otherUserId,
                        otherUserRole: contract.otherUserRole,
                      ),
                    ),
                  );
                },
          onDelete: contract.canDelete
              ? () => _confirmDeleteContract(contract)
              : null,
        );
      },
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required int count,
  }) {
    final isSelected = index == _selectedTabIndex;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? _primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            child: Text(
              '$label ($count)',
              maxLines: 1,
              style: TextStyle(
                color: isSelected ? Colors.white : _primary,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabFilters(
    Map<ContractStatusGroup, List<GeneratedContract>> groups,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F2FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final contracts = groups[tab.group] ?? const <GeneratedContract>[];
            return _buildTabButton(
              index: index,
              label: tab.label,
              count: contracts.length,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabbedContracts(List<GeneratedContract> contracts) {
    final groups = _groupContracts(contracts);
    final selectedTab = _tabs[_selectedTabIndex];
    final selectedContracts =
        groups[selectedTab.group] ?? const <GeneratedContract>[];

    return Column(
      children: [
        _buildTabFilters(groups),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(selectedTab.group),
              child: _buildContractsList(
                emptyLabel: selectedTab.label.toLowerCase(),
                contracts: selectedContracts,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Contracts'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<List<GeneratedContract>>(
          stream: _controller.getGeneratedContracts(userRole: widget.userRole),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Failed to load contracts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              );
            }

            final contracts = _visibleContracts(
              snapshot.data ?? const <GeneratedContract>[],
            );

            return _buildTabbedContracts(contracts);
          },
        ),
      ),
    );
  }
}

class _ContractsTab {
  final String label;
  final ContractStatusGroup group;

  const _ContractsTab({required this.label, required this.group});
}
