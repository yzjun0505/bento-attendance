import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/watermark_template.dart';

class WatermarkLayoutSpec {
  static const double defaultReferenceWidth = 390;

  final double referenceWidth;
  final double x;
  final double y;
  final double width;
  final double padding;
  final double lineHeight;
  final double radius;

  const WatermarkLayoutSpec({
    this.referenceWidth = defaultReferenceWidth,
    this.x = 0.08,
    this.y = 0.68,
    this.width = 0.72,
    this.padding = 16,
    this.lineHeight = 1.6,
    this.radius = 12,
  });

  factory WatermarkLayoutSpec.fromTemplate(WatermarkTemplate template) {
    final schema = template.schemaJson;
    final layout = schema?['layout'];
    final surface = layout is Map ? layout['surface'] : null;
    final source = surface is Map ? surface : const {};

    double readDouble(String key, double fallback) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    final reference = layout is Map ? layout['referenceWidth'] : null;
    final referenceWidth = reference is num
        ? reference.toDouble()
        : double.tryParse(reference?.toString() ?? '') ?? defaultReferenceWidth;

    return WatermarkLayoutSpec(
      referenceWidth:
          referenceWidth <= 0 ? defaultReferenceWidth : referenceWidth,
      x: readDouble('x', 0.08).clamp(0.0, 1.0),
      y: readDouble('y', 0.68).clamp(0.0, 1.0),
      width: readDouble('width', 0.72).clamp(0.2, 1.0),
      padding: readDouble('padding', 16).clamp(0.0, 80.0),
      lineHeight: readDouble('lineHeight', 1.6).clamp(1.0, 2.4),
      radius:
          readDouble('radius', template.skeletonPreset == 'compact' ? 8 : 12)
              .clamp(0.0, 48.0),
    );
  }
}

class WatermarkRenderLine {
  final String text;
  final bool isTitle;
  final bool isSubtitle;
  final double? fontSize;
  final Color? color;

  const WatermarkRenderLine({
    required this.text,
    this.isTitle = false,
    this.isSubtitle = false,
    this.fontSize,
    this.color,
  });
}

class WatermarkRenderResult {
  final Rect rect;

  const WatermarkRenderResult(this.rect);
}

class WatermarkPainter extends CustomPainter {
  final WatermarkTemplate template;
  final Map<String, String> data;
  final Offset normalizedOffset;
  final double scale;
  final int rotationTurns;
  final bool drawSelection;

