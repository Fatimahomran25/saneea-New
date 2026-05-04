import 'package:flutter/material.dart';

import '../controlles/favorites_controller.dart';

class FavoriteHeartButton extends StatefulWidget {
  const FavoriteHeartButton({
    super.key,
    required this.favoriteUserId,
    required this.favoriteUserName,
    required this.favoriteUserRole,
    required this.favoriteUserProfileImage,
    required this.serviceField,
    required this.rating,
    this.iconSize = 20,
    this.padding = const EdgeInsets.all(8),
    this.backgroundColor = Colors.white,
    this.isInteractive = true,
  });

  final String favoriteUserId;
  final String favoriteUserName;
  final String favoriteUserRole;
  final String favoriteUserProfileImage;
  final String serviceField;
  final double rating;
  final double iconSize;
  final EdgeInsets padding;
  final Color backgroundColor;
  final bool isInteractive;

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton> {
  final FavoritesController _controller = FavoritesController();
  bool? _optimisticValue;
  bool _isSaving = false;

  Future<void> _toggleFavorite(bool isFavorite) async {
    if (_isSaving) return;

    final nextValue = !isFavorite;
    setState(() {
      _optimisticValue = nextValue;
      _isSaving = true;
    });

    try {
      if (nextValue) {
        await _controller.addFavorite(
          favoriteUserId: widget.favoriteUserId,
          favoriteUserName: widget.favoriteUserName,
          favoriteUserRole: widget.favoriteUserRole,
          favoriteUserProfileImage: widget.favoriteUserProfileImage,
          serviceField: widget.serviceField,
          rating: widget.rating,
        );
      } else {
        await _controller.removeFavorite(widget.favoriteUserId);
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _optimisticValue = null;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _controller.watchIsFavorite(widget.favoriteUserId),
      builder: (context, snapshot) {
        final isFavorite = _optimisticValue ?? (snapshot.data ?? false);

        if (!widget.isInteractive) {
          return Padding(
            padding: widget.padding,
            child: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite ? Colors.red : const Color(0xFF5A3E9E),
              size: widget.iconSize,
            ),
          );
        }

        return Material(
          color: widget.backgroundColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => _toggleFavorite(isFavorite),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: widget.padding,
              child: _isSaving
                  ? SizedBox(
                      width: widget.iconSize,
                      height: widget.iconSize,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.red : const Color(0xFF5A3E9E),
                      size: widget.iconSize,
                    ),
            ),
          ),
        );
      },
    );
  }
}
