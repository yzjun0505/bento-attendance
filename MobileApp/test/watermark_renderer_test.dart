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
}