  const WatermarkPainter({
    required this.template,
    required this.data,
    this.normalizedOffset = const Offset(0.08, 0.68),
    this.scale = 1,
    this.rotationTurns = 0,
    this.drawSelection = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    WatermarkRenderer.paint(
      canvas: canvas,
      size: size,
      template: template,
      data: data,
      normalizedOffset: normalizedOffset,
      scale: scale,
      rotationTurns: rotationTurns,
      drawSelection: drawSelection,
    );
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.data != data ||
        oldDelegate.normalizedOffset != normalizedOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.rotationTurns != rotationTurns ||
        oldDelegate.drawSelection != drawSelection;
  }
}

class WatermarkRenderer {
  static String getFieldValue(
      WatermarkFieldType type, Map<String, String> data) {
    switch (type) {
      case WatermarkFieldType.timeFull:
        return data['timeFull'] ?? '';
      case WatermarkFieldType.timeDate:
        return data['timeDate'] ?? '';
      case WatermarkFieldType.timeOnly:
        return data['timeOnly'] ?? '';
      case WatermarkFieldType.projectName:
        return data['projectName'] ?? '未关联项目';
      case WatermarkFieldType.projectNo:
        return data['projectNo'] ?? '';
      case WatermarkFieldType.projectAddress:
        return data['projectAddress'] ?? '';
      case WatermarkFieldType.clientOrg:
        return data['clientOrg'] ?? '';
      case WatermarkFieldType.contractorOrg:
        return data['contractorOrg'] ?? '';
      case WatermarkFieldType.supervisorOrg:
        return data['supervisorOrg'] ?? '';
      case WatermarkFieldType.manager:
        return data['manager'] ?? '';
      case WatermarkFieldType.teamLeader:
        return data['teamLeader'] ?? '';
      case WatermarkFieldType.userName:
        return data['userName'] ?? '-';
      case WatermarkFieldType.position:
        return data['position'] ?? '';
      case WatermarkFieldType.workContent:
        return data['workContent'] ?? '';
      case WatermarkFieldType.taskDescription:
        return data['taskDescription'] ?? '';
      case WatermarkFieldType.inspectionContent:
        return data['inspectionContent'] ?? '';
      case WatermarkFieldType.acceptanceContent:
        return data['acceptanceContent'] ?? '';
      case WatermarkFieldType.safetyStatus:
        return data['safetyStatus'] ?? '正常';
      case WatermarkFieldType.deviceStatus:
        return data['deviceStatus'] ?? '正常';
      case WatermarkFieldType.acceptanceResult:
        return data['acceptanceResult'] ?? '合格';
      case WatermarkFieldType.gpsLat:
        return data['gpsLat'] ?? '';
      case WatermarkFieldType.gpsLng:
        return data['gpsLng'] ?? '';
      case WatermarkFieldType.addressDetail:
        return data['addressDetail'] ?? '';
      case WatermarkFieldType.altitude:
        return data['altitude'] ?? '';
      case WatermarkFieldType.weather:
        return data['weather'] ?? '暂无';
      case WatermarkFieldType.temperature:
        return data['temperature'] ?? '';
      case WatermarkFieldType.humidity:
        return data['humidity'] ?? '';
      case WatermarkFieldType.companyName:
        return data['companyName'] ?? '';
      case WatermarkFieldType.companyLogo:
        return '';
      case WatermarkFieldType.antiFakeCode:
        return data['antiFakeCode'] ?? '';
      case WatermarkFieldType.antiTamperNotice:
        return '本照片为现场真实记录，禁止篡改';
      case WatermarkFieldType.remark:
        return data['remark'] ?? '';
      case WatermarkFieldType.homeowner:
        return data['homeowner'] ?? '';
      case WatermarkFieldType.deviceNo:
        return data['deviceNo'] ?? '';
      case WatermarkFieldType.personCount:
        return data['personCount'] ?? '';
      case WatermarkFieldType.photoNo:
        return data['photoNo'] ?? '';
    }
  }

