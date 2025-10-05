# Sound Script API Specification

## Overview
This API serves as a backend for the Sound Script Flutter application, providing audio transcription services. The API acts as a proxy/wrapper around AssemblyAI's transcription service or implements its own speech-to-text functionality.

**Base URL:** `https://your-api-domain.com/api/v1`

---

## Authentication

All API requests must include an authorization header:

```http
Authorization: Bearer YOUR_API_KEY
```

---

## API Endpoints

### 1. Upload Audio File

**Endpoint:** `POST /upload`

**Description:** Upload an audio file to the server for transcription processing.

**Headers:**
```http
Authorization: Bearer YOUR_API_KEY
Content-Type: application/octet-stream
```

**Request Body:**
- **Type:** Binary audio file data
- **Supported Formats:** WAV, MP3, M4A, AAC, FLAC, OGG
- **Max Size:** Recommended 100MB

**Response:**

**Success (200 OK):**
```json
{
  "upload_url": "https://your-storage.com/audio/unique-file-id.wav"
}
```

**Error (400/500):**
```json
{
  "error": "Error message describing what went wrong"
}
```

**Example cURL:**
```bash
curl -X POST https://your-api-domain.com/api/v1/upload \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @audio.wav
```

---

### 2. Submit Transcription Request

**Endpoint:** `POST /transcribe`

**Description:** Submit an audio URL for transcription.

**Headers:**
```http
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

**Request Body:**
```json
{
  "audio_url": "https://your-storage.com/audio/unique-file-id.wav",
  "language_code": "en",
  "punctuate": true,
  "format_text": true
}
```

**Request Fields:**
- `audio_url` (string, required): URL of the uploaded audio file
- `language_code` (string, optional): Language code (default: "en")
- `punctuate` (boolean, optional): Add punctuation (default: true)
- `format_text` (boolean, optional): Format text properly (default: true)

**Response:**

**Success (200 OK):**
```json
{
  "id": "transcript_abc123xyz789"
}
```

**Error (400/500):**
```json
{
  "error": "Error message describing what went wrong"
}
```

**Example cURL:**
```bash
curl -X POST https://your-api-domain.com/api/v1/transcribe \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "audio_url": "https://your-storage.com/audio/unique-file-id.wav",
    "language_code": "en",
    "punctuate": true,
    "format_text": true
  }'
```

---

### 3. Get Transcription Result

**Endpoint:** `GET /transcript/{transcript_id}`

**Description:** Retrieve the transcription result. This endpoint will be polled every 3 seconds until the transcription is complete.

**Headers:**
```http
Authorization: Bearer YOUR_API_KEY
```

**URL Parameters:**
- `transcript_id` (string, required): The ID returned from the transcribe endpoint

**Response:**

**Processing/Queued (200 OK):**
```json
{
  "id": "transcript_abc123xyz789",
  "status": "queued"
}
```
or
```json
{
  "id": "transcript_abc123xyz789",
  "status": "processing"
}
```

**Completed (200 OK):**
```json
{
  "id": "transcript_abc123xyz789",
  "status": "completed",
  "text": "Hello, how are you? I am doing great today.",
  "words": [
    {
      "text": "Hello",
      "start": 0,
      "end": 500
    },
    {
      "text": "how",
      "start": 500,
      "end": 800
    },
    {
      "text": "are",
      "start": 800,
      "end": 1100
    },
    {
      "text": "you",
      "start": 1100,
      "end": 1400
    },
    {
      "text": "I",
      "start": 1600,
      "end": 1700
    },
    {
      "text": "am",
      "start": 1700,
      "end": 1900
    },
    {
      "text": "doing",
      "start": 1900,
      "end": 2200
    },
    {
      "text": "great",
      "start": 2200,
      "end": 2600
    },
    {
      "text": "today",
      "start": 2600,
      "end": 3000
    }
  ]
}
```

**Error (200 OK):**
```json
{
  "id": "transcript_abc123xyz789",
  "status": "error",
  "error": "Audio file format not supported"
}
```

**Response Fields:**
- `id` (string): The transcript ID
- `status` (string): One of: "queued", "processing", "completed", "error"
- `text` (string): Full transcript text (only present when status is "completed")
- `words` (array): Array of word objects with timestamps (only present when status is "completed")
  - `text` (string): The word text
  - `start` (number): Start time in milliseconds
  - `end` (number): End time in milliseconds
- `error` (string): Error message (only present when status is "error")

**Example cURL:**
```bash
curl -X GET https://your-api-domain.com/api/v1/transcript/transcript_abc123xyz789 \
  -H "Authorization: Bearer YOUR_API_KEY"
```

---

## Client Flow

The Flutter app follows this workflow:

```
1. User records/picks audio
   ↓
2. App uploads audio → POST /upload
   ↓ (receives upload_url)
3. App submits transcription → POST /transcribe
   ↓ (receives transcript_id)
