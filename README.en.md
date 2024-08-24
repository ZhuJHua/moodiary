# 📔 Moodiary

[简体中文](README.md)丨English

「Moodiary」 is an open source, ad-free, social-free cross-platform private journal written with Flutter. Designed with Material Design, simple and easy to use.

![GitHub repo size](https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070) ![GitHub Repo stars](https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a) ![GitHub Release](https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f) ![GitHub License](https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7)

## ✨ Feature

- **Cross-platform support**：🌍 Compatible with Android, iOS, Windows (coming soon).
- **Material Design**：🎨 The interface is intuitive and user-friendly, and follows the Material Design specifications.
- **Rich text editing**：📝 Supports text editing in bold, italic, underline and other formats.
- **Multimedia accessories**：📷 You can add pictures and audio to your diary.
- **Search and classification**：🔍 Easily manage your diary by full-text search and categorization.
- **Custom theme**：🌈 Supports choice of light and dark modes, or custom themes.
- **Data security**：🔒 Keep your diary safe with a password.
- **Export and share**：🧾 Support all data import/export, as well as single diary sharing.
- **Cloud synchronization**：☁ Support for synchronizing diaries across multiple devices (coming soon).
- **AI assistant**：🤖 Support ability to access large model provides AI (currently support: [Tencent Hunyuan](https://hunyuan.tencent.com/)).

## 📸 Application screenshot

### Android

| ![](res/screenshot/phone1.png) | ![](res/screenshot/phone2.png) |
| ------------------------------ | ------------------------------ |



## 🚀 Installation guide

### Direct mounting

Use it by downloading the compiled installation package in Release, or manually compiling it if you don't have the platform you need.

### Manual compilation

#### Environmental requirement

- Flutter SDK (>= 3.24.0)
- Dart (>= 3.5.0)
- Compatible ides (e.g. Android Studio, Visual Studio Code)

#### Installation procedure

> Note: When packaging, you need to modify the corresponding platform configuration file, such as Android platform build.gradle

1. **Clone Repo**：

   ```bash
   git clone https://github.com/ZhuJHua/moodiary.git
   cd moodiary
   ```

2. **Installation dependency**：

   ```bash
   flutter pub get
   ```

3. **Running application**：

   ```bash
   flutter run
   ```

4. **Package release**：

   - Android: `flutter build apk`
   - iOS: `flutter build ios`

## 📝 Instructions for use

Once the installation is complete, you can start creating diary entries by clicking the "New Diary" button. Use a rich text editor to format your content, add multimedia attachments, and organize through tags.

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