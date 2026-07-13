import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/my_booking_api_service.dart';

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
  XFile? _image;
  int _overallScore = 5;
  int _serviceQuality = 5;
  int _punctuality = 5;
  int _cleanliness = 5;

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
      setState(() {
        _existingRating = rating;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    setState(() => _image = image);
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _apiService.createBookingRating(
        bookingId: widget.bookingId,
        overallScore: _overallScore,
        comment: _commentController.text.trim(),
        serviceQuality: _serviceQuality,
        punctuality: _punctuality,
        cleanliness: _cleanliness,
        imagePath: _image?.path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted successfully.')),
      );
      context.go('/my-bookings/detail', extra: widget.bookingId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit rating failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Rate booking',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: _existingRating == null
                  ? _buildRatingForm()
                  : _buildExistingRating(),
            ),
    );
  }

  Widget _buildRatingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScoreCard('Overall score', _overallScore, (value) {
          setState(() => _overallScore = value);
        }),
        const SizedBox(height: 12),
        _buildScoreCard('Service quality', _serviceQuality, (value) {
          setState(() => _serviceQuality = value);
        }),
        const SizedBox(height: 12),
        _buildScoreCard('Punctuality', _punctuality, (value) {
          setState(() => _punctuality = value);
        }),
        const SizedBox(height: 12),
        _buildScoreCard('Cleanliness', _cleanliness, (value) {
          setState(() => _cleanliness = value);
        }),
        const SizedBox(height: 20),
        TextField(
          controller: _commentController,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Comment',
            hintText: 'Share your experience',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _pickImage,
          icon: const Icon(Icons.image_outlined),
          label: Text(_image == null ? 'Add image' : 'Change image'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_image != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_image!.path),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Text(
                  'Unable to preview image',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _image!.name,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _image = null),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitRating,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.star, color: Colors.white),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit rating'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingRating() {
    final rating = _existingRating!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You already rated this booking.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildReadOnlyScore('Overall', rating['overallScore']),
          _buildReadOnlyScore('Service quality', rating['serviceQuality']),
          _buildReadOnlyScore('Punctuality', rating['punctuality']),
          _buildReadOnlyScore('Cleanliness', rating['cleanliness']),
          if ((rating['comment']?.toString() ?? '').isNotEmpty) ...[
            const Divider(height: 24),
            Text(rating['comment'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              final score = index + 1;
              return IconButton(
                onPressed: _isSubmitting ? null : () => onChanged(score),
                icon: Icon(
                  score <= value ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700,
                ),
                tooltip: '$score',
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyScore(String label, dynamic value) {
    final score = (value as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$score/5', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
