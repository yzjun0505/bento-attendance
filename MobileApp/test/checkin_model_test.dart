import 'package:flutter_test/flutter_test.dart';
import 'package:jingmap_app/models/checkin_model.dart';

void main() {
  Checkin buildCheckin({
    required String type,
    String? rawStatus,
    String? attendanceStatus,
  }) {
    return Checkin(
      id: 1,
      userId: 1,
      type: type,
      address: '测试地址',
      photo: '',
      remark: '',
      isOutside: false,
      createdAt: DateTime(2026, 5, 25, 18, 49),
      rawStatus: rawStatus,
      attendanceStatus: attendanceStatus,
    );
  }

  group('Checkin statusText', () {
    test('clock_out with normal attendance status is not abnormal', () {
      final checkin = buildCheckin(
        type: 'clock_out',
        rawStatus: 'early',
        attendanceStatus: 'normal',
      );

      expect(checkin.statusText, isNull);
      expect(checkin.isAbnormal, isFalse);
    });

    test('clock_out with early status shows early leave', () {
      final checkin = buildCheckin(
        type: 'clock_out',
        attendanceStatus: 'early',
      );

      expect(checkin.statusText, '早退');
      expect(checkin.isAbnormal, isTrue);
    });

    test('clock_in with late status shows late', () {
      final checkin = buildCheckin(
        type: 'clock_in',
        attendanceStatus: 'late',
      );

      expect(checkin.statusText, '迟到');
      expect(checkin.isAbnormal, isTrue);
    });

    test('clock_in with normal attendance status is not abnormal', () {
      final checkin = buildCheckin(
        type: 'clock_in',
        rawStatus: 'late',
        attendanceStatus: 'normal',
      );

      expect(checkin.statusText, isNull);
      expect(checkin.isAbnormal, isFalse);
    });

    test('clock_out never shows late even if legacy raw status is late', () {
      final checkin = buildCheckin(
        type: 'clock_out',
        rawStatus: 'late',
      );

      expect(checkin.statusText, isNull);
      expect(checkin.isAbnormal, isFalse);
    });
  });
}
