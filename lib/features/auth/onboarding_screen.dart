import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  double _currentPageOffset = 0.0;

  // Particle background logic
  late final AnimationController _particleController;
  final List<FloatingParticle> _particles = [];

  // Screen 1: Rotating sphere animation
  late final AnimationController _sphereRotationController;

  // Screen 3: Bouncing cup & Pulse button & Counters
  late final AnimationController _cupBounceController;
  late final AnimationController _pulseButtonController;
  late final AnimationController _statsCounterController;

  // Final Transition logic
  late final AnimationController _zoomTransitionController;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() {
        _currentPageOffset = _pageController.page ?? 0.0;
      });

      // Trigger stats counter animation when page 3 (index 2) is reached
      if (_currentPageOffset >= 1.5 && !_statsCounterController.isAnimating && _statsCounterController.value == 0.0) {
        _statsCounterController.forward();
      }
    });

    // Particle Background
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _generateParticles(30);

    // Sphere Rotation (Page 1)
    _sphereRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Cup Bounce (Page 3)
    _cupBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Pulse Button (Page 3)
    _pulseButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Stats Counter
    _statsCounterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Zoom Transition Controller (For the final reveal transition)
    _zoomTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  void _generateParticles(int count) {
    final random = math.Random();
    for (int i = 0; i < count; i++) {
      _particles.add(FloatingParticle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: random.nextDouble() * 3.5 + 1.5,
        speed: random.nextDouble() * 0.02 + 0.005,
        angle: random.nextDouble() * math.pi * 2,
        opacity: random.nextDouble() * 0.4 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _particleController.dispose();
    _sphereRotationController.dispose();
    _cupBounceController.dispose();
    _pulseButtonController.dispose();
    _statsCounterController.dispose();
    _zoomTransitionController.dispose();
    super.dispose();
  }

  Future<void> _handleStartNow() async {
    setState(() {
      _isTransitioning = true;
    });

    await _zoomTransitionController.forward();

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black, // Sleek base color for background layers
      body: Stack(
        children: [
          // 1. Dynamic Background Gradient
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              // Interpolate background color layers based on current page
              Color color1;
              Color color2;
              if (_currentPageOffset < 1.0) {
                // Page 1: Dark Navy to deep blue
                color1 = const Color(0xFF071B35);
                color2 = const Color(0xFF0D2C54);
              } else if (_currentPageOffset < 2.0) {
                // Page 2: Deep blue to sporting teal
                final t = _currentPageOffset - 1.0;
                color1 = Color.lerp(const Color(0xFF071B35), const Color(0xFF082845), t)!;
                color2 = Color.lerp(const Color(0xFF0D2C54), const Color(0xFF0F4471), t)!;
              } else {
                // Page 3: Rich blue to vibrant signature blue
                final t = _currentPageOffset - 2.0;
                color1 = Color.lerp(const Color(0xFF082845), const Color(0xFF052F5F), t)!;
                color2 = Color.lerp(const Color(0xFF0F4471), const Color(0xFF0E4A81), t)!;
              }

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color1, color2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),

          // 2. Parallax Faint Background Shapes
          Positioned(
            left: -100 - (_currentPageOffset * 80),
            top: -50,
            child: Opacity(
              opacity: 0.08,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            right: -150 + (_currentPageOffset * 90),
            bottom: -50,
            child: Opacity(
              opacity: 0.06,
              child: Container(
                width: 400,
                height: 400,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // 3. Floating Particles Background (Animated via custom paint)
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              for (var particle in _particles) {
                particle.update();
              }
              return CustomPaint(
                painter: ParticlePainter(particles: _particles),
                size: Size(screenWidth, screenHeight),
              );
            },
          ),

          // 4. Main PageView Content
          PageView(
            controller: _pageController,
            physics: _isTransitioning ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            children: [
              _buildPage1(context),
              _buildPage2(context, screenWidth),
              _buildPage3(context),
            ],
          ),

          // 5. Navigation & Progress indicators (Static overlay at bottom)
          if (!_isTransitioning)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  // Indicators + Skip/Next
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip Button
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _currentPageOffset >= 1.8 ? 0.0 : 1.0,
                        child: IgnorePointer(
                          ignoring: _currentPageOffset >= 1.8,
                          child: TextButton(
                            onPressed: () {
                              _pageController.animateToPage(
                                2,
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOutCubic,
                              );
                            },
                            child: const Text(
                              'تخطي',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Indicators Dots
                      Row(
                        children: List.generate(3, (index) {
                          double selectedRatio = (1.0 - (index - _currentPageOffset).abs()).clamp(0.0, 1.0);
                          double width = 8 + (selectedRatio * 16);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: width,
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                Colors.white24,
                                Colors.white,
                                selectedRatio,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      // Next Button (Only visible on Page 1 & 2)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _currentPageOffset >= 1.8 ? 0.0 : 1.0,
                        child: IgnorePointer(
                          ignoring: _currentPageOffset >= 1.8,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white24,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOutCubic,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 6. Custom Zoom Transition Overlay (Fires on completion)
          if (_isTransitioning)
            AnimatedBuilder(
              animation: _zoomTransitionController,
              builder: (context, child) {
                // Background color fade to AppTheme.primaryColor
                final progress = _zoomTransitionController.value;
                final zoomVal = 1.0 + (progress * 25.0); // Extreme zoom

                return Stack(
                  children: [
                    // Backdrop transitioning to primaryColor
                    Container(
                      color: Color.lerp(
                        Colors.transparent,
                        AppTheme.primaryColor,
                        progress,
                      ),
                    ),
                    // Centered logo that zooms in
                    Center(
                      child: Transform.scale(
                        scale: zoomVal,
                        child: Opacity(
                          opacity: ((progress < 0.8) ? 1.0 : (1.0 - (progress - 0.8) / 0.2)).clamp(0.0, 1.0),
                          child: Image.asset(
                            'assets/images/logo2.png',
                            height: 120,
                            width: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- SCREEN 1 Builder ---
  Widget _buildPage1(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Rotating sports ball + logo container
          SizedBox(
            height: 240,
            width: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 3D-like rotating sphere background
                AnimatedBuilder(
                  animation: _sphereRotationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RotatingSpherePainter(
                        animationValue: _sphereRotationController.value,
                      ),
                      size: const Size(200, 200),
                    );
                  },
                ),
                // University logo positioned on top with scale + fade
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.5 + (value * 0.5),
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo2.png',
                        height: 90,
                        width: 90,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // App Title (Fade + Scale)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                Text(
                  'إدارة الأنشطة الرياضية',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'الجامعية',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 26,
                        color: const Color(0xFF38B6FF), // Highlight Cyan
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Subtitle / Description
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'منصة رقمية متكاملة لتنظيم وإدارة الأنشطة والبطولات الرياضية داخل الجامعة.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- SCREEN 2 Builder ---
  Widget _buildPage2(BuildContext context, double screenWidth) {
    // Parallax coefficient based on scroll offset
    // For page 2 (index 1), relative offset goes from -1 to 1
    double pageOffset = _currentPageOffset - 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Title
          Text(
            'اكتشف الأنشطة الرياضية',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            'تصفح البطولات والفعاليات الرياضية وسجل مشاركتك بسهولة.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Sliding Cards Area
          SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Card 1: Football (Slides from right/left offset)
                Transform.translate(
                  offset: Offset(pageOffset * screenWidth * 1.5 - 30, -35),
                  child: Transform.rotate(
                    angle: -0.1,
                    child: _buildActivityCard(
                      icon: Icons.sports_soccer,
                      title: 'بطولة كرة القدم',
                      sportName: 'كرة القدم',
                      gradient: const [Color(0xFF1E3C72), Color(0xFF2A5298)],
                    ),
                  ),
                ),
                // Card 2: Basketball (Slides from center/offset)
                Transform.translate(
                  offset: Offset(-pageOffset * screenWidth * 1.8, 10),
                  child: Transform.rotate(
                    angle: 0.03,
                    child: _buildActivityCard(
                      icon: Icons.sports_basketball,
                      title: 'دوري كرة السلة',
                      sportName: 'كرة السلة',
                      gradient: const [Color(0xFFE65C00), Color(0xFFF9D423)],
                    ),
                  ),
                ),
                // Card 3: Volleyball (Slides from left/right offset)
                Transform.translate(
                  offset: Offset(pageOffset * screenWidth * 2.1 + 40, 55),
                  child: Transform.rotate(
                    angle: 0.12,
                    child: _buildActivityCard(
                      icon: Icons.sports_volleyball,
                      title: 'بطولة الكرة الطائرة',
                      sportName: 'الكرة الطائرة',
                      gradient: const [Color(0xFF0F2027), Color(0xFF203A43)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required String title,
    required String sportName,
    required List<Color> gradient,
  }) {
    return Container(
      width: 220,
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: Colors.white24, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sportName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- SCREEN 3 Builder ---
  Widget _buildPage3(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Bouncing Glowing Cup Container
          AnimatedBuilder(
            animation: _cupBounceController,
            builder: (context, child) {
              final double bounceOffset = math.sin(_cupBounceController.value * math.pi * 2) * 12;
              return Transform.translate(
                offset: Offset(0, bounceOffset - 10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow background
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFD700).withValues(alpha: 0.35),
                            const Color(0xFFFFD700).withValues(alpha: 0.0),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                    // Cup
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFD700), // Gold
                        size: 70,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 30),

          // Title & Description
          Text(
            'شارك وحقق الإنجازات',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'سجل في الفرق الرياضية، تابع النتائج، وكن جزءاً من المجتمع الرياضي.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Animated stats counters
          AnimatedBuilder(
            animation: _statsCounterController,
            builder: (context, child) {
              final double progress = _statsCounterController.value;
              int activeSports = (progress * 15).toInt();
            //  int participants = (progress * 1200).toInt();
              int quality = (progress * 100).toInt();

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCounterItem(
                    number: '',
                    label: 'بطولة متنوعة',
                  ),
                  _buildCounterItem(
                    number: 'مشاركات طلابية ',
                    label: '',
                  ),
                  _buildCounterItem(
                    number: '',
                    label: 'تنظيم متكامل',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 48),

          // Start Now pulsing button
          AnimatedBuilder(
            animation: _pulseButtonController,
            builder: (context, child) {
              final double scale = 1.0 + (_pulseButtonController.value * 0.04);
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _handleStartNow,
                child: const Text(
                  'ابدأ الآن',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildCounterItem({required String number, required String label}) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Particle class for floating animation
class FloatingParticle {
  double x;
  double y;
  final double radius;
  final double speed;
  final double angle;
  final double opacity;

  FloatingParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.angle,
    required this.opacity,
  });

  void update() {
    x += math.cos(angle) * speed * 0.02;
    y += math.sin(angle) * speed * 0.02;

    // Reset when off bounds
    if (x < 0 || x > 1.0) {
      x = (x < 0) ? 1.0 : 0.0;
    }
    if (y < 0 || y > 1.0) {
      y = (y < 0) ? 1.0 : 0.0;
    }
  }
}

// Particle painter
class ParticlePainter extends CustomPainter {
  final List<FloatingParticle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}

// Custom painter for simulated 3D ball rotating
class RotatingSpherePainter extends CustomPainter {
  final double animationValue;

  RotatingSpherePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw background circular shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center + const Offset(0, 10), radius, shadowPaint);

    // 2. Draw 3D lighting background sphere (radial gradient)
    final spherePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A8BFF),
          const Color(0xFF133987),
          const Color(0xFF071B42),
        ],
        stops: const [0.0, 0.75, 1.0],
        center: const Alignment(-0.35, -0.35),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, spherePaint);

    // 3. Clip path to draw rotation lines inside the sphere boundaries
    canvas.save();
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    // 4. Draw sports-seams / grid lines that shift horizontally to simulate rotation
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Number of vertical curves
    const int curveCount = 6;
    for (int i = 0; i <= curveCount; i++) {
      // Calculate curve horizontal offset based on animationValue
      double progress = (i / curveCount) + (animationValue * 1.0);
      progress = progress % 1.0; // keep in 0..1 range

      // Map progress to X coordinate relative to sphere diameter
      // Using sinusoidal curve projection to simulate sphere curvature
      double relativeX = (progress * 2.0) - 1.0; // -1.0 to 1.0
      double controlOffset = relativeX * radius * 1.5;

      final curvePath = Path();
      // Draw bezier curves representing longitude
      curvePath.moveTo(center.dx + (relativeX * radius), center.dy - radius);
      curvePath.quadraticBezierTo(
        center.dx + controlOffset,
        center.dy,
        center.dx + (relativeX * radius),
        center.dy + radius,
      );
      canvas.drawPath(curvePath, linePaint);
    }

    // Draw horizontal latitude lines
    const int latCount = 4;
    for (int i = 1; i < latCount; i++) {
      double relativeY = (i / latCount) * 2.0 - 1.0; // -1 to 1
      double currentRadius = radius * math.sqrt(1 - relativeY * relativeY);

      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(center.dx, center.dy + relativeY * radius),
          radius: currentRadius,
        ),
        0,
        math.pi * 2,
        false,
        linePaint,
      );
    }

    // 5. Draw highlighted rim glow
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, glowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RotatingSpherePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
