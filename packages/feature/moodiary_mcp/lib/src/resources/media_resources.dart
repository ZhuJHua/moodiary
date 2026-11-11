/// Blob resource of one media file of one diary.
///
/// `read_diary_media` hands audio, video and attachments back as a
/// `resource_link`; this template is what that link points at. The URI carries
/// only a diary id and one media file name, and the reader answers only when
/// that name is exactly one of the diary's media references, so a client cannot
/// use the resource to read arbitrary files.
library;

import 'package:moodiary_data/moodiary_data.dart';

import '../media/diary_media.dart';
import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';

/// Inline cap for one resource read. MCP resource contents are base64 on the
/// wire, and clients keep them around, so a bigger file has to be fetched
/// out of band instead of inflating the session.
const int _maxBlobBytes = 8 * 1024 * 1024;

/// Registers the `moodiary://diary/{id}/media/{name}` resource template.
///
/// [store] is `null` when the composition root did not install one; the default
/// store then reads from the real `AppFiles` media directories. Tests pass a
/// store whose `pathOf` points at a temporary directory.
void registerMediaResources(
  McpRegistry registry, {
  required DiaryRepository diaries,
  DiaryMediaStore? store,
}) {
  final media = store ?? DiaryMediaStore();
  registry.addResourceTemplate(
    const McpResourceTemplate(
      uriTemplate: 'moodiary://diary/{id}/media/{name}',
      name: 'diary-media',
      title: 'One media file of a diary',
      description:
          'The bytes of one media file a diary references, served as a blob '
          'with the sniffed MIME type. {name} is exactly a file name from '
          'list_diary_media; unknown diaries, names the diary does not '
          'reference and files missing from this device are a resource not '
          'found error. Files above 8 MB are refused.',
    ),
    (call, uri, variables) async {
      final id = variables['id'] ?? '';
      final name = variables['name'] ?? '';
      final diary = await diaries.getDiaryByBusinessId(id);
      if (diary == null || !diary.show) {
        throw JsonRpcException(
          JsonRpcCode.resourceNotFound,
          'no diary with id="$id"',
        );
      }
      // Membership in the diary's media lists is the allowlist; the safety
      // guard additionally rejects `..`, `/` and absolute paths that arrive
      // percent-encoded and are decoded by the template matcher.
      final kind = isSafeMediaName(name) ? diary.mediaKindOf(name) : null;
      if (kind == null) {
        throw JsonRpcException(
          JsonRpcCode.resourceNotFound,
          'diary id="$id" has no media named "$name"',
        );
      }
      final stat = await media.stat(kind, name);
      if (!stat.exists) {
        throw JsonRpcException(
          JsonRpcCode.resourceNotFound,
          'media "$name" of diary id="$id" is not on this device',
        );
      }
      if (stat.bytes > _maxBlobBytes) {
        throw JsonRpcException(
          JsonRpcCode.internalError,
          'media "$name" is ${(stat.bytes / (1024 * 1024)).toStringAsFixed(1)} '
          'MB, more than the ${_maxBlobBytes ~/ (1024 * 1024)} MB resource '
          'limit; read it in the app instead',
        );
      }
      final bytes = await media.read(kind, name);
      if (bytes == null) {
        throw JsonRpcException(
          JsonRpcCode.resourceNotFound,
          'media "$name" of diary id="$id" disappeared while it was read',
        );
      }
      return McpResourceReadResult.blob(uri, bytes, mimeType: stat.mimeType);
    },
  );
}
