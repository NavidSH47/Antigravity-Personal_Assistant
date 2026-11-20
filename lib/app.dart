import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

class NSHAssistantApp extends StatefulWidget {
  final StorageService storage;

  const NSHAssistantApp({super.key, required this.storage});

  @override
  State<NSHAssistantApp> createState() => _NSHAssistantAppState();
}

class _NSHAssistantAppState extends State<NSHAssistantApp> {
  late ThemeVibe _currentVibe;
  late AppFontStyle _currentFont;
  late double _fontSizeScale;

  @override
  void initState() {
    super.initState();
    _currentVibe = widget.storage.loadThemeVibe();
    _currentFont = widget.storage.loadFontStyle();
    _fontSizeScale = widget.storage.loadFontSizeScale();
  }

  void _updateThemeVibe(ThemeVibe vibe) {
    setState(() => _currentVibe = vibe);
    widget.storage.saveThemeVibe(vibe);
  }

  void _updateFontStyle(AppFontStyle font) {
    setState(() => _currentFont = font);
    widget.storage.saveFontStyle(font);
  }

  void _updateFontSizeScale(double scale) {
    setState(() => _fontSizeScale = scale);
    widget.storage.saveFontSizeScale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSH Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.createTheme(_currentVibe, _currentFont),
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: TextScaler.linear(_fontSizeScale),
          ),
          child: child!,
        );
      },
      home: HomeScreen(
        storage: widget.storage,
        currentVibe: _currentVibe,
        currentFont: _currentFont,
        fontSizeScale: _fontSizeScale,
        onSelectVibe: _updateThemeVibe,
        onSelectFont: _updateFontStyle,
        onSelectFontSizeScale: _updateFontSizeScale,
      ),
    );
  }
}
