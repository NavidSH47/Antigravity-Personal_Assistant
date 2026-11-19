import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsDrawer extends StatelessWidget {
  final ThemeVibe currentVibe;
  final AppFontStyle currentFont;
  final VibePalette palette;
  final Function(ThemeVibe) onSelectVibe;
  final Function(AppFontStyle) onSelectFont;
  final double fontSizeScale;
  final Function(double) onFontSizeScaleChanged;

  const SettingsDrawer({
    super.key,
    required this.currentVibe,
    required this.currentFont,
    required this.palette,
    required this.onSelectVibe,
    required this.onSelectFont,
    this.fontSizeScale = 1.0,
    required this.onFontSizeScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: palette.bgElevated,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text('⚙️ ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            'Appearance & Settings',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: palette.textMain,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: palette.borderSubtle, height: 1),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- COLOR VIBE THEMES ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'COLOR VIBE THEMES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: palette.textDim,
                            letterSpacing: 0.6,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          AppTheme.vibes[currentVibe]!.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: palette.accentPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Themes Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.8,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: ThemeVibe.values.length,
                    itemBuilder: (context, index) {
                      final vibe = ThemeVibe.values[index];
                      final info = AppTheme.vibes[vibe]!;
                      final isActive = vibe == currentVibe;

                      return InkWell(
                        onTap: () => onSelectVibe(vibe),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.bgSurface,
                            border: Border.all(
                              color: isActive
                                  ? palette.accentPrimary
                                  : palette.borderSubtle,
                              width: isActive ? 1.5 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  gradient: info.sampleGradient,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  info.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: palette.textMain,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // --- TYPOGRAPHY FONT PICKER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FONT STYLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: palette.textDim,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        AppTheme.getFontLabel(currentFont),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: palette.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Fonts Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: AppFontStyle.values.length,
                    itemBuilder: (context, index) {
                      final font = AppFontStyle.values[index];
                      final label = AppTheme.getFontLabel(font);
                      final isActive = font == currentFont;

                      String desc = 'Modern system clean';
                      if (font == AppFontStyle.comicSans) {
                        desc = 'Playful (Persian in Default)';
                      } else if (font == AppFontStyle.roundedBold) {
                        desc = 'Smooth soft corners';
                      } else if (font == AppFontStyle.techMono) {
                        desc = 'Code & terminal look';
                      } else if (font == AppFontStyle.editorialSerif) {
                        desc = 'Bookish elegance';
                      }

                      return InkWell(
                        onTap: () => onSelectFont(font),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.bgSurface,
                            border: Border.all(
                              color: isActive
                                  ? palette.accentPrimary
                                  : palette.borderSubtle,
                              width: isActive ? 1.5 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textMain,
                                  fontFamily: AppTheme.getFontFamilyName(font),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: palette.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // --- GLOBAL FONT SIZE SCALING ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FONT SIZE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: palette.textDim,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Aa — ${(fontSizeScale * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: palette.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: palette.accentPrimary,
                      inactiveTrackColor: palette.borderSubtle,
                      thumbColor: palette.accentPrimary,
                      overlayColor: palette.accentPrimary.withValues(alpha: 0.2),
                      valueIndicatorColor: palette.bgSurface,
                      valueIndicatorTextStyle: TextStyle(color: palette.textMain),
                    ),
                    child: Slider(
                      value: fontSizeScale.clamp(0.8, 1.4),
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      onChanged: (val) {
                        onFontSizeScaleChanged(double.parse(val.toStringAsFixed(1)));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Compact\n(80%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: palette.textMuted))),
                        Expanded(child: Text('Default\n(100%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: palette.textMuted))),
                        Expanded(child: Text('Large\n(120%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: palette.textMuted))),
                        Expanded(child: Text('Extra Large\n(140%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: palette.textMuted))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
