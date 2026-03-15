import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

/// ✅ Controller that highlights text overflow (characters after [limit])
class HighlightOverflowController extends TextEditingController {
  HighlightOverflowController({
    required this.limit,
    required this.normalStyle,
    required this.overflowStyle,
  });

  final int limit;
  final TextStyle normalStyle;
  final TextStyle overflowStyle;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;

    // If within limit, render normally
    if (text.length <= limit) {
      return TextSpan(text: text, style: normalStyle);
    }

    final before = text.substring(0, limit);
    final after = text.substring(limit);

    return TextSpan(
      children: [
        TextSpan(text: before, style: normalStyle),
        TextSpan(text: after, style: overflowStyle),
      ],
    );
  }
}

class AnnouncementView extends StatefulWidget {
  const AnnouncementView({super.key});

  @override
  State<AnnouncementView> createState() => _AnnouncementViewState();
}

class _AnnouncementViewState extends State<AnnouncementView> {
  static const int _limit = 150;

  late HighlightOverflowController _textController;

  bool _hasLink = false;
  bool _tooLong = false;

  final RegExp _linkRegex = RegExp(
    r'(\bhttps?:\/\/\S+|\bwww\S+|\b\S+\.[a-zA-Z]{1,}\b)',
    caseSensitive: false,
  );

  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  @override
  void initState() {
    super.initState();

    // Styles will be finalized in build (based on responsive font),
    // but we must init controller here with placeholder styles.
    _textController = HighlightOverflowController(
      limit: _limit,
      normalStyle: const TextStyle(fontSize: 18, color: Colors.black),
      overflowStyle: const TextStyle(
        fontSize: 18,
        color: Colors.black,
        backgroundColor: Color(0x33FF0000), // light red highlight
      ),
    );

    _textController.addListener(_recalc);
  }

  void _recalc() {
    final text = _textController.text;
    final trimmed = text.trim();

    final newHasLink = _linkRegex.hasMatch(text);
    final newTooLong = text.length > _limit;

    // Update only when needed
    if (newHasLink != _hasLink || newTooLong != _tooLong) {
      setState(() {
        _hasLink = newHasLink;
        _tooLong = newTooLong;
      });
    } else {
      // still update publish enabled state when empty/non-empty changes
      setState(() {});
    }

    // Optional: if user deleted to empty, avoid weird spaces issues
    if (trimmed.isEmpty && text.isNotEmpty) {
      // no-op, just keeping logic explicit
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_recalc);
    _textController.dispose();
    super.dispose();
  }

  bool _containsLetter(String text) {
    return RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(text);
  }

  Future<bool> _hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return false;

    try {
      final lookup = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _publish() async {
    final text = _textController.text.trim();

    if (text.isEmpty || _hasLink || _tooLong) return;

    if (!_containsLetter(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service request must contain at least one letter'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be logged in')));
      return;
    }

    //  جديد: فحص الإنترنت قبل الإرسال
    final ok = await _hasInternet();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('announcements')
          .add({'text': text, 'createdAt': FieldValue.serverTimestamp()});

      Navigator.pop(context, text);
    } on FirebaseException catch (e) {
      // لو صار انقطاع/سيرفر
      final msg =
          (e.code == 'unavailable' || e.code == 'network-request-failed')
          ? 'No internet connection. Please try again.'
          : 'Failed to publish: ${e.message ?? e.code}';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const publishColor = Color(0xFF5A3E9E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;

            final contentMaxWidth = w > 600 ? 520.0 : w;
            final horizontalPadding = _clamp(w * 0.06, 16, 28);
            final topPadding = _clamp(w * 0.04, 12, 20);
            final cancelFontSize = _clamp(w * 0.045, 16, 20);
            final hintFontSize = _clamp(w * 0.05, 18, 22);

            // ✅ Update controller styles responsively (same size as your text)
            final normalStyle = TextStyle(
              fontSize: hintFontSize,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            );

            final overflowStyle = TextStyle(
              fontSize: hintFontSize,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              backgroundColor: const Color(0x33FF0000), // highlight overflow
            );

            // Replace styles (keeps same controller instance)
            _textController =
                HighlightOverflowController(
                    limit: _limit,
                    normalStyle: normalStyle,
                    overflowStyle: overflowStyle,
                  )
                  ..value = _textController.value
                  ..addListener(_recalc);

            final text = _textController.text;
            final remaining = _limit - text.length;

            final canPublish = text.trim().isNotEmpty && !_hasLink && !_tooLong;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context, null),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: cancelFontSize,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: canPublish ? _publish : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: publishColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                vertical: w < 360 ? 8 : 10,
                                horizontal: w < 360 ? 14 : 18,
                              ),
                              shape: const StadiumBorder(),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              disabledBackgroundColor: publishColor.withOpacity(
                                0.35,
                              ),
                              disabledForegroundColor: Colors.white.withOpacity(
                                0.9,
                              ),
                            ),
                            child: Text(
                              'Publish',
                              style: TextStyle(
                                fontSize: w < 360 ? 14 : (w < 480 ? 16 : 17),
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: _clamp(w * 0.08, 24, 40)),

                      // ✅ Warning messages ABOVE the text field (bold English)
                      if (_hasLink)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Links are not allowed',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (_tooLong)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Too long (max 150 characters)',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      // ✅ Multiline + wraps + uses available space
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          autofocus: true,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLines: null,
                          expands: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'What are you looking for?',
                            hintStyle: TextStyle(
                              fontSize: hintFontSize,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          style: normalStyle,
                          cursorColor: Colors.black,
                        ),
                      ),

                      // ✅ Twitter-like counter bottom-right (negative turns red)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            remaining >= 0
                                ? '${text.length}/$_limit'
                                : '${text.length}/$_limit',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: remaining >= 0
                                  ? Colors.grey.shade600
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
