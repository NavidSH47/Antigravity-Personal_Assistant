import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import '../models/shamsi_event.dart';
import '../theme/app_theme.dart';
import '../services/dual_calendar_service.dart';
import '../services/date_navigation_service.dart';

class ShamsiAgendaBanner extends StatefulWidget {
  final List<ShamsiEvent> events;
  final VibePalette palette;
  final Function(ShamsiEvent)? onToggleCheckpoint;
  final Function(ShamsiEvent)? onAddEvent;
  final VoidCallback? onAddCustomEvent;
  final Function(ShamsiEvent)? onRemoveEvent;
  final Jalali? selectedDate;
  final Function(Jalali)? onDateChanged;

  const ShamsiAgendaBanner({
    super.key,
    required this.events,
    required this.palette,
    this.onToggleCheckpoint,
    this.onAddEvent,
    this.onAddCustomEvent,
    this.onRemoveEvent,
    this.selectedDate,
    this.onDateChanged,
  });

  @override
  State<ShamsiAgendaBanner> createState() => _ShamsiAgendaBannerState();
}

class _ShamsiAgendaBannerState extends State<ShamsiAgendaBanner> {
  bool _isCalendarExpanded = false;
  late Jalali _internalSelectedDate;

  Jalali get _selectedDate => widget.selectedDate ?? _internalSelectedDate;

  @override
  void initState() {
    super.initState();
    _internalSelectedDate = widget.selectedDate ?? Jalali.now();
  }

  void _changeDate(Jalali newDate) {
    setState(() {
      _internalSelectedDate = newDate;
    });
    widget.onDateChanged?.call(newDate);
  }

