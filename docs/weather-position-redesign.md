# 天气与位置重做设计（2.8.0）

## 0. 现状与问题

现状链路（`packages/feature_base/moodiary_editor/lib/src/data/`）：

- `GeoRepository.getGeo()`：**先**查 `qweatherApiHost` + `qweatherKey`，缺一即 `GeoFailure.notConfigured` 直接返回 → 再 geolocator 取坐标 → 和风 `/geo/v2/city/lookup` 反查 → `DiaryPosition(lat, lon, name: "adm2 name")`
- `WeatherRepository.getWeather()`：同样先查 key/host → 和风 `/v7/weather/now` → `DiaryWeather(icon, temp, text)`
- 属性头（webview `EditorMetaHeader.vue`）点天气 / 位置 → `post('fetchWeather')` / `post('fetchPosition')` → 回跳 Flutter 打接口

四个问题：

1. **定位被和风绑架**。取坐标只需要 geolocator，一个 key 都不用；和风只负责「坐标 → 城市名」这一步。现在 key 没配就连坐标都不取（`notConfigured` 判定排在权限检查之前），等于把一个不需要注册第三方账号的能力做成了要注册。足迹地图的天地图 tk 是**第三条独立的线**——只管把已有坐标画到底图上，与取坐标、取地名都不相干。
2. **天气只有一种口味**：实时、必带温度。只想写「今天下雨」的人被迫拉一次实时接口。
3. **地名粒度太粗**：`adm2 + name` = 「杭州市 西湖区」。日记里真正想记的是「公司」「家」「奶奶家」。
4. **失败文案会说谎**：没配和风时点位置，只会看到「尚未配置和风天气」。
5. **天气与位置纠缠在一起**。`EditController.fetchWeather()` 在日记还没有位置时会调
   `fetchPosition()`，而后者的 `changePosition()` 是**直接写进日记的** —— 点「获取天气」
   会顺手把位置也填上，用户没要求过。同一段代码还有第二层问题：天气是拿**日记里已有的**
   `position` 去查的，那个位置可能是手选的「家」，而人现在在公司。

## 1. 目标 / 非目标

目标：

- 天气可手动选（图标 + 名称，**无温度**），码值仍与和风对齐，图标字体零改动
- 位置可预设（「公司」「家」），写日记时按当前坐标就近自动命中
- 和风降级为「可选增强」：没配也能记天气、记位置
- 天气与位置各走各的：取天气不再顺手写位置，两个自动开关互相独立

非目标：

- 不换天气数据源，不做天气预报
- 不做地理围栏 / 后台唤醒（只在新建日记那一刻取一次）
- 不动足迹地图（天地图那条线原样不变）

## 1.5 不变量：天气与位置是「写的时候」的快照

**日记里的天气记的是落笔那一刻的事实；位置是对常用地点的引用（同分类）——地点改名 /
挪坐标全体日记跟着变，自动填充只在新建时跑一次，之后只有用户手动改才改。**
这条约束在下面每一处设计里都成立，改动时先对照它：

| 路径 | 何时跑 | 是否覆盖已有值 |
|---|---|---|
| `autoWeather` / `autoPosition` 自动填 | **仅新建日记**首次落库 | 否（`weather != null` / `position != null` 就跳过） |
| 属性头点天气 / 点位置 | 用户主动点 | 是——这就是「手动改」 |
| 面板里选某个天气 / 某个常用地点 | 用户主动选 | 是 |
| 重新打开、编辑正文、自动保存 | —— | **永不触发取数** |

所以给一篇三年前的日记补上今天的天气是错的，现有代码的 `widget.diaryId != null` 守卫
就是这条的实现，两个自动开关都照抄。

反过来，用户**主动**点「自动获取」时用的是**此刻**的坐标——他要的就是「现在」，
不是日记里那个可能是手选的旧 `position`（见 3.0 第二条）。

## 2. 天气：手动选择

### 2.1 码表

16 个（4×4，与心情面板同一栅格）。全部取自和风官方码，图标沿用已内置的 qweather-icons 字体（web 侧 woff2 + Flutter 侧 `mui/qweather_icon.dart`，两边都已覆盖这些码，**无需新增资源**）。

