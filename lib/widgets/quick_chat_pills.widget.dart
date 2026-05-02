import 'package:flutter/material.dart';

class QuickChatPills extends StatelessWidget {
  const QuickChatPills({
    required this.options,
    required this.onSelected,
    this.horizontalPadding = 12,
    this.enabled = true,
    this.showRequestCancellation = true,
    this.onRequestCancellation,
    super.key,
  });

  final List<String> options;
  final double horizontalPadding;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final bool showRequestCancellation;
  final VoidCallback? onRequestCancellation;

  @override
  Widget build(BuildContext context) {
    final hasTrailingRequestCancellation = showRequestCancellation;
    if (options.isEmpty && !hasTrailingRequestCancellation) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: options.length + (hasTrailingRequestCancellation ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isRequestCancellation =
              hasTrailingRequestCancellation && index == options.length;
          final option =
              isRequestCancellation ? "Request cancellation" : options[index];
          final pillColor = isRequestCancellation
              ? const Color(0xFFFF3B30)
              : const Color(0xFF007BFF);
          return Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: pillColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.all(
                  Radius.circular(1000),
                ),
                border: Border.all(
                  color: pillColor.withValues(alpha: 0.18),
                ),
              ),
              child: InkWell(
                onTap: enabled
                    ? () {
                        if (isRequestCancellation) {
                          onRequestCancellation?.call();
                          return;
                        }
                        onSelected(option);
                      }
                    : null,
                borderRadius: const BorderRadius.all(
                  Radius.circular(1000),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: pillColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
