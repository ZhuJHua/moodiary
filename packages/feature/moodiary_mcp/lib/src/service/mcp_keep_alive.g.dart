// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_keep_alive.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mcpKeepAlive)
final mcpKeepAliveProvider = McpKeepAliveProvider._();

final class McpKeepAliveProvider
    extends $FunctionalProvider<McpKeepAlive, McpKeepAlive, McpKeepAlive>
    with $Provider<McpKeepAlive> {
  McpKeepAliveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpKeepAliveProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpKeepAliveHash();

  @$internal
  @override
  $ProviderElement<McpKeepAlive> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  McpKeepAlive create(Ref ref) {
    return mcpKeepAlive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpKeepAlive value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpKeepAlive>(value),
    );
  }
}

String _$mcpKeepAliveHash() => r'bbcd1082f8b07b9802cc1a077ed184cc92ad7302';
