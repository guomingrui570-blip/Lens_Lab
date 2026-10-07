// API Key 安全防護：
// 優先從編譯時環境變量 GEMINI_API_KEY 讀取（String.fromEnvironment）；
// 若未設置，則使用 XOR 混淆拆分後的字節數組進行運行時重組作為兜底。
// 公開發布時，強烈建議使用 --dart-define=GEMINI_API_KEY=your_key 構建，
// 以避免逆向工程直接提取明文字符串。
class ApiKeyGuard {
  // ===== 使用者編譯時注入 =====
  // 構建範例：
  //   flutter run --dart-define=GEMINI_API_KEY=AIzaSyXXXX
  //   flutter build apk --dart-define=GEMINI_API_KEY=AIzaSyXXXX
  //   flutter build web --dart-define=GEMINI_API_KEY=AIzaSyXXXX
  // 同時也可覆蓋模型名：
  //   --dart-define=GEMINI_MODEL=gemini-3.1-flash-lite
  static const String _envKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _envModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: '');

  // ===== XOR 混淆兜底（防止 plaintext 字串搜索）=====
  // 以下數組是明文 key 與一個隨機 8-bit 模式重複 XOR 的結果。
  // 注意：此方案僅用於"防 grep/strings 級別的靜態掃描"，無法防範懂逆向的人。
  // 真實發布場景請優先使用 dart-define 注入，或通過後端代理轉發。
  static const List<int> _keyMask = <int>[
    0xE6,
    0xEE,
    0xDD,
    0xC6,
    0xF4,
    0xDE,
    0xE3,
    0xC1,
    0xC3,
    0xEC,
    0xDE,
    0xDF,
    0xE8,
    0xE2,
    0xD6,
    0x9F,
    0xFF,
    0xC2,
    0xC4,
    0xED,
    0xE1,
    0x9F,
    0x95,
    0xEB,
    0xFD,
    0xD1,
    0xCA,
    0x97,
    0xE8,
    0xF2,
    0xE3,
    0xF4,
    0x9F,
    0xDF,
    0xEC,
    0xED,
    0xE8,
    0xD0,
    0xE6,
  ];
  static const int _xorPattern = 0xA7;

  // 默認模型名（未從環境讀取時使用）
  static const String _defaultModel = 'gemini-3.1-flash-lite';

  static String? _cachedKey;

  // 取得 Gemini API Key
  static String get geminiKey {
    if (_cachedKey != null) return _cachedKey!;
    if (_envKey.isNotEmpty) {
      _cachedKey = _envKey;
      return _cachedKey!;
    }
    // 兜底：運行時 XOR 重組
    final buf = StringBuffer();
    for (int i = 0; i < _keyMask.length; i++) {
      buf.writeCharCode(_keyMask[i] ^ _xorPattern);
    }
    _cachedKey = buf.toString();
    return _cachedKey!;
  }

  // 取得模型名
  static String get geminiModel {
    if (_envModel.isNotEmpty) return _envModel;
    return _defaultModel;
  }

  // 是否有有效 key（簡式校驗：長度合理 & 以 AIza 開頭）
  static bool get hasValidKey {
    final k = geminiKey;
    return k.isNotEmpty && k.length > 20 && k.startsWith('AIza');
  }
}
