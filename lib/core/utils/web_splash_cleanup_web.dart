import 'package:web/web.dart' as web;

void removeWebSplashFallback() {
  web.document.getElementById('splash')?.remove();
  web.document.getElementById('splash-branding')?.remove();
  web.document.body?.style.background = 'transparent';
}
