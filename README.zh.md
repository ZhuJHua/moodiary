<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/social_dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="res/social_light.svg">
  <img alt="moodiary" src="res/social_light.svg">
</picture>
<p align="center">简体中文 | <a href="README.md">English</a></p>

<p align="center"><a href="https://docs.moodiary.net" target="_blank">文档</a>丨<a href="https://answer.moodiary.net" target="_blank">论坛</a>丨QQ 群：<a target="_blank" href="https://qm.qq.com/cgi-bin/qm/qr?k=xGr0TNp_X1z3XEn09_iE_iGSLolQwl6Y&jump_from=webapi&authKey=ZmSb2oEd94FSXxBXRBq53hgTjjvcfmgkQrduB3uL12XtRylPmRlO2OdFz6R25tIo">760014526</a>丨Telegram：<a target="_blank" href="https://t.me/openmoodiary">openmoodiary</a></p>

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-blue?style=for-the-badge">
  <img src="https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070">
  <img src="https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a">
  <img src="https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f">
  <img src="https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7">
</div>

Moodiary 是一款开源日记应用，支持 Android 与 iOS。界面用 Flutter 编写，图片、排版、加密、网络与分词等计算密集的部分用 Rust 实现。除非你自己配置同步，数据只保存在本机。

## ✨ 功能

- **富文本**：可插入图片、音频与视频。
- **搜索与分类**：全文搜索，按分类筛选。
- **主题与字体**：浅色与深色模式、多种配色，支持导入字体，包括可变字体。
- **应用锁**：密码保护，支持生物识别解锁。
- **导出、导入与分享**：导出为 Markdown、Word、PDF 或长图，可从 Markdown 压缩包或本地备份导入。
- **备份与同步**：WebDAV、S3 / MinIO 与局域网同步，可选端到端加密。
- **天气与地点**：天气可手选或自动获取。常去的地方可以保存下来供日记引用，并在地图上查看足迹。
- **智能助手**：接入任意 OpenAI 或 Anthropic 兼容的供应商，提供问答、日记工具调用与心情建议。

## 📸 截图

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/mobile_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/mobile_light_zh.webp">
  <img alt="Moodiary 手机端截图" src="res/screenshot/mobile_light_zh.webp">
</picture>

截图可能落后于当前版本。

## 🚀 开始使用

在 [Releases](https://github.com/ZhuJHua/moodiary/releases) 下载安装包。应用离线即可使用，天气、地图与助手会用你自己的密钥调用第三方服务。

其余内容都在文档站 [docs.moodiary.net](https://docs.moodiary.net)：需要申请哪些第三方服务、密钥填在哪里，如何准备环境与从源码构建，代码是怎样组织的，以及贡献指南。

## 🤝 贡献者

<a href="https://github.com/ZhuJHua/moodiary/graphs/contributors">
  <img alt="Contributors" src="https://contrib.rocks/image?repo=ZhuJHua/moodiary">
</a>

## 📄 许可证

[AGPL-3.0](LICENSE)。

## 🥪 捐助

如果 Moodiary 对你有用，可以请我吃个三明治。

<img src="mobile/res/sponsor/wechat.jpg" style="width:300px" alt="Sponsor"/>

### 捐助者

不分先后。想在名单里带上链接，请在转账备注中留下 GitHub 用户名。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/sponsor/sponsors_dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="res/sponsor/sponsors_light.svg">
  <img alt="捐助者名单" src="res/sponsor/sponsors_light.svg">
</picture>

这面墙由 [`sponsors.json`](sponsors.json) 经 `dart tool/task.dart sponsors` 生成，该文件变动时 CI 会重新渲染。改 JSON，不要改 SVG。
