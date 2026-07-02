import 'dart:async';

import 'package:genui/genui.dart' as genui;
import 'package:moodiary_assistant/src/data/assistant_defs.dart';

const String assistantGenUiCatalogId = 'cn.yooss.moodiary.assistant';

const String toolPermissionCardComponent = 'ToolPermissionCard';

const String toolPermissionStatusPath = '/status';

const String toolPermissionActionAllowOnce = 'allowOnce';
const String toolPermissionActionAllowAlways = 'allowAlways';
const String toolPermissionActionDeny = 'deny';

enum ToolPermissionStatus {
  pending('pending'),

  allowedOnce('allowedOnce'),

  allowedAlways('allowedAlways'),

  denied('denied'),

  canceled('canceled');

  final String id;

  const ToolPermissionStatus(this.id);

  static ToolPermissionStatus fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => pending);
}

enum ToolPermissionDecision { allowOnce, allowAlways, deny, canceled }

class ToolPermissionCoordinator {
  ToolPermissionCoordinator({
    required genui.Catalog catalog,
    required this.onCardCreated,
  }) : surfaces = genui.SurfaceController(catalogs: [catalog]);

  final genui.SurfaceController surfaces;

  final void Function(String surfaceId) onCardCreated;

  final Map<String, Completer<ToolPermissionDecision>> _pending = {};

  int _surfaceSeq = 0;

  Future<ToolPermissionDecision> request(AssistantTool tool) {
    final surfaceId = 'toolPermission#${_surfaceSeq++}';
    surfaces.handleMessage(
      genui.CreateSurface(
        surfaceId: surfaceId,
        catalogId: assistantGenUiCatalogId,
      ),
    );
    surfaces.handleMessage(
      genui.UpdateComponents(
        surfaceId: surfaceId,
        components: [
          genui.Component(
            id: 'root',
            type: toolPermissionCardComponent,
            properties: {
              'tool': tool.id,
              'status': {'path': toolPermissionStatusPath},
            },
          ),
        ],
      ),
    );
    _setStatus(surfaceId, ToolPermissionStatus.pending);

    final completer = Completer<ToolPermissionDecision>();
    _pending[surfaceId] = completer;
    onCardCreated(surfaceId);
    return completer.future;
  }

  void handleAction(String surfaceId, String actionName) {
    final completer = _pending.remove(surfaceId);
    if (completer == null) return;
    final (decision, status) = switch (actionName) {
      toolPermissionActionAllowOnce => (
        ToolPermissionDecision.allowOnce,
        ToolPermissionStatus.allowedOnce,
      ),
      toolPermissionActionAllowAlways => (
        ToolPermissionDecision.allowAlways,
        ToolPermissionStatus.allowedAlways,
      ),
      _ => (ToolPermissionDecision.deny, ToolPermissionStatus.denied),
    };
    _setStatus(surfaceId, status);
    completer.complete(decision);
  }

  void cancelPending() {
    for (final entry in _pending.entries) {
      _setStatus(entry.key, ToolPermissionStatus.canceled);
      entry.value.complete(ToolPermissionDecision.canceled);
    }
    _pending.clear();
  }

  void reset() {
    cancelPending();
    for (final id in surfaces.activeSurfaceIds.toList()) {
      surfaces.handleMessage(genui.DeleteSurface(surfaceId: id));
    }
  }

  void dispose() {
    cancelPending();
    surfaces.dispose();
  }

  void _setStatus(String surfaceId, ToolPermissionStatus status) {
    surfaces.handleMessage(
      genui.UpdateDataModel(
        surfaceId: surfaceId,
        path: genui.DataPath(toolPermissionStatusPath),
        value: status.id,
      ),
    );
  }
}
