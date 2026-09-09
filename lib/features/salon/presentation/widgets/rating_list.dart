import 'package:flutter/material.dart';

import '../../data/models/booking_rating_model.dart';

class RatingList extends StatelessWidget {
  final List<BookingRatingModel> ratings;

  const RatingList({super.key, required this.ratings});

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) {
      return const Text('No ratings yet.');
    }

    return Column(
      children: ratings.map((rating) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.star, color: Colors.amber),
          title: Text('${rating.overallScore}/5'),
          subtitle: Text(
            rating.comment.isEmpty ? 'No comment' : rating.comment,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}
