import 'package:flutter_test/flutter_test.dart';
import 'package:traceitem_mobile/core/voice_query_tokenizer.dart';

void main() {
  group('VoiceQueryTokenizer', () {
    test('清洗标点并优先命中私域物品词典', () {
      final res = VoiceQueryTokenizer.tokenize(
        '帮我找一下去年的红围巾放在哪了？',
        domainVocabulary: ['红围巾', '次卧', '常备药品'],
      );
      expect(res.cleanedSentence, '帮我找一下去年的红围巾放在哪了');
      expect(res.candidates.first.word, '红围巾');
      expect(res.candidates.first.isDomainHit, isTrue);
    });

    test('支持多私域词联合命中（如房间 + 物品）', () {
      final res = VoiceQueryTokenizer.tokenize(
        '次卧的指甲刀在哪里？',
        domainVocabulary: ['次卧', '指甲刀'],
      );
      final words = res.candidates.map((c) => c.word).toList();
      expect(words, containsAll(['次卧', '指甲刀']));
      expect(res.candidates.take(2).every((c) => c.isDomainHit), isTrue);
    });

    test('短词去标点不产生多余碎片', () {
      final res = VoiceQueryTokenizer.tokenize('大便。');
      expect(res.cleanedSentence, '大便');
      expect(res.candidates.length, 1);
      expect(res.candidates.first.word, '大便');
    });

    test('未命中私域词典时切分长短语', () {
      final res = VoiceQueryTokenizer.tokenize('蓝色文件夹放在哪了');
      final words = res.candidates.map((c) => c.word).toList();
      expect(words, contains('蓝色文件夹'));
      expect(words, contains('文件夹'));
      expect(res.candidates.length <= 8, isTrue);
    });
  });
}