| 码 | 名称 | 码 | 名称 | 码 | 名称 | 码 | 名称 |
|---|---|---|---|---|---|---|---|
| 100 | 晴 | 101 | 多云 | 104 | 阴 | 300 | 阵雨 |
| 305 | 小雨 | 306 | 中雨 | 307 | 大雨 | 310 | 暴雨 |
| 302 | 雷阵雨 | 400 | 小雪 | 402 | 大雪 | 404 | 雨夹雪 |
| 501 | 雾 | 502 | 霾 | 900 | 热 | 901 | 冷 |

取舍：和风 400+ 个码里，「少云 / 晴间多云」「小到中雨 / 中到大雨」是预报语义，人手选时只会增加犹豫；夜间变体（150/151…）在手选场景自证多余。上面 16 个覆盖日常记录的全部意图。

> 码名对照的权威来源是 qweather-icons 包自带的别名表（`font/qweather-icons.json`，码与英文名共享码点），不是猜的偏移量。

### 2.2 模型

`DiaryWeather.temp` 由 `required String` 改为 `String?`。

- DB 列 `weather_temp TEXT` **本来就可空**，零迁移
- 2.8.0 已发布：其 `weather_temp` 列本来可空，JSON 里 `temp` 缺省解成 null，无兼容包袱
- 温度展示点 6 处要处理空值：`timeline_tile.dart:271`、`feed_tile.dart:606`、`diary_page.dart:783`（metaJson）与 `:424`（toast）、`markdown_writer.dart:100/120`、`export_doc.dart:65`、`image_card/card.dart:101`

**统一收口**：在 `moodiary_components` 给 `DiaryWeather` 加一个 `displayText` 扩展（`temp` 空则只回 `text`），6 处调用点全部改走它——否则漏一处就是「晴 °C」。

### 2.3 交互

点天气 → **页内面板**（不回跳 Flutter），与心情面板复用同一个 `PopupMenu #panel`：

- 4×4 天气网格，格子 = qweather 字形 + 中文名；选中格用 primary 高亮（心情面板用语义色，天气没有语义色，用主题色）
- 面板底部一条操作行：`⟳ 自动获取`（**仅和风已配置时出现**）+ `✕ 清除`（仅已有天气时出现）
- 选中即 `post('changeWeather', { code })`；Flutter 侧按码查本地化名，写入 `DiaryWeather(icon: code, text: label, temp: null)`
- 「自动获取」= 现有 `fetchWeather` 链路，成功后写入带温度的那份

文案仍由 Flutter 解析好下发（web 侧零 i18n，沿用现契约）。

### 2.4 「保存时自动获取天气」

开关保留，但**行为收窄**：只取天气，不再顺手写位置（见 3.0）。现有守卫
`current.weather != null` 保证手选过就不覆盖，这一条不变。

## 3. 位置：先解耦，再预设

### 3.0 先把天气和位置解绑

`fetchWeather` 不再经过 `DiaryPosition`，改为：

```
fetchWeather:  LocationService.currentCoordinates()  →  和风 /v7/weather/now  →  只写 weather
fetchPosition: LocationService.currentCoordinates()  →  解析名字（见 3.3）    →  只写 position
```

同一个 `LocationService` 底座，两条链路各自消费，互不写对方的字段。顺带修掉两件事：

- 点「获取天气」不再偷偷把位置填上
- 天气按**此刻的坐标**查，不再按日记里那个可能是手选的旧 `position` 查

### 3.1 拆成三件互不相干的事

| 能力 | 依赖 | 拿不到时 |
|---|---|---|
| 取坐标 | geolocator（权限 + 系统定位服务） | 权限 / 服务文案 |
| 坐标 → 名字 | 和风反查（主力）+ 预设地点就近匹配（命中则优先） | 都没有就只存坐标 |
| 坐标 → 地图 | 天地图 tk（**仅足迹地图页**） | 退回 OSM 底图（现状已如此） |

落到代码：

