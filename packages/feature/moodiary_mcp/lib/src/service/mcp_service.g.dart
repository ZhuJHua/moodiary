// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(McpServerController)
final mcpServerStateProvider = McpServerControllerProvider._();

final class McpServerControllerProvider
    extends $NotifierProvider<McpServerController, McpServerState> {
  McpServerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpServerStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpServerControllerHash();

  @$internal
  @override
  McpServerController create() => McpServerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpServerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpServerState>(value),
    );
  }
}

String _$mcpServerControllerHash() =>
    r'6dd62378c3d32bd1407a5b1bd4e1cea8503a2928';

abstract class _$McpServerController extends $Notifier<McpServerState> {
  McpServerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<McpServerState, McpServerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<McpServerState, McpServerState>,
              McpServerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(mcpService)
final mcpServiceProvider = McpServiceProvider._();

final class McpServiceProvider
    extends $FunctionalProvider<McpService, McpService, McpService>
    with $Provider<McpService> {
  McpServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpServiceHash();

  @$internal
  @override
  $ProviderElement<McpService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  McpService create(Ref ref) {
    return mcpService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpService>(value),
    );
  }
}

String _$mcpServiceHash() => r'e17ca7e54bfa355fdb706edf59633ca610806b0f';
