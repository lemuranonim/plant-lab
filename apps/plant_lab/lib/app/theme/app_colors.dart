import 'package:flutter/material.dart';

class AppColors {
  // Light Palette (Crisp Agricultural Slate - Matching Web Portal & Professional Mobile Design)
  static const backgroundLight = Color(0xFFF8FAFC); // Clean Light Slate Page BG
  static const surfaceLight = Color(0xFFFFFFFF);    // Pure White Surface
  static const cardLight = Color(0xFFFFFFFF);       // Pure White Card
  static const cardBorderLight = Color(0xFFE2E8F0); // Subtle Slate Border
  static const textPrimaryLight = Color(0xFF0F172A); // Bold Dark Slate / Navy (High Contrast Title)
  static const textSecondaryLight = Color(0xFF334155); // Slate Body Text
  static const textMutedLight = Color(0xFF64748B); // Muted Slate Caption

  // Dark Palette
  static const backgroundDark = Color(0xFF0B110E);
  static const surfaceDark = Color(0xFF131C16);
  static const cardDark = Color(0xFF151F18);
  static const cardBorderDark = Color(0xFF1E293B);
  static const textPrimaryDark = Color(0xFFF8FAFC);
  static const textSecondaryDark = Color(0xFFCBD5E1);
  static const textMutedDark = Color(0xFF94A3B8);

  // Common Accents & Statuses
  static const accent = Color(0xFF10B981); // Emerald Green
  static const accentDark = Color(0xFF059669);
  static const accentLight = Color(0xFF34D399);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const statusProposed = Color(0xFFF59E0B);
  static const statusApproved = Color(0xFF10B981);
  static const statusRejected = Color(0xFFEF4444);
  static const statusDraft = Color(0xFF64748B);

  // Default Static Colors (Light mode primary for ultimate legibility)
  static const background = backgroundLight;
  static const surface = surfaceLight;
  static const card = cardLight;
  static const cardBorder = cardBorderLight;
  static const textPrimary = textPrimaryLight;
  static const textSecondary = textSecondaryLight;
  static const textMuted = textMutedLight;
}
