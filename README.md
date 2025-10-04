# SoundScript

Flutter app for audio recording and transcription.

## Setup

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure API Key

**IMPORTANT:** Before building/running the app, you must add your AssemblyAI API key.

1. Copy the example config file:
   ```bash
   copy lib\data\api_config.example.dart lib\data\api_config.dart
   ```

2. Open `lib/data/api_config.dart` and replace `YOUR_ASSEMBLYAI_API_KEY_HERE` with your actual API key:
   ```dart
   class ApiConfig {
     static const String assemblyAiApiKey = 'your_actual_api_key_here';
     static const String assemblyAiBaseUrl = 'https://api.assemblyai.com/v2';
   }
   ```

3. Get your API key from: https://www.assemblyai.com/

### 3. Run the App
```bash
flutter run
```

## Security Notes
- `lib/data/api_config.dart` is git-ignored for security
- Never commit your API key to version control
- The example file (`api_config.example.dart`) shows the structure without exposing your key
