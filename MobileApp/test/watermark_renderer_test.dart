import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jingmap_app/models/watermark_template.dart';
import 'package:jingmap_app/utils/watermark_renderer.dart';

void main() {
  test('normalizes web layout spec from template schema', () {
    final template = WatermarkTemplate(
      id: 'wm-1',
      name: '测试水印',
      category: WatermarkCategory.general,
      fields: const [WatermarkFieldType.userName],
      schemaJson: {
        'layout': {
          'referenceWidth': 390,
          'surface': {
            'x': 0.1,
            'y': 0.7,
            'width': 0.68,
            'padding': 18,
            'lineHeight': 1.5,
            'radius': 14,
          },
        },
      },
    );

    final layout = WatermarkLayoutSpec.fromTemplate(template);

    expect(layout.referenceWidth, 390);
    expect(layout.x, 0.1);
    expect(layout.y, 0.7);
    expect(layout.width, 0.68);
    expect(layout.padding, 18);
    expect(layout.lineHeight, 1.5);
    expect(layout.radius, 14);
  });

  test('builds title, subtitle and custom slot lines in template order', () {
    final template = WatermarkTemplate(
      id: 'wm-2',
      name: '测试水印',
      category: WatermarkCategory.general,
      fields: const [WatermarkFieldType.projectName],
      titleSlot: WatermarkSlot(
        id: 'title',
        label: '项目名称',
        binding: 'projectName',
        style: const {'fontSize': 18},
      ),
      subtitleSlot: WatermarkSlot(
        id: 'subtitle',
        label: '打卡时间',
        binding: 'checkinTime',
      ),
      contentSlots: [
        WatermarkSlot(id: 'worker', label: '打卡人', binding: 'userName'),
        WatermarkSlot(id: 'addr', label: '位置', binding: 'location'),
      ],
    );

    final lines = WatermarkRenderer.buildLines(template, const {
      'projectName': '遵义医科大学',
      'timeFull': '2026-04-23 12:00:00',
      'userName': '张三',
      'addressDetail': '贵州省遵义市',
    });

    expect(lines.map((line) => line.text), [
      '遵义医科大学',
      '2026-04-23 12:00:00',
      '打卡人：张三',
      '位置：贵州省遵义市',
    ]);
    expect(lines.first.isTitle, isTrue);
    expect(lines.first.fontSize, 18);
  });

  group('right-side fixed marks avoidance', () {
    /// Helper: run paint() and return the card rect from the result.
    WatermarkRenderResult? paintCardResult(
      Size size,
      WatermarkTemplate template,
      Map<String, String> data, {
      Offset normalizedOffset = const Offset(0.08, 0.80),
      double scale = 1,
    }) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      return WatermarkRenderer.paint(
        canvas: canvas,
        size: size,
        template: template,
        data: data,
        normalizedOffset: normalizedOffset,
        scale: scale,
      );
    }

    // Default card width for 390px at 72% = 280.8
    double defaultCardWidth(Size size) => size.width * 0.72;

    test('long address narrows card when vertically overlapping right marks',
        () {
      final data = {
        'timeFull': '2026/05/25 14:30:00',
        'userName': '测试用户',
        'addressDetail':
            '广东省深圳市南山区粤海街道某某科技园一期二栋三单元地下停车场入口东侧施工区域',
        'antiFakeCode': 'ABCD-EFGH-IJKL-MNOP',
      };
      final template = WatermarkTemplate(
        id: 'test-avoid',
        name: 'test',
        category: WatermarkCategory.general,
        defaultStyle: WatermarkStyle.bottomLeft,
        fields: const [
          WatermarkFieldType.addressDetail,
          WatermarkFieldType.userName,
        ],
      );

      const testSize = Size(390, 600);
      final result = paintCardResult(testSize, template, data);

      expect(result, isNotNull);
      // Card should be narrower than the default 72% width when overlapping
      expect(result!.rect.width, lessThan(defaultCardWidth(testSize)));
      // Right edge should leave room for fixed marks (not at far right)
      expect(result.rect.right, lessThan(280.0));
    });

    test('short address keeps default card width', () {
      final data = {
        'timeFull': '2026/05/25 14:30:00',
        'userName': '测试用户',
        'addressDetail': '贵州省遵义市',
        'antiFakeCode': 'ABCD-EFGH-IJKL-MNOP',
      };
      final template = WatermarkTemplate(
        id: 'test-short',
        name: 'test',
        category: WatermarkCategory.general,
        defaultStyle: WatermarkStyle.bottomLeft,
        fields: const [
          WatermarkFieldType.addressDetail,
          WatermarkFieldType.userName,
        ],
      );

      const testSize = Size(390, 600);
      final result = paintCardResult(testSize, template, data);

      expect(result, isNotNull);
      // Short address → no wrapping → card not tall enough to overlap → width unchanged
      expect(result!.rect.width, closeTo(defaultCardWidth(testSize), 1.0));
    });

    test('bottomBar style is unaffected by avoidance', () {
      final data = {
        'timeFull': '2026/05/25 14:30:00',
        'addressDetail':
            '广东省深圳市南山区粤海街道某某科技园一期二栋三单元地下停车场入口东侧施工区域',
        'antiFakeCode': 'ABCD-EFGH-IJKL-MNOP',
      };
      final template = WatermarkTemplate(
        id: 'test-bottombar',
        name: 'test',
        category: WatermarkCategory.general,
        defaultStyle: WatermarkStyle.bottomBar,
        fields: const [
          WatermarkFieldType.addressDetail,
          WatermarkFieldType.userName,
        ],
      );

      const testSize = Size(390, 600);
      final result = paintCardResult(testSize, template, data);

      expect(result, isNotNull);
      // bottomBar spans full width regardless
      expect(result!.rect.width, closeTo(390.0, 1.0));
    });

    test('no antiFakeCode still narrows when address overflows', () {
      // Data without antiFakeCode — right marks contain only time
      final data = {
        'timeFull': '2026/05/25 14:30:00',
        'userName': '测试用户',
        'addressDetail':
            '广东省深圳市南山区粤海街道某某科技园一期二栋三单元地下停车场入口东侧施工区域',
      };
      final template = WatermarkTemplate(
        id: 'test-no-code',
        name: 'test',
        category: WatermarkCategory.general,
        defaultStyle: WatermarkStyle.bottomLeft,
        fields: const [
          WatermarkFieldType.addressDetail,
          WatermarkFieldType.userName,
        ],
      );

      const testSize = Size(390, 600);
      final result = paintCardResult(testSize, template, data);

      expect(result, isNotNull);
      // Even without antiFakeCode, time alone creates a right-side zone → avoid
      expect(result!.rect.width, lessThan(defaultCardWidth(testSize)));
    });
  });
}