- 新增 `LocationService`（`packages/core/moodiary_platform`）：`Future<LocationResult> currentCoordinates()`，只包 geolocator，返回坐标或 `LocationFailure { permissionDenied, permissionDeniedForever, serviceOff, unavailable }`。geolocator 依赖从 `moodiary_editor` 下移到 `moodiary_platform`——core 层是它正确的家（该包已在管生物识别 / 网络状态 / 应用目录）
- `GeoRepository` 瘦身为 `ReverseGeocoder`：`Future<String?> lookup(LatLng)`，未配置返回 `null`（**不是** failure）
- `GeoFailure.notConfigured` 从位置链路删除；天气「自动获取」那条仍保留它

### 3.2 数据库：`diaries.place_id` 引用，新增一张 `places`（2026-09-05 改为引用）

**日记不再存位置快照。** 原先的 `latitude / longitude / place_name` 三列换成一列
`place_id TEXT`，语义与 `category_id` 完全一样：引用常用地点的 id，不是快照。
理由：快照让「编辑常用地点」毫无意义（改名后旧日记还是老名字），而用户要的就是
改一处全体生效。代价是没有「裸坐标」这种位置——**每个位置都必须是一个常用地点**，
和风反查出来的行政区名也进 `places`（同名复用，见 3.3）。

新表 `places`（`base_tables.drift`，与 `categories` 平级、零外键）：

```sql
CREATE TABLE places (
  id            TEXT NOT NULL PRIMARY KEY,
  name          TEXT NOT NULL,
  latitude      REAL NOT NULL,
  longitude     REAL NOT NULL,
  icon          TEXT,               -- lucide 图标名，null = map-pin
  last_modified INTEGER NOT NULL
) AS PlaceRow;
```

**不建任何索引**：全表撑死几十行，全量读进内存算 Haversine 比什么索引都快。
顺序不进表，走 KV `placeOrder<List<String>>`（同 `categoryOrder`）。

删除守卫同分类：`deleteAPlace` 先查 `diaries WHERE place_id = ?`，有引用返回 false、
管理页 toast「仍有日记使用该地点」。「N 篇日记」按 `place_id` 分组数（`diaryCountByPlace`）。
足迹地图按地点打点：同一地点的日记挂在一个图钉下（角标篇数，点开先列后选）。

#### 迁移：v1（已发布的 2.8.0）→ v2，本仓第一个 `onUpgrade`

`database.dart` 现在 `schemaVersion == 1`，且 `MigrationStrategy` **只有 `onCreate`、
没有 `onUpgrade`**。所以要：

1. `schemaVersion` 1 → 2
2. 新增 `onUpgrade` 分支（`from < 2 → m.createTable(places)`）——建立本仓第一档
3. `base_tables.drift` **追加**建表语句，不动已发布的 v1 语句

全新安装走 `onCreate` 的 `createAll()` 直接带上。**v1 是已发布的 2.8.0**（日记带
`latitude / longitude / place_name`、没有 `places`），2.8.1 的 `onUpgrade` 必须一篇不丢：

```
createTable(places) → addColumn(diaries.place_id)
→ 快照按地名归并成地点（同名一个、坐标取最近一篇；没地名的拿「30.2841, 120.1552」当名字）
→ UPDATE diaries.place_id → DROP COLUMN latitude / longitude / place_name
```

地点 id 由地名派生（`Place.forName` = uuid v5），两台设备各自升级得到**同一批 id**，
同步时合并成一个而不是各留一份。`db_migration_test` 用「把新库降回 v1 形状」的办法复现
已发布的形状，不手抄旧 DDL。

**2.7.x（Isar）直升 2.8.1** 走 `EngineMigrationService`，同一套归并规则（派生 id、坐标名
兜底）；只有坐标解析失败的才丢定位（`positionDropped`）。

配套：`Place`（moodiary_models，纯 Freezed）+ `PlaceRepository`（moodiary_data，
`@lazySingleton`，事件流 `placeEvents`，整体仿 `CategoryRepository`）。

### 3.3 名字从哪来：两级来源，不是二选一（2026-09-05 拍板）

| 来源 | 特点 | 前提 |
|---|---|---|
| 常用地点（预设） | 名字有信息量（「公司」）、只在半径内有效 | 定位权限 + 至少一个预设 |
| 和风反查（API） | 到处都有名字、但只到「杭州市 西湖区」 | 定位权限 + 和风 key/host |

