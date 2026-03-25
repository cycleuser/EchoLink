# EchoLink

Cross-platform Wi-Fi P2P communication application enabling direct device-to-device communication without any infrastructure or base station.

## Features

- **Cross-Platform P2P Communication**: Support for both Android and iOS devices
- **One-to-One Chat**: Direct messaging between two devices
- **Group Communication**: Create and join groups for multi-device communication
- **File Transfer**: Send and receive files with progress tracking
- **Auto Discovery**: Automatically discover nearby devices
- **Offline Communication**: No internet connection required

## Communication Architecture

EchoLink uses a hybrid communication strategy:

| Platform Pair | Technology | Performance |
|--------------|------------|-------------|
| Android ↔ Android | Wi-Fi Direct (P2P) | Best |
| iOS ↔ iOS | Multipeer Connectivity | Best |
| Android ↔ iOS | Wi-Fi Hotspot Bridge | Good |

## Project Structure

```
echolink/
├── lib/
│   ├── core/                    # Core infrastructure
│   │   ├── constants.dart       # App constants
│   │   ├── result.dart          # Result pattern
│   │   ├── exceptions.dart      # Custom exceptions
│   │   └── utils/               # Utilities
│   │
│   ├── domain/                  # Domain layer
│   │   ├── models/              # Data models
│   │   ├── repositories/        # Repository interfaces
│   │   └── usecases/            # Business use cases
│   │
│   ├── infrastructure/          # Infrastructure layer
│   │   ├── network/             # Network services
│   │   │   ├── connection_manager.dart
│   │   │   ├── protocols/       # Communication protocols
│   │   │   └── platforms/       # Platform-specific implementations
│   │   ├── storage/             # Local storage
│   │   └── permissions/         # Permission handling
│   │
│   ├── presentation/            # Presentation layer
│   │   ├── pages/               # UI pages
│   │   ├── widgets/             # Reusable widgets
│   │   ├── providers/           # State management
│   │   └── theme/               # App theming
│   │
│   └── main.dart                # App entry point
│
├── test/                        # Test suite
│   ├── unit/
│   ├── widget/
│   └── integration/
│
└── platforms/                   # Platform-specific code
    ├── android/
    └── ios/
```

## Requirements

- Flutter SDK 3.0.0 or higher
- Dart 3.0.0 or higher
- Android SDK 21+ (Android 5.0+)
- iOS 12.0+

## Permissions

### Android
- `ACCESS_FINE_LOCATION` - Required for Wi-Fi P2P discovery
- `ACCESS_COARSE_LOCATION` - Location access
- `NEARBY_WIFI_DEVICES` - Nearby device discovery (Android 13+)
- `ACCESS_WIFI_STATE` - Wi-Fi state access
- `CHANGE_WIFI_STATE` - Wi-Fi configuration
- `INTERNET` - Network access

### iOS
- Local Network Usage - Required for Bonjour discovery
- Bluetooth Permission - For Multipeer Connectivity

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourorg/echolink.git
cd echolink
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Usage

### Device Discovery
1. Open the app on both devices
2. Tap "Discover Devices" on the home screen
3. Wait for nearby devices to appear
4. Tap on a device to connect

### Chat
1. Connect to a device first
2. Navigate to the Chat tab
3. Type your message and tap send

### File Transfer
1. Connect to a device first
2. Navigate to the Transfer tab
3. Tap "Send File" to select a file
4. Monitor progress in the transfer list

## Architecture

EchoLink follows Clean Architecture principles:

1. **Domain Layer**: Contains business logic, models, and repository interfaces
2. **Infrastructure Layer**: Implements repositories and platform-specific services
3. **Presentation Layer**: UI components and state management

## Key Components

### ConnectionManager
Manages device discovery, connection establishment, and data channels.

### MessageProtocol
Binary protocol for efficient message serialization and transmission.

### FileProtocol
Chunked file transfer with progress tracking and checksum verification.

### PermissionHandler
Cross-platform permission request and verification.

## Testing

Run unit tests:
```bash
flutter test test/unit/
```

Run integration tests:
```bash
flutter test integration_test/
```

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a pull request.

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/yourorg/echolink/issues) page.