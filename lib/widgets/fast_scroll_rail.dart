import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FastScrollSection {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;
  final double weight;

  const FastScrollSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isEnabled = true,
    this.weight = 1.0,
  });
}

class FastScrollRail extends StatefulWidget {
  final ScrollController controller;
  final VibePalette palette;
  final List<FastScrollSection> sections;

  const FastScrollRail({
    super.key,
    required this.controller,
    required this.palette,
    required this.sections,
  });

  @override
  State<FastScrollRail> createState() => _FastScrollRailState();
}

class _FastScrollRailState extends State<FastScrollRail>
    with SingleTickerProviderStateMixin {
  // Visibility
  bool _isVisible = false;
  Timer? _hideTimer;

  // Drag state
  bool _isDragging = false;
  double _dragFraction = 0.0;
  String? _bubbleLabel;
  double? _dragMaxExtent;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const double _railWidth = 3.0;
  static const double _thumbHeight = 28.0;
  static const Duration _fadeDuration = Duration(milliseconds: 200);
  static const Duration _hideDelay = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: _fadeDuration);
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(FastScrollRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isDragging && mounted) {
      _showRail();
      setState(() {});
    }
  }

  void _showRail() {
    _hideTimer?.cancel();
    if (!_isVisible) {
      setState(() => _isVisible = true);
      _fadeController.forward();
    }
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && !_isDragging) {
        _fadeController.reverse().then((_) {
          if (mounted) setState(() => _isVisible = false);
        });
      }
    });
  }

  double get _scrollFraction {
    if (!widget.controller.hasClients) return 0.0;
    try {
      final position = widget.controller.position;
      if (!position.hasContentDimensions) return 0.0;
      final max = position.maxScrollExtent;
      if (max <= 0) return 0.0;
      return (position.pixels / max).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  String? _resolveSectionLabel(double fraction) {
    final activeSections = widget.sections
        .where((s) => s.isEnabled && s.weight > 0)
        .toList();

    if (activeSections.isEmpty) return null;
    if (activeSections.length == 1) return activeSections.first.label;

    final totalWeight =
        activeSections.fold<double>(0.0, (sum, s) => sum + s.weight);
    if (totalWeight <= 0) return null;

    final ranges = <({double start, double end, String label})>[];
    double accumulated = 0.0;
    for (int i = 0; i < activeSections.length; i++) {
      final s = activeSections[i];
      final start = accumulated;
      final end = (i == activeSections.length - 1)
          ? 1.0
          : (accumulated + (s.weight / totalWeight));
      ranges.add((start: start, end: end, label: s.label));
      accumulated = end;
    }

    // Apply hysteresis with current label to prevent boundary oscillation/flicker
    const hysteresis = 0.025; // 2.5% deadband
    if (_bubbleLabel != null) {
      final currentIdx = ranges.indexWhere((r) => r.label == _bubbleLabel);
      if (currentIdx != -1) {
        final currentRange = ranges[currentIdx];
        final effectiveStart = (currentIdx == 0)
            ? 0.0
            : (currentRange.start - hysteresis);
        final effectiveEnd = (currentIdx == ranges.length - 1)
            ? 1.0
            : (currentRange.end + hysteresis);

        if (fraction >= effectiveStart && fraction <= effectiveEnd) {
          return currentRange.label;
        }
      }
    }

    for (final r in ranges) {
      if (fraction >= r.start && fraction <= r.end) {
        return r.label;
      }
    }
    return ranges.last.label;
  }

  void _handleDragUpdate(double localY, double totalHeight) {
    if (!widget.controller.hasClients || totalHeight <= _thumbHeight) return;
    try {
      final position = widget.controller.position;
      if (!position.hasContentDimensions) return;

      final currentMax = position.maxScrollExtent;
      if (_dragMaxExtent == null || currentMax > _dragMaxExtent!) {
        _dragMaxExtent = currentMax;
      }
      final max = _dragMaxExtent!;

      final fraction =
          ((localY - _thumbHeight / 2) / (totalHeight - _thumbHeight))
              .clamp(0.0, 1.0);

      if (max > 0) {
        widget.controller.jumpTo((fraction * max).clamp(0.0, currentMax));
      }

      final label = _resolveSectionLabel(fraction);

      setState(() {
        _isDragging = true;
        _dragFraction = fraction;
        _bubbleLabel = label;
      });
    } catch (_) {}
  }

  void _startDrag(double localY, double totalHeight) {
    _hideTimer?.cancel();
    if (!_isVisible) {
      setState(() => _isVisible = true);
      _fadeController.forward();
    }
    if (widget.controller.hasClients &&
        widget.controller.position.hasContentDimensions) {
      _dragMaxExtent = widget.controller.position.maxScrollExtent;
    }
    _handleDragUpdate(localY, totalHeight);
  }

  void _endDrag() {
    if (!mounted) return;
    _dragMaxExtent = null;
    setState(() {
      _isDragging = false;
      _bubbleLabel = null;
    });
    _showRail(); // restart the hide timer
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _isDragging ? _dragFraction : _scrollFraction;

    return LayoutBuilder(builder: (context, constraints) {
      final totalHeight = constraints.maxHeight;
      final maxThumbOffset = (totalHeight - _thumbHeight).clamp(0.0, double.infinity);
      final thumbTop = maxThumbOffset > 0
          ? (fraction * maxThumbOffset).clamp(0.0, maxThumbOffset)
          : 0.0;

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (d) => _startDrag(d.localPosition.dy, totalHeight),
        onVerticalDragUpdate: (d) => _handleDragUpdate(d.localPosition.dy, totalHeight),
        onVerticalDragEnd: (_) => _endDrag(),
        onVerticalDragCancel: () => _endDrag(),
        child: SizedBox(
          width: 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              // Thin rail track + thumb — fade in/out on scroll
              FadeTransition(
                opacity: _fadeAnim,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _railWidth,
                    height: totalHeight,
                    child: Stack(
                      children: [
                        // Track
                        Container(
                          width: _railWidth,
                          height: totalHeight,
                          decoration: BoxDecoration(
                            color: widget.palette.borderSubtle
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(_railWidth / 2),
                          ),
                        ),
                        // Thumb
                        Positioned(
                          top: thumbTop,
                          child: Container(
                            width: _railWidth,
                            height: _thumbHeight,
                            decoration: BoxDecoration(
                              color: _isDragging
                                  ? widget.palette.accentPrimary
                                  : widget.palette.textMuted
                                      .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(_railWidth / 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bubble label — only shown while dragging
              if (_isDragging && _bubbleLabel != null)
                Positioned(
                  top: (thumbTop + _thumbHeight / 2 - 14).clamp(
                      0.0, totalHeight - 28.0),
                  right: _railWidth + 6,
                  child: Material(
                    elevation: 4,
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.palette.accentPrimary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: widget.palette.accentPrimary
                                .withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        _bubbleLabel!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
