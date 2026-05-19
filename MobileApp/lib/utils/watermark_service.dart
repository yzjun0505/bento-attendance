import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import '../models/watermark_template.dart';
import 'watermark_renderer.dart';

class WatermarkService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> capturePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (photo == null) return null;
    return File(photo.path);
  }

  static Future<File?> pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (photo == null) return null;
    return File(photo.path);
  }

  static String _getWeekdayStr(DateTime dt) {
    const days = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return days[dt.weekday - 1];
  }

  static String _getFieldValue(
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

  static String _getSlotValue(WatermarkSlot slot, Map<String, String> data) {
    if (slot.binding != null && slot.binding!.isNotEmpty) {
      final fieldType = WatermarkTemplate.bindingToFieldType(slot.binding);
      if (fieldType != null) {
        return _getFieldValue(fieldType, data);
      }
    }
    if (slot.customText != null && slot.customText!.isNotEmpty) {
      return slot.customText!;
    }
    if (slot.label.isNotEmpty) {
      final fieldType = WatermarkTemplate.labelToFieldType(slot.label);
      return _getFieldValue(fieldType, data);
    }
    return '';
  }

  static String _getSlotDisplayText(WatermarkSlot slot, Map<String, String> data) {
    final value = _getSlotValue(slot, data);
    if (value.isEmpty) return '';
    if (slot.id == 'title' || slot.id == 'subtitle') {
      return value;
    }
    return '${slot.label}：$value';
  }

  static Future<File> addWatermark({
    required File imageFile,
    required String userName,
    required String projectName,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required String watermarkCode,
    String? address,
    String weather = '暂无天气',
    String? temperature,
    String? humidity,
    double? altitude,
    String customName = '上班打卡',
    File? localLogoFile,
    WatermarkTemplate? template,
    Offset normalizedOffset = const Offset(0, 0.7),
    double scale = 1.0,
    int rotationTurns = 0,
    String? companyName,
    String? homeowner,
    String? contractorOrg,
    String? teamLeader,
    String? manager,
    String? workContent,
    String? safetyStatus,
    String? deviceNo,
    String? deviceStatus,
    String? acceptanceResult,
    String? position,
    String? remark,
    Map<String, String>? watermarkData,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;
    final imgWidth = originalImage.width.toDouble();
    final imgHeight = originalImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(originalImage, Offset.zero, Paint());

    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    final dateStr = DateFormat('yyyy-MM-dd').format(timestamp);
    final timeOnlyStr = DateFormat('HH:mm:ss').format(timestamp);
    final weekdayStr = _getWeekdayStr(timestamp);
    final locStr = address ??
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

    final data = watermarkData ?? <String, String>{
      'timeFull': timeStr,
      'timeDate': '$dateStr  $weekdayStr',
      'timeOnly': timeOnlyStr,
      'projectName': projectName,
      'addressDetail': locStr,
      'userName': userName,
      'gpsLat': '纬度: ${latitude.toStringAsFixed(6)}',
      'gpsLng': '经度: ${longitude.toStringAsFixed(6)}',
      'weather': weather,
      'temperature': (temperature != null && temperature != '--')
          ? '温度: $temperature℃'
          : '',
      'humidity':
          (humidity != null && humidity != '--') ? '湿度: $humidity%' : '',
      'altitude': altitude != null ? '海拔: ${altitude.toStringAsFixed(1)}m' : '',
      'antiFakeCode': '防伪码: $watermarkCode',
      'homeowner': homeowner ?? '',
      'contractorOrg': contractorOrg ?? '',
      'teamLeader': teamLeader ?? '',
      'manager': manager ?? '',
      'workContent': workContent ?? customName,
      'safetyStatus': safetyStatus ?? '正常',
      'deviceNo': deviceNo ?? '',
      'deviceStatus': deviceStatus ?? '正常',
      'acceptanceResult': acceptanceResult ?? '合格',
      'position': position ?? '',
      'remark': remark ?? '',
      'companyName': companyName ?? '',
      'inspectionContent': customName,
      'acceptanceContent': customName,
    };

    if (!data.containsKey('antiFakeCode') || data['antiFakeCode']!.isEmpty) {
      data['antiFakeCode'] = '防伪码: $watermarkCode';
    }

    final tmpl = template ?? _defaultTemplate();
    WatermarkRenderer.paint(
      canvas: canvas,
      size: Size(imgWidth, imgHeight),
      template: tmpl,
      data: data,
      normalizedOffset: normalizedOffset,
      scale: scale,
      rotationTurns: rotationTurns,
    );

    final picture = recorder.endRecording();
    final newImage = await picture.toImage(imgWidth.toInt(), imgHeight.toInt());
    final byteData = await newImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('无法生成图片');

    final directory = await getApplicationDocumentsDirectory();
    final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(timestamp);
    final fileName = 'wm_${timestampStr}_$watermarkCode.png';
    final outputPath = '${directory.path}/$fileName';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(byteData.buffer.asUint8List());
    try {
      await Gal.putImage(outputPath);
    } catch (e) {
      debugPrint('保存图片到相册失败: $e');
    }
    return outputFile;
  }

  static int legacyGetDisplayLines(WatermarkTemplate tmpl, Map<String, String> data) {
    int lines = 0;
    if (tmpl.titleSlot != null && _getSlotValue(tmpl.titleSlot!, data).isNotEmpty) {
      lines++;
    }
    if (tmpl.subtitleSlot != null && _getSlotValue(tmpl.subtitleSlot!, data).isNotEmpty) {
      lines++;
    }
    for (final slot in tmpl.contentSlots) {
      if (_getSlotValue(slot, data).isNotEmpty) {
        lines++;
      }
    }
    if (lines == 0) {
      lines = tmpl.enabledFields
          .map((f) => _getFieldValue(f, data))
          .where((v) => v.isNotEmpty)
          .length;
    }
    return lines;
  }

  static WatermarkTemplate _defaultTemplate() => WatermarkTemplate(
        id: 'default',
        name: '默认',
        category: WatermarkCategory.general,
        fields: [
          WatermarkFieldType.timeFull,
          WatermarkFieldType.userName,
          WatermarkFieldType.addressDetail,
        ],
      );

  static void legacyDrawWrappedText(Canvas canvas, String text, TextStyle style,
      Offset offset, double maxWidth,
      {int maxLines = 0}) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLines == 0 ? null : maxLines,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  static void legacyDrawStyledWatermark(
    Canvas canvas,
    double imgWidth,
    double imgHeight,
    double scale,
    double baseScale,
    double destX,
    double destY,
    Map<String, String> data,
    WatermarkTemplate tmpl,
    WatermarkStyle style,
    String skeletonPreset,
  ) {
    final displayLines = <String>[];
    final lineStyles = <LegacyLineStyle>[];

    if (tmpl.titleSlot != null) {
      final ft = tmpl.titleSlot!.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(tmpl.titleSlot!, data);
        if (value.isNotEmpty) {
          displayLines.add(value);
          lineStyles.add(LegacyLineStyle(isTitle: true));
        }
      }
    }

    if (tmpl.subtitleSlot != null) {
      final ft = tmpl.subtitleSlot!.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(tmpl.subtitleSlot!, data);
        if (value.isNotEmpty) {
          displayLines.add(value);
          lineStyles.add(LegacyLineStyle(isSubtitle: true));
        }
      }
    }

    for (final slot in tmpl.contentSlots) {
      final ft = slot.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (!enabled) continue;
      final text = _getSlotDisplayText(slot, data);
      if (text.isNotEmpty) {
        displayLines.add(text);
        lineStyles.add(LegacyLineStyle());
      }
    }

    if (displayLines.isEmpty) {
      final fields = tmpl.enabledFields;
      for (final f in fields) {
        final val = _getFieldValue(f, data);
        if (val.isNotEmpty) {
          displayLines.add(val);
          lineStyles.add(LegacyLineStyle());
        }
      }
    }

    if (displayLines.isEmpty) return;

    final baseFontSize = tmpl.fontSize * scale;
    final textColor = tmpl.textColor;
    final padding = 16 * scale;
    final cardWidth =
        (style == WatermarkStyle.bottomBar) ? imgWidth : 500 * scale;

    double cardHeight = padding * 2;
    for (int i = 0; i < displayLines.length; i++) {
      final ls = lineStyles[i];
      final lineH = (ls.isTitle ? baseFontSize * 1.3 : baseFontSize) * 1.6;
      cardHeight += lineH;
    }

    double x, y;
    if (style == WatermarkStyle.bottomBar) {
      x = 0;
      y = imgHeight - cardHeight;
    } else if (style == WatermarkStyle.topRight) {
      x = imgWidth - cardWidth - padding;
      y = padding;
    } else {
      x = destX.clamp(0.0, (imgWidth - cardWidth).clamp(0.0, double.infinity));
      y = destY.clamp(
          0.0, (imgHeight - cardHeight).clamp(0.0, double.infinity));
    }

    final borderRadius = _getBorderRadius(skeletonPreset, scale);

    if (skeletonPreset == 'clean') {
    } else if (style == WatermarkStyle.bottomBar) {
      final bgPaint = Paint()..color = tmpl.backgroundColor;
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [tmpl.backgroundColor, tmpl.backgroundColor.withValues(alpha: 0.0)],
      );
      bgPaint.shader =
          gradient.createShader(Rect.fromLTWH(x, y, cardWidth, cardHeight));
      canvas.drawRect(Rect.fromLTWH(x, y, cardWidth, cardHeight), bgPaint);
    } else if (skeletonPreset == 'glass') {
      final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.15);
      canvas.drawRRect(
          RRect.fromLTRBR(
              x, y, x + cardWidth, y + cardHeight, borderRadius),
          bgPaint);
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale;
      canvas.drawRRect(
          RRect.fromLTRBR(
              x, y, x + cardWidth, y + cardHeight, borderRadius),
          borderPaint);
    } else if (skeletonPreset == 'compact') {
      final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
      canvas.drawRRect(
          RRect.fromLTRBR(
              x, y, x + cardWidth, y + cardHeight, borderRadius),
          bgPaint);
    } else {
      final bgPaint = Paint()..color = tmpl.backgroundColor;
      canvas.drawRRect(
          RRect.fromLTRBR(
              x, y, x + cardWidth, y + cardHeight, borderRadius),
          bgPaint);
    }

    double curY = y + padding;
    for (int i = 0; i < displayLines.length; i++) {
      final text = displayLines[i];
      final ls = lineStyles[i];
      final fontSize = ls.isTitle ? baseFontSize * 1.3 : baseFontSize;
      final fontWeight = ls.isTitle ? FontWeight.bold : FontWeight.w500;

      legacyDrawWrappedText(
        canvas,
        text,
        TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          shadows: [
            Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 2 * scale)
          ],
        ),
        Offset(x + padding, curY),
        cardWidth - padding * 2,
        maxLines: 2,
      );
      curY += fontSize * 1.6;
    }
  }

  static Radius _getBorderRadius(String skeletonPreset, double scale) {
    if (skeletonPreset == 'glass') {
      return Radius.circular(12 * scale);
    } else if (skeletonPreset == 'compact') {
      return Radius.circular(4 * scale);
    }
    return Radius.circular(8 * scale);
  }

  static void legacyDrawFullScreenWatermark(
    Canvas canvas,
    double imgWidth,
    double imgHeight,
    double scale,
    Map<String, String> data,
    WatermarkTemplate tmpl,
    String skeletonPreset,
  ) {
    final companyName = data['companyName'] ?? '';
    final projectName = data['projectName'] ?? '';
    final text = '$companyName $projectName'.trim();
    if (text.isNotEmpty) {
      final fontSize = 40 * scale;
      final alpha = (tmpl.opacity * 255).clamp(0, 255).toInt();

      canvas.save();
      canvas.translate(imgWidth / 2, imgHeight / 2);
      canvas.rotate(-15 * 3.14159 / 180);

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black.withValues(alpha: alpha / 255),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final spacingX = tp.width + 120 * scale;
      final spacingY = tp.height + 120 * scale;
      final cols = (imgWidth * 1.5 / spacingX).ceil() + 2;
      final rows = (imgHeight * 1.5 / spacingY).ceil() + 2;

      for (int r = -rows ~/ 2; r < rows ~/ 2; r++) {
        for (int c = -cols ~/ 2; c < cols ~/ 2; c++) {
          tp.paint(canvas,
              Offset(c * spacingX - tp.width / 2, r * spacingY - tp.height / 2));
        }
      }
      canvas.restore();
    }

    final displayLines = <String>[];
    if (tmpl.titleSlot != null) {
      final ft = tmpl.titleSlot!.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(tmpl.titleSlot!, data);
        if (value.isNotEmpty) displayLines.add(value);
      }
    }
    if (tmpl.subtitleSlot != null) {
      final ft = tmpl.subtitleSlot!.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(tmpl.subtitleSlot!, data);
        if (value.isNotEmpty) displayLines.add(value);
      }
    }
    for (final slot in tmpl.contentSlots) {
      final ft = slot.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (!enabled) continue;
      final text = _getSlotDisplayText(slot, data);
      if (text.isNotEmpty) displayLines.add(text);
    }

    if (displayLines.isEmpty) {
      final fields = tmpl.enabledFields;
      for (final f in fields) {
        final val = _getFieldValue(f, data);
        if (val.isNotEmpty) displayLines.add(val);
      }
    }

    if (displayLines.isNotEmpty) {
      final fontSize2 = 14 * scale;
      final lineH = fontSize2 * 1.5;
      final cardH = displayLines.length * lineH + 32 * scale;
      final cardW = 400 * scale;
      final x = 20 * scale;
      final y = imgHeight - cardH - 20 * scale;
      final borderRadius = _getBorderRadius(skeletonPreset, scale);

      if (skeletonPreset != 'clean') {
        final bgColor = skeletonPreset == 'glass'
            ? Colors.white.withValues(alpha: 0.15)
            : (skeletonPreset == 'compact'
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0x33000000));
        canvas.drawRRect(
          RRect.fromLTRBR(x, y, x + cardW, y + cardH, borderRadius),
          Paint()..color = bgColor,
        );
        if (skeletonPreset == 'glass') {
          final borderPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 * scale;
          canvas.drawRRect(
            RRect.fromLTRBR(x, y, x + cardW, y + cardH, borderRadius),
            borderPaint,
          );
        }
      }

      double curY = y + 16 * scale;
      for (final val in displayLines) {
        legacyDrawWrappedText(
          canvas,
          val,
          TextStyle(
            color: Colors.white,
            fontSize: fontSize2,
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 2 * scale)
            ],
          ),
          Offset(x + 16 * scale, curY),
          cardW - 32 * scale,
          maxLines: 2,
        );
        curY += lineH;
      }
    }
  }

  static void legacyDrawQrCodeWatermark(
    Canvas canvas,
    double imgWidth,
    double imgHeight,
    double scale,
    double destX,
    double destY,
    Map<String, String> data,
    WatermarkTemplate tmpl,
    String skeletonPreset,
  ) {
    final qrSize = 120 * scale;
    final cardW = 450 * scale;

    final displayLines = <String>[];
    if (tmpl.titleSlot != null) {
      final ft = tmpl.titleSlot!.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(tmpl.titleSlot!, data);
        if (value.isNotEmpty) displayLines.add(value);
      }
    }
    if (tmpl.subtitleSlot != null) {
      final ft = tmpl.subtitleSlot!.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (enabled) {
        final value = _getSlotValue(tmpl.subtitleSlot!, data);
        if (value.isNotEmpty) displayLines.add(value);
      }
    }
    for (final slot in tmpl.contentSlots) {
      final ft = slot.fieldType;
      final enabled = ft == null || (tmpl.fieldEnabled[ft] ?? true);
      if (!enabled) continue;
      final text = _getSlotDisplayText(slot, data);
      if (text.isNotEmpty) displayLines.add(text);
    }

    if (displayLines.isEmpty) {
      final fields = tmpl.enabledFields;
      for (final f in fields) {
        final val = _getFieldValue(f, data);
        if (val.isNotEmpty) displayLines.add(val);
      }
    }

    final fontSize = 13 * scale;
    final lineH = fontSize * 1.5;
    final cardH = qrSize + 32 * scale;

    final x = destX.clamp(0.0, (imgWidth - cardW).clamp(0.0, double.infinity));
    final y = (imgHeight - cardH - 20 * scale)
        .clamp(0.0, (imgHeight - cardH).clamp(0.0, double.infinity));

    final borderRadius = _getBorderRadius(skeletonPreset, scale);

    if (skeletonPreset == 'glass') {
      final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.15);
      canvas.drawRRect(
          RRect.fromLTRBR(x, y, x + cardW, y + cardH, borderRadius),
          bgPaint);
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale;
      canvas.drawRRect(
          RRect.fromLTRBR(x, y, x + cardW, y + cardH, borderRadius),
          borderPaint);
    } else if (skeletonPreset == 'compact') {
      canvas.drawRRect(
        RRect.fromLTRBR(x, y, x + cardW, y + cardH, borderRadius),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
    } else {
      canvas.drawRRect(
        RRect.fromLTRBR(x, y, x + cardW, y + cardH, borderRadius),
        Paint()..color = const Color(0xCC000000),
      );
    }

    final qrX = x + 16 * scale;
    final qrY = y + 16 * scale;
    canvas.drawRect(
        Rect.fromLTWH(qrX, qrY, qrSize, qrSize), Paint()..color = Colors.white);

    const grid = 21;
    final cellSize = qrSize / grid;
    final code = data['antiFakeCode'] ?? '';
    for (int i = 0; i < grid; i++) {
      for (int j = 0; j < grid; j++) {
        if ((code.hashCode + i * 31 + j * 17) % 3 != 0) {
          canvas.drawRect(
            Rect.fromLTWH(
                qrX + i * cellSize, qrY + j * cellSize, cellSize, cellSize),
            Paint()..color = Colors.black,
          );
        }
      }
    }

    double curY = y + 10 * scale;
    final textX = qrX + qrSize + 12 * scale;
    final textMaxW = cardW - (qrSize + 28 * scale);

    for (final val in displayLines) {
      legacyDrawWrappedText(
        canvas,
        val,
        TextStyle(color: Colors.white, fontSize: fontSize),
        Offset(textX, curY),
        textMaxW,
        maxLines: 2,
      );
      curY += lineH;
    }
  }
}

class LegacyLineStyle {
  final bool isTitle;
  final bool isSubtitle;

  LegacyLineStyle({this.isTitle = false, this.isSubtitle = false});
}