  static String getSlotValue(WatermarkSlot slot, Map<String, String> data) {
    if (slot.binding != null && slot.binding!.isNotEmpty) {
      final fieldType = WatermarkTemplate.bindingToFieldType(slot.binding);
      if (fieldType != null) {
        final value = getFieldValue(fieldType, data);
        if (value.isNotEmpty) return value;
      }
    }
    if (slot.customText != null && slot.customText!.isNotEmpty) {
      return slot.customText!;
    }
    if (slot.label.isNotEmpty) {
      final fieldType = WatermarkTemplate.labelToFieldType(slot.label);
      final value = getFieldValue(fieldType, data);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String getSlotDisplayText(
      WatermarkSlot slot, Map<String, String> data) {
    final value = getSlotValue(slot, data);
    if (value.isEmpty) return '';
    if (slot.id == 'title' || slot.id == 'subtitle') return value;
    return '${slot.label}：$value';
  }

  static List<WatermarkRenderLine> buildLines(
    WatermarkTemplate template,
    Map<String, String> data,
  ) {
    final lines = <WatermarkRenderLine>[];

    void addSlot(WatermarkSlot slot,
        {bool isTitle = false, bool isSubtitle = false}) {
      final fieldType = slot.fieldType;
      if (_isFixedSystemField(fieldType)) return;
      if (fieldType != null && !(template.fieldEnabled[fieldType] ?? true)) {
        return;
      }
      final text = isTitle || isSubtitle
          ? getSlotValue(slot, data)
          : getSlotDisplayText(slot, data);
      if (text.isEmpty) return;
      final style = slot.style ?? const {};
      final fontSize = style['fontSize'] is num
          ? (style['fontSize'] as num).toDouble()
          : double.tryParse(style['fontSize']?.toString() ?? '');
      lines.add(WatermarkRenderLine(
        text: text,
        isTitle: isTitle,
        isSubtitle: isSubtitle,
        fontSize: fontSize,
        color: _parseColor(style['color']),
      ));
    }

    if (template.titleSlot != null) {
      addSlot(template.titleSlot!, isTitle: true);
    }
    if (template.subtitleSlot != null) {
      addSlot(template.subtitleSlot!, isSubtitle: true);
    }
    for (final slot in template.contentSlots) {
      addSlot(slot);
    }

    if (lines.isEmpty) {
      for (final field in template.enabledFields) {
        if (_isFixedSystemField(field)) continue;
        final value = getFieldValue(field, data);
        if (value.isNotEmpty) {
          lines.add(WatermarkRenderLine(text: value));
        }
      }
    }

    return lines;
  }

  static WatermarkRenderResult? paint({
    required Canvas canvas,
    required Size size,
    required WatermarkTemplate template,
    required Map<String, String> data,
    Offset normalizedOffset = const Offset(0.08, 0.68),
    double scale = 1,
    int rotationTurns = 0,
    bool drawSelection = false,
  }) {
    if (size.width <= 0 || size.height <= 0) return null;
    if (template.defaultStyle == WatermarkStyle.fullScreenWatermark) {
      _paintFullScreen(canvas, size, template, data, scale);
    }

    final lines = buildLines(template, data);
    WatermarkRenderResult? result;

    // Pre-compute the right-side fixed marks rect for bottomLeft avoidance.
    final systemMarksRect = template.defaultStyle == WatermarkStyle.bottomLeft
        ? _calculateFixedSystemMarksRect(size, data, scale)
        : Rect.zero;

    if (template.defaultStyle == WatermarkStyle.qrCode) {
      if (lines.isNotEmpty) {
        result = _paintQr(canvas, size, template, data, lines, normalizedOffset,
            scale, rotationTurns, drawSelection);
      }
    } else if (lines.isNotEmpty) {
      result = _paintCard(canvas, size, template, lines, normalizedOffset, scale,
          rotationTurns, drawSelection, systemMarksRect: systemMarksRect);
    }

    _paintFixedSystemMarks(canvas, size, data, scale);
    return result;
  }

  static WatermarkRenderResult _paintCard(
    Canvas canvas,
    Size size,
    WatermarkTemplate template,
    List<WatermarkRenderLine> lines,
    Offset normalizedOffset,
    double userScale,
    int rotationTurns,
    bool drawSelection, {
    Rect systemMarksRect = Rect.zero,
  }) {
    final layout = WatermarkLayoutSpec.fromTemplate(template);
    final renderScale = size.width / layout.referenceWidth * userScale;
    final padding = layout.padding * renderScale;
    double cardWidth = template.defaultStyle == WatermarkStyle.bottomBar
        ? size.width
        : size.width * layout.width * userScale;
    double maxTextWidth = (cardWidth - padding * 2).clamp(1.0, double.infinity);

    final painters = <TextPainter>[];
    double cardHeight = padding * 2;
    for (final line in lines) {
      final baseFontSize = _lineFontSize(template, line) * renderScale;
      final baseStyle = TextStyle(
        color: line.color ?? template.textColor,
        fontSize: baseFontSize,
        fontWeight: line.isTitle ? FontWeight.bold : FontWeight.w500,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 2 * renderScale,
          ),
        ],
      );
      final painter = _createAutoScaledTextPainter(
        line.text,
        baseStyle,
        maxTextWidth,
        maxLines: 2,
      );
      painters.add(painter);
      final actualFontSize =
          painter.text?.style?.fontSize ?? baseFontSize;
      cardHeight +=
          painter.height + actualFontSize * (layout.lineHeight - 1).clamp(0.0, 1.4);
    }

    double x = template.defaultStyle == WatermarkStyle.bottomBar
        ? 0
        : size.width * normalizedOffset.dx;
    double y = template.defaultStyle == WatermarkStyle.bottomBar
        ? size.height - cardHeight
        : size.height * normalizedOffset.dy;
    x = x.clamp(0.0, (size.width - cardWidth).clamp(0.0, double.infinity));
    y = y.clamp(0.0, (size.height - cardHeight).clamp(0.0, double.infinity));

    // bottomLeft 样式：检查与右下固定标记的垂直重叠，动态收窄卡片宽度
    if (template.defaultStyle == WatermarkStyle.bottomLeft &&
        systemMarksRect != Rect.zero) {
      final cardRect = Rect.fromLTWH(x, y, cardWidth, cardHeight);
      if (cardRect.bottom > systemMarksRect.top &&
          cardRect.top < systemMarksRect.bottom) {
        final safeGap = 10 * renderScale;
        final maxRight = systemMarksRect.left - safeGap;
        final narrowedWidth =
            (maxRight - x).clamp(60 * renderScale, cardWidth);
        if (narrowedWidth < cardWidth - 0.5) {
          cardWidth = narrowedWidth;
          // 以收窄后的宽度重新布局文本、重新计算卡片高度
          maxTextWidth = (cardWidth - padding * 2).clamp(1.0, double.infinity);
          painters.clear();
          cardHeight = padding * 2;
          for (final line in lines) {
            final baseFontSize = _lineFontSize(template, line) * renderScale;
            final baseStyle = TextStyle(
              color: line.color ?? template.textColor,
              fontSize: baseFontSize,
              fontWeight: line.isTitle ? FontWeight.bold : FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 2 * renderScale,
                ),
              ],
            );
            final painter = _createAutoScaledTextPainter(
              line.text,
              baseStyle,
              maxTextWidth,
              maxLines: 2,
            );
            painters.add(painter);
            final actualFontSize =
                painter.text?.style?.fontSize ?? baseFontSize;
            cardHeight += painter.height +
                actualFontSize * (layout.lineHeight - 1).clamp(0.0, 1.4);
          }
          // 卡片高度变化后重新计算 y 位置
          y = size.height * normalizedOffset.dy;
          y = y.clamp(
              0.0, (size.height - cardHeight).clamp(0.0, double.infinity));
        }
      }
    }

