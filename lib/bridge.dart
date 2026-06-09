import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final tapBackTrigger = ValueNotifier<int>(0);

const _channel = MethodChannel('com.gnemmialex.tapbacknote/tapback');

void initTapBackChannel() {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'trigger') tapBackTrigger.value++;
  });
}

Future<void> openAccessibilitySettings() async {
  try {
    await _channel.invokeMethod('openAccessibility');
  } catch (_) {}
}
