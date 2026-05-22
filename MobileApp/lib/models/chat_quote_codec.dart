import 'dart:convert';
import 'package:flutter/foundation.dart';

class ChatQuoteDecoded {
  final String bodyText;
  final String? quoteSenderNickname;
  final String? quoteText;

  const ChatQuoteDecoded({
    required this.bodyText,
    this.quoteSenderNickname,
    this.quoteText,
  });

  bool get hasQuote => (quoteText ?? '').trim().isNotEmpty;
}

const _quoteStartTag = '[[BQ]]';
const _quoteEndTag = '[[/BQ]]';

String encodeChatQuote({
  required String bodyText,
  String? quoteSenderNickname,
  String? quoteText,
}) {
  final sender = (quoteSenderNickname ?? '').trim();
  final qt = (quoteText ?? '').trim();
  if (sender.isEmpty || qt.isEmpty) return bodyText;
  final meta = jsonEncode({'v': 1, 's': sender, 't': qt});
  return '$bodyText\n$_quoteStartTag$meta$_quoteEndTag';
}

ChatQuoteDecoded decodeChatQuote(String rawText) {
  final trimmedRight = rawText.trimRight();
  if (trimmedRight.endsWith(_quoteEndTag)) {
    final startIdx = trimmedRight.lastIndexOf(_quoteStartTag);
    if (startIdx >= 0) {
      final metaStart = startIdx + _quoteStartTag.length;
      final metaEnd = trimmedRight.length - _quoteEndTag.length;
      if (metaEnd >= metaStart) {
        final metaRaw = trimmedRight.substring(metaStart, metaEnd);
        try {
          final meta = jsonDecode(metaRaw);
          if (meta is Map) {
            final sender = (meta['s'] as String?)?.trim();
            final qt = (meta['t'] as String?)?.trim();
            var body = trimmedRight.substring(0, startIdx);
            if (body.endsWith('\n')) body = body.substring(0, body.length - 1);
            return ChatQuoteDecoded(
              bodyText: body,
              quoteSenderNickname: sender,
              quoteText: qt,
            );
          }
        } catch (e) {
          debugPrint('解析引用消息失败: $e');
        }
      }
    }
  }

  if (rawText.startsWith('引用 ') && rawText.contains('\n')) {
    final nl = rawText.indexOf('\n');
    if (nl > 0) {
      final header = rawText.substring(0, nl);
      final colon = header.indexOf(':');
      if (colon > 3) {
        final sender = header.substring(3, colon).trim();
        final qt = header.substring(colon + 1).trim();
        final body = rawText.substring(nl + 1);
        if (sender.isNotEmpty && qt.isNotEmpty) {
          return ChatQuoteDecoded(
            bodyText: body,
            quoteSenderNickname: sender,
            quoteText: qt,
          );
        }
      }
    }
  }

  return ChatQuoteDecoded(bodyText: rawText);
}
