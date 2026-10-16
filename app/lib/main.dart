import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SpotFinderApp());
}

class SpotFinderApp extends StatelessWidget {
  const SpotFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermal Signal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F3F1),
        fontFamily: 'sans-serif',
      ),
      home: const ThermalSignalScreen(),
    );
  }
}

class ThermalSignalScreen extends StatefulWidget {
  const ThermalSignalScreen({super.key});

  @override
  State<ThermalSignalScreen> createState() => _ThermalSignalScreenState();
}

class _ThermalSignalScreenState extends State<ThermalSignalScreen>
    with TickerProviderStateMixin {
  static const _eventChannel =
      EventChannel('com.example.app/telephony_events');

  bool _isScannerActive = true;
  int _currentDbm = -68;
  int _peakDbm = -68;
  StreamSubscription? _signalSubscription;

  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _initSignalMonitoring();
  }

  void _initSignalMonitoring() {
    _signalSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is int && data < 0 && data > -140 && mounted) {
          setState(() {
            _currentDbm = data;
            if (_currentDbm > _peakDbm) {
              _peakDbm = _currentDbm;
            }
          });
        }
      },
      onError: (_) {
        // Fallback or keep default
      },
    );
  }

  @override
  void dispose() {
    _signalSubscription?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F1),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  // Signal bars icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBar(8, const Color(0xFFFFA726)),
                      const SizedBox(width: 2.5),
                      _buildBar(13, const Color(0xFFFFA726)),
                      const SizedBox(width: 2.5),
                      _buildBar(18, const Color(0xFFFFA726)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'THERMAL SIGNAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: Color(0xFF5A5C5E),
                    ),
                  ),
                  const Spacer(),
                  // Top right soft glowing indicator dot
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA726).withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFA726),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Radar Disc Area
            Center(
              child: SizedBox(
                width: 340,
                height: 340,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Neumorphic Outer Raised Disc
                    Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF1F1EF),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.95),
                            offset: const Offset(-8, -8),
                            blurRadius: 16,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            offset: const Offset(10, 10),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),

                    // Radar grid, concentric dashed/dotted rings, and tick marks
                    const RepaintBoundary(
                      child: CustomPaint(
                        size: Size(320, 320),
                        painter: RadarRingsPainter(),
                      ),
                    ),

                    // Glowing middle active circle
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse =
                            _isScannerActive ? _pulseController.value : 0.0;
                        return Container(
                          width: 195,
                          height: 195,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFFFFDF5),
                                Color(0xFFFFF6DD),
                              ],
                              stops: [0.7, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB300)
                                    .withValues(alpha: 0.45 + (0.2 * pulse)),
                                blurRadius: 14 + (6 * pulse),
                                spreadRadius: 1 + (2 * pulse),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                offset: const Offset(4, 6),
                                blurRadius: 10,
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFFFFB74D)
                                  .withValues(alpha: 0.7),
                              width: 1.8,
                            ),
                          ),
                        );
                      },
                    ),

                    // Expanding Signal Waves (thermal ripples visible across and beyond center disk)
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(320, 320),
                          painter: SignalWavesPainter(
                            progress: _waveController.value,
                            isActive: _isScannerActive,
                          ),
                        );
                      },
                    ),

                        // Radar Center Indicator
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFB300).withValues(alpha: 0.28),
                          ),
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFFA000),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFFB300),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Labels: "WARM" and "HOT"
                        Positioned(
                          left: 42,
                          child: Text(
                            'WARM',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Colors.black.withValues(alpha: 0.38),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 42,
                          child: Text(
                            'HOT',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: const Color(0xFFE65100).withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

            const Spacer(flex: 1),

            // Signal Temperature Section
            Column(
              children: [
                Text(
                  'SIGNAL TEMPERATURE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'GETTING WARMER',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Color(0xFF1F2428),
                  ),
                ),
                const SizedBox(height: 14),
                // Progress capsule and dBm reading
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mini Capsule Bar
                    Container(
                      width: 50,
                      height: 5.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0DC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '-68  dBm',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.45),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(flex: 1),

            // Bottom Switch Card (Haptic Scanner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F4),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.9),
                      offset: const Offset(-6, -6),
                      blurRadius: 14,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      offset: const Offset(6, 8),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'HAPTIC SCANNER',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: Color(0xFF2B3034),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          _isScannerActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: _isScannerActive
                                ? const Color(0xFFF57C00)
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),

                    // Neumorphic Pill Toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isScannerActive = !_isScannerActive;
                          if (_isScannerActive) {
                            _pulseController.repeat(reverse: true);
                            _waveController.repeat();
                          } else {
                            _pulseController.stop();
                            _waveController.stop();
                          }
                        });
                      },
                      child: Container(
                        width: 82,
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECECE8),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              offset: const Offset(2, 3),
                              blurRadius: 5,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              offset: const Offset(-2, -2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          alignment: _isScannerActive
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: _isScannerActive
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF9800),
                                      Color(0xFFFFB300),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFD0D0CC),
                                      Color(0xFFDDDDD8),
                                    ],
                                  ),
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF9F9F7),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  offset: const Offset(1, 3),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.power_settings_new_rounded,
                                size: 18,
                                color: _isScannerActive
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(double height, Color color) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class RadarRingsPainter extends CustomPainter {
  const RadarRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintDotted = Paint()
      ..color = const Color(0xFF6E7378).withValues(alpha: 0.22)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    final paintCross = Paint()
      ..color = const Color(0xFF6E7378).withValues(alpha: 0.18)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Draw Crosshairs (vertical and horizontal dashed/dotted lines)
    _drawDottedLine(
      canvas,
      Offset(center.dx, 16),
      Offset(center.dx, size.height - 16),
      paintCross,
    );
    _drawDottedLine(
      canvas,
      Offset(16, center.dy),
      Offset(size.width - 16, center.dy),
      paintCross,
    );

    // Radii of concentric circles
    final radii = [52.0, 78.0, 102.0, 126.0, 145.0];
    for (final r in radii) {
      _drawDottedCircle(canvas, center, r, paintDotted);
    }

    // Outer warm highlight ring
    final outerRingPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.5)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 142.0, outerRingPaint);
  }

  void _drawDottedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 2.0;
    const dashSpace = 3.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final count = (distance / (dashLength + dashSpace)).floor();
    final unitVector = Offset(dx / distance, dy / distance);

    for (int i = 0; i < count; i++) {
      final start = p1 + unitVector * (i * (dashLength + dashSpace));
      final end = start + unitVector * dashLength;
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDottedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    final circumference = 2 * math.pi * radius;
    const dashLength = 2.5;
    const dashSpace = 3.5;
    final count = (circumference / (dashLength + dashSpace)).floor();
    final angleStep = (2 * math.pi) / count;
    final sweepAngle = (dashLength / circumference) * 2 * math.pi;

    for (int i = 0; i < count; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SignalWavesPainter extends CustomPainter {
  final double progress;
  final bool isActive;

  const SignalWavesPainter({
    required this.progress,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    const minRadius = 14.0;
    const maxRadius = 152.0;
    const waveCount = 3;

    for (int i = 0; i < waveCount; i++) {
      final waveProgress = (progress + (i / waveCount)) % 1.0;
      final radius = minRadius + (maxRadius - minRadius) * waveProgress;

      // Soft entrance, bright crest, graceful fadeout
      final alpha = math.sin(waveProgress * math.pi);
      final strokeOpacity = (alpha * 0.75).clamp(0.0, 1.0);
      final fillOpacity = (alpha * 0.08).clamp(0.0, 1.0);

      // Soft warm radial tint inside wave
      final fillPaint = Paint()
        ..color = Color.fromRGBO(255, 179, 0, fillOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);

      // Glowing ripple wave stroke
      final strokePaint = Paint()
        ..color = Color.fromRGBO(255, 160, 0, strokeOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * (1.0 - (0.45 * waveProgress));
      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SignalWavesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isActive != isActive;
  }
}

