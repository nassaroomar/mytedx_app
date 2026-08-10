import 'package:flutter/material.dart';

import '../services/local_history_service.dart';
import '../theme/app_theme.dart';
import 'tag_chip.dart';

/// First-launch interests picker. English UI as requested.
class InterestsDialog extends StatefulWidget {
  const InterestsDialog({
    super.key,
    required this.onDone,
  });

  final Future<void> Function(List<String> selected) onDone;

  static Future<void> showIfNeeded(BuildContext context) async {
    final local = LocalHistoryService();
    if (await local.hasCompletedInterestsPrompt()) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return InterestsDialog(
          onDone: (selected) async {
            if (selected.isEmpty) {
              await local.markInterestsPromptDone();
            } else {
              await local.saveInterests(selected);
            }
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
    );
  }

  @override
  State<InterestsDialog> createState() => _InterestsDialogState();
}

class _InterestsDialogState extends State<InterestsDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text(
        'What are your interests?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick one or more topics so we can personalize your home feed.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LocalHistoryService.interestOptions.map((tag) {
                  final selected = _selected.contains(tag);
                  return TagChip(
                    label: tag,
                    selected: selected,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selected.remove(tag);
                        } else {
                          _selected.add(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onDone(const []),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => widget.onDone(_selected.toList()),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.tedRed),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
