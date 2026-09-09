import 'package:flutter/material.dart';

class BasicNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final double width;

  const BasicNetworkImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.storefront_outlined, size: 40),
      );
    }

    return Image.network(
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
    );
  }
}
