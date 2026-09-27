import 'package:flutter/material.dart';

class BasicNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final double width;
  final IconData placeholderIcon;
  final BorderRadius? borderRadius;

  const BasicNetworkImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.width = double.infinity,
    this.placeholderIcon = Icons.storefront_outlined,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget wrap(Widget child) {
      if (borderRadius == null) return child;
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }

    if (imageUrl.isEmpty) {
      return wrap(
        Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF0F5), Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(placeholderIcon, size: 40, color: Colors.grey.shade500),
        ),
      );
    }

    return wrap(
      Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          width: width,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, size: 40),
        ),
      ),
    );
  }
}