```
命中 = places 中满足 distance(当前坐标, p) <= Place.matchRadius(200 m) 的、距离最小的那个

autoNearestPlace 开 && 有命中     → placeId = 命中的地点
否则 autoPosition 开 && 和风已配  → 和风反查行政区名 → 同名地点复用 / 没有就建一个 → placeId
否则                              → 不写
```

反查出来的「杭州市 西湖区」**也是一个常用地点**（`getPlaceByName` 同名复用，坐标取第一次
反查时的），日记只认地点 id、没有别的落点；它出现在管理页里，用户可以改名成「家」。

两条是**互相独立的开关**（各受自己的前提闸住），不是一条链上的自动兜底；都开时
预设优先——精确的私人名字永远赢过粗糙的行政区名，只有这一种合理顺序，不给用户选。
代码上也分开：`GeoRepository.getGeo` **只做和风那一级**（反查不到就是失败、不落裸
坐标），预设匹配是页面层拿 `PlaceMatching.matchAt` 做的，两者互不知道对方。

Haversine 自己算（`distanceMeters`，data 层不为七行函数引 latlong2）。命中半径是
**全局常量 `Place.matchRadius` = 200 m**，不进表、不给用户调（2026-09-05：「对用户
意义不大」）。

日记只存 `placeId`，坐标随地点走——足迹地图上同一地点的日记落在同一个图钉下，
这是引用语义的直接后果，也是用户接受的。

### 3.4 有坐标、没名字

自动链与「自动获取」都不再产出裸坐标（见 3.3）。`_metaJson` 里「空 name 显示格式化
坐标」的分支保留作防御——`DiaryPosition.name` 仍是可空语义，旧数据不该被当成
「没有位置」抹掉。

### 3.5 交互：点即弹面板（2026-09-05 拍板，与心情 / 天气一致）

```
点 位置图标（无论有没有位置）
  ┌────────────────────────────┐
  │ ⌖  自动获取                 │  ← 仅和风已配置时渲染（= 定位 + 和风反查）
  ├────────────────────────────┤
  │ 🏢 公司             120 m  │  ← 面板打开那一刻取一次定位，按距离升序
  │ 🏠 家               4.2 km │     没定位到就是用户手排顺序、不带距离
  ├────────────────────────────┤
  │ ＋ 新建常用地点             │  ← 常驻；本会话定位过就把坐标带进表单
  │ ⚙  管理常用地点             │
  │ ✕  清除                    │  ← 仅已有位置
  └────────────────────────────┘
```

- 面板打开 → web `post('locateForPlaces')` → 宿主 `LocationService.current()`
  （last-known 优先）→ 记入页面级 `_fix` → 重发 meta。距离**基于此刻的定位**，不是
  日记里那个可能是三年前的 `position`。首次打开会触发一次定位权限弹窗——用户正在
  表达「我要选位置」，这是对的时机。
- 「自动获取」只走和风，与天气面板同名同义；预设就在同一面板里，让用户自己点。
- 点某个预设 = `placeId` 指向它。
- 「新建常用地点」开新增表单（本会话定位过就带上 `_fix`，否则表单确认时再定位），
  存完顺手选中它。

### 3.6 三个自动开关

设置 → 日记 → **天气与位置**：

| 开关 | KV | 默认 | 触发时机 | 需要 |
|---|---|---|---|---|
| 新建日记时自动获取天气 | `autoWeather` | 关 | 新建日记首次落库 | 定位权限 + **和风** |
| 新建日记时自动获取位置 | `autoPosition` | 关 | 同上 | 定位权限 + **和风**（反查行政区名） |
| 新建日记时自动选择就近地点 | `autoNearestPlace` | 关 | 同上 | 定位权限 |

**和风闸门**：前两条在和风没配好（host 或 key 缺一）时开关灰掉显示关、副标题换成
「需先在第三方服务中配置和风天气」、整行点击跳到第三方服务页。KV 值保留，配好即
恢复；被清掉 key 之后等价于关（`_maybeAutoFill` 里按 `qweatherCredentials() != null`
判，不为它们要定位权限）。第三条只要定位权限。

三条合成一个 `_maybeAutoFill`，共用守卫（抄自旧的 `_maybeAutoWeather`）：

