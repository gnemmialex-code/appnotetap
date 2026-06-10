import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final tapBackTrigger = ValueNotifier<int>(0);

const _channel = MethodChannel('com.gnemmialex.tapbacknote/tapback');

void initTapBackChannel() {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'trigger') tapBackTrigger.value++;
  });
  // Récupère un trigger qui aurait eu lieu avant que Flutter soit prêt (cold start)
  _channel.invokeMethod('checkPendingTrigger').ignore();
}

Future<void> openAccessibilitySettings() async {
  try {
    await _channel.invokeMethod('openAccessibility');
  } catch (_) {}
}

/// Renvoie l'app en arrière-plan (retour à l'écran d'accueil de l'iPhone).
/// Utilisé quand on ferme la petite fenêtre rapide.
Future<void> minimizeApp() async {
  try {
    await _channel.invokeMethod('minimizeApp');
  } catch (_) {}
}
