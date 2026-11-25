// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(filePicker)
final filePickerProvider = FilePickerProvider._();

final class FilePickerProvider
    extends $FunctionalProvider<IFilePicker, IFilePicker, IFilePicker>
    with $Provider<IFilePicker> {
  FilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filePickerHash();

  @$internal
  @override
  $ProviderElement<IFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IFilePicker create(Ref ref) {
    return filePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IFilePicker>(value),
    );
  }
}

String _$filePickerHash() => r'7690b6847c798d3e03c03e32ea08b40f021c8bc9';

@ProviderFor(heifDecoder)
final heifDecoderProvider = HeifDecoderProvider._();

final class HeifDecoderProvider
    extends $FunctionalProvider<IHeifDecoder, IHeifDecoder, IHeifDecoder>
    with $Provider<IHeifDecoder> {
  HeifDecoderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heifDecoderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heifDecoderHash();

  @$internal
  @override
  $ProviderElement<IHeifDecoder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IHeifDecoder create(Ref ref) {
    return heifDecoder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IHeifDecoder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IHeifDecoder>(value),
    );
  }
}

String _$heifDecoderHash() => r'02b16d30160ad83b805086bf167d4629e2427152';
