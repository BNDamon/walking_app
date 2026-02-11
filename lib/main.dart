import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // Required for the Wave math
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const Seafarer());

class Seafarer extends StatefulWidget {
  const Seafarer({super.key});

  @override
  State<Seafarer> createState() => _SeafarerState();
}

class _SeafarerState extends State<Seafarer> {
  late Stream<StepCount> _stepCountStream;
  int _totalSteps = 0;
  int _gold = 0;
  int _xp = 0;
  final int _xpToNextLevel = 1000; // Steps needed to reach next island

  @override
  void initState() {
    super.initState();
    _loadSaveData();
    initPlatformState();
  }

  Future<void> _loadSaveData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalSteps = prefs.getInt('totalSteps') ?? 0;
      _gold = prefs.getInt('gold') ?? 0;
      _xp = prefs.getInt('xp') ?? 0;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalSteps', _totalSteps);
    await prefs.setInt('gold', _gold);
    await prefs.setInt('xp', _xp);
  }

  void onStepCount(StepCount event) {
    setState(() {
      // Logic to handle Pedometer resetting on reboot (simplified for now)
      // We just treat the event as "current status"
      _totalSteps = event.steps; 
      
      _updateStats();
    });
  }

  void _updateStats() {
    setState(() {
      _gold = (_totalSteps / 10).floor();
      _xp = _totalSteps % _xpToNextLevel; 
    });
    _saveData(); // <--- Save every time we update!
  }

  void onStepCountError(Object error) {
    debugPrint('Step Count Error: $error');
  }

  void initPlatformState() {
    // This try-catch prevents the app from crashing on Chrome/Windows
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen(onStepCount).onError(onStepCountError);
    } catch (e) {
      debugPrint("Pedometer not available (Running on Simulator/Web?)");
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = _xp / _xpToNextLevel;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep dark grey
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView( // Prevents overflow on small screens
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  const Text(
                    "SEAFARER",
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- THE OCEAN STAGE ---
                  // This is the animated widget we built
                  OceanScene(stepCount: _totalSteps),

                  const SizedBox(height: 30),
                  // --- SIMULATE BUTTON (For Testing) ---
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.waves),
                      label: const Text("Row! (+100 Steps)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _totalSteps += 100;
                          _updateStats();
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- XP BAR ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Next Island", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("$_xp / $_xpToNextLevel mi", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFF4FB5E6), // Ocean Blue
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- STATS GRID ---
                  Row(
                    children: [
                      // Steps Card
                      Expanded(
                        child: _buildStatCard("NAUTICAL MILES", "$_totalSteps", Icons.sailing, Colors.blueAccent),
                      ),
                      const SizedBox(width: 16),
                      // Gold Card
                      Expanded(
                        child: _buildStatCard("GOLD", "$_gold", Icons.circle, Colors.amber),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}

// --- THE ANIMATED OCEAN WIDGET ---

class OceanScene extends StatefulWidget {
  final int stepCount;
  
  const OceanScene({super.key, required this.stepCount});

  @override
  State<OceanScene> createState() => _OceanSceneState();
}

class _OceanSceneState extends State<OceanScene> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Loops the wave animation endlessly
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        // Sky Gradient
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF87CEEB), Color(0xFF64B5F6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Layer 1: Background Wave (Slow, Darker)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 200),
                  painter: WavePainter(
                    waveValue: _controller.value,
                    waveColor: const Color(0xFF1976D2), // Medium Blue
                    speed: 1.0, 
                    offset: 0,
                    waveHeight: 15,
                  ),
                );
              },
            ),

            // Layer 2: Foreground Wave (Fast, Lighter)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 180),
                  painter: WavePainter(
                    waveValue: _controller.value,
                    waveColor: const Color(0xFF2196F3), // Bright Blue
                    speed: 1.5, 
                    offset: math.pi, // Starts at different phase
                    waveHeight: 20,
                  ),
                );
              },
            ),

            // Layer 3: The Boat
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Bobbing Math
                double bobbing = 10 * math.sin(_controller.value * 2 * math.pi);
                
                return Positioned(
                  bottom: 70 + bobbing, 
                  child: Column(
                    children: [
                      // REPLACE THIS ICON WITH YOUR IMAGE LATER:
                      // Image.asset('assets/images/boat.png', width: 100),
                      const Icon(
                        Icons.sailing, 
                        size: 100, 
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- THE WAVE PAINTER ---

class WavePainter extends CustomPainter {
  final double waveValue;
  final Color waveColor;
  final double speed;
  final double offset;
  final double waveHeight;

  WavePainter({
    required this.waveValue,
    required this.waveColor,
    this.speed = 1.0,
    this.offset = 0.0,
    this.waveHeight = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = waveColor;
    final path = Path();

    // The water level base height
    final yBase = size.height * 0.4; 

    path.moveTo(0, size.height);
    path.lineTo(0, yBase);

    // Draw the sine wave points
    for (double x = 0; x <= size.width; x++) {
      double y = yBase + 
          math.sin((x / size.width * 2 * math.pi) + (waveValue * 2 * math.pi * speed) + offset) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}