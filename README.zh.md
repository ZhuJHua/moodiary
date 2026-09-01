<picture>
  <source media="(prefers-color-scheme: dark)" srcset="mobile/res/banner/dark_zh.svg">
  <source media="(prefers-color-scheme: light)" srcset="mobile/res/banner/light_zh.svg">
  <img alt="The preview for moodiary." src="mobile/res/banner/light_zh.svg">
</picture>
<p align="center">简体中文 | <a href="README.md">English</a></p>

<p align="center"><a href="https://answer.moodiary.net" target="_blank">官方论坛</a>丨QQ群: <a target="_blank" href="https://qm.qq.com/cgi-bin/qm/qr?k=xGr0TNp_X1z3XEn09_iE_iGSLolQwl6Y&jump_from=webapi&authKey=ZmSb2oEd94FSXxBXRBq53hgTjjvcfmgkQrduB3uL12XtRylPmRlO2OdFz6R25tIo">760014526</a>丨Telegram: <a target="_blank" href="https://t.me/openmoodiary">openmoodiary</a></p>

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44.6-blue?style=for-the-badge">
  <img src="https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070">
  <img src="https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a">
  <img src="https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f">
  <img src="https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7">
</div>



## ✨ 功能特性

- **移动端优先**：📱 目前支持 Android 与 iOS。
- **Material Design**：🎨 界面直观且用户友好，遵循 Material Design 设计规范。
- **富文本编辑**：📝 基于 TipTap 的编辑器，旧版 Markdown / 富文本日记可一键迁移。
- **多媒体附件**：📷 可以为你的日记添加图片、音频、视频甚至画一张画。
- **搜索和分类**：🔍 轻松通过全文搜索及分类管理你的日记。
- **自定义主题**：🌈 支持浅色和深色模式，以及多种配色的主题。
- **自定义字体**：✍️ 支持导入不同的字体，并支持可变字体。
- **数据安全**：🔒 通过密码来保障你的日记安全，支持通过生物识别解锁。
- **导出和分享**：🧾 支持所有数据的导入/导出，以及单篇日记的分享。
- **备份与同步**：☁ 支持 WebDAV、S3 / MinIO 与局域网同步，同步数据可端到端加密。
- **足迹地图**：🗺️ 在地图上查看你足迹，生活中的每一步都值得被记录。
- **智能助手**：💬 支持接入第三方大模型，提供问答、日记工具调用、情绪分析等功能。

（注：桌面端正在基于新架构重写，`desktop/` 目前只是骨架，暂不提供构建产物）

## 🔧 主要技术栈

