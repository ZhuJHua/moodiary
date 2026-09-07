import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';

String syncTriggerLabel(Translations l10n, SyncTrigger trigger) =>
    switch (trigger) {
      .manual => l10n.sync.triggerManual,
      .change => l10n.sync.triggerChange,
      .close => l10n.sync.triggerClose,
      .poll => l10n.sync.triggerPoll,
      .resume => l10n.sync.triggerResume,
      .network => l10n.sync.triggerNetwork,
    };

String? syncTriggerLabelOf(Translations l10n, Object? name) {
  if (name is! String) return null;
  for (final t in SyncTrigger.values) {
    if (t.name == name) return syncTriggerLabel(l10n, t);
  }
  return null;
}

String? syncHealthTitle(
  Translations l10n,
  SyncHealth health, {
  required String backend,
}) => switch (health) {
  .unreachable => l10n.sync.healthUnreachable(backend: backend),
  .authFailed => l10n.sync.healthAuthFailed,
  .keyConflict => l10n.sync.healthKeyConflict,
  _ => null,
};

String? syncHealthShort(Translations l10n, SyncHealth health) =>
    switch (health) {
      .reachable => l10n.sync.healthConnected,
      .unreachable => l10n.sync.healthUnreachableShort,
      .authFailed => l10n.sync.healthAuthFailedShort,
      .keyConflict => l10n.sync.healthKeyConflictShort,
      _ => null,
    };

String syncElapsedLabel(Translations l10n, Duration elapsed) =>
    elapsed.inMilliseconds < 1000
    ? l10n.sync.elapsedMillis(ms: elapsed.inMilliseconds)
    : l10n.sync.elapsedSeconds(
        seconds: (elapsed.inMilliseconds / 1000).toStringAsFixed(1),
      );
