import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const SeafarerApp());

class SeafarerApp extends StatefulWidget {
  const SeafarerApp({super.key});

  @override
  State<SeafarerApp> createState() => _SeafarerAppState();
}

class _SeafarerAppState extends State<SeafarerApp> with TickerProviderStateMixin {
  late Stream<StepCount> _stepCountStream;
  int _totalSteps = 0;
  int _gold = 0;
  final int _xpToNextLevel = 1000;
  int _awaySteps = 0;
  int _awayGold = 0;
  // Active Play State
  bool _isSalvaging = false;
  
  // Floating Text State (The "Juice")
  List<FloatingText> _floatingTexts = [];

  @override
  void initState() {
    super.initState();
    _loadSaveData();
    initPlatformState();
  }

  Future<void> _loadSaveData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. Load existing data
  int savedSteps = prefs.getInt('totalSteps') ?? 0;
  int savedGold = prefs.getInt('gold') ?? 0;
  int lastUnixTime = prefs.getInt('lastExitTime') ?? DateTime.now().millisecondsSinceEpoch;

  // 2. Calculate time passed (for passive gold/events)
  int currentTime = DateTime.now().millisecondsSinceEpoch;
  int secondsAway = (currentTime - lastUnixTime) ~/ 1000;

  setState(() {
    _totalSteps = savedSteps;
    _gold = savedGold;
    
    // 3. Logic: If they were away for more than 1 minute, show reward
    if (secondsAway > 60) {
      // For an idle game, we can give 'Passive Gold' based on time
      // or 'Step Gold' if the pedometer updated in the background.
      _awaySteps = (secondsAway ~/ 60) * 10; // 10 miles per 1 min (passive drift)
      _gold += _awayGold;
      _totalSteps += _awaySteps;
      
      // We'll trigger the popup after the build is done
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAwayReport(secondsAway));
    }
  });
}

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalSteps', _totalSteps);
    await prefs.setInt('gold', _gold);
    await prefs.setInt('lastExitTime', DateTime.now().millisecondsSinceEpoch);
  }

  // --- PROCEDURAL ENGINE ---
  String _getProceduralIslandName() {
    int seed = (_totalSteps ~/ _xpToNextLevel);
    var rnd = math.Random(seed);
    List<String> pre = ["Misty", "Iron", "Sunken", "Azure", "Lost", "Silent"];
    List<String> suf = ["Harbor", "Reef", "Sands", "Gully", "Peak", "Atoll"];
    return "${pre[rnd.nextInt(pre.length)]} ${suf[rnd.nextInt(suf.length)]}";
  }

  void onStepCount(StepCount event) {
    setState(() {
      _totalSteps = event.steps;
      _gold = (_totalSteps / 10).floor();
    });
    _saveData();
  }

  void initPlatformState() {
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen(onStepCount).onError((e) => debugPrint(e.toString()));
    } catch (e) {
      debugPrint("Pedometer unavailable");
    }
  }

  void _showAwayReport(int secondsAway) {
  int minutes = secondsAway ~/ 60;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF4FB5E6), width: 2)
      ),
      title: const Column(
        children: [
          Icon(Icons.wb_sunny, color: Colors.amber, size: 50),
          SizedBox(height: 10),
          Text("WELCOME BACK!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("You were at shore for $minutes minutes.", 
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70)
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(15)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.circle, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Text("+$_awayGold Doubloons", 
                  style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FB5E6)),
            onPressed: () => Navigator.pop(context),
            child: const Text("SET SAIL", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    ),
  );
}

  // --- ACTIVE PLAY: SALVAGE ---
  void _startSalvage() {
    if (_isSalvaging) return;
    
    setState(() => _isSalvaging = true);

    // 1. ADD FLOATING TEXT (VISUAL FEEDBACK)
    _addFloatingText("+5 Gold");

    // 2. CHECK FOR RANDOM LOOT (POPUP)
    if (math.Random().nextDouble() < 0.2) { // 20% chance
      Future.delayed(const Duration(milliseconds: 500), () {
        _showLootDialog();
      });
    }

    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isSalvaging = false;
          _gold += 5;
        });
        _saveData();
      }
    });
  }

  void _addFloatingText(String text) {
    setState(() {
      _floatingTexts.add(FloatingText(id: DateTime.now().millisecondsSinceEpoch, text: text));
    });
    // Remove it after animation finishes
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _floatingTexts.removeWhere((ft) => ft.text == text); // Simple cleanup
        });
      }
    });
  }

  void _showLootDialog() {
    int bonus = 50 + math.Random().nextInt(100);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 2)),
        title: const Row(children: [Icon(Icons.stars, color: Colors.amber), SizedBox(width: 10), Text("SUNKEN CRATE!", style: TextStyle(color: Colors.white))]),
        content: Text("You pulled up a rusty crate containing $bonus Doubloons!", style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              setState(() => _gold += bonus);
              Navigator.pop(context);
            },
            child: const Text("CLAIM LOOT"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("SEAFARER", style: TextStyle(fontSize: 14, letterSpacing: 2.0, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 20),
                    
                    // OCEAN STAGE (Now Animated!)
                    SizedBox(
                      height: 250,
                      child: Stack(
                        children: [
                          OceanScene(isSalvaging: _isSalvaging),
                          // Floating Texts Layer
                          ..._floatingTexts.map((ft) => Positioned(
                            bottom: 100,
                            left: 0, right: 0,
                            child: FloatingTextWidget(text: ft.text),
                          )),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // SALVAGE BUTTON
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _isSalvaging ? null : _startSalvage,
                          icon: _isSalvaging 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                              : const Icon(Icons.anchor),
                          label: Text(_isSalvaging ? "REELING IN..." : "SALVAGE DEBRIS"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            elevation: 10,
                            shadowColor: Colors.blueAccent.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    Text("Approaching ${_getProceduralIslandName()}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4FB5E6))),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_totalSteps % 1000) / 1000,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFF4FB5E6),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // STATS GRID
                    Row(
                      children: [
                        _buildStatCard("NAUTICAL MILES", "$_totalSteps", Icons.sailing, Colors.blueAccent),
                        const SizedBox(width: 16),
                        _buildStatCard("DOUBLOONS", "$_gold", Icons.circle, Colors.amber),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}

// --- ANIMATED OCEAN WIDGET ---
class OceanScene extends StatefulWidget {
  final bool isSalvaging;
  const OceanScene({super.key, required this.isSalvaging});

  @override
  State<OceanScene> createState() => _OceanSceneState();
}

class _OceanSceneState extends State<OceanScene> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF87CEEB), Color(0xFF64B5F6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // MOVING WAVES
            AnimatedBuilder(animation: _controller, builder: (context, child) => CustomPaint(size: const Size(double.infinity, 200), painter: WavePainter(waveValue: _controller.value, waveColor: const Color(0xFF1976D2), speed: 1.0, waveHeight: 15))),
            AnimatedBuilder(animation: _controller, builder: (context, child) => CustomPaint(size: const Size(double.infinity, 180), painter: WavePainter(waveValue: _controller.value, waveColor: const Color(0xFF2196F3), speed: 1.5, offset: math.pi, waveHeight: 20))),
            
            // BOAT / HOOK ANIMATION
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: widget.isSalvaging 
                  ? const Icon(Icons.arrow_downward, key: ValueKey(1), size: 80, color: Colors.white)
                  : AnimatedBuilder( // BOBBING BOAT
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 10 * math.sin(_controller.value * 2 * math.pi)),
                          child: const Icon(Icons.sailing, key: ValueKey(2), size: 100, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 10)]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WAVES PAINTER ---
class WavePainter extends CustomPainter {
  final double waveValue;
  final Color waveColor;
  final double speed;
  final double offset;
  final double waveHeight;
  WavePainter({required this.waveValue, required this.waveColor, this.speed = 1.0, this.offset = 0.0, this.waveHeight = 20.0});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = waveColor;
    final path = Path();
    final yBase = size.height * 0.4;
    path.moveTo(0, size.height);
    path.lineTo(0, yBase);
    for (double x = 0; x <= size.width; x++) {
      double y = yBase + math.sin((x / size.width * 2 * math.pi) + (waveValue * 2 * math.pi * speed) + offset) * waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- FLOATING TEXT WIDGET (THE JUICE) ---
class FloatingText {
  final int id;
  final String text;
  FloatingText({required this.id, required this.text});
}

class FloatingTextWidget extends StatefulWidget {
  final String text;
  const FloatingTextWidget({super.key, required this.text});
  @override
  State<FloatingTextWidget> createState() => _FloatingTextWidgetState();
}

class _FloatingTextWidgetState extends State<FloatingTextWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));
    _offset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.5)).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Center(child: Text(widget.text, style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 2)]))),
      ),
    );
  }
}