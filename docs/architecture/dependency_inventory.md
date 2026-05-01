# Dependency Inventory

## 1. MOBI (Flutter Master Shell)
**SDK:** Flutter (`sdk: flutter`), Dart `^3.10.8`

**Key Dependencies:**
- State Management: `flutter_riverpod: ^3.3.1`
- Navigation: `go_router: ^17.1.0`
- Networking/API: `dio: ^5.9.2`, `supabase_flutter: ^2.12.0`
- Storage: `shared_preferences: ^2.5.4`, `flutter_secure_storage: ^9.2.4`
- Firebase: `firebase_core`, `firebase_crashlytics`, `firebase_analytics`, `firebase_remote_config`, `firebase_auth`, `firebase_messaging`
- UI: `google_fonts`, `flutter_animate`, `shimmer`, `cached_network_image`, `lucide_icons`
- Utilities: `intl`, `logger`, `freezed_annotation`, `json_annotation`, `geolocator`, `permission_handler`, `connectivity_plus`, `flutter_native_splash`

## 2. PayLedger (Android Kotlin Engine)
**SDK:** Android `compileSdk 35`, `minSdk 26`
**Language:** Kotlin `2.1.0`

**Key Dependencies (to be ported into MOBI Android runtime):**
- UI (To be discarded): Jetpack Compose (`compose-bom`, `material3`, `navigation-compose`)
- Database: Room (`room-runtime`, `room-ktx`, `room-compiler`) `2.6.1`
- Security/Encryption: `security-crypto`, SQLCipher (`sqlcipher-android`), `sqlite-ktx`
- Background Tasks: WorkManager (`work-runtime-ktx`)
- Supabase (Kotlin Client): `postgrest-kt`, `realtime-kt`, `auth-kt`, `functions-kt` (via `bom 3.0.3`)
- Networking: Ktor (`ktor-client-okhttp`)
- Export: Apache POI
- DI (To be discarded/simplified): Koin

## 3. BioPay (Flutter + FastAPI backend)
**Flutter Dependencies (to be merged into MOBI pubspec):**
- ML & Camera: `camera`, `google_mlkit_face_detection`, `tflite_flutter`
- QR & NFC: `qr_flutter`, `mobile_scanner`, `flutter_nfc_kit`, `ndef`
- Auth & Image processing: `local_auth`, `image`

**FastAPI Backend Dependencies (Python):**
- Framework: `fastapi==0.115.12`, `uvicorn[standard]==0.34.0`
- Database/API: `supabase==2.15.0`, `psycopg[binary]==3.2.6` (pgvector)
- Validation: `pydantic`, `pydantic-settings`
- Auth: `PyJWT[crypto]`
- Networking: `httpx`
