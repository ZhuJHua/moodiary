import 'embedding_models.dart';

/// Add every live model catalog here so storage cleanup always uses a whitelist.
Set<String> liveModelFileNames() => {
  for (final model in embeddingModelCatalog) ...[
    model.modelFileName,
    model.tokenizerFileName,
  ],
};

const retiredModelStems = {'qwen3-0.6b-int8'};
