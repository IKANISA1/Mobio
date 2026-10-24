import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Restores an attached, input-focused Flutter control for an Android reader.
///
/// The caller resolves the current semantics ID after modal disposal. Android
/// declines the request if another control already has accessibility focus.
abstract final class AccessibilityFocusService {
  static const _channel = MethodChannel('rw.mobi.app/accessibility_focus');

  static Future<bool> restoreFocus(int nodeId) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        nodeId < 0) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('restoreFocus', {
            'nodeId': nodeId,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
