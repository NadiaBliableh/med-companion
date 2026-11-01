import 'package:flutter/material.dart';

import '../profile/profile_theme.dart';

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.highlight = false});
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? pTeal.withValues(alpha: 0.12) : pTrack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? pTeal.withValues(alpha: 0.5) : pCardBorder,
        ),
      ),
      child: Text(label,
          style: TextStyle(color: highlight ? pTeal : pMuted, fontSize: 12.5)),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
