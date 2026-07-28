<picture>
  <source media="(prefers-color-scheme: dark)" srcset="mobile/res/banner/dark_en.svg">
  <source media="(prefers-color-scheme: light)" srcset="mobile/res/banner/light_en.svg">
  <img alt="The preview for moodiary." src="mobile/res/banner/light_en.svg">
</picture>
<p align="center"><a href="README.zh.md">简体中文</a> | English</p>

<p align="center"><a href="https://answer.moodiary.net" target="_blank">Official forum</a>丨QQ Group: <a target="_blank" href="https://qm.qq.com/cgi-bin/qm/qr?k=xGr0TNp_X1z3XEn09_iE_iGSLolQwl6Y&jump_from=webapi&authKey=ZmSb2oEd94FSXxBXRBq53hgTjjvcfmgkQrduB3uL12XtRylPmRlO2OdFz6R25tIo">760014526</a>丨Telegram: <a target="_blank" href="https://t.me/openmoodiary">openmoodiary</a></p>

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44.6-blue?style=for-the-badge">
  <img src="https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070">
  <img src="https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a">
  <img src="https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f">
  <img src="https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7">
</div>


## ✨ Feature

- **Mobile first**: 📱 Android and iOS are supported for now.
- **Material Design**: 🎨 The interface is intuitive and user-friendly, and follows the Material Design specifications.
- **Rich text editing**: 📝 A TipTap based editor, legacy markdown / rich text diaries can be migrated in one tap.
- **Multimedia accessories**: 📷 You can add pictures, audio, video or even draw a picture to your diary.
- **Search and classification**: 🔍 Easily manage your diary by full-text search and categorization.
- **Custom theme**: 🌈 Supports light and dark modes, as well as a variety of color schemes.
- **Custom fonts**: ✍️ Supports importing different fonts, and supports variable fonts.
- **Data security**: 🔒 Keep your diary safe with a password, supports biometric unlocking.
- **Export and share**: 🧾 Support all data import/export, as well as single diary sharing.
- **Backup and synchronization**: ☁ Support for WebDAV, S3 / MinIO and LAN sync, with optional end-to-end encryption.
- **Trail Map**:  🗺️ See your footprints on a map. Every step of your life is worth documenting.
- **Intelligent assistant**: 💬 Supports access to third-party large models, provides Q&A, diary tool calls, sentiment analysis and other functions.

(Note: the desktop app is being rewritten on the new architecture, `desktop/` is only a skeleton for now and ships no builds)

## 🔧 Main Technology stack

- [Flutter](https://github.com/flutter/flutter) ( Cross-platform UI framework )
- [Rust](https://github.com/rust-lang/rust) + [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) ( Native image, audio, crypto and network capabilities )
- [Isar Plus](https://pub.dev/packages/isar_plus) ( High performance local database )
- [Riverpod](https://github.com/rrousselGit/riverpod) ( State management framework )

## 📸 Application screenshot

> The application is constantly updated, and the interface may change slightly in the new version

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="mobile/res/screenshot/mobile_dark_en.webp">
  <source media="(prefers-color-scheme: light)" srcset="mobile/res/screenshot/mobile_light_en.webp">
  <img alt="The mobile screenshot for moodiary." src="mobile/res/screenshot/mobile_light_en.webp">
</picture>

## 🚀 Installation guide

### Third party SDK

Some capabilities need to apply for third-party SDKS, and the following service providers provide free versions, and the obtained keys are configured in Settings → Third-party services.

#### Weather service

- [QWeather](https://dev.qweather.com/docs/api/)

#### Map service

- [Tianditu](http://lbs.tianditu.gov.cn/server/MapService.html)

#### Intelligent assistant

The assistant is built on [rig](https://github.com/0xPlaygrounds/rig). Add the API key of any OpenAI / Anthropic compatible provider under Assistant settings → Model providers, the key is only kept in the local secure storage.

### Direct install

Use it by downloading the compiled installation package in Release, or manually compiling it if you don't have the platform you need.

### Manual compilation

#### Environmental requirement

> I always use the latest Flutter version (if possible), using newer versions will bring more features and better performance improvements, never use older versions unless you want your code to become a piece of 💩

- Flutter SDK (>= 3.44.0 Stable) (It is recommended to use FVM to manage the Flutter version)
- Dart (>= 3.12.0)
- Rust Toolchain (rustup, the native library is built by a build hook)
- Clang/LLVM
- Node + Corepack (to build the editor web bundle)
- Compatible IDE (e.g. Android Studio, Visual Studio Code)

#### Installation procedure

> Note: For security reasons, I did not include my signature in the code base, when you need to manually package, you need to modify the configuration file of the corresponding platform, such as build.gradle on the Android platform, and package after modifying the package name, thank you for your understanding.

1. **Clone Repo**：

```bash
git clone https://github.com/ZhuJHua/moodiary.git
cd moodiary
```

2. **Installation dependency**：

```bash
fvm use
dart tool/task.dart setup
```

3. **Running application**：

```bash
dart tool/task.dart run
```

4. **Package release**：

- Android: `dart tool/task.dart build-apk`
- iOS: `dart tool/task.dart build-ios`

> Run `dart tool/task.dart` for the full command list; extra flutter flags go after `--`, e.g. `dart tool/task.dart run -- --release`.

## 📦 Project structure

The repo is a pub workspace monorepo, shared code is layered as `foundation → core → ui → feature`, upper layers depend on lower ones.

```
mobile/      mobile app (Android / iOS)
desktop/     desktop skeleton (work in progress)
packages/    layered shared packages
tool/        cross-platform task entry (task.dart)
```

## 🤝 Contribution guide

Contributions are welcome! Please follow these steps to contribute:

1. Fork this repository.
2. Create a new branch(`git checkout -b feature-branch-name`)。
3. Commit your changes(`git commit -am 'Add some feature'`)。
4. Push to branch(`git push origin feature-branch-name`)。
5. Create a Pull Request.

Please make sure that your code to follow [Flutter style guide](https://flutter.dev/docs/development/tools/formatting) and include the appropriate tests.

## 📄 License

This project is licensed under the AGPL-3.0 LICENSE, see the [LICENSE](LICENSE) file for details.

## 💖 Thanks

- Thanks to the Flutter team for the excellent framework.
- Special thanks to the open source community for their valuable contributions.

## 🥪 Sponsor

You can buy me a sandwich to keep me motivated to continue developing.

<img src="mobile/res/sponsor/wechat.jpg" style="width:300px"  alt="Sponsor"/>

### List of sponsors

If you want to appear on the list, you can leave your Github username in the comment, in no particular order, and the list will be updated regularly.

| Sponsor                           | Price    | Sponsor                                          | Price  |
|-----------------------------------| -------- | ------------------------------------------------ | ------ |
| [dsxksss](https://github.com/dsxksss) | 50 CNY   | 十*                                            | 20 CNY |
| 沭**                             | 10 CNY   | 朱东杰                                           | 60 CNY |
| *Person*                    | 5 CNY    | wu*                                             | 10 CNY |
| 云*                               | 2.76 CNY | 不对味的雪碧                                     | 10 CNY |
| w**                        | 6.6 CNY  | [帕斯卡的芦苇](https://github.com/xiaoxianzi-99) | 10 CNY |
| 不** | 20 CNY | 曾** | 20 CNY |
| *Person* | 20 CNY | *Person* | 18.88 CNY |
| Lucci | 9.9 CNY | *Person* | 5 CNY |
| 宋** | 5 CNY | 翰** | 5 CNY |
