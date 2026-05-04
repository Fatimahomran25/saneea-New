import 'package:flutter/material.dart';

class ChatActionButton extends StatelessWidget {
  const ChatActionButton({
    super.key,
    required this.onPressed,
    this.isEnabled = true,
    this.isLoading = false,
    this.label = 'Chat',
  });

  final VoidCallback onPressed;
  final bool isEnabled;
  final bool isLoading;
  final String label;

  static const Color _primary = Color(0xFF5A3E9E);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.7,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}
