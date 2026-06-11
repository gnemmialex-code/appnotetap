import Flutter
import UIKit

// Délégué de scène minimal. L'ancien déclencheur de panneau (URL scheme
// shortist://tapback qui OUVRAIT l'app au premier plan) a été supprimé :
// le panneau au-dessus des autres apps est désormais rendu exclusivement
// par le système via le snippet App Intents (QuickPanel.swift), sans que
// l'app ne soit jamais activée.
class SceneDelegate: FlutterSceneDelegate {}
