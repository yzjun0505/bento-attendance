import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/chat_quote_codec.dart';

void main() {
  test('encode/decode roundtrip', () {
    final raw = encodeChatQuote(
      bodyText: '你好',
      quoteSenderNickname: '张三',
      quoteText: '原消息',
    );
    final decoded = decodeChatQuote(raw);
    expect(decoded.bodyText, '你好');
    expect(decoded.quoteSenderNickname, '张三');
    expect(decoded.quoteText, '原消息');
  });

  test('decode without quote', () {
    final decoded = decodeChatQuote('hello');
    expect(decoded.bodyText, 'hello');
    expect(decoded.quoteSenderNickname, isNull);
    expect(decoded.quoteText, isNull);
  });

  test('decode legacy format', () {
    final decoded = decodeChatQuote('引用 李四: 旧引用\n正文');
    expect(decoded.bodyText, '正文');
    expect(decoded.quoteSenderNickname, '李四');
    expect(decoded.quoteText, '旧引用');
  });
}
