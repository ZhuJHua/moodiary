// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reminderNotifications)
final reminderNotificationsProvider = ReminderNotificationsProvider._();

final class ReminderNotificationsProvider
    extends
        $FunctionalProvider<
          ReminderNotifications,
          ReminderNotifications,
          ReminderNotifications
        >
    with $Provider<ReminderNotifications> {
  ReminderNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderNotificationsHash();

  @$internal
  @override
  $ProviderElement<ReminderNotifications> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReminderNotifications create(Ref ref) {
    return reminderNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderNotifications value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderNotifications>(value),
    );
  }
}

String _$reminderNotificationsHash() =>
    r'97e53e8b89aa564470871bf8f8c02421f388129f';

@ProviderFor(reminderService)
final reminderServiceProvider = ReminderServiceProvider._();

final class ReminderServiceProvider
    extends
        $FunctionalProvider<ReminderService, ReminderService, ReminderService>
    with $Provider<ReminderService> {
  ReminderServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderServiceHash();

  @$internal
  @override
  $ProviderElement<ReminderService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReminderService create(Ref ref) {
    return reminderService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderService>(value),
    );
  }
}

String _$reminderServiceHash() => r'2e8d1f560033393f6cc8a3f4eda90f831018c039';

@ProviderFor(reminderState)
final reminderStateProvider = ReminderStateProvider._();

final class ReminderStateProvider
    extends $FunctionalProvider<ReminderState, ReminderState, ReminderState>
    with $Provider<ReminderState> {
  ReminderStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderStateHash();

  @$internal
  @override
  $ProviderElement<ReminderState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReminderState create(Ref ref) {
    return reminderState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderState>(value),
    );
  }
}

String _$reminderStateHash() => r'ed57d53e31994039240055ce6d4acc2f6e977427';
