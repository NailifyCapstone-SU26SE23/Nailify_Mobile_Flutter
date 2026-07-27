import 'dart:io';

import 'package:flutter/material.dart';

import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/services/ar_try_on_service.dart';

/// Màn hình xem trước Snapshot Try-on.
///
/// Hiển thị ảnh tĩnh được xử lý từ Native, kéo tràn viền để dễ xem.
/// Khi không có bàn tay: hiện nút "Chụp lại" → mở lại camera ngay (không về
/// trang chọn phương thức).
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
    final file = File(snapshot.imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      // Không dùng AppBar → ảnh tràn viền, rộng hơn
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── ẢNH: fitWidth để tận dụng chiều ngang toàn màn hình ──────────
          Image.file(
            file,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            width: double.infinity,
            height: double.infinity,
          ),

          // ── NÚT BACK (góc trên-trái) ─────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // ── OVERLAY KHI KHÔNG PHÁT HIỆN BÀN TAY ─────────────────────────
          if (!snapshot.hasHand)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pan_tool_outlined,
                          color: Colors.white70,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Không phát hiện bàn tay trong ảnh.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hãy đảm bảo bàn tay nằm gọn trong khung\nvà ánh sáng đủ, sau đó thử chụp lại.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Trả 'retake' → TryOnMethodSelectionScreen mở camera lại
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop('retake'),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Chụp lại'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF69B4),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(180, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

