<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/social_dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="res/social_light.svg">
  <img alt="moodiary" src="res/social_light.svg">
</picture>
<p align="center"><a href="README.zh.md">简体中文</a> | English</p>

<p align="center"><a href="https://docs.moodiary.net" target="_blank">Docs</a>丨<a href="https://answer.moodiary.net" target="_blank">Forum</a>丨QQ group: <a target="_blank" href="https://qm.qq.com/cgi-bin/qm/qr?k=xGr0TNp_X1z3XEn09_iE_iGSLolQwl6Y&jump_from=webapi&authKey=ZmSb2oEd94FSXxBXRBq53hgTjjvcfmgkQrduB3uL12XtRylPmRlO2OdFz6R25tIo">760014526</a>丨Telegram: <a target="_blank" href="https://t.me/openmoodiary">openmoodiary</a></p>

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-blue?style=for-the-badge">
  <img src="https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070">
  <img src="https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a">
  <img src="https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f">
  <img src="https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7">
</div>

Moodiary is an open-source diary app for Android and iOS. The interface is Flutter, the heavy work (images, typesetting, encryption, networking, tokenization) is Rust. Your data stays on your device unless you set up sync yourself.

## ✨ Features

- **Rich text**: insert images, audio and video.
- **Search and categories**: full-text search and per-category filtering.
- **Themes and fonts**: light and dark modes, several color schemes, and imported fonts including variable fonts.
- **App lock**: a password with biometric unlock.
- **Export, import and share**: export to Markdown, Word, PDF or a long image, and import from a Markdown zip or a local backup.
- **Backup and sync**: WebDAV, S3 / MinIO and LAN sync, with optional end-to-end encryption.
- **Weather and places**: pick or fetch the weather, save places and reference them from entries, and view your footprints on a map.
- **Assistant**: connect any OpenAI- or Anthropic-compatible provider for chat, diary tools and mood suggestions.

## 📸 Screenshots

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/mobile_dark_en.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/mobile_light_en.webp">
  <img alt="Moodiary on a phone." src="res/screenshot/mobile_light_en.webp">
</picture>

Screenshots may lag behind the current release.

## 🚀 Getting started

Download an installer from [Releases](https://github.com/ZhuJHua/moodiary/releases). The app works offline out of the box. Weather, the map and the assistant call third-party services with your own keys.

Everything else is in the docs at [docs.moodiary.net](https://docs.moodiary.net): which third-party services to sign up for and where to enter the keys, how to set up the environment and build from source, how the code is organized, and the contributing guide.

## 🤝 Contributors

<a href="https://github.com/ZhuJHua/moodiary/graphs/contributors">
  <img alt="Contributors" src="https://contrib.rocks/image?repo=ZhuJHua/moodiary">
</a>

## 📄 License

[AGPL-3.0](LICENSE).

## 🥪 Sponsor

If Moodiary is useful to you, you can buy me a sandwich.

<img src="mobile/res/sponsor/wechat.jpg" style="width:300px" alt="Sponsor"/>

### Sponsors

Listed in no particular order. Leave your GitHub username in the transfer note if you want a link next to your name.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/sponsor/sponsors_dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="res/sponsor/sponsors_light.svg">
  <img alt="Sponsors" src="res/sponsor/sponsors_light.svg">
</picture>

The wall is rendered from [`sponsors.json`](sponsors.json) by `dart tool/task.dart sponsors`, and CI re-renders it when that file changes. Edit the JSON, not the SVG.
