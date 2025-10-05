# 🎙️ SoundScript# SoundScript



**SoundScript** is a modern Flutter application for audio recording and AI-powered transcription. Record audio on mobile or web, get real-time transcriptions with word-level timestamps, and enjoy seamless playback synchronization.Flutter app for audio recording and transcription.



![Flutter](https://img.shields.io/badge/Flutter-3.27.1-blue)## Setup

![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-green)

![License](https://img.shields.io/badge/License-MIT-yellow)### 1. Install Dependencies

```bash

## ✨ Featuresflutter pub get

```

### 🎤 Recording

- **Multi-platform**: Record audio on iOS, Android, and Web### 2. Configure API Key

- **Blob URL support**: Efficient audio handling on web browsers

- **High-quality audio**: AAC/M4A format recording**IMPORTANT:** Before building/running the app, you must add your AssemblyAI API key.

- **File picker**: Import existing audio files

1. Copy the example config file:

### 📝 Transcription   ```bash

- **AI-powered**: Custom API backend for speech-to-text   copy lib\data\api_config.example.dart lib\data\api_config.dart

- **Word-level timestamps**: Precise timing for each word   ```

- **Real-time status**: Live updates during transcription processing

- **High accuracy**: Professional-grade transcription quality2. Open `lib/data/api_config.dart` and replace `YOUR_ASSEMBLYAI_API_KEY_HERE` with your actual API key:

   ```dart

### 🎧 Playback   class ApiConfig {

- **Synchronized text**: Words highlight as audio plays     static const String assemblyAiApiKey = 'your_actual_api_key_here';

- **Playback controls**: Play, pause, seek, skip forward/backward     static const String assemblyAiBaseUrl = 'https://api.assemblyai.com/v2';

- **Progress tracking**: Visual timeline with current position   }

- **Web-aware**: Smart handling of blob URL limitations   ```



### 💾 Storage3. Get your API key from: https://www.assemblyai.com/

- **Local database**: Hive-based storage for offline access

- **Persistent transcripts**: Transcriptions survive page refreshes### 3. Run the App

- **Recording history**: Access all your past recordings```bash

- **Edit & manage**: Update titles, view details, delete recordingsflutter run

```

### 🌐 Web Support

- **Full functionality**: Recording and transcription on web browsers## Security Notes

- **User notifications**: Clear warnings about browser limitations- `lib/data/api_config.dart` is git-ignored for security

- **Responsive design**: Works on desktop and mobile browsers- Never commit your API key to version control

- **PWA ready**: Progressive Web App capabilities- The example file (`api_config.example.dart`) shows the structure without exposing your key


## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.27.1 or higher
- Dart SDK 3.6.0 or higher
- For mobile: Android Studio or Xcode
- For web: Chrome browser

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sunnydodti/sound-script.git
   cd sound-script
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API** (see [API Setup](docs/api-setup.md))
   ```dart
   // lib/data/api_config.dart
   class ApiConfig {
     static const bool isDevelopment = true;
     
     static String get apiBaseUrl {
       if (isDevelopment) {
         return 'http://127.0.0.1:8787/api/v1';
       } else {
         return 'https://soundscript-api.dodtisunny.workers.dev/api/v1';
       }
     }
   }
   ```

4. **Run the app**
   ```bash
   # For web
   flutter run -d chrome
   
   # For mobile
   flutter run -d <device_id>
   ```

## 📚 Documentation

- **[API Specification](docs/api-specification.md)** - Complete API endpoint documentation
- **[API Setup Guide](docs/api-setup.md)** - Step-by-step API configuration
- **[Web Compatibility](docs/web-platform.md)** - Web-specific features and limitations
- **[Features Overview](docs/features.md)** - Technical implementation overview

## 🏗️ Architecture

```
soundscript/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # Main app widget
│   ├── data/
│   │   ├── api_config.dart       # API configuration
│   │   ├── constants.dart        # App constants
│   │   ├── theme.dart            # App theming
│   │   └── provider/             # State management
│   ├── models/                   # Data models
│   ├── pages/                    # UI screens
│   ├── service/                  # Business logic & API
│   └── startup_service.dart      # App initialization
├── docs/                         # Documentation
├── android/                      # Android platform code
├── ios/                          # iOS platform code
├── web/                          # Web platform code
└── windows/                      # Windows platform code
```

## 🔧 Configuration

### Development Mode

```dart
// lib/data/api_config.dart
static const bool isDevelopment = true; // Use local API
```

### Production Mode

```dart
// lib/data/api_config.dart
static const bool isDevelopment = false; // Use production API
```

## 🌐 API Requirements

SoundScript requires a backend API with three endpoints:

1. **POST /api/v1/upload** - Upload audio file
2. **POST /api/v1/transcribe** - Start transcription
3. **GET /api/v1/transcript/{id}** - Get transcription result

See [API Specification](docs/api-specification.md) for detailed requirements.

## 📱 Platform Support

| Platform | Recording | Transcription | Playback | Notes |
|----------|-----------|---------------|----------|-------|
| iOS | ✅ | ✅ | ✅ | Full support |
| Android | ✅ | ✅ | ✅ | Full support |
| Web | ✅ | ✅ | ⚠️ | Blob URLs invalid after refresh |
| Windows | ❌ | ✅ | ✅ | File picker only |
| macOS | ❌ | ✅ | ✅ | File picker only |
| Linux | ❌ | ✅ | ✅ | File picker only |

## 🎨 Theming

SoundScript supports light and dark themes with customizable accent colors:

```dart
// lib/data/theme.dart
MaterialColor accentColor = Colors.blue; // Change to your brand color
```

## 🔐 Security

- ✅ No API keys stored in client code
- ✅ Open API (backend handles auth)
- ✅ Local data encryption (Hive)
- ✅ Blob URL isolation per session
- ✅ CORS-enabled for web

## 🐛 Known Limitations

### Web Platform
- **Audio persistence**: Recorded audio cannot be played after page refresh due to browser blob URL restrictions
- **Workaround**: Transcripts remain available and can be viewed/edited
- **User notification**: App shows clear warnings about this limitation

See [Web Compatibility](docs/web-platform.md) for details.

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - UI framework
- [flutter_sound](https://pub.dev/packages/flutter_sound) - Audio recording/playback
- [Hive](https://pub.dev/packages/hive_ce) - Local database
- [AssemblyAI](https://www.assemblyai.com/) - Transcription API reference

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/sunnydodti/sound-script/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sunnydodti/sound-script/discussions)
- **Email**: dodtisunny@gmail.com

## 🗺️ Roadmap

- [ ] Speaker diarization
- [ ] Multiple language support
- [ ] Audio editing features
- [ ] Cloud sync
- [ ] Export to various formats (PDF, DOCX, etc.)
- [ ] Real-time streaming transcription
- [ ] Collaboration features

---

**Built with ❤️ using Flutter**
