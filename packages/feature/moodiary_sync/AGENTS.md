# moodiary_sync: synchronization contracts

Follow the repository-wide guidance in [AGENTS.md](../../../AGENTS.md).

- Return `null` only for missing remote objects; propagate other backend errors as
  `SyncException`. Reject corrupt manifests and preserve `SyncManifest` version
  guards instead of treating invalid data as an empty remote.
- Compare last-writer-wins timestamps as integer milliseconds. Apply the same
  ordering to updates and deletions; recheck local timestamps before pull writes.
- Upload media before diary JSON and the manifest. Record only media confirmed by
  the existing manifest, a probe or an upload. Missing local files must not create
  unconfirmed references; failed media uploads must block that diary's update.
- Defer obsolete remote deletions and persistence of tombstone coverage until
  after any required manifest commit and verification. On pull, write the diary
  tombstone before deleting its local media.
- Preserve both the manifest baseline-byte check and `writeToken` readback.
  These checks detect races but do not provide atomic compare-and-swap or rollback.
- Keep the process lock outside `RemoteLease`. Keep `sync.lock` plaintext, check
  ownership before renewal and release, and await pending renewal before release.
- Preserve tombstone coverage across the currently configured cloud backends.
  Restoring an entity removes its old tombstone. Changing backend configuration
  or retention semantics can stop deletion propagation to offline devices.
- Count partial failures in `failed`; advance `lastSyncTime` only without failures
  or cancellation. Pair every emitted `syncStart` with `syncEnd`, including errors.
- Cloud-origin writes must preserve timestamps and carry `fromSync` to avoid
  marking pulled changes dirty and pushing them back immediately.
- Keep the data encryption key in secure storage. Passphrase changes rewrap its
  remote envelope; pending keyfile uploads must be retried before sync.
- Re-ciphering must collect media from both the manifest and decoded diary JSON,
  including objects skipped as already converted when toggling encryption.
  Conversion is not transactional: do not treat a partial report as success or
  discard the local key after failed encryption removal.