  Future<void> _pickGregorianDate() async {
    final currentDt = _selectedDate.toDateTime();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDt,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2070, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: widget.palette.accentPrimary,
              onPrimary: Colors.black,
              surface: widget.palette.bgElevated,
              onSurface: widget.palette.textMain,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: widget.palette.bgSurface,
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      _changeDate(Jalali.fromDateTime(picked));
    }
  }

  static const List<String> _shamsiMonthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static const List<String> _persianWeekdays = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنج‌شنبه',
    'جمعه',
  ];

  String _toPersianDigits(int number) {
    return number.toString().toPersianDigit();
  }

  String _getWeekdayName(int weekDay) {
    // Jalali weekDay: 1 = Saturday (شنبه) to 7 = Friday (جمعه)
    if (weekDay >= 1 && weekDay <= 7) {
      return _persianWeekdays[weekDay - 1];
    }
    return '';
  }

  Widget _buildQuickNavButton({
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isHighlighted
              ? widget.palette.accentPrimary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
            color: isHighlighted ? Colors.black : widget.palette.textMain,
          ),
        ),
      ),
    );
  }

  List<ShamsiEvent> _eventsForSelectedDay() {
    return widget.events.where((e) {
      return e.isEnabled &&
          e.jalaliMonth == _selectedDate.month &&
          e.jalaliDay == _selectedDate.day;
    }).toList();
  }

  Color? _resolveDotColor(int month, int day) {
    final dayEvents = widget.events.where(
      (e) => e.isEnabled && e.jalaliMonth == month && e.jalaliDay == day,
    ).toList();

    if (dayEvents.isEmpty) return null;

    // Priority 1: User Birthdays (Pink)
    if (dayEvents.any((e) => e.category == EventCategory.birthday)) {
      return const Color(0xFFEC4899);
    }
    // Priority 2: User Custom Milestones/Events (Blue)
    if (dayEvents.any((e) => e.category == EventCategory.customDate)) {
      return const Color(0xFF60A5FA);
    }
    // Priority 3: Default Official Holiday (Orange)
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _eventsForSelectedDay();
    final monthName = _shamsiMonthNames[_selectedDate.month - 1];
    final weekdayName = _getWeekdayName(_selectedDate.weekDay);
    final monthLength = _selectedDate.monthLength;

    return Container(
      decoration: BoxDecoration(
        color: widget.palette.bgSurface,
        border: Border.all(color: widget.palette.borderSubtle),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Centered Top Header: Centered Date & Centered Action Buttons with Dynamic Proportional Spacing
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Horizontally Centered Date Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _toPersianDigits(_selectedDate.day),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: widget.palette.textMain,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$monthName ${_toPersianDigits(_selectedDate.year)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: widget.palette.accentPrimary,
                        ),
                      ),
                      Text(
                        '$weekdayName • ${DualCalendarService.toGregorianString(_selectedDate)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Centered Action Buttons with Proportional Spacing matching Navigation Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Add Custom Event Button
                          if (widget.onAddCustomEvent != null)
                            InkWell(
                              onTap: widget.onAddCustomEvent,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.palette.bgElevated,
                                  border: Border.all(color: widget.palette.borderSubtle),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 12, color: widget.palette.accentPrimary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Event',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: widget.palette.accentPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Pick Date Button using standard Gregorian DatePicker
                          InkWell(
                            onTap: _pickGregorianDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.palette.bgElevated,
                                border: Border.all(color: widget.palette.borderSubtle),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🗓️ ', style: TextStyle(fontSize: 11)),
                                  Text(
                                    'Pick Date',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: widget.palette.accentPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Expand/Collapse Month Grid Button
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isCalendarExpanded = !_isCalendarExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.palette.bgElevated,
                                border: Border.all(color: widget.palette.borderSubtle),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('📅 ', style: TextStyle(fontSize: 11)),
                                  Text(
                                    _isCalendarExpanded ? 'Close' : 'Calendar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: widget.palette.textMain,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quick Date Navigation Bar: [ « Month ] [ ‹ Week ] [ ‹ Day ] [ Today ] [ Day › ] [ Week › ] [ Month » ]
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: widget.palette.bgElevated,
              border: Border.all(color: widget.palette.borderSubtle),
              borderRadius: BorderRadius.circular(10),
            ),
            child: LayoutBuilder(
              builder: (context, navConstraints) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: navConstraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickNavButton(
                          label: '« Month',
                          onTap: () => _changeDate(
                            DateNavigationService.shiftMonths(_selectedDate, -1),
                          ),
                        ),
                        _buildQuickNavButton(
                          label: '‹ Week',
                          onTap: () => _changeDate(_selectedDate.addDays(-7)),
                        ),
                        _buildQuickNavButton(
                          label: '‹ Day',
                          onTap: () => _changeDate(_selectedDate.addDays(-1)),
                        ),
                        _buildQuickNavButton(
                          label: 'Today',
                          isHighlighted: DateNavigationService.isToday(_selectedDate),
                          onTap: () => _changeDate(Jalali.now()),
                        ),
                        _buildQuickNavButton(
                          label: 'Day ›',
                          onTap: () => _changeDate(_selectedDate.addDays(1)),
                        ),
                        _buildQuickNavButton(
                          label: 'Week ›',
                          onTap: () => _changeDate(_selectedDate.addDays(7)),
                        ),
                        _buildQuickNavButton(
                          label: 'Month »',
                          onTap: () => _changeDate(
                            DateNavigationService.shiftMonths(_selectedDate, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Collapsible Shamsi Month Grid (Strictly RTL)
          if (_isCalendarExpanded) ...[
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl, // RTL: شنبه (right) -> جمعه (left)
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.palette.bgElevated,
                  border: Border.all(color: widget.palette.borderSubtle),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Weekday headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (i) {
                        final isFriday = i == 6; // Far left in RTL is Friday
                        return Expanded(
                          child: Center(
                            child: Text(
                              _persianWeekdays[i][0], // ش، ی، د، س، چ، پ، ج
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isFriday
                                    ? const Color(0xFFEF4444)
                                    : widget.palette.textDim,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),

                    // Days grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      itemCount: monthLength,
                      itemBuilder: (context, index) {
                        final dayNum = index + 1;
                        final isSelected = dayNum == _selectedDate.day;
                        final dotColor = _resolveDotColor(_selectedDate.month, dayNum);
                        final todayJalali = Jalali.now();
                        final isToday = _selectedDate.year == todayJalali.year &&
                            _selectedDate.month == todayJalali.month &&
                            dayNum == todayJalali.day;

                        return InkWell(
                          onTap: () {
                            _changeDate(
                              Jalali(
                                _selectedDate.year,
                                _selectedDate.month,
                                dayNum,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.palette.accentPrimary
                                  : (isToday
                                      ? widget.palette.accentPrimary
                                          .withValues(alpha: 0.15)
                                      : Colors.transparent),
                              border: isToday
                                  ? Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : widget.palette.accentPrimary,
                                      width: 1.5,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  _toPersianDigits(dayNum),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.black
                                        : (isToday
                                            ? widget.palette.accentPrimary
                                            : widget.palette.textMain),
                                  ),
                                ),
                                if (dotColor != null && !isSelected)
                                  Positioned(
                                    bottom: 2,
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: dotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Holidays & Notable Events Display (Clean RTL badge, no reminder checkboxes or empty reminder placeholders)
          if (selectedDayEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: selectedDayEvents.map((evt) {
                  Color bgColor;
                  Color borderColor;
                  Color textColor;
                  String icon;

                  switch (evt.category) {
                    case EventCategory.holiday:
                      bgColor = const Color(0x26F59E0B);
                      borderColor = const Color(0x66F59E0B);
                      textColor = const Color(0xFFFBBF24);
                      icon = '🏛️';
                      break;
                    case EventCategory.birthday:
                      bgColor = const Color(0x26EC4899);
                      borderColor = const Color(0x66EC4899);
                      textColor = const Color(0xFFF472B6);
                      icon = '🎂';
                      break;
                    case EventCategory.customDate:
                      bgColor = const Color(0x2060A5FA);
                      borderColor = const Color(0x5060A5FA);
                      textColor = const Color(0xFF93C5FD);
                      icon = '🎯';
                      break;
                  }

                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(icon, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  evt.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onRemoveEvent != null && evt.isCustom)
                          InkWell(
                            onTap: () => widget.onRemoveEvent!(evt),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
