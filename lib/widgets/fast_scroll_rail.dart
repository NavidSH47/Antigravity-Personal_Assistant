import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FastScrollSection {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;

  const FastScrollSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isEnabled = true,
  });
}

class FastScrollRail extends StatefulWidget {
  final ScrollController controller;
  final VibePalette palette;
  final List<FastScrollSection> sections;
  final double width;

  const FastScrollRail({
    super.key,
    required this.controller,
    required this.palette,
    required this.sections,
    this.width = 32.0,
  });

  @override
  State<FastScrollRail> createState() => _FastScrollRailState();
}

class _FastScrollRailState extends State<FastScrollRail> {
  bool _isDragging = false;
  double _dragFraction = 0.0;
  String? _activeBubbleLabel;
  IconData? _activeBubbleIcon;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScrollUpdate);
  }

  @override
  void didUpdateWidget(FastScrollRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScrollUpdate);
      widget.controller.addListener(_onScrollUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScrollUpdate);
    super.dispose();
  }

  void _onScrollUpdate() {
    if (mounted && !_isDragging) {
      setState(() {});
    }
  }

  double get _currentScrollFraction {
    if (!widget.controller.hasClients) return 0.0;
    final max = widget.controller.position.maxScrollExtent;
    if (max <= 0) return 0.0;
    return (widget.controller.offset / max).clamp(0.0, 1.0);
  }

  void _handleDrag(double localY, double totalHeight) {
    if (!widget.controller.hasClients || totalHeight <= 0) return;
    final max = widget.controller.position.maxScrollExtent;
    final fraction = (localY / totalHeight).clamp(0.0, 1.0);

    if (max > 0) {
      widget.controller.jumpTo(fraction * max);
    }

    // Determine nearest section for tooltip preview
    String? bestLabel;
    IconData? bestIcon;
    if (widget.sections.isNotEmpty) {
      final idx = (fraction * widget.sections.length).clamp(0, widget.sections.length - 1).toInt();
      bestLabel = widget.sections[idx].label;
      bestIcon = widget.sections[idx].icon;
    }

    setState(() {
      _isDragging = true;
      _dragFraction = fraction;
      _activeBubbleLabel = bestLabel;
      _activeBubbleIcon = bestIcon;
    });
  }

  void _endDrag() {
    if (mounted) {
      setState(() {
        _isDragging = false;
        _activeBubbleLabel = null;
        _activeBubbleIcon = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollFrac = _isDragging ? _dragFraction : _currentScrollFraction;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            // Floating Preview Bubble while dragging
            if (_isDragging && _activeBubbleLabel != null)
              Positioned(
                right: widget.width + 10,
                top: (scrollFrac * (totalHeight - 32)).clamp(4.0, totalHeight - 36.0),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  color: widget.palette.accentPrimary,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_activeBubbleIcon != null) ...[
                          Icon(_activeBubbleIcon, size: 14, color: Colors.black),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _activeBubbleLabel!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Main Scroller Track Container
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (d) => _handleDrag(d.localPosition.dy, totalHeight),
              onVerticalDragUpdate: (d) => _handleDrag(d.localPosition.dy, totalHeight),
              onVerticalDragEnd: (_) => _endDrag(),
              onVerticalDragCancel: () => _endDrag(),
              child: Container(
                width: widget.width,
                height: totalHeight,
                decoration: BoxDecoration(
                  color: widget.palette.bgElevated.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(widget.width / 2),
                  border: Border.all(
                    color: widget.palette.borderSubtle.withValues(alpha: 0.8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center Vertical Track Line
                    Positioned.fill(
                      top: 16,
                      bottom: 16,
                      child: Center(
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: widget.palette.borderSubtle.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),

                    // Scroll Thumb Indicator
                    Positioned(
                      top: 8 + (scrollFrac * (totalHeight - 36)).clamp(0.0, totalHeight - 36.0),
                      child: Container(
                        width: 8,
                        height: 20,
                        decoration: BoxDecoration(
                          color: widget.palette.accentPrimary,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: widget.palette.accentPrimary.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Section Quick-Jump Buttons (Overlaid along the column)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: widget.sections.map((section) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            onTap: section.isEnabled ? section.onTap : null,
                            borderRadius: BorderRadius.circular(widget.width / 2),
                            child: Tooltip(
                              message: section.label,
                              preferBelow: false,
                              child: Container(
                                width: widget.width - 4,
                                height: widget.width - 4,
                                decoration: BoxDecoration(
                                  color: widget.palette.bgSurface.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: section.isEnabled
                                        ? widget.palette.borderSubtle
                                        : widget.palette.borderSubtle.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  section.icon,
                                  size: 13,
                                  color: section.isEnabled
                                      ? widget.palette.textMain
                                      : widget.palette.textDim.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