    final rect = Rect.fromLTWH(x, y, cardWidth, cardHeight);
    _withRotation(canvas, rect, rotationTurns, () {
      _paintSurface(
          canvas, rect, template, layout.radius * renderScale, renderScale);
      double curY = rect.top + padding;
      for (final painter in painters) {
        painter.paint(canvas, Offset(rect.left + padding, curY));
        final fontSize =
            painter.text?.style?.fontSize ?? template.fontSize * renderScale;
        curY +=
            painter.height + fontSize * (layout.lineHeight - 1).clamp(0.0, 1.4);
      }
      if (drawSelection) {
        _paintSelection(canvas, rect, renderScale);
      }
    });

    return WatermarkRenderResult(rect);
  }

  static WatermarkRenderResult _paintQr(
    Canvas canvas,
    Size size,
    WatermarkTemplate template,
    Map<String, String> data,
    List<WatermarkRenderLine> lines,
    Offset normalizedOffset,
    double userScale,
    int rotationTurns,
    bool drawSelection,
  ) {
    final layout = WatermarkLayoutSpec.fromTemplate(template);
    final renderScale = size.width / layout.referenceWidth * userScale;
    final padding = 12 * renderScale;
    final qrSize = 60 * renderScale;
    final cardWidth = size.width * 0.66 * userScale;
    final cardHeight = qrSize + padding * 2;
    final x = (size.width * normalizedOffset.dx)
        .clamp(0.0, (size.width - cardWidth).clamp(0.0, double.infinity));
    final y = (size.height * normalizedOffset.dy)
        .clamp(0.0, (size.height - cardHeight).clamp(0.0, double.infinity));
    final rect = Rect.fromLTWH(x, y, cardWidth, cardHeight);

    _withRotation(canvas, rect, rotationTurns, () {
      _paintSurface(
          canvas, rect, template, layout.radius * renderScale, renderScale);
      final qrRect = Rect.fromLTWH(
          rect.left + padding, rect.top + padding, qrSize, qrSize);
      canvas.drawRect(qrRect, Paint()..color = Colors.white);
      _paintFakeQr(canvas, qrRect, data['antiFakeCode'] ?? '');

      final textLeft = qrRect.right + 10 * renderScale;
      final maxTextWidth =
          (rect.right - padding - textLeft).clamp(1.0, double.infinity);
      double curY = rect.top + padding;
      for (final line in lines.take(4)) {
        final painter = _createTextPainter(
          line.text,
          TextStyle(
              color: line.color ?? Colors.white, fontSize: 11 * renderScale),
          maxTextWidth,
          maxLines: 2,
        );
        painter.paint(canvas, Offset(textLeft, curY));
        curY += painter.height + 2 * renderScale;
      }
      if (drawSelection) _paintSelection(canvas, rect, renderScale);
    });

    return WatermarkRenderResult(rect);
  }

  static void _paintFullScreen(
    Canvas canvas,
    Size size,
    WatermarkTemplate template,
    Map<String, String> data,
    double userScale,
  ) {
    final text =
        '${data['companyName'] ?? ''} ${data['projectName'] ?? ''}'.trim();
    if (text.isEmpty) return;
    final renderScale =
        size.width / WatermarkLayoutSpec.defaultReferenceWidth * userScale;
    final painter = _createTextPainter(
      text,
      TextStyle(
        color: Colors.black.withValues(alpha: template.opacity.clamp(0.0, 1.0)),
        fontSize: 40 * renderScale,
        fontWeight: FontWeight.bold,
      ),
      size.width,
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-15 * 3.14159 / 180);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  static bool _isFixedSystemField(WatermarkFieldType? field) {
    return field == WatermarkFieldType.antiFakeCode ||
        field == WatermarkFieldType.timeFull ||
        field == WatermarkFieldType.timeDate ||
        field == WatermarkFieldType.timeOnly;
  }

  /// Calculates the bounding [Rect] of the bottom-right fixed system marks
  /// (anti-fake code + time), without painting anything.
  static Rect _calculateFixedSystemMarksRect(
    Size size,
    Map<String, String> data,
    double userScale,
  ) {
    final timeText = _formatFixedTime(data);
    final codeText = _formatFixedCode(data['antiFakeCode'] ?? '');
    if (timeText.isEmpty && codeText.isEmpty) return Rect.zero;

    final renderScale =
        size.width / WatermarkLayoutSpec.defaultReferenceWidth * userScale;
    final margin = 18 * renderScale;
    final gap = 4 * renderScale;
    final maxWidth = (size.width * 0.72).clamp(1.0, double.infinity);

    double totalHeight = 0;
    double maxTextWidth = 0;

    void measureLine(String text, double fontSize) {
      if (text.isEmpty) return;
      final painter = _createTextPainter(
        text,
        TextStyle(color: Colors.white, fontSize: fontSize),
        maxWidth,
        maxLines: 1,
      );
      totalHeight += painter.height;
      if (painter.width > maxTextWidth) maxTextWidth = painter.width;
    }

    measureLine(codeText, 13 * renderScale);
    if (codeText.isNotEmpty && timeText.isNotEmpty) totalHeight += gap;
    measureLine(timeText, 18 * renderScale);

    if (totalHeight == 0) return Rect.zero;

    final left = (size.width - margin - maxTextWidth).clamp(0.0, size.width);
    final top = size.height - margin - totalHeight;
    final right = size.width - margin;
    final bottom = size.height - margin;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static void _paintFixedSystemMarks(
    Canvas canvas,
    Size size,
    Map<String, String> data,
    double userScale,
  ) {
    final timeText = _formatFixedTime(data);
    final codeText = _formatFixedCode(data['antiFakeCode'] ?? '');
    if (timeText.isEmpty && codeText.isEmpty) return;

    final renderScale =
        size.width / WatermarkLayoutSpec.defaultReferenceWidth * userScale;
    final margin = 18 * renderScale;
    final gap = 4 * renderScale;
    final maxWidth = (size.width * 0.72).clamp(1.0, double.infinity);
    final lines = <TextPainter>[];

    void addLine(String text, double fontSize) {
      if (text.isEmpty) return;
      lines.add(_createTextPainter(
        text,
        TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 4 * renderScale,
              offset: Offset(0, 1 * renderScale),
            ),
          ],
        ),
        maxWidth,
        maxLines: 1,
      ));
    }

    addLine(codeText, 13 * renderScale);
    addLine(timeText, 18 * renderScale);
    if (lines.isEmpty) return;

    final totalHeight =
        lines.fold<double>(0, (sum, painter) => sum + painter.height) +
            gap * (lines.length - 1);
    double y = size.height - margin - totalHeight;
    for (final painter in lines) {
      painter.paint(canvas, Offset(size.width - margin - painter.width, y));
      y += painter.height + gap;
    }
  }

  static String _formatFixedTime(Map<String, String> data) {
    final value = (data['timeFull'] ?? data['timeDate'] ?? '').trim();
    if (value.isEmpty) return '';
    final normalized = value.replaceAll('-', '/');
    return normalized.length > 16 ? normalized.substring(0, 16) : normalized;
  }

  static String _formatFixedCode(String rawCode) {
    var code = rawCode.trim();
    if (code.isEmpty) return '';
    code = code.replaceFirst(RegExp(r'^防伪码[:：]\s*'), '').trim();
    return '防伪码: $code';
  }

  static void _paintSurface(
    Canvas canvas,
    Rect rect,
    WatermarkTemplate template,
    double radius,
    double scale,
  ) {
    if (template.skeletonPreset == 'clean') return;
    if (template.defaultStyle == WatermarkStyle.bottomBar) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            template.backgroundColor,
            template.backgroundColor.withValues(alpha: 0),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
      return;
    }

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final preset = template.skeletonPreset;
    if (preset == 'glass') {
      // White frosted glass
      canvas.drawRRect(rrect, Paint()..color = Colors.white.withValues(alpha: 0.15));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * scale,
      );
    } else if (preset == 'compact') {
      // Semi-transparent black
      canvas.drawRRect(rrect, Paint()..color = Colors.black.withValues(alpha: 0.6));
    } else if (preset == 'default') {
      // Transparent dark micro-frosted-glass
      canvas.drawRRect(rrect, Paint()..color = Colors.black.withValues(alpha: 0.2));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * scale,
      );
    } else {
      // Custom skeletonPreset — fall back to template backgroundColor
      canvas.drawRRect(rrect, Paint()..color = template.backgroundColor);
    }
  }

  static TextPainter _createTextPainter(
    String text,
    TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);
  }

  /// Creates a [TextPainter] that auto-scales font size down so the text
  /// fits within [maxLines] at [maxWidth]. Starts at the given [baseStyle]
  /// font size and steps down by 0.5 until it fits or reaches [minFontSize].
  static TextPainter _createAutoScaledTextPainter(
    String text,
    TextStyle baseStyle,
    double maxWidth, {
    int maxLines = 2,
    double minFontSize = 9.0,
  }) {
    final initialFontSize = baseStyle.fontSize ?? 14.0;
    double currentSize = initialFontSize;
    TextPainter? lastPainter;

    while (currentSize >= minFontSize - 0.01) {
      final style = baseStyle.copyWith(fontSize: currentSize);
      final painter = _createTextPainter(text, style, maxWidth, maxLines: maxLines);
      lastPainter = painter;
      if (!painter.didExceedMaxLines) {
        return painter;
      }
      currentSize -= 0.5;
    }

    // Return the last attempt (at minFontSize or just above)
    return lastPainter!;
  }

  static void _withRotation(
      Canvas canvas, Rect rect, int rotationTurns, VoidCallback draw) {
    canvas.save();
    if (rotationTurns != 0) {
      final center = rect.center;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationTurns * 3.1415926535897932 / 2);
      canvas.translate(-center.dx, -center.dy);
    }
    draw();
    canvas.restore();
  }

  static void _paintSelection(Canvas canvas, Rect rect, double scale) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.inflate(4 * scale), Radius.circular(14 * scale)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  static void _paintFakeQr(Canvas canvas, Rect rect, String code) {
    const grid = 21;
    final cellSize = rect.width / grid;
    final paint = Paint()..color = Colors.black;
    for (int i = 0; i < grid; i++) {
      for (int j = 0; j < grid; j++) {
        if ((code.hashCode + i * 31 + j * 17) % 3 != 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + i * cellSize,
              rect.top + j * cellSize,
              cellSize,
              cellSize,
            ),
            paint,
          );
        }
      }
    }
  }

  static double _lineFontSize(
      WatermarkTemplate template, WatermarkRenderLine line) {
    if (line.fontSize != null && line.fontSize! > 0) return line.fontSize!;
    if (line.isTitle) return template.fontSize * 1.3;
    if (line.isSubtitle) return template.fontSize * 0.95;
    return template.fontSize;
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('#')) {
      final hex = text.substring(1);
      final normalized =
          hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex;
      if (normalized.length == 6) {
        final color = int.tryParse('FF$normalized', radix: 16);
        if (color != null) return Color(color);
      }
      if (normalized.length == 8) {
        final color = int.tryParse(normalized, radix: 16);
        if (color != null) return Color(color);
      }
    }
    return null;
  }
}
