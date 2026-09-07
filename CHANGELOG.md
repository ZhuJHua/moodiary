# Changelog

All notable changes to this project will be documented in this file.

## [2.8.1] - 2026-09-07

2.8.1 rebuilds Moodiary on new foundations: a new database, a new editor, a new
design system and on-device AI. Everything below is stated relative to 2.7.3.
Upgrading runs a one-time migration of your existing diaries at startup.

### 🚀 Features

- *(data)* SQLite replaces Isar, with FTS5 full-text search, BM25-ranked
  results and semantic search over your diaries
- *(editor)* A new TipTap editor with image resizing, inline video, audio
  recording, custom fonts, first-line indent, wiki links and in-page link
  history
- *(diary)* Timeline and feed home layouts, categories as a filter, long-press
  multi-select, a calendar under Me > Revisit, and a bidirectional-link
  knowledge graph
- *(diary)* 16 emotion and state values replace the old mood scale
- *(diary)* Manual weather, and locations saved as reusable places
- *(ml)* On-device models — Whisper speech-to-text, mood suggestion, and
  embeddings for local semantic search; you can bring your own model
- *(assistant)* A rebuilt AI assistant — any provider and model, agent presets,
  thinking-effort levels, image input, tool calls with tiered approval, a
  JavaScript sandbox, long-term memory and automatic context compaction
- *(sync)* One-way LAN sync with PIN pairing, a self-hosted server backend,
  end-to-end envelope encryption, local zip backup, and a sync console with
  per-run logs
- *(media)* Originals are kept untouched, with tiered thumbnails, a tiled
  viewer for very large images, and text search over images via OCR
- *(export)* Export to Markdown, Word, PDF and image; import Markdown; share a
  diary as a single-entry export
- *(theme)* Grayscale, system-wallpaper and custom colour modes, with font
  scale following the system
- *(ui)* A new design system throughout — unified dialogs, sheets, menus and a
  frosted-glass bottom bar, a new video player, and the Android predictive
  back gesture
- *(security)* The app-lock PIN and API keys move into secure storage, with the
  PIN stored as an Argon2id hash

### ⚡ Performance

- Faster search and indexing, faster diary loading, and smoother scrolling
  through long diaries
- Faster app startup
- Faster media import, export and archiving

### ◀️ Removed

- *(scan)* QR code scanning
- *(sync)* Local JSON import and export
- *(theme)* The in-app font size setting; font scale now follows the system

## [2.7.3] - 2025-03-02

### 🚀 Features

