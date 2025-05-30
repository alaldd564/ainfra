import 'package:flutter/material.dart';

class BrightnessSettings extends ChangeNotifier {
  double brightness = 1.0;
  double saturation = 1.0;
  double lightness = 0.5;

  void updateBrightness(double value) {
    brightness = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void updateSaturation(double value) {
    saturation = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void updateLightness(double value) {
    lightness = value.clamp(0.0, 1.0);
    notifyListeners();
  }
}
  