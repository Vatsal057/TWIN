import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'widgets/brand_mark.dart';

/// Shown while the backend signs in.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key, required this.step, this.error, this.onRetry});

  final String step;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandMark(),
              const SizedBox(height: 40),
              if (!failed)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 30,
                ),
              const SizedBox(height: 20),
              Text(
                step,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.parchment.withValues(alpha: 0.7),
                  letterSpacing: 0.4,
                ),
              ),
              if (failed) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.parchment.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),
                if (onRetry != null)
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
