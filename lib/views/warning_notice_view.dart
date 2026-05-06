import 'package:flutter/material.dart';

class WarningNoticeView extends StatelessWidget {
  const WarningNoticeView({
    super.key,
    required this.title,
    required this.message,
    this.warningCount,
    this.maxWarnings,
  });

  final String title;
  final String message;
  final int? warningCount;
  final int? maxWarnings;

  static const Color _primary = Color(0xFF5A3E9E);
  static const Color _surface = Color(0xFFF6F2FB);

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? 'Account Notice' : title.trim();
    final safeMessage = message.trim().isEmpty
        ? 'You received an account notice from the admin.'
        : message.trim();
    final hasWarningSummary =
        warningCount != null && maxWarnings != null && maxWarnings! > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      appBar: AppBar(
        title: const Text('Warning Details'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE3D8F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: _primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    safeTitle,
                    style: const TextStyle(
                      color: Color(0xFF1F1B2D),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    safeMessage,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (hasWarningSummary) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE3D8F6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: _primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Warning count: $warningCount/$maxWarnings',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
