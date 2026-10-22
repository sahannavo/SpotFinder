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
      title: 'Thermal Signal - Sci-Fi HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0C10),
        fontFamily: 'sans-serif',
      ),
      home: const SciFiThermalScreen(),
    );
  }
}

class SciFiThermalScreen extends StatefulWidget {
  const SciFiThermalScreen({super.key});

  @override
  State<SciFiThermalScreen> createState() => _SciFiThermalScreenState();
}

class _SciFiThermalScreenState extends State<SciFiThermalScreen>
    with TickerProviderStateMixin {
  static const _eventChannel =
      EventChannel('com.example.app/telephony_events');

  bool _isHapticActive = true;
  int _currentDbm = -68;
  int _peakDbm = -68;
  int _bandIndex = 0;
  final List<String> _bands = ['5G ULTRA', 'LTE-ADV', 'SUB-6'];
  StreamSubscription? _signalSubscription;

  late AnimationController _sweepController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Pure black status bar that hides and reveals on swipe down (Immersive sticky mode)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _initSignalMonitoring();
  }

  static const _methodChannel =
      MethodChannel('com.example.app/telephony_methods');

  Timer? _pollingTimer;

  void _initSignalMonitoring() async {
    // 1. Request fine location + phone state permission for live cell tower monitoring
    try {
      await _methodChannel.invokeMethod('requestPermissions');
      _fetchLatestDbm();
    } catch (_) {}

    // 2. Continuous passive stream from Android TelephonyCallback
    _signalSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is int && data < 0 && data > -140 && mounted) {
          setState(() {
            _currentDbm = data;
            if (_currentDbm > _peakDbm) _peakDbm = _currentDbm;
          });
        }
      },
      onError: (_) {},
    );

    // 3. Active 1.5s hardware polling (ensures real-time updates even if Android callback throttles)
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _fetchLatestDbm();
    });
  }

  Future<void> _fetchLatestDbm() async {
    try {
      final dbm = await _methodChannel.invokeMethod('getSignalStrength');
      if (dbm is int && dbm < 0 && dbm > -140 && mounted) {
        setState(() {
          _currentDbm = dbm;
          if (_currentDbm > _peakDbm) _peakDbm = _currentDbm;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _signalSubscription?.cancel();
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Normalize -120 dBm (0.0) to -30 dBm (1.0)
  double get _normSignal {
    final clamped = _currentDbm.clamp(-120, -30);
    return (clamped - (-120)) / 90.0;
  }

  Color get _primaryColor {
    // COLD (-120 to -85 dBm): Deep Cyan (#00E5FF)
    if (_currentDbm <= -85) return const Color(0xFF00E5FF);
    // HOT / SWEET SPOT (-59 to -30 dBm): Blazing Crimson-Orange (#FF3D00)
    if (_currentDbm >= -59) return const Color(0xFFFF3D00);
    // WARM (-84 to -60 dBm): Amber / Gold (#FFAB00)
    return const Color(0xFFFFAB00);
  }

  Color get _secondaryColor {
    if (_currentDbm <= -85) return const Color(0xFF38BDF8);
    if (_currentDbm >= -59) return const Color(0xFFFF6E40);
    return const Color(0xFFFFD54F);
  }

  String get _statusHeadline {
    if (_currentDbm <= -85) return 'SIGNAL COLD';
    if (_currentDbm >= -59) return 'SWEET SPOT LOCKED';
    return 'GETTING WARMER';
  }

  int get _signalBarsCount {
    if (_currentDbm <= -100) return 1;
    if (_currentDbm <= -85) return 2;
    if (_currentDbm <= -60) return 3;
    return 4;
  }

  void _cycleBand() {
    setState(() {
      _bandIndex = (_bandIndex + 1) % _bands.length;
    });
  }

  void _toggleHaptics() {
    setState(() {
      _isHapticActive = !_isHapticActive;
      if (_isHapticActive) {
        _sweepController.repeat();
        _pulseController.repeat(reverse: true);
        HapticFeedback.mediumImpact();
      } else {
        _sweepController.stop();
        _pulseController.stop();
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primaryColor;
    final norm = _normSignal;
    final proximityPct = (norm * 100).round();

    // Telemetry calculations
    final ping = (95 - (norm * 84)).round();
    final linkSpeed = (25 + (math.pow(norm, 2) * 890)).round();
    final snr = (4 + (norm * 36)).round();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0E12),
        body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.6),
            radius: 1.3,
            colors: [
              Color(0xFF221733), // Deep subtle magenta atmosphere
              Color(0xFF141A22), // Subtle cyber teal / charcoal
              Color(0xFF0C0D12),
              Color(0xFF07080B),
            ],
            stops: [0.0, 0.45, 0.75, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Cyberpunk Geometric Mesh Background
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: const CyberpunkMeshPainter(),
                ),
              ),
            ),

            // Diagonal Smoked Glass Glare
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: DiagonalGlarePainter(),
                ),
              ),
            ),

            // Top Flush Cyber Notch: MSI // RF
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildDynamicIsland(primary),
              ),
            ),

            // 4 Corner Chassis Hex Bolts
            Positioned(
              top: 14,
              left: 14,
              child: SafeArea(child: _buildChassisScrew()),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: SafeArea(child: _buildChassisScrew()),
            ),
            Positioned(
              bottom: 14,
              left: 14,
              child: SafeArea(child: _buildChassisScrew()),
            ),
            Positioned(
              bottom: 14,
              right: 14,
              child: SafeArea(child: _buildChassisScrew()),
            ),

            // Main Full-Screen HUD Layout
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    // Spacing so header bar sits below the flush cyber notch
                    const SizedBox(height: 38),

                    // Top Header Bar (Signal Bars + Title + Band Selector + Beacon)
                    _buildHeaderBar(primary),

                    const Spacer(),

                    // Center Multi-Ring Radar Proximity Dial
                    _buildRadarDial(primary, norm),

                    const Spacer(),

                    // Signal Temperature & Status Headline
                    _buildStatusSection(primary, norm, proximityPct),
                    const SizedBox(height: 12),

                    // Telemetry Strip: PING / LINK / SNR
                    _buildTelemetryStrip(ping, linkSpeed, snr),

                    const SizedBox(height: 16),

                    // Bottom Chamfered Haptic Scanner Card
                    _buildHapticCard(primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildChassisScrew() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0A0B0E),
        border: Border.all(
          color: const Color(0xFF333742),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FFFFFF),
            offset: Offset(0, 0.8),
            blurRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black,
            offset: Offset(0, -0.8),
            blurRadius: 1.5,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E323D),
                Color(0xFF14161B),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicIsland(Color primary) {
    return Center(
      child: ClipPath(
        clipper: TrapezoidClipper(),
        child: Container(
          width: 176,
          height: 29,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF00E5FF),
                Color(0xFF3A3D45),
                Color(0xFF3A3D45),
                Color(0xFFD500F9),
              ],
              stops: [0.0, 0.28, 0.72, 1.0],
            ),
          ),
          padding: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 1.5),
          child: ClipPath(
            clipper: TrapezoidClipper(),
            child: Container(
              color: const Color(0xFF101217),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MSI // RF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      color: Color(0xFFD1D5DB),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary,
                          boxShadow: [
                            BoxShadow(
                              color: primary,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF12151E),
                          border: Border.all(color: const Color(0xFF374151)),
                        ),
                        child: Center(
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(Color primary) {
    final activeBars = _signalBarsCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 4 Segmented Signal Bars + THERMAL SIGNAL
        Row(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (i) {
                final isActive = i < activeBars;
                final heights = [6.0, 9.0, 13.0, 16.0];
                return Container(
                  width: 3,
                  height: heights[i],
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: isActive ? primary : const Color(0xFF374151),
                    boxShadow: isActive
                        ? [BoxShadow(color: primary, blurRadius: 4)]
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            const Text(
              'THERMAL SIGNAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: Color(0xFFE5E7EB),
              ),
            ),
          ],
        ),

        // Network Band Switcher + Glowing Beacon
        Row(
          children: [
            GestureDetector(
              onTap: _cycleBand,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _bands[_bandIndex],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00E5FF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    boxShadow: [
                      BoxShadow(
                        color: primary,
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRadarDial(Color primary, double norm) {
    final distanceMeters = ((1.0 - norm) * 4.2).toStringAsFixed(1);
    final targetOffset = Offset(
      math.cos((1.0 - norm) * 2.4) * ((1.0 - norm) * 46),
      -math.sin((1.0 - norm) * 2.4) * ((1.0 - norm) * 46),
    );

    return Center(
      child: SizedBox(
        width: 290,
        height: 290,
        child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Well
              Container(
                width: 288,
                height: 288,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF101217),
                  border: Border.all(color: primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.28),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.95),
                      blurRadius: 20,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),

              // SVG-style Graticules and Crosshairs
              const RepaintBoundary(
                child: CustomPaint(
                  size: Size(288, 288),
                  painter: SciFiGraticulePainter(),
                ),
              ),

              // Rotating Radar Sweep Cone
              if (_isHapticActive)
                AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _sweepController.value * 2 * math.pi,
                      child: Container(
                        width: 284,
                        height: 284,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            center: Alignment.center,
                            startAngle: 0.0,
                            endAngle: math.pi * 2,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              primary.withValues(alpha: 0.24),
                              _secondaryColor.withValues(alpha: 0.75),
                            ],
                            stops: const [0.0, 0.72, 0.95, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Middle Ring
              Container(
                width: 224,
                height: 224,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x99262930),
                      Color(0xCC181A1F),
                      Color(0xF00D0E12),
                    ],
                  ),
                  border: Border.all(color: primary, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),

              // Direction Vector Pill (Top of Middle Ring)
              Positioned(
                top: 38,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.navigation_rounded,
                        size: 11,
                        color: primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        norm > 0.9 ? '0.0m • LOCKED' : '${distanceMeters}m NE',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          color: Color(0xFFD1D5DB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Peak Lock Readout (Bottom of Middle Ring)
              Positioned(
                bottom: 38,
                child: Text(
                  'PEAK LOCK: ${(norm * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: primary.withValues(alpha: 0.8),
                  ),
                ),
              ),

              // WARM & HOT Side Labels
              Positioned(
                left: 42,
                child: Text(
                  'WARM',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: _currentDbm <= -85
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              Positioned(
                right: 42,
                child: Text(
                  'HOT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: _currentDbm >= -59
                        ? const Color(0xFFFF3D00)
                        : const Color(0xFFFFAB00),
                    shadows: [
                      Shadow(
                        color: primary.withValues(alpha: 0.7),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),

              // Inner Core
              Container(
                width: 142,
                height: 142,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF2B2E37),
                      Color(0xFF17181D),
                      Color(0xFF0E0F13),
                    ],
                  ),
                  border: Border.all(color: _secondaryColor, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.45),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),

              // Target Sweet-Spot Blip (Moves toward center as signal improves)
              Transform.translate(
                offset: targetOffset,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E5FF),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),

              // Center Node with Ping Animation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final p = _pulseController.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isHapticActive)
                        Container(
                          width: 24 + (16 * p),
                          height: 24 + (16 * p),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primary.withValues(alpha: 1.0 - p),
                              width: 1.5,
                            ),
                          ),
                        ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.2),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primary,
                                  blurRadius: 10,
                                ),
                              ],
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
        ),
      );
  }

  Widget _buildStatusSection(Color primary, double norm, int proximityPct) {
    return Column(
      children: [
        Text(
          'SIGNAL TEMPERATURE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: const Color(0xFF9CA3AF),
            shadows: [
              Shadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _statusHeadline,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: Colors.white,
            shadows: [
              Shadow(
                color: primary.withValues(alpha: 0.75),
                blurRadius: 18,
              ),
              Shadow(
                color: primary.withValues(alpha: 0.4),
                blurRadius: 32,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Recessed Bento Well with 12 Segmented LEDs + Live dBm
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1015),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2A2D38),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.95),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: primary.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 12 Segmented LEDs
              Row(
                children: List.generate(12, (index) {
                  final activeSegments = (norm * 12).ceil().clamp(1, 12);
                  final isLit = index < activeSegments;
                  return Container(
                    width: 7,
                    height: 4,
                    margin: const EdgeInsets.only(right: 2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: isLit ? primary : const Color(0xFF1E2128),
                      boxShadow: isLit
                          ? [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.8),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
              Container(
                height: 12,
                width: 1,
                color: const Color(0xFF374151),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Text(
                '$_currentDbm dBm',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(
                      color: primary.withValues(alpha: 0.65),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2129),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PEAK: $_peakDbm',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: _currentDbm >= _peakDbm
                        ? primary
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryStrip(int ping, int speed, int snr) {
    return Row(
      children: [
        _buildTelemetryCell('PING', '$ping', 'ms', Colors.white),
        const SizedBox(width: 8),
        _buildTelemetryCell(
            'LINK', '$speed', 'Mb', const Color(0xFF00E5FF)),
        const SizedBox(width: 8),
        _buildTelemetryCell('SNR', '$snr', 'dB', Colors.white),
      ],
    );
  }

  Widget _buildTelemetryCell(
      String label, String value, String unit, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF101217),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF262934),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.9),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9CA3AF),
                letterSpacing: 1.0,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: valColor,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHapticCard(Color primary) {
    return ClipPath(
      clipper: ChamferedCardClipper(),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xBB2C3038),
              Color(0xD91C1E24),
              Color(0xF50E0F13),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF4B5563).withValues(alpha: 0.4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Accent & Title
            Row(
              children: [
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.5),
                    color: _isHapticActive ? primary : const Color(0xFF4B5563),
                    boxShadow: _isHapticActive
                        ? [BoxShadow(color: primary, blurRadius: 8)]
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HAPTIC SCANNER',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isHapticActive
                                ? primary
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isHapticActive
                              ? 'ACTIVE • 1.8Hz PULSE'
                              : 'STANDBY • MUTED',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: _isHapticActive
                                ? primary
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Tactile Power Toggle Button
            GestureDetector(
              onTap: _toggleHaptics,
              child: Container(
                width: 78,
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF0F1014),
                  border: Border.all(color: const Color(0xFF2E323D)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.9),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  alignment: _isHapticActive
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _isHapticActive
                            ? [
                                primary,
                                _secondaryColor,
                              ]
                            : [
                                const Color(0xFF4B4F5C),
                                const Color(0xFF1D1F25),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isHapticActive
                              ? primary.withValues(alpha: 0.6)
                              : Colors.black,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        size: 17,
                        color: _isHapticActive
                            ? Colors.black87
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Precision Crosshairs and Graticule Painter
class SciFiGraticulePainter extends CustomPainter {
  const SciFiGraticulePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintDotted = Paint()
      ..color = const Color(0xFF6B7280).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Crosshairs
    _drawDashedLine(
      canvas,
      Offset(center.dx, 10),
      Offset(center.dx, size.height - 10),
      paintDotted,
    );
    _drawDashedLine(
      canvas,
      Offset(10, center.dy),
      Offset(size.width - 10, center.dy),
      paintDotted,
    );

    // Dotted Rings
    _drawDashedCircle(canvas, center, 134, paintDotted);
    _drawDashedCircle(canvas, center, 100, paintDotted);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 3.0;
    const dashSpace = 3.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final count = (dist / (dashLength + dashSpace)).floor();
    final unit = Offset(dx / dist, dy / dist);

    for (int i = 0; i < count; i++) {
      final start = p1 + unit * (i * (dashLength + dashSpace));
      final end = start + unit * dashLength;
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedCircle(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final circum = 2 * math.pi * radius;
    const dashLen = 3.0;
    const dashSpace = 5.0;
    final count = (circum / (dashLen + dashSpace)).floor();
    final step = (2 * math.pi) / count;
    final sweep = (dashLen / circum) * 2 * math.pi;

    for (int i = 0; i < count; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Multi-Tone Diagonal Smoked Glass Reflection Painter (Specular split from bottom-left to top-right)
class DiagonalGlarePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Primary diagonal specular split reflection
    final glarePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.85, -1.0),
        end: Alignment(0.85, 1.0),
        colors: [
          Color(0x30FFFFFF),
          Color(0x12FFFFFF),
          Color(0x28FFFFFF),
          Colors.transparent,
          Color(0x25000000),
          Color(0x66000000),
        ],
        stops: [0.0, 0.44, 0.528, 0.531, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glarePaint);

    // 2. Translucent top-left acrylic specular arc
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.7),
        radius: 0.9,
        colors: [
          const Color(0x1CFFFFFF),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), highlightPaint);

    // 3. Crisp diagonal reflection line across the split
    final linePaint = Paint()
      ..color = const Color(0x35FFFFFF)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height * 0.48),
      Offset(size.width, size.height * 0.18),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Chamfered Card Polygon Clipper
class ChamferedCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const c = 12.0;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Dynamic Island Trapezoid Clipper
class TrapezoidClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w * 0.84, h)
      ..lineTo(w * 0.16, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Geometric Cyberpunk Mesh Background with subtle teal and magenta facets
class CyberpunkMeshPainter extends CustomPainter {
  const CyberpunkMeshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final tealPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;

    final magentaPaint = Paint()
      ..color = const Color(0xFFD500F9).withValues(alpha: 0.022)
      ..style = PaintingStyle.fill;

    final gridLinePaint = Paint()
      ..color = const Color(0xFF9CA3AF).withValues(alpha: 0.035)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Draw subtle faceted triangular polygon geometry across screen
    final pathTeal = Path()
      ..moveTo(0, size.height * 0.12)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(size.width, size.height * 0.28)
      ..lineTo(size.width * 0.35, size.height * 0.42)
      ..close();
    canvas.drawPath(pathTeal, tealPaint);
    canvas.drawPath(pathTeal, gridLinePaint);

    final pathMagenta = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.65, size.height * 0.68)
      ..lineTo(size.width * 0.2, size.height * 0.92)
      ..lineTo(0, size.height * 0.82)
      ..close();
    canvas.drawPath(pathMagenta, magentaPaint);
    canvas.drawPath(pathMagenta, gridLinePaint);

    // Subtle isometric tech diagonals
    canvas.drawLine(
      Offset(0, size.height * 0.2),
      Offset(size.width, size.height * 0.5),
      gridLinePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.85),
      Offset(size.width * 0.9, size.height * 0.6),
      gridLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



