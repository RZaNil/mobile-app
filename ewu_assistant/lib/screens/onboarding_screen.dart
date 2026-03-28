import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/app_branding.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  static const String onboardingKey = 'onboarding_complete';

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  final List<_OnboardingItem> _items = const <_OnboardingItem>[
    _OnboardingItem(
      icon: Icons.mic_rounded,
      title: 'Ask With Your Voice',
      description:
          'Talk naturally and get quick answers about admissions, tuition, routine, faculty, and campus life.',
    ),
    _OnboardingItem(
      icon: Icons.chat_bubble_rounded,
      title: 'Chat Anytime',
      description:
          'Switch to text chat whenever you want a quieter, scrollable conversation with EWU Assistant.',
    ),
    _OnboardingItem(
      icon: Icons.groups_rounded,
      title: 'Join The Campus Feed',
      description:
          'Share posts, react, comment, and stay connected with the EWU student community.',
    ),
    _OnboardingItem(
      icon: Icons.auto_awesome_rounded,
      title: 'Use Notes & Smart Tools',
      description:
          'Save notes, upload study materials, and use tools like CGPA Predictor, Routine Generator, Faculty Finder, and Exam Countdown.',
    ),
  ];

  int _pageIndex = 0;

  Future<void> _completeOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.onboardingKey, true);
    widget.onFinished();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _pageIndex == _items.length - 1;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (int index) {
                      setState(() {
                        _pageIndex = index;
                      });
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final _OnboardingItem item = _items[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.primaryDark.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                AppLogoMark(size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'EWU Assistant',
                                  style: TextStyle(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            height: 124,
                            width: 124,
                            decoration: BoxDecoration(
                              gradient: AppTheme.navyGradient,
                              borderRadius: BorderRadius.circular(34),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x220A1F44),
                                  blurRadius: 24,
                                  offset: Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Icon(
                              item.icon,
                              size: 54,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.description,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    _items.length,
                    (int index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _pageIndex == index ? 28 : 8,
                      decoration: BoxDecoration(
                        color: _pageIndex == index
                            ? AppTheme.primaryDark
                            : AppTheme.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLastPage
                        ? _completeOnboarding
                        : () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOut,
                            );
                          },
                    child: Text(isLastPage ? 'Get Started' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
