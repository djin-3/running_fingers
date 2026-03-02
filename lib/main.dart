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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final Map<String, RecordData?> _bests = {};
  bool _bgmEnabled = true;
  late TabController _tabController;

  // タブ順: 0 = 2 Fingers, 1 = 1 Finger
  static const _tabs = [
    (fingerMode: 1, label: '1 Finger'),
    (fingerMode: 2, label: '2 Fingers'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadBests();
    _initAudio();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      return 'Best: ${best.value.toStringAsFixed(2)}s';
    } else {
      return 'Best: ${best.value.toInt()} taps';
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
    _loadBests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // タイトル
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Running Fingers',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      onPressed: _toggleBgm,
                      icon: Icon(
                        _bgmEnabled ? Icons.volume_up : Icons.volume_off,
                        color: _bgmEnabled ? Colors.deepOrange : Colors.grey,
                      ),
                      tooltip: _bgmEnabled ? 'BGMをオフにする' : 'BGMをオンにする',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // タブ
            TabBar(
              controller: _tabController,
              tabs: [
                for (final t in _tabs) Tab(text: t.label),
              ],
            ),
            // タブコンテンツ
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final t in _tabs)
                    _buildModeList(context, fingerMode: t.fingerMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeList(BuildContext context, {required int fingerMode}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Time Attack\n100 taps',
                subtitle: '100回タップの時間を計測',
                best: _bestLabel(fingerMode, true),
                onTap: () => _startGame(context, fingerMode: fingerMode, isTimeAttack: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeButton(
                label: 'Tap Challenge\n10 sec',
                subtitle: '10秒間のタップ数を計測',
                best: _bestLabel(fingerMode, false),
                onTap: () => _startGame(context, fingerMode: fingerMode, isTimeAttack: false),
              ),
            ),
          ],
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
            mainAxisSize: MainAxisSize.min,
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