- 只认**新建**（`widget.diaryId == null`）——给三年前的日记补上今天的天气或位置是错的
- 已有值就不覆盖（`weather != null` / `position != null`）
- 每次会话只试一次（`_autoFillTried`），失败也不重试
- **静默失败**，不弹提示：用户没主动点，不该被打断书写
- **只打一发 GPS**：一次 `currentCoordinates()` 的结果分别喂给三条

### 3.7 管理页 = 分类管理的同一套骨架

**入口在「我的」页的管理区，紧挨分类管理、带数量角标**（2026-09-05 从设置 → 日记
里搬出来：藏太深，且与其它管理项不在一处）。属性头位置面板里的「管理常用地点」是
第二入口。

`PlaceManagerPage` 放在 `packages/feature/moodiary_diary/lib/src/presentation/place/`，
就在 `category/` 隔壁。**不抽公共页面组件**——两者的字段差异比骨架还多，抽出来的参数会比
重复的代码长。但视觉与交互 1:1 对齐，并把四段真正逐字相同的代码提到同包共享文件
（`presentation/widget/manager_parts.dart`）：

| 部件 | 复用 | 说明 |
|---|---|---|
| AppBar + FAB | 逐字相同 | 只有标题与图标不同 |
| 搜索框 | **抽 `ManagerSearchField`** | 只有 hintText 不同 |
| 空态 / 无匹配 | **抽 `ManagerEmpty` / `ManagerNoMatch`** | 图标 + 两句文案不同 |
| 拖拽排序 | **抽 `managerProxyDecorator`** | scale 1.03 + 阴影那段整块可搬 |
| 瓦片外壳 | 逐字相同 | `Card.filled`(radius 16, `surfaceContainerLow`, margin 纵 4) + `ListTile`（leading 42×42 / radius 13 方块 + 21px 图标）+ `MMenuButton`(⋮, padding 12) + `ReorderableDragStartListener`(grip) |
| 编辑弹窗 | 骨架相同 | 同一个 `MAlert.show` + `onIntercept` 校验空名；字段不同 |
| 瓦片内容 | **不同** | 见下 |
| 删除 | **不同** | 见下 |

**顺序存 KV，不给 `Place` 加 `sortOrder`** —— 与 `categoryOrder` 同一条理由（同步是整对象
LWW，排序字段会互相踩）。新 KV `placeOrder<List<String>>`。

#### 瓦片内容的两处不同

| | 分类 | 位置 |
|---|---|---|
| 方块图标 | 固定 `folder` | 用户选的地点图标（8 个 lucide） |
| 方块底色 | 用户从 `kCategoryPalette` 选 | **按 id 自动取色**，复用现成的 `categoryColorOf(colorValue: null, id: place.id)` |
| 副标题 | 「12 篇日记」/「暂无日记」 | 「12 篇日记 · 半径 200 m」 |

地点不给用户选颜色：图标已经承担了辨识，再加一个调色板等于让人为一条设置做两次选择。
按 id 自动取色白拿视觉一致性，还省掉一个字段和一份同步语义。

「N 篇日记」按**坐标落在半径内**统计（复用 `getDiariesWithPosition()`，同 `MapPage` 那一趟），
不按名字匹配——名字是快照，改名就断。

#### 删除：同分类，有引用就拦

`deleteAPlace` 先查 `diaries.place_id`，有日记引用返回 false，管理页 toast
「仍有日记使用该地点，删除失败」。远端墓碑（别的设备删的）照常应用——被引用的日记
只是暂时没了名字，这与分类今天的行为一致。

#### 编辑弹窗

`showPlaceEditor`，`MAlert.show` 承载（340 宽 / `surfaceContainerHigh` / radius 24 /
padding 16-20-16-16，内容区本身可滚），字段自上而下：

1. 名称 `TextField`（filled `surfaceContainerHighest`, radius 12, isDense）
2. 图标：8 个 36×36 圆角方块（对位分类的 28px 色环）
3. 坐标**不展示、不给按钮**：点确认那一刻才高精度定位，确认键转圈等它
   （`MAction.onSubmit`）；失败 toast 提示、弹窗留住，再点确认重试。编辑时多一个
   「更新为当前位置」开关，打开后确认时同样重新定位并覆盖坐标
4. 与已有地点靠太近（< 2 × 200 m）时的红字提示

