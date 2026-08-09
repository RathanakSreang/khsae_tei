import 'package:flutter/material.dart';

/// Shared dark/cosmic palette used by Home and Settings so the two tabs
/// (and the bottom nav shell around them) read as one consistent app
/// instead of Home's dark redesign against Settings' unstyled Material
/// defaults.
const kBgTop = Color(0xFF081420);
const kBgBottom = Color(0xFF0B1E30);
const kAccent = Color(0xFF35E3EA);
const kAccentDim = Color(0xB335E3EA);
const kCardBorder = Color(0x1FFFFFFF);
const kCardFill = Color(0x0DFFFFFF);

const kBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kBgTop, kBgBottom],
);

/// Input decoration theme for text fields on the dark background - default
/// Material `TextField` styling assumes a light surface and is unreadable
/// against this palette without this.
final kDarkInputDecorationTheme = InputDecorationTheme(
  labelStyle: const TextStyle(color: Colors.white60),
  hintStyle: const TextStyle(color: Colors.white38),
  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kCardBorder)),
  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kAccent)),
  filled: false,
);
