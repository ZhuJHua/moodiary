// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secretKv)
final secretKvProvider = SecretKvFamily._();

final class SecretKvProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  SecretKvProvider._({
    required SecretKvFamily super.from,
    required MoodiarySecureKVs super.argument,
  }) : super(
         retry: null,
         name: r'secretKvProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$secretKvHash();

  @override
  String toString() {
    return r'secretKvProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as MoodiarySecureKVs;
    return secretKv(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SecretKvProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$secretKvHash() => r'85633856dc8532ffe44ed1cdb6efc9d74d75c01e';

final class SecretKvFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, MoodiarySecureKVs> {
  SecretKvFamily._()
    : super(
        retry: null,
        name: r'secretKvProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SecretKvProvider call(MoodiarySecureKVs key) =>
      SecretKvProvider._(argument: key, from: this);

  @override
  String toString() => r'secretKvProvider';
}