确认键走 `onIntercept` 校验空名——就地亮红字、留住弹窗，不关掉再 toast 骂人。与
`showCategoryEditor` 逐字同构。

### 3.8 同步：manifest v2（2026-09-05）

`places` 走 `categories` 完全相同的路子（LWW by `lastModified` + 墓碑）。但日记对象的
`position: {latitude, longitude, name}` 换成了 `placeId`，这是格式变更：`SyncManifest.currentVersion`
1 → 2、`lanProtoVersion` 2 → 3（并删掉「没带 proto 头按 2 放行」的宽容）。

**2.8.0 用户的远端是 v1，升级后要能继续同步**：

- manifest **读 1 放行、写 2**（`copyForUpdate` 升版本）。用户升级后第一次 push 把远端
  升到 v2，此后没升级的 2.8.0 设备被版本门拦住——它看不懂 `placeId`，继续推会把位置抹掉。
- pull 端的日记解码（`ArchiveApplier._adoptLegacyPosition`）遇到 `position` 快照就按地名
  归并成地点（派生 id 优先、其次同名、都没有才建）再补 `placeId`；`p:` 条目整批先于其它
  条目落地。远端对象不改写，由持有该日记的设备下次推送时自然换成新格式。
- 本地 zip 备份走同一条 `ArchiveApplier`，2.8.0 导出的备份照样能导入。
- LAN：2.8.0（协议 2）与 2.8.1（协议 3）互不相通，两台都升级即可。

下面三条是加 `p:` 命名空间那部分仍然成立的事实：

1. **push 是合并进远端 manifest，不是用本地重建。**
   `incremental_engine.dart:353` 是 `final updated = manifest.copyForUpdate()`，各
   `pushOneXxx` 只往里 **写** 键。所以老客户端 push **不会**抹掉新客户端写的 `p:` 条目
   ——这是最关键的一条，否则跨版本会静默孤儿化 `place/*.json`。
2. **老客户端 pull 静默忽略 `p:`。** `archive_apply.dart` 的 `pullOneEntry` 是
   `if / else if` 前缀链（`d:` / `c:` / `m:`），`p:` 落不进任何分支，不报错、不中断整次同步。
3. LAN 的指纹测试（`lan_protocol_test.dart`）钉的是端点 / 令牌头 / nonce 长度 /
   manifest 版本 / cipher magic；这次 bump 后期望值是 `proto=3;…manifestVersion=2`。

#### 改动清单

| 文件 | 改动 |
|---|---|
| `moodiary_models/sync_tombstone.dart` | `placePrefix = 'p:'` / `forPlace()` / `TombstoneKind.place` |
| `sync/data/model/manifest.dart` | `SyncKeys.placePrefix` / `place(id)` / `placeObjectPath(id)` |
| `sync/data/sync_stores.dart` | `SyncPlaceStore` 端口 + `RepoSyncPlaceStore` |
| `sync/data/incremental_engine.dart` | 构造器多一个 store；`pushOnePlace`（照抄 `pushOneCategory`）；`pushOneTombstone` 的 `switch (kind)` 加 `.place` |
| `sync/data/archive_apply.dart` | pull 分支加一支；末尾错误归类的 switch 加一支 |
| `writeArchive` + `local_archive.dart` | 多一个 `places:` 参数、一个循环、两处调用 |
| `sync/application/re_cipher.dart` | 重加密多一轮 `place/` |
| `sync/application/sync_stats_controller.dart` | 远端计数多一项 |
| `sync/data/model/sync_event.dart` + i18n | `placeUpload` / `placeDownload` / `placeSkip` / `placeTombstonePush` / `placeTombstonePull` 五个日志 kind + 文案 |

**不用改** `SyncPendingTracker`——那是给日记 / 分类卡片的「待同步」角标，地点没有卡片。

> `pushOneTombstone` 里的 `switch (kind)` 是**穷尽**的，给 `TombstoneKind` 加一个值会直接
> 编译报错。这是好事：编译器会把所有该改的点指出来，不靠人肉找。

#### 分期调整：同步跟 `places` 表一起进 P2

原本排在 P3。改主意的理由：**只要表存在但不同步，A 机建的「公司」在 B 机不存在，
B 机的自动命中就静默地与 A 机不一致**——这比「压根没这个功能」更难向用户解释。
而按上表，改动量确实不大，且编译器帮着兜底。

