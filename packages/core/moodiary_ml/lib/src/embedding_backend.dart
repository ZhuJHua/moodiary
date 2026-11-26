import 'dart:typed_data';

abstract class EmbeddingBackend {
  bool get loaded;

  Future<void> load(
    String modelPath, {
    required String tokenizerPath,
    required String padToken,
    int contextSize = 512,
  });

  Future<void> unload();

  Future<List<Float32List>> embed(List<String> texts);
}
