import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/record_data.dart';
import 'screens/game_screen.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const RunningFingersApp());
}

class RunningFingersApp extends StatelessWidget {
  const RunningFingersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running Fingers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// ホーム画面: 操作モードとゲームモードの選択
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // best[fingerMode][isTimeAttack]
  final Map<String, RecordData?> _bests = {};
  bool _bgmEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadBests();
    _initAudio();
  }

  Future<void> _initAudio() async {
    final enabled = await StorageService.getBgmEnabled();
    if (mounted) {
      setState(() => _bgmEnabled = enabled);
    }
    await AudioService().init(bgmEnabled: enabled);
  }

  Future<void> _toggleBgm() async {
    final newEnabled = !_bgmEnabled;
    setState(() => _bgmEnabled = newEnabled);
    await StorageService.saveBgmEnabled(newEnabled);
    await AudioService().setBgmEnabled(newEnabled);
  }

  Future<void> _loadBests() async {
    final results = await Future.wait([
      StorageService.getBest(fingerMode: 2, isTimeAttack: true),
      StorageService.getBest(fingerMode: 2, isTimeAttack: false),
      StorageService.getBest(fingerMode: 1, isTimeAttack: true),
      StorageService.getBest(fingerMode: 1, isTimeAttack: false),
    ]);
    if (mounted) {
      setState(() {
        _bests['2_ta'] = results[0];
        _bests['2_tc'] = results[1];
        _bests['1_ta'] = results[2];
        _bests['1_tc'] = results[3];
      });
    }
  }

  String? _bestLabel(int fingerMode, bool isTimeAttack) {
    final key = '${fingerMode}_${isTimeAttack ? 'ta' : 'tc'}';
    final best = _bests[key];
    if (best == null) return null;
    if (isTimeAttack) {
      return 'ベスト: ${best.value.toStringAsFixed(2)}秒';
    } else {
      return 'ベスト: ${best.value.toInt()}回';
    }
  }

  Future<void> _startGame(BuildContext context, {required int fingerMode, required bool isTimeAttack}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          fingerMode: fingerMode,
          isTimeAttack: isTimeAttack,
        ),
      ),
    );
    // ゲームから戻ったらベスト記録を再読み込み
    _loadBests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Running Fingers',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _toggleBgm,
                      icon: Icon(
                        _bgmEnabled ? Icons.volume_up : Icons.volume_off,
                        color: _bgmEnabled ? Colors.deepOrange : Colors.grey,
                      ),
                      tooltip: _bgmEnabled ? 'BGMをオフにする' : 'BGMをオンにする',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '指で走れ！',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 64),
                // 2本モード
                Text(
                  '2本モード',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'タイムアタック\n100回',
                        subtitle: '100回タップの時間を計測',
                        best: _bestLabel(2, true),
                        onTap: () => _startGame(context, fingerMode: 2, isTimeAttack: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeButton(
                        label: 'タップチャレンジ\n10秒',
                        subtitle: '10秒間のタップ数を計測',
                        best: _bestLabel(2, false),
                        onTap: () => _startGame(context, fingerMode: 2, isTimeAttack: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // 1本モード
                Text(
                  '1本モード',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'タイムアタック\n100回',
                        subtitle: '100回タップの時間を計測',
                        best: _bestLabel(1, true),
                        onTap: () => _startGame(context, fingerMode: 1, isTimeAttack: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeButton(
                        label: 'タップチャレンジ\n10秒',
                        subtitle: '10秒間のタップ数を計測',
                        best: _bestLabel(1, false),
                        onTap: () => _startGame(context, fingerMode: 1, isTimeAttack: false),
                      ),
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
}

class _ModeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final String? best;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.best,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              if (best != null) ...[
                const SizedBox(height: 6),
                Text(
                  best!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
