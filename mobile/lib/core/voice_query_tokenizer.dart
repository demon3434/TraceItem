class VoiceTokenCandidate {
  final String word;
  final bool isDomainHit;

  const VoiceTokenCandidate(this.word, {this.isDomainHit = false});
}

class VoiceTokenizeResult {
  final String cleanedSentence;
  final List<VoiceTokenCandidate> candidates;

  const VoiceTokenizeResult({
    required this.cleanedSentence,
    required this.candidates,
  });
}

/// 端侧口语分词与私域热词锚定器（纯内存计算，<3ms，100%离线可用）
class VoiceQueryTokenizer {
  static final RegExp _punctRegex = RegExp(
    r'''[，。？！、；：“”‘’（）()\[\]【】《》.,?!;:'"~·\-_]+''',
  );
  static final RegExp _prefixRegex = RegExp(
    r'^(请问|麻烦|帮我找一下|帮我找|我想找|找一下|查一下|搜一下|看看|我记得|好像)+',
  );
  static final RegExp _suffixRegex = RegExp(
    r'(放在哪儿了|放在哪里了|放在哪了|放哪儿了|放哪了|在哪里|在哪儿|在哪|去哪儿了|去哪了|呢|啊|呀|吗)+$',
  );
  static final RegExp _stopwordSplitter = RegExp(
    r'(的|了|在|是|把|给|和|与|跟|个|些|那个|这个|这|那|去年|今年|以前|之前)',
  );
  static final RegExp _asciiWordRegex = RegExp(r'[a-zA-Z0-9]+');
  static final RegExp _cjkChunkRegex = RegExp(r'[\u4e00-\u9fa5]+');

  static const Set<String> _singleStopChars = {
    '的', '了', '在', '是', '把', '给', '和', '与', '跟', '个', '些', '这', '那',
    '我', '你', '他', '她', '它', '们', '哪', '里', '儿', '吗', '呢', '啊', '呀',
    '有', '没', '不', '要', '想', '找', '看', '放',
  };

  static VoiceTokenizeResult tokenize(
    String rawText, {
    Iterable<String> domainVocabulary = const [],
    int maxCandidates = 8,
  }) {
    final cleaned = rawText
        .replaceAll(_punctRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return const VoiceTokenizeResult(cleanedSentence: '', candidates: []);
    }

    var core = cleaned.replaceAll(' ', '');
    core = core.replaceFirst(_prefixRegex, '');
    core = core.replaceFirst(_suffixRegex, '');
    core = core.trim();
    if (core.isEmpty) core = cleaned;

    final result = <VoiceTokenCandidate>[];
    final seen = <String>{};

    void addCandidate(String word, {bool isDomainHit = false}) {
      final w = word.trim();
      if (w.isEmpty || seen.contains(w.toLowerCase())) return;
      if (w.length == 1 && _singleStopChars.contains(w)) return;
      if (result.length >= maxCandidates) return;
      seen.add(w.toLowerCase());
      result.add(VoiceTokenCandidate(w, isDomainHit: isDomainHit));
    }

    // 1. 私域词典最长优先匹配（物品名、品牌、分类、房间名）
    final sortedVocab = domainVocabulary
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    var remainder = core;
    for (final term in sortedVocab) {
      final lowerRem = remainder.toLowerCase();
      final lowerTerm = term.toLowerCase();
      if (lowerRem.contains(lowerTerm)) {
        addCandidate(term, isDomainHit: true);
        remainder = remainder.replaceAll(
          RegExp(RegExp.escape(term), caseSensitive: false),
          ' ',
        );
      }
    }

    // 2. 对剩余片段剥离停用词并切分有意义短语
    final segments = remainder
        .replaceAll(_stopwordSplitter, ' ')
        .split(RegExp(r'\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    for (final seg in segments) {
      for (final m in _asciiWordRegex.allMatches(seg)) {
        addCandidate(m.group(0)!);
      }
      for (final m in _cjkChunkRegex.allMatches(seg)) {
        final chunk = m.group(0)!;
        if (chunk.length <= 8) {
          addCandidate(chunk);
        }
        if (chunk.length >= 3) {
          // 切分常见 2 字/3 字尾部核心名词（如 "红围巾" -> "围巾", "蓝色文件夹" -> "文件夹"）
          if (chunk.length >= 4) {
            addCandidate(chunk.substring(0, 2));
            addCandidate(chunk.substring(chunk.length - 3));
          }
          addCandidate(chunk.substring(chunk.length - 2));
        }
      }
    }

    // 3. 若清洗后整句很短且未收录，保底加入
    if (core.length <= 6) {
      addCandidate(core);
    }

    return VoiceTokenizeResult(
      cleanedSentence: cleaned,
      candidates: result,
    );
  }
}

