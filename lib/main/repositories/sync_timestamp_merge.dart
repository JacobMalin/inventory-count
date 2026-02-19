enum SyncTimestampResolution { pullRemote, pushLocal, noChange }

class SyncTimestampMerge {
  static SyncTimestampResolution resolve({
    required DateTime? localUpdatedAt,
    required DateTime remoteUpdatedAt,
  }) {
    if (localUpdatedAt == null || localUpdatedAt.isBefore(remoteUpdatedAt)) {
      return SyncTimestampResolution.pullRemote;
    }

    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return SyncTimestampResolution.pushLocal;
    }

    return SyncTimestampResolution.noChange;
  }
}
