class QuizQuestion {
  final int id;
  final String question;
  final List<String> options;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
  });
}

class QuizMockData {
  static const List<QuizQuestion> questions = [
    QuizQuestion(
      id: 1,
      question: 'How does your morning usually begin?',
      options: [
        'In a hurry, coffee & rush out',
        'Relax, music & choose outfit',
        'Sleep in & scroll phone',
        'Wake early, workout & eat healthy',
      ],
    ),
    QuizQuestion(
      id: 2,
      question: 'In your wardrobe, which color predominates?',
      options: [
        'White, black, gray (Basic, minimalist)',
        'Pink, orange, yellow (Bright, dynamic)',
        'Blue, green (Pleasant, natural)',
        'Red, purple, silver (Rebellious, seductive)',
      ],
    ),
    QuizQuestion(
      id: 3,
      question: 'When do you feel most confident?',
      options: [
        'When finishing a pile of work (Strong)',
        'When being complimented as cute (Sweet)',
        'When being different from the crowd (Personality)',
        'When everything is neat and clean (Meticulous)',
      ],
    ),
    QuizQuestion(
      id: 4,
      question: "You're choosing a nail set for tonight. What's most important?",
      options: [
        'Durability, no peeling in the middle',
        'Colors that stand out under the lights',
        'Having a "highlight" (1-2 nails of a different color/with stones)',
        'Simple but must be very "elegant"',
      ],
    ),
    QuizQuestion(
      id: 5,
      question: 'What is your biggest challenge when getting your nails done?',
      options: [
        'Sitting for more than 1 hour',
        'Not knowing which color suits your skin tone',
        'Fear of nails breaking/chipping easily',
        'Getting bored of the color quickly after finishing',
      ],
    ),
    QuizQuestion(
      id: 6,
      question: 'If you were compared to a drink, what would you choose?',
      options: [
        'Iced tea (Rustic, easy-going)',
        'Black coffee (Strong, straightforward)',
        'Matcha milk/black tea (Gentle, sophisticated)',
        'Vibrant cocktail (Liberal, outstanding)',
      ],
    ),
    QuizQuestion(
      id: 7,
      question: 'What content do you watch most on TikTok/Reels?',
      options: [
        'Life hacks, fast-paced life',
        'Fashion, beauty',
        'Humor, entertainment',
        'Art, creativity',
      ],
    ),
    QuizQuestion(
      id: 8,
      question: 'Choose a quote that resonates with you most:',
      options: [
        '"Less is more"',
        '"Live to shine"',
        '"I\'m fine, I don\'t need anyone" (Independent)',
        '"Sweet but tough"',
      ],
    ),
    QuizQuestion(
      id: 9,
      question: 'Describe yourself in 1 word?',
      options: [
        'Dynamic',
        'Sweet',
        'Personality/Unique',
        'Minimalist',
        'Elegant/Luxurious',
        'Artistic',
      ],
    ),
  ];
}
