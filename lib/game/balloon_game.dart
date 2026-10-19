import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';

class BalloonModel {
  final String id;
  final Color color;
  final String type; // 'normal', 'golden', 'rainbow', 'heart'
  double x;
  double y;
  final double size;
  final double speed;
  final double wobbleFactor;

  BalloonModel({
    required this.id,
    required this.color,
    required this.type,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.wobbleFactor,
  });
}

class BalloonPopGame extends StatefulWidget {
  const BalloonPopGame({super.key});

  @override
  State<BalloonPopGame> createState() => _BalloonPopGameState();
}

class _BalloonPopGameState extends State<BalloonPopGame> with SingleTickerProviderStateMixin {
  final List<BalloonModel> _balloons = [];
  final Random _random = Random();
  Timer? _gameTimer;
  Timer? _spawnTimer;

  int _score = 0;
  int _lives = 3;
  int _combo = 0;
  bool _isGameOver = false;

  final List<Color> _balloonPalette = const [
    Color(0xFFFF477E), // Pink
    Color(0xFFFF70A6),
    Color(0xFFFF9770), // Orange
    Color(0xFFFFD670), // Yellow
    Color(0xFF70D6FF), // Sky Blue
    Color(0xFF38B6FF), // Cyan
    Color(0xFF9B5DE5), // Violet
    Color(0xFF00F5D4), // Teal
  ];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      _balloons.clear();
      _score = 0;
      _lives = 3;
      _combo = 0;
      _isGameOver = false;
    });

    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    // 60 FPS Game Loop for smooth balloon floating
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_isGameOver) return;
      _updatePhysics();
    });

    // Spawn new balloons every 800ms
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_isGameOver) return;
      _spawnBalloon();
    });
  }

  void _spawnBalloon() {
    final double r = _random.nextDouble();
    String type = 'normal';
    Color color = _balloonPalette[_random.nextInt(_balloonPalette.length)];

    if (r < 0.08) {
      type = 'golden';
      color = const Color(0xFFFFD700);
    } else if (r < 0.14) {
      type = 'rainbow';
    } else if (r < 0.20 && _lives < 3) {
      type = 'heart';
      color = const Color(0xFFFF3366);
    }

    setState(() {
      _balloons.add(BalloonModel(
        id: UniqueKey().toString(),
        color: color,
        type: type,
        x: 0.1 + _random.nextDouble() * 0.8, // 10% to 90% screen width
        y: 1.1, // starts just below viewport
        size: 70.0 + _random.nextDouble() * 25.0,
        speed: 0.003 + _random.nextDouble() * 0.003,
        wobbleFactor: _random.nextDouble() * 2 * pi,
      ));
    });
  }

  void _updatePhysics() {
    setState(() {
      for (int i = _balloons.length - 1; i >= 0; i--) {
        final b = _balloons[i];
        b.y -= b.speed;

        // If balloon escaped off top of screen
        if (b.y < -0.15) {
          _balloons.removeAt(i);
          if (b.type == 'normal') {
            _lives--;
            _combo = 0;
            if (_lives <= 0) {
              _triggerGameOver();
            }
          }
        }
      }
    });
  }

  void _popBalloon(BalloonModel balloon) {
    if (_isGameOver) return;

    // Trigger Sound Effect via AudioService
    AudioService().playPopSound();

    setState(() {
      _balloons.removeWhere((b) => b.id == balloon.id);
      _combo++;

      int points = 10;
      if (balloon.type == 'golden') {
        points = 50;
        AudioService().playGoldenChime();
      } else if (balloon.type == 'rainbow') {
        points = 30;
        AudioService().playRainbowChime();
        // Rainbow pops all other normal balloons on screen!
        _balloons.removeWhere((b) => b.type == 'normal');
      } else if (balloon.type == 'heart') {
        _lives = min(3, _lives + 1);
        AudioService().playHeartDing();
      }

      final multiplier = min(5, 1 + (_combo ~/ 5));
      _score += points * multiplier;
    });
  }

  void _triggerGameOver() {
    _isGameOver = true;
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    // Show COPPA-compliant Interstitial Ad at this natural break point
    AdMobService().showInterstitialAd(
      onDismissed: () {
        debugPrint('Interstitial dismissed. Game over modal stays active.');
      },
    );
  }

  void _watchRewardedAdForLives() {
    // Show Child-Directed Rewarded Ad to restore 3 lives
    AdMobService().showRewardedAd(
      onUserEarnedReward: (reward) {
        setState(() {
          _lives = 3;
          _isGameOver = false;
        });
        _startNewGame();
        AudioService().playRewardFanfare();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('🎉 Super Kid! +3 Hearts Restored!'),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Sky Background with Gentle Clouds
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF87CEEB), Color(0xFFE0F7FA)],
            ),
          ),
        ),

        // Balloons
        ..._balloons.map((b) {
          final posX = b.x * screenSize.width - (b.size / 2);
          final posY = b.y * screenSize.height;

          return Positioned(
            left: posX,
            top: posY,
            child: GestureDetector(
              onTapDown: (_) => _popBalloon(b),
              child: _buildBalloonVisual(b),
            ),
          );
        }),

        // Top HUD (Score, Hearts, Combo)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hearts
                Row(
                  children: List.generate(3, (index) {
                    return Icon(
                      index < _lives ? Icons.favorite : Icons.favorite_border,
                      color: const Color(0xFFFF3366),
                      size: 32,
                    );
                  }),
                ),
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    'Score: $_score',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Game Over Overlay with Rewarded Ad Button
        if (_isGameOver)
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎈 Good Effort! 🎈', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Final Score: $_score', style: const TextStyle(fontSize: 24, color: Colors.blueAccent)),
                  const SizedBox(height: 24),
                  // Rewarded Ad Option
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.video_library, color: Colors.black),
                    label: const Text('Watch Short Video (+3 Hearts)', style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
                    onPressed: _watchRewardedAdForLives,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _startNewGame,
                    child: const Text('Play Again', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBalloonVisual(BalloonModel b) {
    return Container(
      width: b.size,
      height: b.size * 1.25,
      decoration: BoxDecoration(
        color: b.color,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(b.size / 2),
          bottom: Radius.circular(b.size / 1.8),
        ),
        boxShadow: [
          BoxShadow(
            color: b.color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Balloon highlight reflection
          Positioned(
            top: b.size * 0.15,
            left: b.size * 0.2,
            child: Container(
              width: b.size * 0.2,
              height: b.size * 0.35,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (b.type == 'golden')
            const Icon(Icons.star, color: Colors.white, size: 28),
          if (b.type == 'heart')
            const Icon(Icons.favorite, color: Colors.white, size: 28),
          if (b.type == 'rainbow')
            const Text('🌈', style: TextStyle(fontSize: 24)),
          if (b.type == 'normal')
            const Text('😊', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}
