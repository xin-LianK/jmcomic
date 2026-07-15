import 'package:flutter_test/flutter_test.dart';
import 'package:jm_visual/models/download_job.dart';
import 'package:jm_visual/services/jm_presentation.dart';

DownloadJob _job({
  bool deduped = false,
  String reason = '',
  String kind = 'album',
}) {
  return DownloadJob.fromJson({
    'id': 'job-1',
    'kind': kind,
    'jmId': kind == 'album' ? '100' : '1001',
    'albumTitle': '测试漫画',
    'episodeTitle': '第一话',
    'deduped': deduped,
    'dedupeReason': reason,
  });
}

void main() {
  test('new downloads keep queued feedback', () {
    expect(downloadEnqueueMessage(_job()), '已加入服务器下载队列：测试漫画');
    expect(
      downloadEnqueueMessage(_job(kind: 'photo')),
      '章节已加入服务器下载队列：第一话',
    );
  });

  test('active, completed, and unknown dedupe feedback is accurate', () {
    expect(
      downloadEnqueueMessage(
        _job(deduped: true, reason: 'already_active'),
      ),
      '已在下载：测试漫画',
    );
    expect(
      downloadEnqueueMessage(
        _job(deduped: true, reason: 'already_downloaded'),
      ),
      '已下载：测试漫画',
    );
    expect(
      downloadEnqueueMessage(
        _job(deduped: true, reason: 'future_reason'),
      ),
      '下载任务已存在：测试漫画',
    );
  });

  test('partial scheduler status is localized', () {
    expect(jmTaskRunStatusLabel('partial'), '部分成功');
    expect(jmTaskRunStatusLabel('succeeded'), '成功');
    expect(jmTaskRunStatusLabel('failed'), '失败');
  });
}