## 4. 契约改动（EditorMeta / 事件）

```ts
// 新增
weatherOptions: { code: string; label: string }[]
weatherAutoLabel?: string | null          // null = 和风未配置，不显示「自动获取」
weatherClearLabel: string
places: { id: string; name: string; icon: string; distance?: string | null }[]
                                          // 顺序由宿主给（定位过按距离升序），web 不排序
positionAutoLabel?: string | null         // null = 和风未配置，不显示「自动获取」
positionSaveAsPlaceLabel?: string | null  // 仅本会话定位过、且不在任何预设半径内时下发
positionManageLabel: string
positionClearLabel: string

// 改
weather?: { icon: string; text: string } | null   // text 不再含温度，由 Flutter 侧拼
position?: string | null                          // 空 name 时下发格式化坐标
```

事件：

| 事件 | 触发 | 宿主动作 |
|---|---|---|
| `changeWeather{code}` | 天气面板选中 | 按码查本地化名，写 `DiaryWeather(icon, text, temp: null)` |
| `clearWeather` | 天气面板 | `changeWeather(null)` |
| `fetchWeather` | 天气面板「自动获取」 | 定位 → 和风 now → **只写 weather** |
| `locateForPlaces` | 位置面板打开 | 取一次定位记入 `_fix`，重发 meta（预设按距离排序） |
| `fetchPosition` | 位置面板「自动获取」 | 定位 → 和风反查 → **只写 position** |
| `pickPlace{id}` | 位置面板选中预设 | 写预设名 + 预设中心坐标 |
| `savePlaceFromCurrent` | 位置面板「存为常用地点」 | 带 `_fix` 坐标开新增表单，存完选中 |
| `managePlaces` | 位置面板 | 导航到 `PlaceManagerPage` |
| `clearPosition` | 位置面板 | `changePosition(null)` |

点位置图标总是弹面板，web 侧不再按 `meta.position` 是否为空分流。

## 5. 分期

| 期 | 内容 | 触及 |
|---|---|---|
| P1 | 天气手动选择 + 天气/位置解绑 | models（temp 可空）/ `EditorMetaHeader.vue` / `edit_controller`（fetchWeather 不写 position）/ `diary_page` / 6 处温度展示点收成 1 处扩展 |
| P2 | 定位解耦 + `places` 表（含 schemaVersion 2 的首个 onUpgrade）+ 位置面板 + 管理页 + `autoPosition` + **places 同步** | platform（LocationService）/ models / data（表 + 仓储）/ editor 契约 / settings / sync 9 处 |
| P3 | 地图选点（天地图 tk 已配时在表单里嵌小地图微调） | 管理页表单 |

P1 独立可发；P2 依赖 P1 的面板脚手架；P3 是纯增强，不阻塞前两期。

## 6. 风险

- **温度可空的漏改**：6 个展示点必须全走 `displayText` 扩展，漏一处就是「晴 °C」。
- **权限文案继续说谎**：解耦后没配和风也会走到权限请求，`GeoFailure.notConfigured` 不能再是位置链路的第一道判定。
- **半径与 GPS 误差**：室内误差常有 50–100 m，默认 200 m 是折中；靠得近的两个预设（同一栋楼的「公司」与「食堂」）会互相误命中——取最近者，并在新增时提示距离。
- **耗电 / 隐私观感**：两个自动开关都默认关；只在新建日记时取一次，两条链路共用同一次定位，`getLastKnownPosition` 优先（现有代码已如此）。
- **解绑的回归面**：`fetchWeather` 不再写 position 之后，今天「点获取天气顺带有了位置」的用户会觉得少了一步。这是有意的——想要就把 `autoPosition` / `autoNearestPlace` 打开，或者点一下位置图标。
- **预设赢过反查的边界**：半径设得过大（1 km 档）会让市中心的一次出行全被记成「公司」。管理页的默认档是 200 m，1 km 档留给「母校」这类本来就大的地方。
- **面板高度**：4×4 天气网格 + 操作行在小屏（360×640）上高约 260 px，`PopupMenu` 的翻转逻辑已覆盖上下空间不足；位置面板条目多时需自带 `max-height` + 滚动。
