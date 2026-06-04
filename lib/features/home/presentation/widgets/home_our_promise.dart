import 'package:flutter/material.dart';

class OurPromisePage extends StatelessWidget {
  const OurPromisePage({super.key}); // hoặc const OurPromiseSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // return Scaffold(body: SingleChildScrollView(...)) (con bọ RenderCustomMultiChildLayoutBox object was given an infinite size during layout)
    // chỉ trả về thẳng một Container hoặc Padding
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // chỉ cho Column này chiếm chiều cao vừa đủ chứa nội dung bên trong
        children: [
          const Text(
            'OUR PROMISE',
            style: TextStyle(
              color: Color(0xFFFF66C4),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Why Choose Us',
            style: TextStyle(
              color: Color(0xFFFF66C4),
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'At Nailify, we understand that when it comes to nail art, you have many options to choose from.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // --- Phần Danh sách Cặrd ---
          _buildPromiseCard(
            icon: Icons.access_time,
            title: 'Years of Experience',
            description: 'We bring a wealth of experience to the world of nail art.',
          ),
          const SizedBox(height: 16),
          _buildPromiseCard(
            icon: Icons.people_outline,
            title: 'Experienced Staff',
            description: 'Our experienced staff members have honed skills for nail care.',
          ),
          const SizedBox(height: 16),
          _buildPromiseCard(
            icon: Icons.star_border,
            title: 'Best Quality',
            description: 'You\'ll notice our unwavering commitment to quality service.',
          ),
          const SizedBox(height: 16),
          _buildPromiseCard(
            icon: Icons.trending_up,
            title: 'Trend Awareness',
            description: 'We stay up-to-date with the latest nail art trends and techniques.',
          ),
        ],
      ),
    );
  }

  Widget _buildPromiseCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6E6D7),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            bottom: -20,
            right: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFF66C4).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFFF66C4),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Text(
                            'Read more',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}