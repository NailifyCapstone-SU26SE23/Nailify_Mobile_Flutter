import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../widgets/booking_rating_widgets.dart';

class BookingRatingPage extends StatefulWidget {
  final String bookingId;

  const BookingRatingPage({super.key, required this.bookingId});

  @override
  State<BookingRatingPage> createState() => _BookingRatingPageState();
}

class _BookingRatingPageState extends State<BookingRatingPage> {
  final MyBookingApiService _apiService = MyBookingApiService();
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _existingRating;
  File? _localImage;
  String? _existingImageUrl;

  int _overallScore = 5;
  int _serviceQuality = 5;
  int _punctuality = 5;
  int _cleanliness = 5;
  bool _canEdit = true;
  String _disableReason = '';

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRating() async {
    try {
      final rating = await _apiService.getRatingByBooking(widget.bookingId);
      if (!mounted) return;

      if (rating != null) {
        // Calculate editability (48 hours limit)
        final dateStr =
            rating['createdDate'] ??
            rating['createdAt'] ??
            rating['creationDate'] ??
            rating['created'] ??
            '';
        final createdTime =
            DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
        final difference = DateTime.now().difference(createdTime);

        setState(() {
          _existingRating = rating;
          _overallScore = rating['overallScore'] ?? 5;
          _serviceQuality = rating['serviceQuality'] ?? 5;
          _punctuality = rating['punctuality'] ?? 5;
          _cleanliness = rating['cleanliness'] ?? 5;
          _commentController.text = rating['comment'] ?? '';
          _existingImageUrl = rating['imageUrl'] ?? rating['image'];

          if (difference.inHours > 48) {
            _canEdit = false;
            _disableReason = 'Chỉ có thể chỉnh sửa trong 48h sau khi đánh giá';
          } else {
            _canEdit = true;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _canEdit = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (!_canEdit) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    setState(() {
      _localImage = File(image.path);
      _existingImageUrl = null; // Overwrite network image if local image chosen
    });
  }

  void _removeImage() {
    if (!_canEdit) return;
    setState(() {
      _localImage = null;
      _existingImageUrl = null;
    });
  }

  Future<void> _deleteRating() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa đánh giá',
          style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa đánh giá này không? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final ratingId =
          _existingRating!['bookingRatingId'] ?? _existingRating!['id'] ?? '';
      await _apiService.deleteBookingRating(ratingId.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa đánh giá thành công!')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa đánh giá thất bại: $e')));
    }
  }

  Future<void> _submitRating() async {
    if (_isSubmitting || !_canEdit) return;
    setState(() => _isSubmitting = true);

    try {
      if (_existingRating == null) {
        await _apiService.createBookingRating(
          bookingId: widget.bookingId,
          overallScore: _overallScore,
          comment: _commentController.text.trim(),
          serviceQuality: _serviceQuality,
          punctuality: _punctuality,
          cleanliness: _cleanliness,
          imagePath: _localImage?.path,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi đánh giá thành công!')),
        );
      } else {
        final ratingId =
            _existingRating!['bookingRatingId'] ?? _existingRating!['id'] ?? '';
        await _apiService.updateBookingRating(
          ratingId: ratingId.toString(),
          overallScore: _overallScore,
          comment: _commentController.text.trim(),
          serviceQuality: _serviceQuality,
          punctuality: _punctuality,
          cleanliness: _cleanliness,
          imagePath: _localImage?.path,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật đánh giá thành công!')),
        );
      }
      context.pop(true); // Return true to indicate reload needed
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gặp lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewRating = _existingRating == null;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isNewRating ? 'Đánh giá dịch vụ' : 'Chỉnh sửa đánh giá',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
            color: AppColors.primaryDark,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning Banner if cannot edit
                  if (!_canEdit) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.amber.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _disableReason,
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Scorecards block
                  ScoreCard(
                    label: 'Đánh giá chung',
                    value: _overallScore,
                    onChanged: (val) => setState(() => _overallScore = val),
                    enabled: _canEdit,
                  ),
                  const SizedBox(height: 12),
                  ScoreCard(
                    label: 'Chất lượng dịch vụ',
                    value: _serviceQuality,
                    onChanged: (val) => setState(() => _serviceQuality = val),
                    enabled: _canEdit,
                  ),
                  const SizedBox(height: 12),
                  ScoreCard(
                    label: 'Đúng giờ',
                    value: _punctuality,
                    onChanged: (val) => setState(() => _punctuality = val),
                    enabled: _canEdit,
                  ),
                  const SizedBox(height: 12),
                  ScoreCard(
                    label: 'Vệ sinh sạch sẽ',
                    value: _cleanliness,
                    onChanged: (val) => setState(() => _cleanliness = val),
                    enabled: _canEdit,
                  ),
                  const SizedBox(height: 24),

                  // Comment Input Box
                  RatingCommentInput(
                    controller: _commentController,
                    enabled: _canEdit,
                  ),
                  const SizedBox(height: 20),

                  // Image Upload/Preview
                  RatingImagePicker(
                    existingImageUrl: _existingImageUrl,
                    localImage: _localImage,
                    onPickImage: _pickImage,
                    onRemoveImage: _removeImage,
                    enabled: _canEdit,
                  ),
                  const SizedBox(height: 32),

                  // Bottom Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Tooltip(
                      message: _canEdit ? '' : _disableReason,
                      child: ElevatedButton(
                        onPressed: _canEdit && !_isSubmitting
                            ? _submitRating
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade500,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isNewRating ? 'Gửi đánh giá' : 'Cập nhật',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (!isNewRating) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Tooltip(
                        message: _canEdit ? '' : _disableReason,
                        child: OutlinedButton(
                          onPressed: _canEdit && !_isSubmitting
                              ? _deleteRating
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(
                              color: _canEdit
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: const Text(
                            'Xóa đánh giá',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
