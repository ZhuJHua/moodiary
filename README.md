# 📔 心绪日记

简体中文丨[English](README.en.md)

「心绪日记」 是采用 Flutter 编写的，无广告、无社交的开源跨平台私密日记本。采用 Material Design 设计，简洁且易用。

![Flutter Version](https://img.shields.io/badge/Flutter-3.25.0--0.1.pre-blue?style=for-the-badge) ![GitHub repo size](https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070) ![GitHub Repo stars](https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a) ![GitHub Release](https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f) ![GitHub License](https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7)

## ✨ 功能特性

- **跨平台支持**：🌍 兼容 Android、iOS、Windows（即将支持）。
- **Material Design**：🎨 界面直观且用户友好，遵循 Material Design 设计规范。
- **富文本编辑**：📝 支持加粗、斜体、下划线等多种格式的文本编辑。
- **多媒体附件**：📷 可以为你的日记添加图片、音频。
- **搜索和分类**：🔍 轻松通过全文搜索及分类管理你的日记。
- **自定义主题**：🌈 支持选择浅色和深色模式，或自定义主题。
- **数据安全**：🔒 通过密码来保障你的日记安全。
- **导出和分享**：🧾 支持所有数据的导入/导出，以及单篇日记的分享。
- **云同步**：☁ 支持在多个设备间同步日记（即将支持）。
- **AI 助手**：🤖 支持接入大模型提供 AI 能力（目前支持：[腾讯混元](https://hunyuan.tencent.com/)）。

## 📸 应用截图

### Android

| ![](res/screenshot/phone1.png) | ![](res/screenshot/phone2.png) |
| ------------------------------ | ------------------------------ |



## 🚀 安装指南

### 直接安装

通过下载 Release 中已编译好的安装包来使用，如果没有你所需要的平台，请使用手动编译。

### 手动编译

#### 环境要求

- Flutter SDK (>= 3.25.0-0.1.pre)
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

## 📝 使用说明

安装完成后，你可以通过点击“新建日记”按钮开始创建日记条目。使用富文本编辑器来格式化你的内容，添加多媒体附件，并通过标签进行组织。

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