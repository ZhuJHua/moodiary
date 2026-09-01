### KV —— MMKV，且是同步的

2.8.0 起本地 KV 落在 **MMKV**（`mmkv: 2.4.1`），后端换掉之后接口跟着变了形：

**`IKVStorage.set` / `remove` / `clear` 返回 `void`，不是 `Future`。** MMKV 是 mmap +
增量 append，没有平台通道往返可等，落盘交给内核。由此 `KVNotifier` 的监听者在赋值当帧
就收到通知（旧后端要等一个平台往返，开关类 UI 肉眼可见地滞后）。`init` 仍是异步的
（要等平台侧给出 rootDir），`ISecureKVStorage` 也保持全异步——那边是真的钥匙串调用。

后端实现在 `moodiary_storage/lib/src/kv/mmkv.dart`，四个不报错的点：

1. **「没有值」得靠 `containsKey` 判**：`decodeBool` / `decodeInt` 一类不返回 null，
   取不到就给 defaultValue，直接读会把「没设过」和「设成了 false / 0」混为一谈。
2. **MMKV 没有字符串数组类型**：`List<String>` 存成 JSON 文本。解不出来当作没有值
   （回退 defaultValue），不让一格坏数据把整条读取路径带崩。
3. **mmapID（`moodiary`）与 rootDir（`applicationSupport/mmkv`）改了就等于弃数据。**
   rootDir 是显式钉的：MMKV 默认落 `${Documents}/mmkv`，而 iOS 的 Documents 用户在
   「文件」App 里看得见、还会进 iCloud 备份。
4. **加键只能用那五种类型**（int / bool / double / String / List&lt;String&gt;）：类型分派是
   `switch (T)` 加一个抛异常的 default，多加一种不会有编译错误，只会在运行时炸。
   `moodiary_storage/test/kv_migration_test.dart` 里有条闸门守着。

**2.8.0 的一次性搬迁整个在 `MmkvKVStorage._migrateFromPrefsOnce` 里**，一轮四步：
读旧仓库 → 机密进 SecureKV（`SecretKVMigration`）→ 明文进 MMKV → `clearStore()` 删掉旧仓库
→ 置 `__migrated_from_prefs`。

- **不能挂进 `VersionMigrator`**：判版本用的 `appVersion` 自己就存在 KV 里，搬完之前读不到，
  挂过去会把老用户误判成全新安装。
- **整轮共用一个标记，中途失败就整轮重来**，所以**机密必须排在明文之前** ——
  写钥匙串是唯一可能整体失败的一步，让它在任何东西落地之前失败，重试才干净；反过来
  先搬明文的话，重试会拿旧仓库的值覆盖掉用户在这中间改过的配置。机密失败时
  `SecretKVMigration` 一律上抛，调用方亮 `legacyMigrationPending` 并整轮跳过 —— 吞掉的话
  应用锁会变成「开着但没有密码」，用户直接进不去。
- **搬完直接删旧仓库**：那里躺着明文 PIN / API Key / WebDAV 密码。两个平台都不允许降级
  安装、卸载重装又等于清数据，没有回滚路径要照顾。`resetAllData` 仍调一次 `clearStore()`，
  兜住「重置发生在搬迁完成之前」；`MmkvKVStorage.clear()` 要把标记补回去，否则重置后的
  那次启动会重跑搬迁。
- `shared_preferences` 依赖只为这次搬迁留着，窗口过后连同 `legacy_pref.dart` 一起删。

**机密不进明文 KV**：应用锁 PIN（`password`）与两个第三方 API Key（`qweatherKey` /
`tiandituKey`）2.8.0 起归 `MoodiarySecureKVs`，已从 `MoodiaryKVs` 删除。它们在 2.7.3 是明文
写进旧仓库的，而枚举驱动的明文那趟不再经手它们，所以 `LegacyPrefsKVSource` 有一份
**字面量** `_legacyKeys`（读的 allowList 与清除共用）。别改成从枚举推导 —— 那只是「旧名字
碰巧等于新名字」，给枚举改个名就静默地少读一个键、少清一个键，不报错。闸门在
`secret_migration_test.dart`。

取值分两种：事件回调里直接 `await MoodiarySecureKVs.xxx.get()`；widget 里走
`secretKvProvider(key)`（moodiary_data），**写完必须 `ref.invalidate`** —— SecureKV 没有
`KVNotifier` 那套通知，不 invalidate 界面不刷新。

**PIN 别直接读写 `MoodiarySecureKVs.password`，走 `AppLockPin`**：存的是 Argon2id 的
PHC 串（`rust.Argon2.hash`，盐随机且写在串里），不是原文。钥匙串已经加密了它，多这一层
是因为加密可逆而哈希不可逆 —— 四位 PIN 挡不住爆破，真正防的是**PIN 复用**（应用锁 PIN
常常就是手机解锁 PIN）。原语可注入（`AppLockPin.hasher` / `verifier`），宿主单测没有
Rust FFI，同 `SyncKeyManager` 的做法。

**「应用锁开没开」= 有没有凭据**（`AppLockPin.enabled`），没有独立的 `lock` 开关。
那个开关早先在 MMKV 而凭据在钥匙串，两边存活条件不同：MMKV 是普通文件、恢复备份照样
带过来，钥匙串的密文却要 Keystore 私钥来解，而那把钥匙不进备份。一旦分叉就是「锁开着
但没有密码」——校验对任何输入都 false，用户永久进不去，只能卸载重装。现在读不出凭据
就是没开锁（fail-open）：应用锁本就不保护静态数据，能拿到 App 文件的人直接读 Isar 就行。
`enabled` 是进程内的 `ValueListenable`（路由与生命周期回调都是同步的，够不着异步的
SecureKV），由 `main.dart` 里的 `AppLockPin.load()` 装载，不落盘所以不会再分叉。
**因此搬迁只在旧 `lock` 为真时才搬 PIN** —— 否则等于替关着锁的用户把锁打开。

**搬迁把 PIN 原样挪过去，哈希推迟到 `verify` 头一次比对时就地做**（`isHashed` 分辨）。
不在搬迁里哈希是有原因的：那会让 KV 初始化依赖 Rust 桥先就绪，等于让一次性迁移的需求
永久钉死 `main.dart` 的启动顺序，而那个顺序只有注释守着 —— 谁调换一下，`Argon2.hash`
抛 `StateError`，整轮搬迁被静默跳过、每次启动都一样。代价只是 PIN 在钥匙串里明文待到
下次解锁，而开着锁的用户下一次启动就是解锁。

