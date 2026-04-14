import '../repositories/device_id.dart';
import '../repositories/sync_timestamp_merge.dart';

class SyncCoordinator {
  static Future<void> reconcileSingle<TRemote>({
    required TRemote? remoteRecord,
    required String Function(TRemote record) remoteUdid,
    required DateTime Function(TRemote record) remoteUpdatedAt,
    required DateTime? localUpdatedAt,
    required Future<void> Function(TRemote record, DateTime remoteUpdatedAt)
    onPullRemote,
    required Future<void> Function() onPushLocal,
  }) async {
    if (remoteRecord == null) {
      return;
    }

    final String ownDeviceId = await DeviceId.getDeviceId();
    if (remoteUdid(remoteRecord) == ownDeviceId) {
      return;
    }

    final DateTime remoteTimestamp = remoteUpdatedAt(remoteRecord);
    final SyncTimestampResolution resolution = SyncTimestampMerge.resolve(
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteTimestamp,
    );

    if (resolution == SyncTimestampResolution.pullRemote) {
      await onPullRemote(remoteRecord, remoteTimestamp);
      return;
    }

    if (resolution == SyncTimestampResolution.pushLocal) {
      await onPushLocal();
    }
  }

  static Future<void> reconcileCollection<TRemote, TKey>({
    required Iterable<TRemote> remoteRecords,
    required TKey Function(TRemote record) keyOf,
    required String Function(TRemote record) remoteUdid,
    required DateTime Function(TRemote record) remoteUpdatedAt,
    required DateTime? Function(TKey key) localUpdatedAtOf,
    required Future<void> Function(
      TKey key,
      TRemote record,
      DateTime remoteUpdatedAt,
    )
    onPullRemote,
    required Future<void> Function(TKey key, DateTime localUpdatedAt)
    onPushLocal,
  }) async {
    for (final record in remoteRecords) {
      final TKey key = keyOf(record);
      await reconcileSingle<TRemote>(
        remoteRecord: record,
        remoteUdid: remoteUdid,
        remoteUpdatedAt: remoteUpdatedAt,
        localUpdatedAt: localUpdatedAtOf(key),
        onPullRemote: (remoteRecord, remoteTimestamp) =>
            onPullRemote(key, remoteRecord, remoteTimestamp),
        onPushLocal: () => onPushLocal(key, localUpdatedAtOf(key)!),
      );
    }
  }
}
