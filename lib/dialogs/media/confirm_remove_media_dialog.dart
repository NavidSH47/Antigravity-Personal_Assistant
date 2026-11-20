import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../theme/app_theme.dart';

class ConfirmRemoveMediaDialog {
  static void show({
    required BuildContext context,
    required VibePalette palette,
    required MediaItem item,
    required VoidCallback onConfirmed,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.bgElevated,
        title: Text(
          'Remove Media Item',
          style: TextStyle(
            color: palette.textMain,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${item.title}" from your library? Any ongoing daily goals linked to this item will remain as standalone tasks.',
          style: TextStyle(color: palette.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.borderSubtle),
              foregroundColor: palette.textMuted,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirmed();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
