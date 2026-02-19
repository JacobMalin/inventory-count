import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/repositories/sync_timestamp_merge.dart';

void main() {
  group('SyncTimestampMerge', () {
    test('returns pullRemote when local timestamp is null', () {
      final SyncTimestampResolution result = SyncTimestampMerge.resolve(
        localUpdatedAt: null,
        remoteUpdatedAt: DateTime.utc(2026),
      );

      expect(result, SyncTimestampResolution.pullRemote);
    });

    test('returns pullRemote when local timestamp is older', () {
      final SyncTimestampResolution result = SyncTimestampMerge.resolve(
        localUpdatedAt: DateTime.utc(2026),
        remoteUpdatedAt: DateTime.utc(2026, 1, 2),
      );

      expect(result, SyncTimestampResolution.pullRemote);
    });

    test('returns pushLocal when local timestamp is newer', () {
      final SyncTimestampResolution result = SyncTimestampMerge.resolve(
        localUpdatedAt: DateTime.utc(2026, 1, 3),
        remoteUpdatedAt: DateTime.utc(2026, 1, 2),
      );

      expect(result, SyncTimestampResolution.pushLocal);
    });

    test('returns noChange when timestamps are equal', () {
      final timestamp = DateTime.utc(2026, 1, 2);
      final SyncTimestampResolution result = SyncTimestampMerge.resolve(
        localUpdatedAt: timestamp,
        remoteUpdatedAt: timestamp,
      );

      expect(result, SyncTimestampResolution.noChange);
    });
  });
}
