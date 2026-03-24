// AppColors
// Centralised color palette. Category colors match seed data hex values.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color healthFitness      = Color(0xFF1D9E75);
  static const Color learningDev        = Color(0xFF534AB7);
  static const Color familyPersonal     = Color(0xFFBA7517);
  static const Color dailyRoutine       = Color(0xFF185FA5);

  /// Predefined color palette for category creation/editing.
  static const List<String> palette = [
    '#1D9E75', '#534AB7', '#BA7517', '#185FA5',
    '#E53935', '#8E24AA', '#00897B', '#F4511E',
    '#3949AB', '#039BE5', '#43A047', '#757575',
  ];

  /// Parse a hex color string like "#1D9E75" into a Flutter [Color].
  static Color hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
