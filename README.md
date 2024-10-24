# 📔 心绪日记

简体中文丨[English](README.en.md)

「心绪日记」 是采用 Flutter 编写的，无广告、无社交的开源跨平台私密日记本。采用 Material Design 设计，简洁且易用。

QQ 交流群：760014526

![Flutter Version](https://img.shields.io/badge/Flutter-3.26.0--0.1.pre-blue?style=for-the-badge) ![GitHub repo size](https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070) ![GitHub Repo stars](https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a) ![GitHub Release](https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f) ![GitHub License](https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7)

## ✨ 功能特性

- **跨平台支持**：🌍 兼容 Android、iOS\*、Windows、MacOS\*、Linux\*。
- **Material Design**：🎨 界面直观且用户友好，遵循 Material Design 设计规范。
- **富文本编辑**：📝 支持加粗、斜体、下划线等多种格式的文本编辑。
- **多媒体附件**：📷 可以为你的日记添加图片、音频、视频甚至画一张画。
- **搜索和分类**：🔍 轻松通过全文搜索及分类管理你的日记。
- **自定义主题**：🌈 支持浅色和深色模式，以及多种配色的主题。
- **数据安全**：🔒 通过密码来保障你的日记安全。
- **导出和分享**：🧾 支持所有数据的导入/导出，以及单篇日记的分享。
- **云同步**：☁ 支持在多个设备间同步日记（即将支持）。
- **自然语言处理（NLP）**：🤖 让你的日记更懂你。

（注：跨平台能力由 Flutter 提供，带 * 号的平台可能需要更多测试）

## 🔧 主要技术栈

- [Flutter](https://github.com/flutter/flutter)
- [Isar](https://github.com/isar/isar)
- [GetX](https://github.com/jonataslaw/getx)

## 📸 应用截图

### 移动端

![移动端](res/screenshot/mobile.webp)

### 桌面端

![桌面端](res/screenshot/desktop.webp)

## 🚀 安装指南

### 第三方 SDK

某些能力需要自行申请第三方 SDK，下列服务商均提供免费的版本，获取到的 Key 在实验室中配置。

#### 天气服务

- [和风天气](https://dev.qweather.com/docs/api/)

### 直接安装

通过下载 Release 中已编译好的安装包来使用，如果没有你所需要的平台，请使用手动编译。

### 手动编译

#### 环境要求

- Flutter SDK (>= 3.26.0-0.1.pre，因为使用了尚未合并到稳定版的功能，我只能使用测试版，等稳定版更新后会尽快迁移)
- Dart (>= 3.6.0)
- 兼容的 IDE（如 Android Studio、Visual Studio Code）

#### 安装步骤

> 注意：当打包时，需要自己修改对应平台的配置文件，例如安卓平台的 build.gradle

1. **克隆仓库**：

   ```bash
   git clone https://github.com/ZhuJHua/moodiary.git
   cd moodiary
   ```

2. **安装依赖**：

   ```bash
   flutter pub get
   ```

3. **运行应用**：

   ```bash
   flutter run
   ```

4. **打包发布**：

    - Android: `flutter build apk`
    - iOS: `flutter build ios`
    - Windows: `flutter build windows`

## 📝 更多说明

### 自然语言处理（NLP）

> 处于实验阶段

如今，越来越多的行业产品开始融入 AI 技术，这无疑极大地提升了我们的使用体验。然而，对于日记应用来说，将数据交给大型模型处理并不可接受，因为无法确定这些数据是否会被用于训练。因此，更好的方法是采用本地模型。虽然由于体积限制，本地模型的能力可能不如大型模型强大，但在一定程度上仍能为我们提供必要的帮助。

目前，我在源码中集成了以下任务：

#### 基于 Bert 预训练模型的 SQuAD 任务

我采用了 MobileBert 来处理 SQuAD 任务，这是一个简单的机器阅读理解任务。你可以向它提出问题，它会返回你需要的答案。模型文件采用 TensorFlow Lite 所需的 `.tflite` 格式，所以你可以添加自己的模型文件到 `assets/tflite` 目录下。

感谢以下开源项目：

- [Chinese MobileBERT](https://github.com/ymcui/Chinese-MobileBERT)
- [Mobilebert](https://github.com/google-research/google-research/tree/master/mobilebert)
- [ChineseSquad](https://github.com/junzeng-pluto/ChineseSquad)

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
