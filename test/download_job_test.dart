import 'package:flutter_test/flutter_test.dart';
import 'package:jm_visual/models/download_job.dart';

void main() {
  test('download job defaults missing dedupe metadata', () {
    final job = DownloadJob.fromJson({'id': 'job-1'});

    expect(job.deduped, isFalse);
    expect(job.dedupeReason, isEmpty);
  });

  test('download job parses, serializes, and copies dedupe metadata', () {
    final job = DownloadJob.fromJson({
      'id': 'job-1',
      'deduped': true,
      'dedupeReason': 'already_downloaded',
    });

    expect(job.deduped, isTrue);
    expect(job.dedupeReason, 'already_downloaded');
    expect(job.toJson()['deduped'], isTrue);
    expect(job.toJson()['dedupeReason'], 'already_downloaded');
    expect(job.copyWith().deduped, isTrue);
    expect(job.copyWith().dedupeReason, 'already_downloaded');

    final changed = job.copyWith(
      deduped: false,
      dedupeReason: 'already_active',
    );
    expect(changed.deduped, isFalse);
    expect(changed.dedupeReason, 'already_active');
  });
}