4. App polls for result → GET /transcript/{id}
   ↓ (every 3 seconds until status is "completed" or "error")
5. App displays transcript to user
```

---

## Status Update Flow

The app provides real-time status updates to the user:

1. **Uploading** - While uploading audio file
2. **Uploaded** - Upload complete, submitting transcription
3. **Processing** - Transcription in progress
4. **Completed** - Transcription finished successfully
5. **Error** - An error occurred

---

## Error Handling

### HTTP Status Codes

- **200 OK** - Request successful
- **400 Bad Request** - Invalid request (missing fields, invalid format)
- **401 Unauthorized** - Invalid or missing API key
- **413 Payload Too Large** - Audio file exceeds size limit
- **500 Internal Server Error** - Server error

### Error Response Format

All errors should return a JSON object with an `error` field:

```json
{
  "error": "Detailed error message"
}
```

---

## Implementation Notes

### For Backend Developers

1. **Audio Upload Storage:**
   - Store uploaded audio files temporarily (can delete after transcription)
   - Use cloud storage (AWS S3, Google Cloud Storage, Azure Blob, etc.)
   - Generate unique URLs for each upload

2. **Transcription Processing:**
   - You can use AssemblyAI API as the underlying service
   - Or implement your own speech-to-text model
   - Queue system recommended for handling multiple requests

3. **Polling vs Webhooks:**
   - Current implementation uses polling (app checks every 3 seconds)
   - Optional: Implement webhook support for push notifications

4. **Security:**
   - Validate API keys
   - Rate limiting recommended
   - Validate audio file formats
   - Set file size limits

5. **CORS:**
   - Enable CORS if the Flutter web app runs on a different domain
   - Allow headers: `Authorization`, `Content-Type`
   - Allow methods: `GET`, `POST`

---

## Example Backend Implementation (Node.js/Express)

```javascript
const express = require('express');
const multer = require('multer');
const axios = require('axios');

const app = express();
const upload = multer({ storage: multer.memoryStorage() });

// Upload endpoint
app.post('/api/v1/upload', upload.single('file'), async (req, res) => {
  try {
    // Upload to your storage (S3, etc.)
    const uploadUrl = await uploadToStorage(req.file.buffer);
    res.json({ upload_url: uploadUrl });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Transcribe endpoint
app.post('/api/v1/transcribe', express.json(), async (req, res) => {
  try {
    const { audio_url, language_code, punctuate, format_text } = req.body;
    
    // Call AssemblyAI or your transcription service
    const response = await axios.post('https://api.assemblyai.com/v2/transcript', {
      audio_url,
      language_code,
      punctuate,
      format_text
    }, {
      headers: {
        'authorization': 'YOUR_ASSEMBLYAI_API_KEY'
      }
    });
    
    res.json({ id: response.data.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get transcript endpoint
app.get('/api/v1/transcript/:id', async (req, res) => {
  try {
    const response = await axios.get(
      `https://api.assemblyai.com/v2/transcript/${req.params.id}`,
      {
        headers: {
          'authorization': 'YOUR_ASSEMBLYAI_API_KEY'
        }
      }
    );
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

---

## Testing

### Test with cURL

```bash
# 1. Upload audio
curl -X POST https://your-api-domain.com/api/v1/upload \
  -H "Authorization: Bearer test_api_key" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @test_audio.wav

# 2. Submit transcription
curl -X POST https://your-api-domain.com/api/v1/transcribe \
  -H "Authorization: Bearer test_api_key" \
  -H "Content-Type: application/json" \
  -d '{"audio_url": "returned_upload_url", "language_code": "en"}'

# 3. Get result
curl -X GET https://your-api-domain.com/api/v1/transcript/returned_transcript_id \
  -H "Authorization: Bearer test_api_key"
```

---

## Configuration in Flutter App

Update `lib/data/api_config.dart`:

```dart
class ApiConfig {
  static const String assemblyAiApiKey = 'YOUR_API_KEY';
}
```

Update `lib/service/custom_api_service.dart`:

```dart
final String _baseUrl = 'https://your-api-domain.com/api/v1';
```

---

## Deployment Checklist

- [ ] API deployed and accessible
- [ ] HTTPS enabled (SSL certificate)
- [ ] CORS configured for web app
- [ ] API key authentication working
- [ ] Upload endpoint tested
- [ ] Transcribe endpoint tested
- [ ] Get transcript endpoint tested
- [ ] Error handling implemented
- [ ] Rate limiting configured
- [ ] File size limits enforced
- [ ] Storage configured (S3, etc.)
- [ ] Update Flutter app with API base URL
- [ ] Update Flutter app with API key

---

## Support

For issues or questions about the API integration, please refer to:
- AssemblyAI Documentation: https://www.assemblyai.com/docs
- Flutter HTTP Package: https://pub.dev/packages/http
