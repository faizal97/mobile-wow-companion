import 'package:flutter/material.dart';

class NewsSourceColors {
  NewsSourceColors._();

  static const Color blizzard = Color(0xFF00AEFF);
  static const Color wowhead = Color(0xFFDE3804);
  static const Color mmochampion = Color(0xFFA335EE);
  static const Color icyveins = Color(0xFF69CCF0);
  static const Color reddit = Color(0xFFFF4500);

  static Color forSource(String source) {
    switch (source) {
      case 'blizzard': return blizzard;
      case 'wowhead': return wowhead;
      case 'mmochampion': return mmochampion;
      case 'icyveins': return icyveins;
      case 'reddit': return reddit;
      default: return const Color(0xFF3FC7EB);
    }
  }

  static String displayName(String source) {
    switch (source) {
      case 'blizzard': return 'BLIZZARD';
      case 'wowhead': return 'WOWHEAD';
      case 'mmochampion': return 'MMO-C';
      case 'icyveins': return 'ICYVEINS';
      case 'reddit': return 'REDDIT';
      default: return source.toUpperCase();
    }
  }

  static Color forSourceDark(String source) {
    return Color.lerp(forSource(source), Colors.black, 0.7)!;
  }

  static Color forSourceSurface(String source) {
    return forSource(source).withValues(alpha: 0.08);
  }
}
