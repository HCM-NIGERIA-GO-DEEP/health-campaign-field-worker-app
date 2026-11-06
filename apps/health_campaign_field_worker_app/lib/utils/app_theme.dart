import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

/// The app's light theme, built once.
///
/// `DigitExtendedTheme.getLightTheme()` returns a theme that is never `==` to
/// an earlier copy: its time-picker and button styles hold new closures on
/// every call. When `MaterialApp` gets a fresh copy on a rebuild, it runs a
/// 200 ms theme animation, and every widget that reads the theme is rebuilt on
/// each frame of it. The home stock card reloaded its data on each of those
/// frames (13 times per rebuild). Pass this one instance instead.
final ThemeData appLightTheme = DigitExtendedTheme.instance.getLightTheme();
