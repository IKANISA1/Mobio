# Testing

Required verification commands for structural changes:

```bash
./scripts/ci/verify_backend.sh
./scripts/ci/verify_flutter.sh
git diff --check
```

Android-native changes should also run:

```bash
cd android
./gradlew :app:compileDebugKotlin
```

Supabase release checks should include linked public-schema lint when credentials are available:

```bash
supabase db lint --linked --schema public --fail-on error
```
