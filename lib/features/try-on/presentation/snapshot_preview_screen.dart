import 'dart:io';

import 'package:flutter/material.dart';

import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/services/ar_try_on_service.dart';

/// Màn hình xem trước Snapshot Try-on.
///
/// Hiển thị ảnh tĩnh được xử lý từ Native.
/// Móng và phụ kiện đã được Native (OverlayView) render đè trực tiếp lên ảnh.
class SnapshotPreviewScreen extends StatelessWidget {
  final SnapshotResult snapshot;
  final CustomerNailModel nail;

  const SnapshotPreviewScreen({
    super.key,
    required this.snapshot,
    required this.nail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Snapshot Try-on'),
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _buildImage(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            );
          },
        ),
      ),
    );
  }

  Widget _buildImage({
    required double maxWidth,
    required double maxHeight,
  }) {
    final file = File(snapshot.imagePath);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Lớp nền: ảnh tĩnh đã được Native vẽ móng (composite image)
        Image.file(
          file,
          fit: BoxFit.contain,
          width: maxWidth,
          height: maxHeight,
        ),

        // Thông báo khi không phát hiện tay
        if (!snapshot.hasHand)
          const Center(
            child: Card(
              color: Color(0xCC000000),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Không phát hiện bàn tay trong ảnh.\nVui lòng chụp lại.',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

