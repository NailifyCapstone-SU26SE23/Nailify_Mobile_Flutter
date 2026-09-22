import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';

class DesignGalleryCta extends StatelessWidget {
  final VoidCallback? onBookPressed;
  final VoidCallback? onCustomPressed;

  const DesignGalleryCta({super.key, this.onBookPressed, this.onCustomPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = _tryGetL10n(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppColors.primarySurface,
            AppColors.primaryLight.withValues(alpha: 0.4),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.primaryLight, width: 1.2),
      ),
      child: Column(
        children: [
          // Sparkle Icon Circle Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            l10n?.galleryCtaTitle ?? "Can't find your dream design?",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            l10n?.galleryCtaSubtitle ??
                'Upload your inspiration image or generate a personalized AI design.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: _GradientPillButton(
                  label: l10n?.galleryBookBtn ?? 'Book Now',
                  icon: Icons.calendar_today_rounded,
                  onPressed: onBookPressed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OutlinedPillButton(
                  label: l10n?.galleryCustomBtn ?? 'Custom Design ↗',
                  icon: Icons.brush_rounded,
                  onPressed: onCustomPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  dynamic _tryGetL10n(BuildContext context) {
    try {
      return context.l10n;
    } catch (_) {
      return null;
    }
  }
}

class _GradientPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GradientPillButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _OutlinedPillButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
