class IntroScreen {
  final String title;
  final String description;
  final String imagePath;

  IntroScreen({
    required this.title,
    required this.description,
    required this.imagePath,
  });

  static List<IntroScreen> getIntroScreens() {
    return [
      IntroScreen(
        title: 'Discover Lucid Dreaming',
        description: 'You dream 2 hours every night. Reclaim this time. Live 26 hours a day and Take control of your dreams. Unlock the impossible with Lucid Now.',
        imagePath: 'assets/introscreen/screen1.jpg',
      ),
      IntroScreen(
        title: 'Targeted Lucidity Reactivation',
        description: 'TLR protocol delivers sound cues that trigger lucidity instantly during dreams. Science-backed for concrete results.',
        imagePath: 'assets/introscreen/screen2.png',
      ),
      IntroScreen(
        title: 'Train Your Brain',
        description: 'Quick evening meditation training with powerful melody cues creates instant awareness triggers.',
        imagePath: 'assets/introscreen/screen3.jpg',
      ),
      IntroScreen(
        title: 'Smart Sleep Monitoring',
        description: 'Sleep phases estimation to target your dream phases. Delivers cues at the key moment for maximum lucidity.',
        imagePath: 'assets/introscreen/screen4.png',
      ),
      IntroScreen(
        title: 'Remember Your Adventures',
        description: 'Capture mind-blowing dream experiences effortlessly. Watch your lucid skills improve with every journal entry.',
        imagePath: 'assets/introscreen/screen5.jpg',
      ),
      IntroScreen(
        title: 'Soar Through the Skies',
        description: 'Feel the rush as you fly at incredible speeds. Experience complete freedom tonight in your dreams.',
        imagePath: 'assets/introscreen/screen6.jpg',
      ),
      IntroScreen(
        title: 'Unleash Your Inner Wizard',
        description: 'Command incredible powers with a thought. Become unstoppable in your own dream universe.',
        imagePath: 'assets/introscreen/screen7.jpg',
      ),
      IntroScreen(
        title: 'Live Your Wildest Dreams',
        description: 'Meet anyone. Visit anywhere. Create paradise exactly as you want it. No fantasy is off-limits.',
        imagePath: 'assets/introscreen/screen8.jpg',
      ),
      IntroScreen(
        title: 'Solve Problems Creatively',
        description: 'Tap your subconscious genius while you sleep. Wake up with breakthrough solutions every morning.',
        imagePath: 'assets/introscreen/screen9.jpg',
      ),
      IntroScreen(
        title: 'Connect With Your Inner Self',
        description: 'Journey to your core consciousness. Discover your true self. Experience profound insights impossible when awake.',
        imagePath: 'assets/introscreen/screen10.jpg',
      ),
      IntroScreen(
        title: 'Your Lucid Adventure Begins',
        description: 'Start Lucid Now tonight. Begin your first epic adventure. Your dream universe awaits.',
        imagePath: 'assets/introscreen/screen11.jpg',
      ),
    ];
  }
} 