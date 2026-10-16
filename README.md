# OmniReaderHQ

OmniReader is a modular Flutter reader for user-configured web catalogs and personal comic archives. The initial desktop target is macOS, with Android support (APK) available from the same codebase.

The app starts without a bundled catalog, reading history, favorites, or source URLs. On first launch, the user supplies a public catalog URL; catalog settings and reading data are stored locally on that installation.

## Features

- Modular catalog and archive-provider interfaces.
- Generic metadata extraction for blogs using the standard Blogger post layout.
- Local reading history, page progress, favorites, collections, and cache.
- On-demand archive handling for ZIP/CBZ and RAR/CBR files, subject to platform and archive compatibility.
- Page-based reader with zoom and saved reading position.
- Shared Flutter UI for macOS and Android, with local preferences and files.

## Technology

- Flutter and Dart
- HTML parsing and HTTP clients behind source adapters
- `archive` and `rar` libraries for archive handling
- SharedPreferences for local settings and progress
- Native macOS and Android runners

## Run locally

Install Flutter. For macOS, install Xcode and CocoaPods. For Android, install Android Studio or the Android SDK command-line tools and configure a JDK supported by the Flutter/Gradle toolchain.

```sh
flutter pub get
flutter run -d macos
```

To run on a connected Android device, list available devices and pass its ID:

```sh
flutter devices
flutter run -d <device-id>
```

## Build artifacts

Build the macOS app bundle:

```sh
flutter build macos --release
```

The `.app` bundle is created under `build/macos/Build/Products/Release/`. To package it as a compressed DMG on macOS:

```sh
hdiutil create \
  -volname "OmniReader" \
  -srcfolder "build/macos/Build/Products/Release/OmniReader.app" \
  -ov -format UDZO \
  "build/OmniReader-macos.dmg"
```

Build a release APK:

```sh
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The repository's current Android release configuration is intended for local testing; configure a private release keystore before publishing through an app store. Do not commit signing keys or passwords. macOS distribution outside local use also requires appropriate Apple signing and notarization.

The Android and macOS application identifiers are starter identifiers. Before publishing to an app store, replace them with a unique reverse-domain identifier you control.

## Legal notice

OmniReader is a software utility for catalogs and archive files selected or supplied by the user. It does not bundle a catalog, host, distribute, or endorse third-party content. Users are responsible for ensuring that their access to and use of any source or file is authorized and complies with applicable law and the source's terms.

## License

This project is distributed under the MIT License. See [LICENSE](LICENSE). Please preserve the copyright and license notices in copies or substantial portions of the software.