- [Flutter](https://github.com/flutter/flutter)（跨平台 UI 框架）
- [Rust](https://github.com/rust-lang/rust) + [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge)（图片、音频、加密、网络等原生能力）
- [Isar Plus](https://pub.dev/packages/isar_plus)（高性能本地数据库）
- [Riverpod](https://github.com/rrousselGit/riverpod)（状态管理框架）

## 📸 应用截图

> 应用持续更新中，新版本界面可能稍有变化

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="mobile/res/screenshot/mobile_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="mobile/res/screenshot/mobile_light_zh.webp">
  <img alt="The mobile screenshot for moodiary." src="mobile/res/screenshot/mobile_light_zh.webp">
</picture>

## 🚀 安装指南

### 第三方 SDK

某些能力需要自行申请第三方 SDK，下列服务商均提供免费的版本，获取到的 Key 在「设置 → 第三方服务」中配置。

#### 天气服务

- [和风天气](https://dev.qweather.com/docs/api/)

#### 地图服务

- [天地图](http://lbs.tianditu.gov.cn/server/MapService.html)

#### 智能助手

助手基于 [rig](https://github.com/0xPlaygrounds/rig) 构建，在「助手设置 → 模型供应商」中填入任意 OpenAI / Anthropic 兼容服务商的 API Key 即可使用，Key 仅保存在本机安全存储。

### 直接安装

通过下载 Release 中已编译好的安装包来使用，如果没有你所需要的平台，请使用手动编译。

### 手动编译

#### 环境要求

> 我总是会使用最新的 Flutter 版本（如果可能的话），使用新版本可以带来更多的功能和更好的性能提升，永远不要使用老版本除非你希望代码变成一坨 💩

- Flutter SDK (>= 3.44.0 Stable)（建议使用 fvm 来管理 flutter 版本）
- Dart (>= 3.12.0)
- Rust 工具链（rustup，原生库由构建钩子编译）
- Clang/LLVM
- Node + Corepack（编译编辑器 Web 产物）
- 兼容的 IDE（如 Android Studio、Visual Studio Code）

#### 安装步骤

> 注意：出于安全考虑，我并没有在代码库中包含我的签名，当您需要手动打包时，需要自己修改对应平台的配置文件，例如安卓平台的 build.gradle，修改包名后打包，感谢您的理解

1. **克隆仓库**：

```bash
git clone https://github.com/ZhuJHua/moodiary.git
cd moodiary
```

2. **安装依赖**：

```bash
fvm use
dart tool/task.dart setup
```

3. **运行应用**：

```bash
dart tool/task.dart run
```

4. **打包发布**：

- Android: `dart tool/task.dart build-apk`
- iOS: `dart tool/task.dart build-ios`

> 更多命令用 `dart tool/task.dart` 查看；额外的 flutter 参数写在 `--` 之后，如 `dart tool/task.dart run -- --release`。

## 📦 项目结构

仓库是一个 pub workspace 单体仓库，共享能力按 `foundation → core → ui → feature` 分层，上层依赖下层。

```
mobile/      移动端应用（Android / iOS）
desktop/     桌面端骨架（开发中）
packages/    分层共享包
tool/        跨平台任务入口（task.dart）
```

## 🤝 贡献指南

欢迎贡献！请按照以下步骤进行贡献：

1. Fork 本仓库。
2. 创建一个新分支（`git checkout -b feature-branch-name`）。
3. 提交你的修改（`git commit -am 'Add some feature'`）。
4. 推送到分支（`git push origin feature-branch-name`）。
5. 创建一个 Pull Request。

请确保你的代码遵循 [Flutter 风格指南](https://flutter.dev/docs/development/tools/formatting) 并包含适当的测试。

## 📄 许可证

此项目基于 AGPL-3.0 许可证进行许可，详情请参阅 [LICENSE](LICENSE) 文件。

## 💖 鸣谢

- 感谢 Flutter 团队提供出色的框架。
- 特别感谢开源社区的宝贵贡献。

## 🥪 捐助

可以给我买一个三明治，让我更有动力继续开发。

<img src="mobile/res/sponsor/wechat.jpg" style="width:300px" alt="Sponsor"/>

### 捐助者名单

如果您想要出现在名单中，可以在留言中留下您的 Github 用户名，排名不分先后，名单会定期更新。

| 捐助者                                | 金额     | 捐助者                                           | 金额      |
| ------------------------------------- | -------- | ------------------------------------------------ | --------- |
| [dsxksss](https://github.com/dsxksss) | 50 CNY   | 十*                                              | 20 CNY    |
| 沭**                                  | 10 CNY   | 朱东杰                                           | 60 CNY    |
| *人*                                  | 5 CNY    | wu*                                              | 10 CNY    |
| 云*                                   | 2.76 CNY | 不对味的雪碧                                     | 10 CNY    |
| w**                                   | 6.6 CNY  | [帕斯卡的芦苇](https://github.com/xiaoxianzi-99) | 10 CNY    |
| 不**                                  | 20 CNY   | 曾**                                             | 20 CNY    |
| *人*                                  | 20 CNY   | *人*                                             | 18.88 CNY |
| Lucci                                 | 9.9 CNY  | *人*                                             | 5 CNY     |
| 宋**                                  | 5 CNY    | 翰**                                             | 5 CNY     |
