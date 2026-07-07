/// Koreksi ejaan deterministik chat Indonesia (mirror OmniChatSpellfix.php).
class OmniChatSpellfix {
  static final _replacements = <RegExp, String>{
    RegExp(r'\bape\b', caseSensitive: false): 'apa',
    RegExp(r'\bapae\b', caseSensitive: false): 'apa',
    RegExp(r'\bapaa\b', caseSensitive: false): 'apa',
    RegExp(r'\bgmn\b', caseSensitive: false): 'gimana',
    RegExp(r'\bgimna\b', caseSensitive: false): 'gimana',
    RegExp(r'\bknp\b', caseSensitive: false): 'kenapa',
    RegExp(r'\bknpa\b', caseSensitive: false): 'kenapa',
    RegExp(r'\bblm\b', caseSensitive: false): 'belum',
    RegExp(r'\budh\b', caseSensitive: false): 'sudah',
    RegExp(r'\budah\b', caseSensitive: false): 'sudah',
    RegExp(r'\btlg\b', caseSensitive: false): 'tolong',
    RegExp(r'\btolongnya\b', caseSensitive: false): 'tolong',
    RegExp(r'\bmksd\b', caseSensitive: false): 'maksud',
    RegExp(r'\bbgt\b', caseSensitive: false): 'banget',
    RegExp(r'\btrims\b', caseSensitive: false): 'terima kasih',
    RegExp(r'\bmakasih\b', caseSensitive: false): 'terima kasih',
    RegExp(r'\bmaafin\b', caseSensitive: false): 'maaf',
    RegExp(r'\bsy\b', caseSensitive: false): 'saya',
    RegExp(r'\bgk\b', caseSensitive: false): 'nggak',
    RegExp(r'\bga\b', caseSensitive: false): 'nggak',
    RegExp(r'\bdongh\b', caseSensitive: false): 'dong',
    RegExp(r'\bsiapah\b', caseSensitive: false): 'siapa',
  };

  static String apply(String text) {
    var out = text;
    for (final entry in _replacements.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return _preserveTrailingPunctuation(text, out);
  }

  static String _preserveTrailingPunctuation(String original, String fixed) {
    final m = RegExp(r'([?!.…]+)\s*$').firstMatch(original);
    if (m == null) return fixed;
    if (RegExp(r'[?!.…]+\s*$').hasMatch(fixed)) return fixed;
    return fixed.trimRight() + m.group(1)!;
  }
}
