import 'dart:async';

import 'package:genui/genui.dart' as genui;
import 'package:moodiary/core/values/assistant.dart';

/// 助手 GenUI 目录 id（`Catalog.catalogId` / `CreateSurface.catalogId`，反域名规范）。
const String assistantGenUiCatalogId = 'cn.yooss.moodiary.assistant';

/// 权限卡片组件名（A2UI `Component.component` 判别值）。
const String toolPermissionCardComponent = 'ToolPermissionCard';

/// 卡片状态在 surface 数据模型中的绑定路径。
const String toolPermissionStatusPath = '/status';

/// 卡片三个按钮的动作名（A2UI `UserActionEvent.name`）。
const String toolPermissionActionAllowOnce = 'allowOnce';
const String toolPermissionActionAllowAlways = 'allowAlways';
const String toolPermissionActionDeny = 'deny';

/// 权限卡片的展示状态；[id] 写入数据模型，卡片经 `{'path': '/status'}` 绑定订阅。
enum ToolPermissionStatus {
  pending('pending'),

  allowedOnce('allowedOnce'),

  allowedAlways('allowedAlways'),

  denied('denied'),

  /// 申请未决时回复被停止 / 会话被切换，按钮失效。
  canceled('canceled');

  final String id;

  const ToolPermissionStatus(this.id);

  static ToolPermissionStatus fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => pending);
}

/// 用户对一次权限申请的决定；「始终允许」的持久化由调用方负责。
enum ToolPermissionDecision { allowOnce, allowAlways, deny, canceled }

/// 工具权限的 GenUI 协调器：把权限申请变成聊天流里的一张 A2UI 卡片。
///
/// 申请时本地构造 `CreateSurface` + `UpdateComponents` 喂给 [surfaces]，经
/// [onCardCreated] 通知页面插入聊天项；用户点按钮后只发 `UpdateDataModel`
/// 改写 `/status`，卡片原地更新为结果态而不被移除。不做 KV 授权策略。
class ToolPermissionCoordinator {
  ToolPermissionCoordinator({
    required genui.Catalog catalog,
    required this.onCardCreated,
  }) : surfaces = genui.SurfaceController(catalogs: [catalog]);

  /// surface 宿主；页面用 [genui.SurfaceController.contextFor] 渲染卡片。
  final genui.SurfaceController surfaces;

  /// 新卡片建好后通知页面把对应聊天项插入消息列表。
  final void Function(String surfaceId) onCardCreated;

  final Map<String, Completer<ToolPermissionDecision>> _pending = {};

  int _surfaceSeq = 0;

  /// 为 [tool] 创建一张 pending 卡片并等待用户决定。
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

  /// 卡片按钮动作（经 ActionDelegate 转入）。已决 / 迟到的动作直接忽略，
  /// 未知动作名按拒绝处理。
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

  /// 取消全部在途申请：卡片置「已取消」，等待方收到 [ToolPermissionDecision.canceled]。
  void cancelPending() {
    for (final entry in _pending.entries) {
      _setStatus(entry.key, ToolPermissionStatus.canceled);
      entry.value.complete(ToolPermissionDecision.canceled);
    }
    _pending.clear();
  }

  /// 清空 / 切换会话时调用：取消在途申请并删掉全部 surface
  /// （对应聊天项由页面一并移除）。
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
