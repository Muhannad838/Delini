import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PopupOverlay extends StatelessWidget {
  final Widget child;
  final String title;
  final VoidCallback onClose;
  final Animation<double> animation;
  final bool isDark;

  const PopupOverlay({
    super.key,
    required this.child,
    required this.title,
    required this.onClose,
    required this.animation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final borderColor = isDark ? Colors.white : const Color(0xFF000000);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (animation.value == 0) return const SizedBox.shrink();

        return Stack(
          children: [
            // Semi-transparent backdrop
            GestureDetector(
              onTap: onClose,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3 * animation.value),
              ),
            ),
            // Centered popup window — absorb taps so they don't hit backdrop
            Center(
              child: GestureDetector(
                onTap: () {}, // absorb taps on popup area
                child: Transform.scale(
                scale: Curves.easeOutBack.transform(animation.value),
                child: Opacity(
                  opacity: animation.value.clamp(0.0, 1.0),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.92,
                      maxHeight: MediaQuery.of(context).size.height * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.75),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? AppColors.darkDivider : AppColors.divider,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: onClose,
                                icon: Icon(Icons.close, size: 20, color: textColor),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        Flexible(child: child),
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ],
        );
      },
    );
  }
}
