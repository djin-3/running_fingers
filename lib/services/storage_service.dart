import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/record_data.dart';

/// SharedPreferencesを使った記録の保存・読み込み
class StorageService {
  static const int _maxHistory = 10;

  // BGM設定キー
  static const String bgmEnabledKey = 'bgm_enabled';

  static Future<bool> getBgmEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(bgmEnabledKey) ?? true;
  }

  static Future<void> saveBgmEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(bgmEnabledKey, enabled);
  }

  // ボタン位置キー
  static const String posKeyLeft = 'btn_pos_left';
  static const String posKeyRight = 'btn_pos_right';
  static const String posKeyCenter = 'btn_pos_center';

  /// ボタン位置を取得（デフォルト値つき）
  static Future<Offset> getButtonPos(String key, Offset defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(key);
    if (json == null) return defaultValue;
    final map = jsonDecode(json) as Map<String, dynamic>;
    return Offset((map['x'] as num).toDouble(), (map['y'] as num).toDouble());
  }

  /// ボタン位置を保存（スクリーンサイズで正規化した値）
  static Future<void> saveButtonPos(String key, Offset norm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode({'x': norm.dx, 'y': norm.dy}));
  }

  // キー生成: {fingerMode}_{isTimeAttack}_{best|history}
  static String _bestKey(int fingerMode, bool isTimeAttack) =>
      'best_${fingerMode}f_${isTimeAttack ? 'ta' : 'tc'}';

  static String _historyKey(int fingerMode, bool isTimeAttack) =>
      'history_${fingerMode}f_${isTimeAttack ? 'ta' : 'tc'}';

  /// 記録を保存し、更新後のベスト記録を返す
  ///
  /// [isTimeAttack] が true ならタイムアタック（値が小さいほど良い）
  /// false ならタップチャレンジ（値が大きいほど良い）
  static Future<RecordData?> saveRecord({
    required RecordData record,
    required bool isTimeAttack,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 履歴に追加（先頭が最新）
    final historyKey = _historyKey(record.fingerMode, isTimeAttack);
    final historyJson = prefs.getStringList(historyKey) ?? [];
    historyJson.insert(0, jsonEncode(record.toJson()));
    if (historyJson.length > _maxHistory) {
      historyJson.removeRange(_maxHistory, historyJson.length);
    }
    await prefs.setStringList(historyKey, historyJson);

    // ベスト更新チェック
    final bestKey = _bestKey(record.fingerMode, isTimeAttack);
    final bestJson = prefs.getString(bestKey);
    RecordData? currentBest;
    if (bestJson != null) {
      currentBest = RecordData.fromJson(jsonDecode(bestJson) as Map<String, dynamic>);
    }

    final isBetter = currentBest == null ||
        (isTimeAttack ? record.value < currentBest.value : record.value > currentBest.value);

    if (isBetter) {
      await prefs.setString(bestKey, jsonEncode(record.toJson()));
      return record;
    }
    return currentBest;
  }

  /// ベスト記録を取得
  static Future<RecordData?> getBest({
    required int fingerMode,
    required bool isTimeAttack,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bestJson = prefs.getString(_bestKey(fingerMode, isTimeAttack));
    if (bestJson == null) return null;
    return RecordData.fromJson(jsonDecode(bestJson) as Map<String, dynamic>);
  }

  /// 履歴を取得（先頭が最新）
  static Future<List<RecordData>> getHistory({
    required int fingerMode,
    required bool isTimeAttack,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey(fingerMode, isTimeAttack)) ?? [];
    return historyJson
        .map((s) => RecordData.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }
}
