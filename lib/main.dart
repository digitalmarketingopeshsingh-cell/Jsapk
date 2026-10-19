import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/admob_service.dart';
import 'game/balloon_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdMobService().initialize();
  runApp(const KidBalloonPopApp());
}

class KidBalloonPopApp extends StatelessWidget {
  const KidBalloonPopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kid Balloon Pop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: BalloonPopGame(),
      ),
    );
  }
}
