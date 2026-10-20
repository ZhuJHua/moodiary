# Incremental sync architecture

This document covers the current cloud sync contracts and known limitations.

## Architecture

- `SyncRunner` coordinates operations; `AutoSyncWatcher` debounces local changes
  and polls the remote manifest. Cloud-origin events use `fromSync` to avoid echo
  pushes. Unchanged manifest probes can skip idle polls, with periodic full-sync
  fallback.
- `IRemoteSyncBackend` implements WebDAV or S3 / MinIO storage. The provider scope
  selects the active backend through DI.
- `IncrementalSyncEngine` handles push and pull under a process-wide lock and
  `RemoteLease`. Separate pools bound network requests and media pipelines.
- `SyncManifest` records entries, media references and millisecond timestamps.
  `SyncTombstone` records local deletions and their coverage across cloud backends.
- `SyncCipher` encodes objects with optional AES-GCM encryption. `SyncKeyManager`
  stores the data encryption key locally in secure storage and its wrapped envelope
  remotely in `keys.json`. Changing the passphrase rewraps the envelope; pending
  keyfile uploads are retried before sync.
- `CloudReCipher` rewrites remote objects when changing encryption. `SyncLogger`
  publishes events and persistent logs.

Remote layout is defined by `SyncKeys` in
[manifest.dart](lib/src/data/model/manifest.dart):

```text
manifest.json
sync.lock
keys.json                       # when using envelope encryption
diary/<id>.json
category/<id>.json
place/<id>.json
mediainfo/<type>/<filename>.json
media/<type>/<filename>
```

`sync()` pulls and then pushes in the same critical section. It reuses the fetched
manifest only when pull made no entry changes and reported no failures. Pull
applies entries through `ArchiveApplier` and repairs missing media. Push uploads
media, writes entry JSON, publishes the manifest, then performs deferred cleanup.

## Design contracts

1. **Absence is not failure.** Reads return `null` only for missing objects;
   deleting a missing object succeeds. Other backend errors propagate as
   `SyncException`. A present but corrupt manifest must fail rather than become an
   empty remote. Readers accept manifest versions 1 and 2; updates write version 2.
   Unsupported versions and invalid `entries` structure fail; malformed individual
   entries are skipped.
2. **Compare integer milliseconds.** Last-writer-wins comparisons use
   `millisecondsSinceEpoch`, matching `ManifestEntry.timeMs`. Push skips equal or
   newer remote entries. An old local deletion must not replace a newer live
   remote entry. Pull rechecks local timestamps before applying writes.
3. **Confirm media before recording it.** Media references must come from the
   existing remote manifest, a successful probe or an upload. A locally missing
   file without a confirmed remote reference is warned about and omitted. Upload
   failure prevents publication of that diary's updated JSON and manifest entry.
4. **Publish before cleanup.** Push defers obsolete remote object and media
   deletion, plus persistence of tombstone coverage, until after any required
   manifest commit and verification. Pull writes a diary tombstone before deleting
   local media. Cleanup failures can leave unreferenced remote objects.
5. **Detect manifest races.** Before writing, compare current manifest bytes with
   the original read; afterward, read back the unique `writeToken`. A mismatch
   raises `manifestRace`. Writes remain ordinary `writeObject` calls, not atomic
   compare-and-swap. Detection does not roll back JSON or media already uploaded
   and cannot guarantee that concurrent operations leave all data unchanged.
6. **Respect lock ownership.** The process lock surrounds the remote lease.
   `sync.lock` is plaintext. Lease acquisition probes conditional-create support;
   unsupported or unreliable servers use read/write plus delayed owner readback.
   Renewal and release check the current owner first. Release waits for pending
   renewal; observing a different owner stops renewal and prevents deleting that
   owner's lock.
7. **Track deletion coverage.** Business rows are hard-deleted; tombstones carry
   deletion timestamps and `pushedBackends`. Cleanup waits for coverage of the
   currently configured cloud backends. Restoring an entity removes its old
   tombstone. Startup also purges local tombstones after the retention window,
   currently 90 days.
8. **Report partial outcomes.** Entry failures count toward `failed`;
   `lastSyncTime` advances only without failures or cancellation. Engine exceptions
   emit an aborted `syncEnd` so event-driven sync state can reset.
9. **Collect conversion media from both sources.** Re-ciphering gathers media
   from the manifest and diary JSON passed to `onDecoded`. It does not discover
   objects outside those entries.

## Known limitations

- Lease owner checks and manifest checks are separate requests, leaving race
  windows. Conditional-create fallback is advisory. Losing lease ownership stops
  renewal but does not cancel the operation already running.
- Local timestamp rechecks are not repository-level compare-and-swap. An edit
  after a pulled tombstone is applied can reuse media that the ongoing deletion
  subsequently removes.
- A restored local media file may not upload until its diary changes because an
  up-to-date diary is skipped. Existence probes do not verify remote content or
  its encryption key.
- Remote tombstones accumulate without coordinated expiry. Local tombstone expiry
  or removing a backend from configuration can stop deletion propagation; adding
  that backend again may restore old entries.
- Both cloud backends support object listing, but incremental sync has no general
  orphan-object collector. Interrupted uploads and failed cleanup can leave remote
  objects outside the manifest, which re-ciphering also does not discover.
- Re-ciphering is not transactional: object failures are counted but the target
  manifest is still published. This can leave mixed encodings or keys. The UI
  reports partial failures, and disabling encryption retains the local key on
  failure; neither behavior provides rollback or guarantees successful recovery.

## Tests

Tests under [test/sync](test/sync) cover manifest parsing, conflict resolution,
media ordering, partial outcomes, tombstone coverage, race detection, lease owner
checks and fallback, automatic-sync scheduling, provider scope and key envelopes.
The [test harness](test/sync/sync_test_harness.dart) supplies in-memory stores and
a fake backend; disk-adapter tests use `MemoryFileSystem`.

[Re-cipher tests](test/sync/application/re_cipher_test.dart) supply explicit
`from` and `to` ciphers and cover manifest races, media collection and skipping
already converted objects. They use plaintext remote data and a plaintext target,
so they do not cover a full encrypted rewrite or partial encrypted recovery.
Key-manager tests inject fake KDF and AEAD functions. Native cryptography and real
WebDAV / S3 behavior require separate validation.