- *(telegram-bot)* Enhance release notification workflow
- *(telegram-bot)* Enhance release notification workflow
- *(llama)* Add LlamaUtil class and update dependencies
- *(text)* Introduce AdaptiveText and EllipsisText components for improved text handling
- *(about)* Replace Text with AnimatedText for dynamic app info display
- *(cache)* Implement LRUCache and AsyncLRUCache for efficient data management
- *(font)* Streamline font loading
- *(font)* Add caching for font name and weight axis retrieval
- *(diary)* Enhance text handling by trimming titles and removing line breaks from content
- *(font)* Enhance font loading capabilities
- *(font)* Clear cache when font style change
- *(aes)* Add aes-gcm encryption algorithm
- Add secure storage to store user key
- Use the new route transition
- Optimize image preview
- Enhance image viewing experience with hero transitions and loading states
- Improve image handling with enhanced hero transitions and dynamic sizing
- Add WindowsBar and MoveTitle widgets for improved window management
- Enhance UI and improve desktop experience (#179)
- Add workflow_run trigger for Git Cliff completion
- Update changelog workflow to check PR merge status before generating changelog
- Add an abstract sync interface
- Enhance diary card views with icons and improve page transitions

### 🐛 Bug Fixes

- *(font)* Fix adding the font may cause the application crash
- *(font)* Fix font is not loaded when startup
- *(log)* Log did not work in release mode
- Route error
- Update application name and improve debug configuration
- Update localization configuration to include synthetic package option
- Update dependencies and remove unused localization imports
- Ci (#177)
- Correct syntax for workflow_run trigger in auto-merge.yml
- Update diary_view to use Get.put for DiaryLogic instantiation

### 💼 Other

- *(*)* Upgrade dependencies

### 🚜 Refactor

- Rename rust library from rust_lib_mood_diary to moodiary_rust
- Remove video page routing and update video state initialization
- Streamline theme management and dynamic color support
- Remove Objectbox plugin references and update tile caching implementation

### ⚙️ Miscellaneous Tasks

- *(*)* Update telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- *(*)* Adjust the output format of outdated dependencies in the Telegram bot workflow
- Update flutter_rust_bridge to version 2.7.1 and adjust generated files
- Update imports and refresh package version to 3.0.0
- Update readme
- *(*)* Upgrade flutter and frb version
- *(*)* Upgrade flutter version to 3.29.0
- Add git-cliff to generate changelog
- Add git-cliff to generate changelog
- Add git-cliff to generate changelog
- Add git-cliff to generate changelog
- Add git-cliff to generate changelog
- Upgrade actions/checkout to v4 across workflow files
- Fix cliff ci
- Update dependencies in pubspec.yaml to latest versions
- Update NDK and plugin versions in build configuration
- Update .gitignore
- *(fix build error)* [skip ci]

## [2.7.2] - 2025-01-27

### 🚀 Features

- *(ui)* Adjust lock page and correct localization
- *(markdown)* Add support for markdown diary
- *(android)* Update NDK and Kotlin versions
- *(dependencies)* Update SDK and package versions
- *(readme)* Update Flutter and Dart version requirements
- *(category)* Init support nested multi-level classification
- *(*)* Add workflow to send release notifications to Telegram
- *(ui)* Optimize home page ui
- *(ui)* Optimize UI details
- *(about)* Add easter eggs
- *(media)* Optimize UI layout
- *(markdown)* Add markdown preview support
- *(lint)* Add more lint rules
- *(about)* Enhance confetti effect and update duration
- *(text)* Optimize ellipsis text rendering
- *(ui)* Refine window buttons and UI components
- *(ui)* Add simple window button support for windows
- *(msix)* Add msix configuration for store publishing
- *(msix)* Update msix configuration for store
- *(msix)* Update msix config for store publishing
- *(pubspec)* Add logo path for desktop
- *(ui)* Enhance diary card text visibility and format
- *(markdown)* Support markdown editing and embed rendering
- *(home)* Add shadow option for the HomeFab component
- *(ui)* Enhance image viewing and navigation

### 🐛 Bug Fixes

- *(ui)* Improve desktop page switching performance
- *(ui)* Add microsoft yahei ui as default font at windows
- *(*)* Remove pull to refresh at desktop platform

### 💼 Other

- *(macos)* Update code signing and provisioning settings

### 🚜 Refactor

- *(*)* Organize the project structure and use absolute paths uniformly
- *(*)* Optimize project structure
- *(media)* Reconstruct the media library, with more animation and better performance

### 🎨 Styling

- Code clean

### ⚙️ Miscellaneous Tasks

- *(flutter)* Update flutter version to 3.27.2
- Simplify telegram release notification
- *(ci)* Enhance telegram notification with release details
- Refine release notification workflow
- Update Flutter version to 3.27.3
- Update shared_preferences_android to 2.4.3
- *(*)* Adjust msix_config settings in pubspec.yaml
- *(*)* Bump version to 2.7.2+72

## [2.7.1] - 2025-01-18

### 🚀 Features

- *(l10n)* Add full localization support
- *(edit)* Add audio file selection
- *(l10n)* Add localization for diary operations and data sync

### 🐛 Bug Fixes

- *(ci)* Add release drafter
- *(*)* Fix ci
- *(*)* Fix ci
- *(*)* Fix ci
- *(ci)* Fix ci (#107)
- *(*)* Fix ci
- *(*)* Fix ci
- *(calendar)* Filter visible diaries

### 💼 Other

- *(action)* Fix workflow
- *(android)* Upgrade AGP to 8.8.0
- *(android)* Upgrade AGP to 8.8.0

### ⚙️ Miscellaneous Tasks

- *(*)* Update readme
- *(*)* Optimize release note generation logic
- *(*)* Add flutter analyze workflow and dynamic flutter version support
- *(ci)* Adjust flutter analyze trigger
- *(ci)* Install dependencies for rust builder project in flutter analyze workflow
- *(workflow)* Update flutter analyze workflow
- *(ci)* Add dependency installation step for rust builder
- *(*)* Bump version to 2.7.1+71

## [2.7.0] - 2025-01-17

### 🚀 Features

- *(diary)* Init support for multi diary
- *(private)* Add private mode
- *(feedback)* Add new feedback
- *(lock)* Automatically invoke biometrics on startup
- *(edit)* Add multi image picker support
- *(webdav)* Added more option for webdav

### 🐛 Bug Fixes

- *(webdav)* Fix webdav error
- *(logger)* Fix logger can't export
- *(log)* Fix logger
- *(ci)* Fix workflow error (#105)
- *(ci)* Fix ci (#106)
- *(ci)* Fix work flows
- *(media_view)* Fix file time sorting bug in media library
- *(sync)* Fix local sync exception
- *(*)* Fix unexpected issue causing immediate lockup

### 💼 Other

- *(pub)* Update dependencies
- *(pub)* Upgrade dependencies
- *(pub)* Upgrade dependencies
- *(pub)* Upgrade dependencies

### 🚜 Refactor

- *(ui)* Improve ui
- *(ui)* Improve ui
- *(*)* Use refreshed to replace getx &use in app webview
- *(ui)* Improve ui
- *(ui)* Improve ui
- *(ui)* Limit the maximum height of media files in rich text to 300

### 🎨 Styling

- *(*)* Code clean up
- *(*)* Code clean
- *(*)* Code clean

### ⚙️ Miscellaneous Tasks

- *(*)* Update readme
- *(*)* Update readme
- *(*)* Update readme
- *(*)* Update readme
- *(*)* Release at 2.7.0

## [2.6.5] - 2025-01-02

### 🚀 Features

- *(category)* Init support nested multi-level classification
- *(font)* Add support for custom font
- *(ui)* Optimize image and video viewing
- *(ui)* Optimize desktop operating experience
- *(fvm)* Add fvm to manager flutter version
- *(*)* Improve category manager
- *(hitokoto)* Add hitokoto in title
- *(ui)* Add marquee to fix long text
- *(*)* Add dev mode

### 🐛 Bug Fixes

- *(fix display error when local send)* Closes #80
- *(android)* Fix release build error on android platform
- *(logger)* Fix can't catch error log at release mode
- *(webdav)* Fix webdav error when creating dir
- *(ui)* Fix text painter did not match custom text scale
- *(font)* Fix variable font misans vf
- *(action)* Fix github action

### 🚜 Refactor

- *(*)* Add some notice when catching error
- *(ui)* New bottom sheet ui & new theme color picker
- *(home)* New ui for home page
- *(ui)* Add animated switcher to fade
- *(ui)* Remove useless widget & add try catch for hitokoto

### 🎨 Styling

- *(code)* Cleanup the code
- *(*)* Code cleanup

### ⚙️ Miscellaneous Tasks

- *(*)* Update readme
- *(*)* Update readme
- *(*)* Fix isar build error
- *(*)* Release at 2.6.5

## [2.6.4] - 2024-12-15

### 🐛 Bug Fixes

- *(data)* Fix date merge error
- *(data)* Fix data merge error to 2.6.3
- *(diary)* Home page did not remove deleted diary

### 🚜 Refactor

- *(ui)* Improve ui

### ⚙️ Miscellaneous Tasks

- *(*)* Release at 2.6.4 as hotfix

## [2.6.3] - 2024-12-15

### 🚀 Features

- *(icon)* Add new icon for desktop
- *(webdav)* Improve webdav behavior
- *(*)* Add try catch
- *(sync)* Add local sync at home page
- *(webdav)* Improve webdav util
- *(save_image)* Add save image to local
- *(media)* Improve media library
- *(media)* Improve media

### 🐛 Bug Fixes

- *(layout)* Fix home page layout overflow
- *(desktop)* Improve desktop experience
- *(layout)* Fix layout
- *(logic)* Fix did not jump to new category tabview when add category
- *(webdav)* Local did not delete
- *(android)* Fix splash screen not full
- *(lab)* Key did not update after input
- *(log)* Error log did not write into file
- *(local_sync)* Category sync error
- *(location)* Fix can't get location on macos
- *(toast)* Remove flutter hook

### 🚜 Refactor

- *(*)* Remove hitokoto
- *(calendar)* Better calendar view
- *(l10n)* Refactor localization
- *(ui)* Refactor ui
- *(ui)* Refactor rich text adding media
- *(ui)* Make record_sheet_view higher

### ⚡ Performance

- *(image)* Improve image performance
- *(*)* Improve performance
- *(*)* Use isolate to improve performance

### 🎨 Styling

- *(*)* Code clean

### ⚙️ Miscellaneous Tasks

- *(*)* Hotfix at 2.6.1
- *(*)* Update readme
- *(isar)* Gen code
- *(*)* Release at 2.6.3

## [2.6.1] - 2024-12-11

### 🐛 Bug Fixes

- *(data)* Fix data merge error
- *(webdav)* Behavior when has no options
- *(rust)* Frb version
- *(*)* Can't start on some devices

### 🚜 Refactor

- *(*)* Remove font setting
- *(diary_detail)* Remove squad

## [2.6.0] - 2024-12-10

### 🚀 Features

- *(server)* Init server support
- *(kmp)* Add kmp search use rust
- *(webdav)* Init webdav util
- *(server)* Init server
- *(*)* Add rich text and media editor
- *(util)* Add keyboard listener
- *(icon)* Use new app icon
- *(webdav)* Support webdav sync
- *(webdav)* Improve webdav support
- *(edit)* Add auto select category
- *(*)* Add data merge to 2.6.0

### 🐛 Bug Fixes

- *(rust)* Fix string error in kmp
- *(ui)* Fixed layout issues with three-button navigation mode
- *(image_compress)* Fix can't compress heif image
- *(local_send)* Fix can't find ip at ethernet mode

### 💼 Other

- *(pubspec)* Upgrade dependencies
- *(rust)* Update dependencies
- *(rust)* Generated rust builder
- *(*)* Platform build option
- *(pubsepc)* Remove unused dependencies

### 🚜 Refactor

- *(ui)* Improve ui
- *(ui)* Improve ui
- *(*)* Use the new flutter api to catch error

### ⚡ Performance

- *(*)* Improve perf at home page

### ⚙️ Miscellaneous Tasks

- *(git)* Add attributes
- *(*)* Add workflows
- *(release)* Prepare release version 2.6.0

## [2.4.9] - 2024-11-19

### 🐛 Bug Fixes

- *(password)* Remove password error
- *(windows)* Fix biometric auth error in windows
- *(windows)* Fix get video thumbnail error in windows
- *(home)* Fix pagination error

### 🚜 Refactor

- *(image)* Use rust to compress image
- *(ui)* Add some animation
- *(ui)* Improve layout for better user experience
- *(ui)* Improve layout for better user experience
- *(*)* Add category manager

### 🎨 Styling

- *(*)* Code clean

### ⚙️ Miscellaneous Tasks

- *(*)* Release 2.4.9

## [2.4.8] - 2024-11-12

### 🐛 Bug Fixes

- *(*)* Fix many bugs

## [2.4.8-rc] - 2024-11-12

### 🚀 Features

- *(*)* Initial localization and LAN synchronization
- *(macos)* Prepare for macos support
- *(map)* Add map support for viewing and managing diary entry locations
- *(local_send)* Add local send support
- *(local_send)* More improve about local send
- *(*)* Add more function in home page

### 🐛 Bug Fixes

- *(search)* Add title search support
- *(*)* Fix title bar in macos
- *(local_send)* Fix modifying list in loop
- *(map)* Fix map cache error

### 💼 Other

- *(android)* Remove unused dependencies

### 🚜 Refactor

- *(*)* Improve performance

### 🎨 Styling

- *(*)* Code clean

### ⚙️ Miscellaneous Tasks

- *(*)* Release 2.4.8

## [2.4.7] - 2024-10-27

### 🚀 Features

- *(edit)* Add automatic weather getting
- *(page/map)* Map

### 🐛 Bug Fixes

- *(edit)* Fix tooltip position error
- *(edit)* Fix tooltip position
- *(category)* Fix category not be able to deselect
- *(file_util)* Fix share and data export error on windows

### ⚡ Performance

- *(page/setting)* Improve performance

### 🎨 Styling

- *(*)* Code clean

### ⚙️ Miscellaneous Tasks

- *(*)* Release 2.4.7

## [2.4.6] - 2024-10-18

### 🚀 Features

- *(update)* Add check update in app

### 🐛 Bug Fixes

- *(location)* Fix location error
- *(app)* Fix title display on some devices
- *(file_util)* Fix data import and export

## [2.4.5] - 2024-10-17

### 🚀 Features

- *(video)* Add support for video player

### 🐛 Bug Fixes

- *(*)* Landscape cannot be used on Android tablets
- *(weather)* Weather cannot be obtained due to positioning problems

### 💼 Other

- *(android)* Update gradle version
- *(*)* Update version

### 🚜 Refactor

- *(*)* Refactor directory structure
- *(*)* Refactor for  performance

### ⚙️ Miscellaneous Tasks

- *(*)* Code clean

## [2.4.4] - 2024-10-01

### 🚀 Features

- *(ask_question)* Add SQuAD task in diary
- *(media_view)* Add media view in navigator bar
- *(media_view)* Add image manager

### 💼 Other

- *(android)* Change the minSdk 26
- *(pubspec)* Update dependencies

### 🚜 Refactor

- *(*)* Optimize the color scheme

### ⚡ Performance

- *(setting_view)* Cache the list reduces unnecessary rebuild

### 🎨 Styling

- *(*)* Code clean

### ⚙️ Miscellaneous Tasks

- *(lint)* Add lint rules
- *(lfs)* Add lfs support

## [2.4.3] - 2024-09-23

### 🚀 Features

- *(calendar)* Add timeline view in calendar page
- *(home)* Auto hidden navigation bar
- *(calendar_view)* Add calendar view
- *(About)* Add about page
- *(Calendar)* Add expansion panel in calendar view

### 🐛 Bug Fixes

- *(isar)* Fix error when importing data
- *(home)* Fix scrolling error
- *(record_sheet)* Can not start recording after stop recording
- *(calendar)* Unnecessary build in calendar page
- *(*)* Diary is not change after edit or delete

### 💼 Other

- *(pubspec)* Update dependencies
- *(pubspec)* Update dependencies
- *(pubspec)* Update dependencies

### 🚜 Refactor

- *(wave_form)* Make wave form componentized
- *(*)* Make the code clear
- *(*)* Extract the border radius settings
- *(isar)* Add equal method in diary
- *(isar)* Rename the method
- *(pref)* Change the default color when start up
- *(*)* Remove useless method

### ⚙️ Miscellaneous Tasks

- *(theme)* New theme color
- *(*)* Code clean
- *(intl)* More localization
- *(intl)* More localization

## [2.4.2] - 2024-09-19

### 🚀 Features

- *(windows)* Prepare for windows platform
- *(assistant)* Prepare for assistant page

### 🐛 Bug Fixes

- *(diary_details)* Fix banner height
- *(home)* Fix multi scroll in home page
- *(permission_util)* Fix get location on android platform
- *(diary_card)* Fix  an unexpected jump after modify a diary

### 💼 Other

- *(pubspec)* Update dependencies
- *(android)* Remove unused abiFilters
- *(pubspec)* Update dependencies
- *(*)* Remove unused dependencies
- *(pubsepc)* Update dependencies
- *(android)* Update agp version

### 🚜 Refactor

- *(*)* There are so many changes, I don't know what changes, so fuck it

### ⚡ Performance

- *(*)* Improve performance in some cases

### ⚙️ Miscellaneous Tasks

- *(intl)* More localization

## [2.4.1] - 2024-08-26

### 🐛 Bug Fixes

- *(record_sheet)* Fix wave form width anomalies
- *(notice_util)* Something wrong when catching bugs

### 💼 Other

- *(pubspec)* Update dependencies

### ⚡ Performance

- *(home)* Improve performance in home view

<!-- generated by git-cliff -->
