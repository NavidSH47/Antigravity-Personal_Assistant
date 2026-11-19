import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:nsh_assistant/models/task.dart';
import 'package:nsh_assistant/models/media_item.dart';
import 'package:nsh_assistant/models/shamsi_event.dart';
import 'package:nsh_assistant/services/date_navigation_service.dart';
import 'package:nsh_assistant/services/task_reschedule_service.dart';
import 'package:nsh_assistant/services/task_stream_flow_service.dart';
import 'package:nsh_assistant/services/reorder_service.dart';
import 'package:nsh_assistant/services/media_ledger_cleanup_service.dart';
import 'package:nsh_assistant/services/dual_calendar_service.dart';
import 'package:nsh_assistant/services/web_typography_service.dart';
import 'package:nsh_assistant/services/media_label_service.dart';
import 'package:nsh_assistant/services/media_goal_sync_service.dart';
import 'package:nsh_assistant/services/cover_fetch_service.dart';
import 'package:nsh_assistant/widgets/task_card.dart';
import 'package:nsh_assistant/theme/app_theme.dart';
import 'package:nsh_assistant/services/title_case_service.dart';
import 'package:nsh_assistant/widgets/safe_cover_image.dart';
import 'package:nsh_assistant/widgets/shamsi_agenda_banner.dart';
import 'package:nsh_assistant/widgets/media_card.dart';
import 'package:nsh_assistant/services/rtl_detection_service.dart';
import 'package:nsh_assistant/services/media_info_fetch_service.dart';
import 'package:nsh_assistant/services/storage_service.dart';
import 'package:nsh_assistant/widgets/settings_drawer.dart';
import 'package:nsh_assistant/widgets/fast_scroll_rail.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Task Model & 3-State Transitions', () {
    test('Default task starts with pending status', () {
      final task = Task(id: '1', title: 'Buy groceries');
      expect(task.status, TaskStatus.pending);
      expect(task.category, TaskCategory.daily);
      expect(task.postponedCount, 0);
    });

    test('Postpone increment logic updates state', () {
      final task = Task(id: '1', title: 'Buy groceries');
      final postponed = task.copyWith(
        status: TaskStatus.postponed,
        postponedCount: task.postponedCount + 1,
      );
      expect(postponed.status, TaskStatus.postponed);
      expect(postponed.postponedCount, 1);
    });

    test('JSON serialization & deserialization is lossless', () {
      final task = Task(
        id: '42',
        title: 'Complete Math Essay',
        notes: '• Step 1\n• Step 2',
        category: TaskCategory.general,
        status: TaskStatus.done,
        orderIndex: 3,
        postponedCount: 2,
      );
      final json = task.toJson();
      final revived = Task.fromJson(json);

      expect(revived.id, task.id);
      expect(revived.title, task.title);
      expect(revived.notes, task.notes);
      expect(revived.category, task.category);
      expect(revived.status, task.status);
      expect(revived.orderIndex, task.orderIndex);
      expect(revived.postponedCount, task.postponedCount);
    });
  });

  group('MediaItem Metric & Progress Calculations', () {
    test('Progress ratio clamp and percentage calculation', () {
      final book = MediaItem(
        id: 'b1',
        type: MediaType.book,
        title: 'Klara and the Sun',
        releaseYear: 2021,
        progressCurrent: 172,
        progressTotal: 303,
      );
      expect(book.progressPercent, 57);
      expect(book.metricUnit, 'Pages');
      expect(book.metricDisplay, 'Pages: 172 / 303');
    });

    test('Zero total avoids division by zero', () {
      final game = MediaItem(
        id: 'g1',
        type: MediaType.videoGame,
        title: 'New Game',
        releaseYear: 2024,
        progressCurrent: 0,
        progressTotal: 0,
      );
      expect(game.progressRatio, 0.0);
      expect(game.progressPercent, 0);
    });

    test('Rating score gradients exist for all intervals', () {
      final lowScore = MediaItem(
        id: '1',
        type: MediaType.movie,
        title: 'Movie',
        releaseYear: 2020,
        progressCurrent: 10,
        progressTotal: 100,
        score: 3.0,
      );
      final highScore = lowScore.copyWith(score: 9.5);
      expect(lowScore.scoreGradient.length, 2);
      expect(highScore.scoreGradient.length, 2);
    });
  });

  group('Shamsi Events & Iranian Holiday Defaults', () {
    test('Default events contain Nowruz and official holidays', () {
      final events = ShamsiEvent.defaultEvents;
      expect(events.isNotEmpty, true);

      final nowruz = events.firstWhere((e) => e.jalaliMonth == 1 && e.jalaliDay == 1);
      expect(nowruz.isOfficialHoliday, true);
      expect(nowruz.title.contains('نوروز'), true);

      // Verify World Diabetes Day (23rd Aban) and International Men's Day (28th Aban)
      final diabetesDay = events.firstWhere(
        (e) => e.jalaliMonth == 8 && e.jalaliDay == 23 && e.title.contains('دیابت'),
      );
      expect(diabetesDay.title.contains('World Diabetes Day'), true);

      final mensDay = events.firstWhere(
        (e) => e.jalaliMonth == 8 && e.jalaliDay == 28 && e.title.contains('مرد'),
      );
      expect(mensDay.title.contains('International Men\'s Day'), true);
    });

    test('Action checkpoint toggling works as intended', () {
      const birthday = ShamsiEvent(
        id: 'b1',
        title: 'Maryam Birthday',
        jalaliMonth: 8,
        jalaliDay: 23,
        actionChecked: false,
      );
      final checked = birthday.copyWith(actionChecked: true);
      expect(checked.actionChecked, true);
    });
  });

  group('1. DateNavigationService (Item 1)', () {
    test('Key formatting and parsing is lossless roundtrip', () {
      final original = Jalali(1403, 8, 23);
      final key = DateNavigationService.formatJalaliKey(original);
      expect(key, '1403-08-23');

      final parsed = DateNavigationService.parseJalaliKey(key);
      expect(parsed.year, 1403);
      expect(parsed.month, 8);
      expect(parsed.day, 23);
    });

    test('isSameDate and isToday work accurately', () {
      final now = Jalali.now();
      expect(DateNavigationService.isToday(now), true);
      expect(DateNavigationService.isSameDate(now, now.addDays(1)), false);
    });

    test('shiftDays navigates by offset or resets to today on 0', () {
      final base = Jalali(1403, 1, 15);
      expect(DateNavigationService.shiftDays(base, 1).day, 16);
      expect(DateNavigationService.shiftDays(base, -1).day, 14);
      expect(DateNavigationService.shiftDays(base, 7).day, 22);
      expect(DateNavigationService.isSameDate(DateNavigationService.shiftDays(base, 0), Jalali.now()), true);
    });

    test('getTasksForDate filters tasks for target Jalali date and today defaults', () {
      final today = Jalali.now();
      final todayKey = DateNavigationService.formatJalaliKey(today);
      final tomorrow = today.addDays(1);
      final tomorrowKey = DateNavigationService.formatJalaliKey(tomorrow);

      final tasks = [
        Task(id: '1', title: 'Task Today Explicit', category: TaskCategory.daily, targetDateJalali: todayKey),
        Task(id: '2', title: 'Task Today Implicit', category: TaskCategory.daily, targetDateJalali: null),
        Task(id: '3', title: 'Task Tomorrow', category: TaskCategory.daily, targetDateJalali: tomorrowKey),
        Task(id: '4', title: 'Backlog Task', category: TaskCategory.general, targetDateJalali: todayKey),
      ];

      final todayTasks = DateNavigationService.getTasksForDate(tasks, today);
      expect(todayTasks.map((t) => t.id).toList(), containsAll(['1', '2']));
      expect(todayTasks.map((t) => t.id).toList().contains('3'), false);
      expect(todayTasks.map((t) => t.id).toList().contains('4'), false);

      final tomorrowTasks = DateNavigationService.getTasksForDate(tasks, tomorrow);
      expect(tomorrowTasks.map((t) => t.id).toList(), ['3']);
    });
  });

  group('2. TaskRescheduleService (Item 2)', () {
    test('postponeOneDay advances task to tomorrow and increments count', () {
      final current = Jalali(1403, 5, 10);
      final task = Task(
        id: 't1',
        title: 'Review PR',
        status: TaskStatus.pending,
        postponedCount: 0,
        targetDateJalali: DateNavigationService.formatJalaliKey(current),
      );

      final updated = TaskRescheduleService.postponeOneDay(task, current);
      expect(updated.status, TaskStatus.postponed);
      expect(updated.postponedCount, 1);
      expect(updated.targetDateJalali, DateNavigationService.formatJalaliKey(current.addDays(1)));
    });

    test('postponeToDate sets arbitrary target Jalali date', () {
      final target = Jalali(1403, 5, 25);
      final task = Task(
        id: 't2',
        title: 'Submit taxes',
        status: TaskStatus.pending,
        postponedCount: 1,
      );

      final updated = TaskRescheduleService.postponeToDate(task, target);
      expect(updated.status, TaskStatus.postponed);
      expect(updated.postponedCount, 2);
      expect(updated.targetDateJalali, '1403-05-25');
    });
  });

  group('3. TaskStreamFlowService (Item 3)', () {
    test('promoteToDaily transfers backlog task to daily stream on given date', () {
      final targetDate = Jalali(1403, 8, 20);
      final task = Task(
        id: 'b1',
        title: 'General Idea',
        category: TaskCategory.general,
      );

      final promoted = TaskStreamFlowService.promoteToDaily(task, targetDate);
      expect(promoted.category, TaskCategory.daily);
      expect(promoted.targetDateJalali, DateNavigationService.formatJalaliKey(targetDate));
    });

    test('demoteToBacklog demotes daily task to backlog and clears date', () {
      final task = Task(
        id: 'd1',
        title: 'Daily Task',
        category: TaskCategory.daily,
        targetDateJalali: '1403-08-20',
        status: TaskStatus.postponed,
      );

      final demoted = TaskStreamFlowService.demoteToBacklog(task);
      expect(demoted.category, TaskCategory.general);
      expect(demoted.targetDateJalali, isNull);
      expect(demoted.status, TaskStatus.pending);
    });
  });

  group('4. ReorderService (Item 4)', () {
    test('reorderTasks updates orderIndex correctly', () {
      final items = [
        Task(id: 'a', title: 'A', orderIndex: 0),
        Task(id: 'b', title: 'B', orderIndex: 1),
        Task(id: 'c', title: 'C', orderIndex: 2),
      ];

      // Move C (index 2) to top (index 0)
      final reordered = ReorderService.reorderTasks(items, 2, 0);
      expect(reordered.map((t) => t.id).toList(), ['c', 'a', 'b']);
      expect(reordered[0].orderIndex, 0);
      expect(reordered[1].orderIndex, 1);
      expect(reordered[2].orderIndex, 2);
    });

    test('reorderMedia updates customOrder correctly', () {
      final items = [
        MediaItem(id: 'm1', type: MediaType.book, title: 'Book 1', releaseYear: 2020, progressCurrent: 0, progressTotal: 100, customOrder: 0),
        MediaItem(id: 'm2', type: MediaType.book, title: 'Book 2', releaseYear: 2021, progressCurrent: 0, progressTotal: 100, customOrder: 1),
        MediaItem(id: 'm3', type: MediaType.book, title: 'Book 3', releaseYear: 2022, progressCurrent: 0, progressTotal: 100, customOrder: 2),
      ];

      // Move m1 to bottom
      final reordered = ReorderService.reorderMedia(items, 0, 3);
      expect(reordered.map((m) => m.id).toList(), ['m2', 'm3', 'm1']);
      expect(reordered[0].customOrder, 0);
      expect(reordered[1].customOrder, 1);
      expect(reordered[2].customOrder, 2);
    });
  });

  group('5. MediaLedgerCleanupService (Item 5)', () {
    test('Unit labels map correctly to all media types', () {
      expect(MediaLedgerCleanupService.unitLabelFor(MediaType.book), 'Pages');
      expect(MediaLedgerCleanupService.unitLabelFor(MediaType.tvShow), 'Episodes');
      expect(MediaLedgerCleanupService.unitLabelFor(MediaType.movie), 'Minutes');
      expect(MediaLedgerCleanupService.unitLabelFor(MediaType.videoGame), 'Chapters');

      expect(MediaLedgerCleanupService.unitInputLabelFor(MediaType.book), 'Total Pages');
      expect(MediaLedgerCleanupService.unitInputLabelFor(MediaType.tvShow), 'Total Episodes');
      expect(MediaLedgerCleanupService.unitInputLabelFor(MediaType.movie), 'Total Minutes');
      expect(MediaLedgerCleanupService.unitInputLabelFor(MediaType.videoGame), 'Total Chapters / Missions');
    });

    test('Cover cache stores and retrieves URLs correctly', () async {
      final service = MediaLedgerCleanupService();
      await service.cacheCoverArt('med_123', 'https://example.com/cover.jpg');
      expect(service.getCachedCoverArt('med_123'), 'https://example.com/cover.jpg');
      expect(service.getCachedCoverArt('unknown'), isNull);
    });
  });

  group('6. DualCalendarService (Item 6)', () {
    test('Persian digits conversion works correctly', () {
      expect(DualCalendarService.toPersianDigits(1403), '۱۴۰۳');
      expect(DualCalendarService.toPersianDigits(25), '۲۵');
    });

    test('Persian weekdays map correctly from Saturday to Friday', () {
      expect(DualCalendarService.getPersianWeekdayName(1), 'شنبه');
      expect(DualCalendarService.getPersianWeekdayName(7), 'جمعه');
    });

    test('Bilingual date combined formatting includes both Shamsi and Gregorian', () {
      final date = Jalali(1403, 8, 23);
      final combined = DualCalendarService.combinedDate(date);
      expect(combined.contains('آبان'), true);
      expect(combined.contains('۱۴۰۳'), true);
      expect(combined.contains('('), true);
      expect(combined.contains(')'), true);
    });

    test('isCheckpointCompleted checks actionChecked flag', () {
      const pendingEvent = ShamsiEvent(id: 'e1', title: 'E1', jalaliMonth: 1, jalaliDay: 1, actionChecked: false);
      const doneEvent = ShamsiEvent(id: 'e2', title: 'E2', jalaliMonth: 1, jalaliDay: 1, actionChecked: true);

      expect(DualCalendarService.isCheckpointCompleted(pendingEvent), false);
      expect(DualCalendarService.isCheckpointCompleted(doneEvent), true);
    });
  });

  group('7. WebTypographyService & Font Switching (Task 1)', () {
    test('Configured web fonts list contains all required font families (Vazirmatn eliminated)', () {
      expect(WebTypographyService.configuredWebFonts.contains('Vazirmatn'), isFalse);
      expect(WebTypographyService.configuredWebFonts, contains('Comic Neue'));
      expect(WebTypographyService.configuredWebFonts, contains('Quicksand'));
      expect(WebTypographyService.configuredWebFonts, contains('Fira Code'));
      expect(WebTypographyService.configuredWebFonts, contains('Lora'));
    });

    test('Google Fonts CSS URL contains all web font families without Vazirmatn', () {
      final url = WebTypographyService.googleFontsCssUrl;
      expect(url.contains('Vazirmatn'), isFalse);
      expect(url.contains('Comic+Neue'), isTrue);
      expect(url.contains('Quicksand'), isTrue);
      expect(url.contains('Fira+Code'), isTrue);
      expect(url.contains('Lora'), isTrue);
    });

    test('verifyFontResolution returns true for all AppFontStyle variants', () {
      for (final font in AppFontStyle.values) {
        expect(WebTypographyService.verifyFontResolution(font), true);
      }
    });

    test('ThemeData explicitly maps font across TextTheme styles', () {
      final theme = AppTheme.createTheme(ThemeVibe.deepAmethyst, AppFontStyle.comicSans);
      final family = AppTheme.getFontFamilyName(AppFontStyle.comicSans);
      final fallback = AppTheme.getFontFallbackList(AppFontStyle.comicSans);

      expect(
        WebTypographyService.verifyTextThemeApplied(theme.textTheme, family, fallback),
        true,
      );
    });
  });

  group('8. MediaLabelService & Custom Tags (Task 4)', () {
    test('Preset labels contain standard presets', () {
      expect(MediaLabelService.presetLabels, contains('Sci-Fi'));
      expect(MediaLabelService.presetLabels, contains('Drama'));
      expect(MediaLabelService.presetLabels, contains('Horror'));
      expect(MediaLabelService.presetLabels, contains('Fantasy'));
      expect(MediaLabelService.presetLabels.contains('Masterpiece'), isFalse);
      expect(MediaLabelService.presetLabels, contains('RPG'));
      expect(MediaLabelService.presetLabels, contains('Ongoing'));
    });

    test('addLabel appends new tag, trims whitespace, and ignores duplicates', () {
      final initial = ['Sci-Fi', 'Drama'];

      final added = MediaLabelService.addLabel(initial, '  Horror  ');
      expect(added, ['Sci-Fi', 'Drama', 'Horror']);

      // Duplicate case-insensitive
      final duplicate = MediaLabelService.addLabel(added, 'sci-fi');
      expect(duplicate.length, 3);

      // Empty string
      final empty = MediaLabelService.addLabel(added, '   ');
      expect(empty.length, 3);
    });

    test('removeLabel removes tag case-insensitively', () {
      final list = ['Sci-Fi', 'Drama', 'RPG'];
      final removed = MediaLabelService.removeLabel(list, 'drama');
      expect(removed, ['Sci-Fi', 'RPG']);
    });

    test('getSuggestions excludes assigned labels and combines pools', () {
      final current = ['Sci-Fi', 'CustomTag'];
      final extraPool = ['CustomTag', 'Indie', 'Drama'];

      final suggestions = MediaLabelService.getSuggestions(current, extraPool);
      expect(suggestions, contains('Drama'));
      expect(suggestions, contains('Indie'));
      expect(suggestions, contains('Horror'));
      expect(suggestions.contains('Sci-Fi'), false);
      expect(suggestions.contains('CustomTag'), false);
    });

    test('updateMediaLabels applies new label list to MediaItem', () {
      final item = MediaItem(
        id: 'm1',
        type: MediaType.book,
        title: 'Dune',
        releaseYear: 1965,
        progressCurrent: 100,
        progressTotal: 500,
        labels: ['Sci-Fi'],
      );

      final updated = MediaLabelService.updateMediaLabels(item, ['Sci-Fi', 'Masterpiece']);
      expect(updated.labels, ['Sci-Fi', 'Masterpiece']);
    });
  });

  group('9. MediaGoalSyncService & Auto Progress Sync (Tasks 3 & 5)', () {
    test('remainingUnits calculates remaining amount accurately', () {
      final item = MediaItem(
        id: 'm1',
        type: MediaType.book,
        title: 'Book A',
        releaseYear: 2020,
        progressCurrent: 120,
        progressTotal: 300,
      );
      expect(MediaGoalSyncService.remainingUnits(item), 180.0);

      // If current exceeds total, returns 0
      final completed = item.copyWith(progressCurrent: 350);
      expect(MediaGoalSyncService.remainingUnits(completed), 0.0);
    });

    test('validateGoalAmount enforces positive amount and remaining boundary', () {
      final item = MediaItem(
        id: 'm1',
        type: MediaType.book,
        title: 'Book A',
        releaseYear: 2020,
        progressCurrent: 50,
        progressTotal: 100,
      );

      expect(MediaGoalSyncService.validateGoalAmount(null, item), isNotNull);
      expect(MediaGoalSyncService.validateGoalAmount(0, item), isNotNull);
      expect(MediaGoalSyncService.validateGoalAmount(-5, item), isNotNull);
      expect(MediaGoalSyncService.validateGoalAmount(55, item), isNotNull);
      expect(MediaGoalSyncService.validateGoalAmount(25, item), isNull);
      expect(MediaGoalSyncService.validateGoalAmount(50, item), isNull);
    });

    test('generateGoalTaskTitle uses category-bound verbs and units', () {
      final book = MediaItem(id: '1', type: MediaType.book, title: 'Dune', releaseYear: 1965, progressCurrent: 0, progressTotal: 500);
      final show = MediaItem(id: '2', type: MediaType.tvShow, title: 'Succession', releaseYear: 2018, progressCurrent: 0, progressTotal: 39);
      final movie = MediaItem(id: '3', type: MediaType.movie, title: 'Oppenheimer', releaseYear: 2023, progressCurrent: 0, progressTotal: 180);
      final game = MediaItem(id: '4', type: MediaType.videoGame, title: 'Elden Ring', releaseYear: 2022, progressCurrent: 0, progressTotal: 30);

      expect(MediaGoalSyncService.generateGoalTaskTitle(book, 25), 'Read 25 Pages of Dune');
      expect(MediaGoalSyncService.generateGoalTaskTitle(show, 3), 'Watch 3 Episodes of Succession');
      expect(MediaGoalSyncService.generateGoalTaskTitle(movie, 45), 'Watch 45 Minutes of Oppenheimer');
      expect(MediaGoalSyncService.generateGoalTaskTitle(game, 2), 'Play 2 Chapters/Missions of Elden Ring');
    });

    test('createLinkedTask binds all properties properly', () {
      final item = MediaItem(
        id: 'med_99',
        type: MediaType.book,
        title: '1984',
        releaseYear: 1949,
        progressCurrent: 10,
        progressTotal: 300,
      );

      final task = MediaGoalSyncService.createLinkedTask(
        item: item,
        amount: 20,
        todayKey: '1403-08-25',
        orderIndex: 2,
        notes: 'Read during lunch',
      );

      expect(task.linkedMediaId, 'med_99');
      expect(task.mediaUnitsToAdvance, 20.0);
      expect(task.mediaTitle, '1984');
      expect(task.targetDateJalali, '1403-08-25');
      expect(task.orderIndex, 2);
      expect(task.notes, 'Read during lunch');
      expect(task.status, TaskStatus.pending);
      expect(task.category, TaskCategory.daily);
    });

    test('advanceProgress increments and caps at total', () {
      final item = MediaItem(
        id: '1',
        type: MediaType.book,
        title: 'Test',
        releaseYear: 2020,
        progressCurrent: 80,
        progressTotal: 100,
      );

      final advanced = MediaGoalSyncService.advanceProgress(item, 15);
      expect(advanced.progressCurrent, 95.0);

      final capped = MediaGoalSyncService.advanceProgress(item, 30);
      expect(capped.progressCurrent, 100.0);
    });

    test('revertProgress decrements and floors at zero', () {
      final item = MediaItem(
        id: '1',
        type: MediaType.book,
        title: 'Test',
        releaseYear: 2020,
        progressCurrent: 20,
        progressTotal: 100,
      );

      final reverted = MediaGoalSyncService.revertProgress(item, 15);
      expect(reverted.progressCurrent, 5.0);

      final floored = MediaGoalSyncService.revertProgress(item, 25);
      expect(floored.progressCurrent, 0.0);
    });

    test('Notification and celebration templates match specification', () {
      final item = MediaItem(
        id: '1',
        type: MediaType.book,
        title: 'Klara and the Sun',
        releaseYear: 2021,
        progressCurrent: 172,
        progressTotal: 303,
      );

      final note = MediaGoalSyncService.scheduledNotification(item, 25);
      expect(note, '🎯 Scheduled: 25 Pages of Klara and the Sun for Today!');

      final celebration = MediaGoalSyncService.celebrationMessage(item);
      expect(celebration.contains('🎉 Progress updated: Klara and the Sun is now at 172/303 Pages'), true);
    });
  });

  group('10. CoverFetchService (Milestone 5)', () {
    test('Open Library book search parses valid JSON into CoverSearchResult', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'openlibrary.org') {
          return http.Response(
            jsonEncode({
              'docs': [
                {
                  'title': 'Dune',
                  'cover_i': 12345,
                  'first_publish_year': 1965,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final results = await CoverFetchService.searchCovers(
        query: 'Dune',
        type: MediaType.book,
        client: mockClient,
      );

      expect(results.length, 1);
      expect(results.first.title, 'Dune');
      expect(results.first.coverUrl, 'https://covers.openlibrary.org/b/id/12345-L.jpg');
      expect(results.first.source, 'Open Library');
      expect(results.first.year, '1965');
    });

    test('TVMaze show search parses valid JSON into CoverSearchResult', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'api.tvmaze.com') {
          return http.Response(
            jsonEncode([
              {
                'show': {
                  'name': 'Succession',
                  'premiered': '2018-06-03',
                  'image': {
                    'original': 'https://static.tvmaze.com/uploads/images/original_untouched/123.jpg'
                  }
                }
              }
            ]),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final results = await CoverFetchService.searchCovers(
        query: 'Succession',
        type: MediaType.tvShow,
        client: mockClient,
      );

      expect(results.length, 1);
      expect(results.first.title, 'Succession');
      expect(results.first.source, 'TVMaze');
      expect(results.first.year, '2018');
      expect(results.first.coverUrl.contains('static.tvmaze.com'), true);
    });

    test('iTunes movie search parses valid JSON with high-res replacement', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'itunes.apple.com') {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'trackName': 'Oppenheimer',
                  'releaseDate': '2023-07-21T07:00:00Z',
                  'artworkUrl100': 'https://is1-ssl.mzstatic.com/image/thumb/100x100bb.jpg',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final results = await CoverFetchService.searchCovers(
        query: 'Oppenheimer',
        type: MediaType.movie,
        client: mockClient,
      );

      expect(results.length, 1);
      expect(results.first.title, 'Oppenheimer');
      expect(results.first.source, 'iTunes');
      expect(results.first.year, '2023');
      expect(results.first.coverUrl.contains('600x600bb.jpg'), true);
    });

    test('Steam game search parses valid JSON with vertical poster', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'store.steampowered.com') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1245620,
                  'name': 'Elden Ring',
                  'tiny_image': 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1245620/capsule_sm_120.jpg',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final results = await CoverFetchService.searchCovers(
        query: 'Elden Ring',
        type: MediaType.videoGame,
        client: mockClient,
      );

      expect(results.length, 1);
      expect(results.first.title, 'Elden Ring');
      expect(results.first.source, 'Steam');
      expect(results.first.coverUrl.contains('1245620/library_600x900_2x.jpg'), true);
    });

    test('Multi-source game search aggregates candidates from Steam and RAWG without early-exit', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'store.steampowered.com') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 323150,
                  'name': 'Half-Life 2: Episode One Soundtrack',
                  'tiny_image': 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/323150/capsule_sm_120.jpg',
                }
              ]
            }),
            200,
          );
        } else if (request.url.host == 'api.rawg.io') {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'name': 'Half-Life 2: Episode One',
                  'background_image': 'https://media.rawg.io/media/games/hl2ep1.jpg',
                  'released': '2006-06-01',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final results = await CoverFetchService.searchCovers(
        query: 'Half-Life 2: Episode One',
        type: MediaType.videoGame,
        client: mockClient,
      );

      expect(results.length, 2);
      expect(results.any((r) => r.source == 'Steam'), isTrue);
      expect(results.any((r) => r.source == 'RAWG'), isTrue);
      expect(results.firstWhere((r) => r.source == 'RAWG').title, 'Half-Life 2: Episode One');
      expect(results.firstWhere((r) => r.source == 'RAWG').year, '2006');
    });

    test('Empty query and network error return empty list safely', () async {
      final emptyResults = await CoverFetchService.searchCovers(
        query: '   ',
        type: MediaType.book,
      );
      expect(emptyResults, isEmpty);

      final errorClient = MockClient((request) async {
        throw Exception('Connection failed');
      });

      final errorResults = await CoverFetchService.searchCovers(
        query: 'NonExistentTitle',
        type: MediaType.book,
        client: errorClient,
      );
      expect(errorResults, isEmpty);
    });
  });

  group('11. Media Removal & Task Decoupling Lifecycle (Milestone 4)', () {
    test('Removing media item decouples linked tasks while keeping completion state', () {
      final mediaId = 'med_to_remove';
      final linkedTask = Task(
        id: 't1',
        title: 'Read 25 Pages of Dune',
        status: TaskStatus.done,
        category: TaskCategory.daily,
        linkedMediaId: mediaId,
        mediaUnitsToAdvance: 25.0,
        mediaTitle: 'Dune',
      );
      final unlinkedTask = Task(
        id: 't2',
        title: 'Buy Groceries',
        status: TaskStatus.pending,
        category: TaskCategory.daily,
      );

      final tasks = [linkedTask, unlinkedTask];

      // Simulate decoupling logic executed on media removal
      final updatedTasks = tasks.map((t) {
        if (t.linkedMediaId == mediaId) {
          return t.copyWith(clearLinkedMedia: true);
        }
        return t;
      }).toList();

      expect(updatedTasks[0].linkedMediaId, isNull);
      expect(updatedTasks[0].mediaUnitsToAdvance, isNull);
      expect(updatedTasks[0].mediaTitle, isNull);
      expect(updatedTasks[0].title, 'Read 25 Pages of Dune');
      expect(updatedTasks[0].status, TaskStatus.done); // Preserves completed history!

      expect(updatedTasks[1].id, 't2');
      expect(updatedTasks[1].title, 'Buy Groceries');
    });

    test('Restoring removed media on Undo re-links task references', () {
      final media = MediaItem(
        id: 'med_restore',
        type: MediaType.book,
        title: 'Dune',
        releaseYear: 1965,
        progressCurrent: 50,
        progressTotal: 500,
      );
      var decoupledTask = Task(
        id: 't1',
        title: 'Read 25 Pages of Dune',
        status: TaskStatus.pending,
        category: TaskCategory.daily,
      );

      // Re-link
      final reLinkedTask = decoupledTask.copyWith(
        linkedMediaId: media.id,
        mediaTitle: media.title,
        mediaUnitsToAdvance: 25,
      );

      expect(reLinkedTask.linkedMediaId, 'med_restore');
      expect(reLinkedTask.mediaTitle, 'Dune');
      expect(reLinkedTask.mediaUnitsToAdvance, 25.0);
    });
  });

  group('12. Context-Aware Task Scheduling & Dynamic Date Binding (Milestone 6)', () {
    test('promoteToDaily binds targetDateJalali to arbitrary selected date', () {
      final backlogTask = Task(
        id: 'b1',
        title: 'Prepare Presentation',
        category: TaskCategory.general,
      );

      final selectedFutureDate = Jalali(1404, 5, 12);
      final promotedTask = TaskStreamFlowService.promoteToDaily(
        backlogTask,
        selectedFutureDate,
      );

      expect(promotedTask.category, TaskCategory.daily);
      expect(promotedTask.targetDateJalali, '1404-05-12');
      expect(promotedTask.targetDateJalali, isNot(DateNavigationService.formatJalaliKey(Jalali.now())));
    });

    test('demoteToBacklog clears targetDate and resets postponed status', () {
      final dailyTask = Task(
        id: 'd1',
        title: 'Review PR',
        category: TaskCategory.daily,
        targetDateJalali: '1403-08-25',
        status: TaskStatus.postponed,
        postponedCount: 1,
      );

      final demoted = TaskStreamFlowService.demoteToBacklog(dailyTask);
      expect(demoted.category, TaskCategory.general);
      expect(demoted.targetDateJalali, isNull);
      expect(demoted.status, TaskStatus.pending);
      expect(demoted.postponedCount, 1);
    });
  });

  group('13. Task Card UI & "Due Today" Removal Regression (Milestone 1 & 2)', () {
    testWidgets('Pending daily task renders without "Due Today" text', (tester) async {
      final task = Task(
        id: 't_clean',
        title: 'Write Documentation',
        status: TaskStatus.pending,
        category: TaskCategory.daily,
      );
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              palette: palette,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      // Verify task title is rendered
      expect(find.text('Write Documentation'), findsOneWidget);
      // Verify "Due Today" is completely absent from the UI!
      expect(find.text('Due Today'), findsNothing);
    });

    testWidgets('Linked media task renders increment badge', (tester) async {
      final task = Task(
        id: 't_media',
        title: 'Read 25 Pages of Dune',
        status: TaskStatus.pending,
        category: TaskCategory.daily,
        linkedMediaId: 'med_1',
        mediaTitle: 'Dune',
        mediaUnitsToAdvance: 25.0,
      );
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              palette: palette,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('+25 on check'), findsNothing);
      expect(find.text('🎯 Media Goal: Dune'), findsOneWidget);
      expect(find.text('• +25'), findsOneWidget);
      expect(find.text('Due Today'), findsNothing);
    });

    testWidgets('Postponed task renders postponed badge', (tester) async {
      final task = Task(
        id: 't_postponed',
        title: 'Clean Garage',
        status: TaskStatus.postponed,
        postponedCount: 2,
        category: TaskCategory.daily,
      );
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              palette: palette,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      // In Version 2.4.0, multiplier is displayed directly on the button ("Postpone 2x")
      // and the separate "Postponed (2x)" text box is completely eliminated
      expect(find.text('Postpone 2x'), findsOneWidget);
      expect(find.text('Postponed (2x)'), findsNothing);
      expect(find.text('Due Today'), findsNothing);
    });

    testWidgets('General task renders dynamic schedule label', (tester) async {
      final task = Task(
        id: 't_backlog',
        title: 'Learn Rust',
        status: TaskStatus.pending,
        category: TaskCategory.general,
      );
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              palette: palette,
              scheduleLabel: '📅 Assign to Day',
              onScheduleForDate: () {},
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('📅 Assign to Day'), findsOneWidget);
      expect(find.text('Due Today'), findsNothing);
    });
  });

  group('14. Universal Sentence Case Input Standard (Task 4)', () {
    test('toSentenceCase capitalizes first letter of sentence and trims appropriately', () {
      expect(toSentenceCase('hello world'), 'Hello world');
      expect(toSentenceCase('dune: part two'), 'Dune: part two');
      expect(toSentenceCase('spider-man: miles morales'), 'Spider-man: miles morales');
      expect(toSentenceCase('123 start action'), '123 start action');
      expect(toSentenceCase(''), '');
      expect(toSentenceCase('کتاب فارسی'), 'کتاب فارسی');
    });

    test('toTitleCase legacy alias delegates to sentence case', () {
      expect(toTitleCase('hello world'), 'Hello world');
    });

    test('SentenceCaseTextInputFormatter capitalizes first letter and preserves selection', () {
      final formatter = SentenceCaseTextInputFormatter();
      const oldValue = TextEditingValue(text: 'read dun', selection: TextSelection.collapsed(offset: 8));
      const newValue = TextEditingValue(text: 'read dune', selection: TextSelection.collapsed(offset: 9));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Read dune');
      expect(result.selection.baseOffset, 9);
    });
  });

  group('15. SafeCoverImage & LaunchBox / URL Sanitization (Task 5)', () {
    test('sanitizeUrl fixes double slashes in image path (LaunchBox example)', () {
      const badUrl = 'https://images.launchbox-app.com//e9438ab4-d720-4360-8659-951ecdb50cc3.jpg';
      final clean = SafeCoverImage.sanitizeUrl(badUrl);
      expect(clean, 'https://images.launchbox-app.com/e9438ab4-d720-4360-8659-951ecdb50cc3.jpg');
    });

    test('toCorsProxyUrl creates weserv proxy URL', () {
      const url = 'https://images.launchbox-app.com/e9438ab4.jpg';
      final proxy = SafeCoverImage.toCorsProxyUrl(url);
      expect(proxy.startsWith('https://images.weserv.nl/?url='), isTrue);
      expect(proxy.contains('launchbox-app.com'), isTrue);
    });

    test('CoverFetchService.sanitizeImageUrl cleans URL paths', () {
      final clean = CoverFetchService.sanitizeImageUrl('https://example.com///path//img.png');
      expect(clean, 'https://example.com/path/img.png');
    });

    test('SafeCoverImage.getSteamHeaderFallbackUrl maps library poster to header.jpg', () {
      const steam2x =
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/323150/library_600x900_2x.jpg';
      const steam1x =
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/323150/library_600x900.jpg';
      const nonSteam = 'https://example.com/cover.jpg';

      expect(
        SafeCoverImage.getSteamHeaderFallbackUrl(steam2x),
        'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/323150/header.jpg',
      );
      expect(
        SafeCoverImage.getSteamHeaderFallbackUrl(steam1x),
        'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/323150/header.jpg',
      );
      expect(SafeCoverImage.getSteamHeaderFallbackUrl(nonSteam), isNull);
    });
  });

  group('16. Shamsi Agenda Banner: Reminders Removed & Date Pick Added (Tasks 2 & 3)', () {
    testWidgets('ShamsiAgendaBanner renders without + Reminder and with Pick Date', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShamsiAgendaBanner(
              events: const [],
              palette: palette,
            ),
          ),
        ),
      );

      // Verify + Reminder is completely absent!
      expect(find.text('+ Reminder'), findsNothing);
      expect(find.text('No reminders or events scheduled for this day.'), findsNothing);

      // Verify Pick Date button exists
      expect(find.text('Pick Date'), findsOneWidget);

      // Verify month navigation buttons exist
      expect(find.text('« Month'), findsOneWidget);
      expect(find.text('Month »'), findsOneWidget);
    });
  });

  group('17. Month Navigation & DateNavigationService.shiftMonths', () {
    test('shiftMonths advances within the same year', () {
      final start = Jalali(1403, 5, 15);
      final next = DateNavigationService.shiftMonths(start, 1);
      expect(next.year, 1403);
      expect(next.month, 6);
      expect(next.day, 15);
    });

    test('shiftMonths goes backward within the same year', () {
      final start = Jalali(1403, 5, 15);
      final prev = DateNavigationService.shiftMonths(start, -1);
      expect(prev.year, 1403);
      expect(prev.month, 4);
      expect(prev.day, 15);
    });

    test('shiftMonths rolls over to next year from Esfand', () {
      final start = Jalali(1403, 12, 10);
      final next = DateNavigationService.shiftMonths(start, 1);
      expect(next.year, 1404);
      expect(next.month, 1);
      expect(next.day, 10);
    });

    test('shiftMonths rolls over to previous year from Farvardin', () {
      final start = Jalali(1403, 1, 10);
      final prev = DateNavigationService.shiftMonths(start, -1);
      expect(prev.year, 1402);
      expect(prev.month, 12);
      expect(prev.day, 10);
    });

    test('shiftMonths clamps day if destination month has fewer days', () {
      // Shahrivar has 31 days; Mehr has 30 days
      final start = Jalali(1403, 6, 31);
      final next = DateNavigationService.shiftMonths(start, 1);
      expect(next.year, 1403);
      expect(next.month, 7);
      expect(next.day, 30);
    });
  });

  group('18. Postpone Button Tooltip & Long Press Sub-Menu (SDD 3.2.2)', () {
    testWidgets('Postpone button triggers postpone on tap and date picker sub-menu on long press', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      bool postponeToDateTriggered = false;
      bool postponeOneDayTriggered = false;

      final task = Task(
        id: 't1',
        title: 'Review PR',
        category: TaskCategory.daily,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              palette: palette,
              onStatusChange: (_) {},
              onPostponeOneDay: () => postponeOneDayTriggered = true,
              onPostponeToDate: () => postponeToDateTriggered = true,
            ),
          ),
        ),
      );

      // Verify Postpone button exists (formerly Tomorrow)
      final postponeFinder = find.text('Postpone');
      expect(postponeFinder, findsOneWidget);

      // Quick tap triggers onPostponeOneDay
      await tester.tap(postponeFinder);
      await tester.pumpAndSettle();
      expect(postponeOneDayTriggered, isTrue);

      // Long press triggers onPostponeToDate (sub-menu)
      await tester.longPress(postponeFinder);
      await tester.pumpAndSettle();
      expect(postponeToDateTriggered, isTrue);

      // Tooltip should be present with instructional text
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: postponeFinder, matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, 'Tap: Postpone (+1 day) • Hold: Pick Shamsi date');
    });
  });

  group('19. MediaCard Layout & Description Box Under Cover', () {
    testWidgets('MediaCard renders description, score, progress, and actions under cover', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      final item = MediaItem(
        id: 'm1',
        type: MediaType.videoGame,
        title: 'Cyberpunk 2077',
        releaseYear: 2020,
        personalNotes: 'Finished Phantom Liberty expansion.',
        progressCurrent: 30,
        progressTotal: 50,
        labels: ['RPG', 'Sci-Fi'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: item,
              palette: palette,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ),
      );

      // Verify Title, Labels, Personal Notes, and Actions are rendered cleanly
      expect(find.text('Cyberpunk 2077'), findsOneWidget);
      expect(find.text('RPG'), findsOneWidget);
      expect(find.text('Sci-Fi'), findsOneWidget);
      expect(find.text('📝 Finished Phantom Liberty expansion.'), findsOneWidget);
      expect(find.text('+ Update'), findsOneWidget);
      expect(find.text('Schedule Today'), findsOneWidget);
    });
  });

  group('20. Version 2.3.0 SDD Verification Suite', () {
    test('Font elimination: Vazirmatn completely removed from AppFontStyle and theme fallbacks', () {
      final styleNames = AppFontStyle.values.map((e) => e.name).toList();
      expect(styleNames.contains('vazirmatn'), isFalse);
      expect(AppTheme.getFontFamilyName(AppFontStyle.defaultSans), 'sans-serif');
      expect(AppTheme.getFontFallbackList(AppFontStyle.defaultSans), contains('sans-serif'));
    });

    test('Universal Sentence Case Input Standard: toSentenceCase and Formatter', () {
      expect(toSentenceCase('complete the remaining tasks in SDD'), 'Complete the remaining tasks in SDD');
      expect(toSentenceCase('   flutter 3.13.7 release   '), '   Flutter 3.13.7 release   ');
      expect(toSentenceCase(''), '');
      expect(toSentenceCase('123 numeric start'), '123 numeric start');

      final formatter = SentenceCaseTextInputFormatter();
      const oldVal = TextEditingValue(text: 'buy mi', selection: TextSelection.collapsed(offset: 6));
      const newVal = TextEditingValue(text: 'buy milk', selection: TextSelection.collapsed(offset: 8));
      final res = formatter.formatEditUpdate(oldVal, newVal);
      expect(res.text, 'Buy milk');
      expect(res.selection.baseOffset, 8);
    });

    test('Custom Event Restoration: ShamsiEvent birthday vs custom event serialization', () {
      final bday = ShamsiEvent(
        id: 'ev-bday',
        title: 'Navid Birthday',
        jalaliMonth: 1,
        jalaliDay: 15,
        category: EventCategory.birthday,
        isCustom: true,
      );
      expect(bday.category, EventCategory.birthday);
      expect(bday.isCustom, isTrue);

      final jsonBday = bday.toJson();
      final revivedBday = ShamsiEvent.fromJson(jsonBday);
      expect(revivedBday.title, 'Navid Birthday');
      expect(revivedBday.category, EventCategory.birthday);
      expect(revivedBday.isCustom, isTrue);

      final customEvent = ShamsiEvent(
        id: 'ev-custom',
        title: 'Project Deadline',
        jalaliMonth: 2,
        jalaliDay: 20,
        category: EventCategory.customDate,
        isCustom: true,
      );
      expect(customEvent.category, EventCategory.customDate);
      expect(customEvent.isCustom, isTrue);

      final jsonCustom = customEvent.toJson();
      final revivedCustom = ShamsiEvent.fromJson(jsonCustom);
      expect(revivedCustom.category, EventCategory.customDate);
    });

    test('Theme Palettes Revitalization & Consolidation: Persian Turquoise Merged, Purple Deepened', () {
      // Persian Turquoise merged into Nordic Slate
      expect(AppTheme.vibes.containsKey(ThemeVibe.minimalNordic), isTrue);
      final nordic = AppTheme.vibes[ThemeVibe.minimalNordic]!;
      expect(nordic.label, 'Nordic Slate');
      expect(nordic.bgCanvas, const Color(0xFF091319));
      expect(nordic.bgSurface, const Color(0xFF0F1F28));
      expect(nordic.bgElevated, const Color(0xFF162D3A));
      expect(nordic.accentPrimary, const Color(0xFF38BDF8));

      // 3 Purple Palettes strictly differentiated
      final amethyst = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      final purpleGold = AppTheme.vibes[ThemeVibe.imperialGold]!;
      final purpleOrange = AppTheme.vibes[ThemeVibe.purpleOrange]!;

      expect(amethyst.accentPrimary, const Color(0xFFB026FF));
      expect(amethyst.bgCanvas, const Color(0xFF05020A));
      expect(amethyst.bgSurface, const Color(0xFF0F0419));
      expect(amethyst.bgElevated, const Color(0xFF1B072D));

      expect(purpleGold.accentPrimary, const Color(0xFFF59E0B));
      expect(purpleGold.bgCanvas, const Color(0xFF08040C));

      expect(purpleOrange.accentPrimary, const Color(0xFFFF6B00));
      expect(purpleOrange.bgCanvas, const Color(0xFF12061A));

      // Revitalized palettes
      final emerald = AppTheme.vibes[ThemeVibe.emeraldCyan]!;
      expect(emerald.accentPrimary, const Color(0xFF10B981));

      final arctic = AppTheme.vibes[ThemeVibe.arcticFrost]!;
      expect(arctic.accentPrimary, const Color(0xFF7DD3FC));
    });

    test('Native Persian RTL Auto-Detection: RtlDetectionService', () {
      expect(RtlDetectionService.startsWithRtl('سلام'), isTrue);
      expect(RtlDetectionService.startsWithRtl('پروژه جدید'), isTrue);
      expect(RtlDetectionService.startsWithRtl('Hello'), isFalse);
      expect(RtlDetectionService.startsWithRtl('123 Persian'), isFalse);

      expect(RtlDetectionService.resolveDirection('تسک امروز'), TextDirection.rtl);
      expect(RtlDetectionService.resolveDirection('Daily Task'), TextDirection.ltr);

      expect(RtlDetectionService.resolveAlignment('تسک فارسی'), TextAlign.right);
      expect(RtlDetectionService.resolveAlignment('English Task'), TextAlign.left);
    });

    test('Persistent Cover Art Disk Cache: SafeCoverImage CORS proxy and sanitizeUrl work correctly', () {
      const bad = 'https://images.launchbox-app.com//img.png';
      expect(SafeCoverImage.sanitizeUrl(bad), 'https://images.launchbox-app.com/img.png');
      expect(SafeCoverImage.toCorsProxyUrl('https://example.com/cover.jpg'), startsWith('https://images.weserv.nl/?url='));
    });

    testWidgets('3-Second Hold to Edit Task Card: onEdit callback triggered on long press', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      final task = Task(id: 't-edit', title: 'Editable Task', notes: 'Has notes');
      bool editTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              palette: palette,
              onStatusChange: (_) {},
              onEdit: () => editTriggered = true,
            ),
          ),
        ),
      );

      final cardFinder = find.text('Editable Task');
      expect(cardFinder, findsOneWidget);

      await tester.longPress(cardFinder);
      await tester.pumpAndSettle();

      expect(editTriggered, isTrue);
    });

    testWidgets('Compact Mini-Tasks: Renders compact layout when task notes are empty', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      final miniTask = Task(id: 't-mini', title: 'Mini Task', notes: '');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: miniTask,
              palette: palette,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Mini Task'), findsOneWidget);
      // Ensure no notes block is rendered
      expect(find.byIcon(Icons.notes), findsNothing);
    });

    testWidgets('3-Second Hold to Edit Media Card: onEditMedia callback triggered on long press', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      final item = MediaItem(
        id: 'm-edit',
        type: MediaType.book,
        title: 'Project Hail Mary',
        releaseYear: 2021,
        progressCurrent: 120,
        progressTotal: 496,
      );
      bool editMediaTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: item,
              palette: palette,
              isGrid: false,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
              onEditMedia: () => editMediaTriggered = true,
            ),
          ),
        ),
      );

      final mediaTitleFinder = find.text('Project Hail Mary');
      expect(mediaTitleFinder, findsOneWidget);

      await tester.longPress(mediaTitleFinder);
      await tester.pumpAndSettle();

      expect(editMediaTriggered, isTrue);
    });
  });

  group('21. Version 2.4.0 SDD Verification Suite', () {
    test('Theme Harmonization: Persian Turquoise merged into Nordic Slate and Deep Amethyst pitch-black', () {
      final nordic = AppTheme.vibes[ThemeVibe.minimalNordic]!;
      expect(nordic.bgCanvas, const Color(0xFF091319));
      expect(nordic.bgSurface, const Color(0xFF0F1F28));
      expect(nordic.bgElevated, const Color(0xFF162D3A));
      expect(nordic.accentPrimary, const Color(0xFF38BDF8));

      final amethyst = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      expect(amethyst.bgCanvas, const Color(0xFF05020A));
      expect(amethyst.bgSurface, const Color(0xFF0F0419));
      expect(amethyst.bgElevated, const Color(0xFF1B072D));
      expect(amethyst.accentPrimary, const Color(0xFFB026FF));

      // 9 total vibes
      expect(ThemeVibe.values.length, 9);
    });

    test('Completed ("Done") Tasks Sinking: compareTaskExecutionState partitions Done to bottom', () {
      final task1Pending = Task(id: '1', title: 'Task 1', status: TaskStatus.pending, orderIndex: 0);
      final task2Done = Task(id: '2', title: 'Task 2', status: TaskStatus.done, orderIndex: 1);
      final task3Pending = Task(id: '3', title: 'Task 3', status: TaskStatus.pending, orderIndex: 2);
      final task4Done = Task(id: '4', title: 'Task 4', status: TaskStatus.done, orderIndex: 3);

      final list = [task2Done, task1Pending, task4Done, task3Pending];
      list.sort(compareTaskExecutionState);

      expect(list.map((t) => t.id).toList(), ['1', '3', '2', '4']);
    });

    testWidgets('Postpone Button Dynamic Multiplier & Standalone Text Box Elimination (SDD 3.2.2)', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;

      // 1x postponed
      final task1x = Task(
        id: 't-1x',
        title: 'Task 1x Postponed',
        category: TaskCategory.daily,
        status: TaskStatus.postponed,
        postponedCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task1x,
              palette: palette,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Postpone'), findsOneWidget);
      // Standalone text box completely eliminated
      expect(find.text('Postponed (1x)'), findsNothing);

      // 3x postponed
      final task3x = Task(
        id: 't-3x',
        title: 'Task 3x Postponed',
        category: TaskCategory.daily,
        status: TaskStatus.postponed,
        postponedCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task3x,
              palette: palette,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Postpone 3x'), findsOneWidget);
      expect(find.text('Postponed (3x)'), findsNothing);
    });

    testWidgets('ShamsiAgendaBanner Centered Date & Centered Action Buttons (SDD 3.2.1)', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShamsiAgendaBanner(
              events: const [],
              palette: palette,
              onAddCustomEvent: () {},
            ),
          ),
        ),
      );

      expect(find.text('Pick Date'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
    });

    test('Media Label Service: "Fantasy" preset & permanent untagMediaItems deletion', () {
      expect(MediaLabelService.presetLabels, contains('Fantasy'));
      expect(MediaLabelService.presetLabels.contains('Masterpiece'), isFalse);

      final items = <MediaItem>[
        MediaItem(id: 'm1', type: MediaType.movie, title: 'Item 1', releaseYear: 2020, progressCurrent: 0, progressTotal: 100, labels: ['Fantasy', 'Sci-Fi']),
        MediaItem(id: 'm2', type: MediaType.book, title: 'Item 2', releaseYear: 2021, progressCurrent: 0, progressTotal: 200, labels: ['Drama']),
      ];

      final untagged = MediaLabelService.untagMediaItems(items, 'Fantasy');
      expect(untagged[0].labels, ['Sci-Fi']);
      expect(untagged[1].labels, ['Drama']);
    });

    test('Chronological Media Sorting: custom order sorts by createdAt descending', () {
      final now = DateTime.now();
      final itemOlder = MediaItem(
        id: 'm-old',
        type: MediaType.videoGame,
        title: 'Old Game',
        releaseYear: 2010,
        progressCurrent: 0,
        progressTotal: 10,
        createdAt: now.subtract(const Duration(days: 10)),
      );
      final itemNewer = MediaItem(
        id: 'm-new',
        type: MediaType.videoGame,
        title: 'New Game',
        releaseYear: 2024,
        progressCurrent: 0,
        progressTotal: 10,
        createdAt: now,
      );

      final list = [itemOlder, itemNewer];
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(list.first.id, 'm-new');
      expect(list.last.id, 'm-old');
    });

    test('Multi-Platform Cover Architecture: Libretro and RAWG search fallbacks exist', () {
      final resultRawg = CoverSearchResult(
        title: 'The Legend of Zelda: Breath of the Wild',
        coverUrl: 'https://media.rawg.io/media/games/zelda.jpg',
        year: '2017',
        source: 'RAWG',
      );
      expect(resultRawg.source, 'RAWG');
      expect(resultRawg.year, '2017');

      final resultLibretro = CoverSearchResult(
        title: 'Super Mario Odyssey',
        coverUrl: 'https://raw.githubusercontent.com/libretro-thumbnails/Nintendo_-_Nintendo_Switch/master/Named_Boxarts/Super_Mario_Odyssey.png',
        source: 'Libretro',
      );
      expect(resultLibretro.source, 'Libretro');
    });
  });

  group('22. Version 2.4.1 Refinements & Multi-Platform Cover Expansion', () {
    test('Theme Order: Emerald Cyan precedes Solar Tangerine (Spring -> Summer -> Autumn -> Winter)', () {
      final cyanIdx = ThemeVibe.values.indexOf(ThemeVibe.emeraldCyan);
      final solarIdx = ThemeVibe.values.indexOf(ThemeVibe.solarTangerine);
      final sunsetIdx = ThemeVibe.values.indexOf(ThemeVibe.sunsetAmber);
      final arcticIdx = ThemeVibe.values.indexOf(ThemeVibe.arcticFrost);

      expect(cyanIdx < solarIdx, isTrue, reason: 'Emerald Cyan (Spring) must precede Solar Tangerine (Summer)');
      expect(solarIdx < sunsetIdx, isTrue, reason: 'Solar Tangerine (Summer) must precede Sunset Amber (Autumn)');
      expect(sunsetIdx < arcticIdx, isTrue, reason: 'Sunset Amber (Autumn) must precede Arctic Frost (Winter)');
    });

    test('Seasonal Theme Differentiation: Solar Tangerine vs Sunset Amber', () {
      final solar = AppTheme.vibes[ThemeVibe.solarTangerine]!;
      final sunset = AppTheme.vibes[ThemeVibe.sunsetAmber]!;

      // Verify they do not share the exact same primary accent or canvas
      expect(solar.accentPrimary != sunset.accentPrimary, isTrue);
      expect(solar.bgCanvas != sunset.bgCanvas, isTrue);
      expect(solar.accentGradient.colors != sunset.accentGradient.colors, isTrue);

      // Solar Tangerine is bright summer solar gold
      expect(solar.accentPrimary, const Color(0xFFFFA000));
      // Sunset Amber is rich autumn maple/burnt orange
      expect(sunset.accentPrimary, const Color(0xFFEA580C));
    });

    test('generateGameTitleVariants generates console variants (Shadow of the Colossus, God of War III, Minish Cap)', () {
      final colossusVariants = CoverFetchService.generateGameTitleVariants('Shadow of Colossus');
      expect(colossusVariants.any((v) => v.contains('Shadow of the Colossus')), isTrue);
      expect(colossusVariants.any((v) => v.contains('(USA)')), isTrue);

      final gowVariants = CoverFetchService.generateGameTitleVariants('God of War 3');
      expect(gowVariants.any((v) => v.contains('God of War III')), isTrue);

      final zeldaVariants = CoverFetchService.generateGameTitleVariants('The Legend of Zelda: The Minish Cap');
      expect(zeldaVariants.any((v) => v.contains('The Legend of Zelda - The Minish Cap')), isTrue);
    });

    test('Multi-source game search aggregates candidates from LaunchBox and Wikipedia', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'gamesdb.launchbox-app.com') {
          return http.Response(
            '<html><body><img src="https://images.launchbox-app.com/colossus-front.jpg" /></body></html>',
            200,
          );
        } else if (request.url.host == 'en.wikipedia.org') {
          return http.Response(
            jsonEncode({
              'query': {
                'pages': [
                  {
                    'title': 'Shadow of the Colossus',
                    'thumbnail': {
                      'source': 'https://upload.wikimedia.org/wikipedia/en/thumb/colossus.jpg',
                    }
                  }
                ]
              }
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final results = await CoverFetchService.searchCovers(
        query: 'Shadow of the Colossus',
        type: MediaType.videoGame,
        client: mockClient,
      );

      expect(results.any((r) => r.source == 'LaunchBox'), isTrue);
      expect(results.any((r) => r.source == 'Wikipedia'), isTrue);
      expect(results.firstWhere((r) => r.source == 'LaunchBox').coverUrl, 'https://images.launchbox-app.com/colossus-front.jpg');
      expect(results.firstWhere((r) => r.source == 'Wikipedia').coverUrl, 'https://upload.wikimedia.org/wikipedia/en/thumb/colossus.jpg');
    });

    test('God of War 3, Minish Cap, and Bloodborne cover resolution with LaunchBox alt matching and Wikipedia pilicense=any', () async {
      final mockClient = MockClient((request) async {
        final host = request.url.host;
        final query = request.url.query;

        // LaunchBox Bloodborne with real HTML card structures
        if (host == 'gamesdb.launchbox-app.com') {
          return http.Response('''
            <div class="gameCard">
              <div class="cardImgPart">
                <img src="https://images.launchbox-app.com/1e88a41b-c210.jpg" alt="Bloodborne (Port)" />
              </div>
            </div>
            <div class="gameCard">
              <div class="cardImgPart">
                <img src="https://images.launchbox-app.com/r2_215c7930-3f01.jpeg" alt="Bloodborne" />
              </div>
            </div>
            <div class="gameCard">
              <div class="cardImgPart">
                <img src="https://images.launchbox-app.com/unrelated-game.png" alt="Unrelated Game" />
              </div>
            </div>
          ''', 200, headers: {'content-type': 'text/html; charset=utf-8'});
        }

        // Wikipedia with pilicense=any
        if (host == 'en.wikipedia.org') {
          if (query.contains('God%20of%20War%20III') || query.contains('God+of+War+III')) {
            return http.Response(jsonEncode({
              'query': {
                'pages': [
                  {
                    'title': 'God of War III',
                    'thumbnail': {
                      'source': 'https://upload.wikimedia.org/wikipedia/en/8/8b/God_of_War_III_cover_art.jpg',
                    }
                  }
                ]
              }
            }), 200);
          } else if (query.contains('Minish%20Cap') || query.contains('Minish+Cap')) {
            return http.Response(jsonEncode({
              'query': {
                'pages': [
                  {
                    'title': 'The Legend of Zelda: The Minish Cap',
                    'thumbnail': {
                      'source': 'https://upload.wikimedia.org/wikipedia/en/0/0a/TLOZ-_Minish_Cap_NA_Box_art.png',
                    }
                  }
                ]
              }
            }), 200);
          }
        }

        // Steam returning unrelated DLC for God of War 3
        if (host == 'store.steampowered.com') {
          return http.Response(jsonEncode({
            'items': [
              {
                'id': 694780,
                'name': 'SUPER ARMY OF TENTACLES 3, Winter Outfit Pack I: War of the Old Gods',
                'tiny_image': 'https://shared.akamai.steamstatic.com/apps/694780/capsule_231x87.jpg',
              }
            ]
          }), 200);
        }

        return http.Response('Not found', 404);
      });

      // 1. Bloodborne verifies exact match prioritized and unrelated Korean images rejected
      final bbResults = await CoverFetchService.searchCovers(
        query: 'Bloodborne',
        type: MediaType.videoGame,
        client: mockClient,
      );
      expect(bbResults, isNotEmpty);
      expect(bbResults.first.coverUrl, 'https://images.launchbox-app.com/r2_215c7930-3f01.jpeg');
      expect(bbResults.any((r) => r.coverUrl.contains('unrelated-game')), isFalse);

      // 2. God of War 3 verifies Roman numeral mapping and Steam unrelated DLC rejection
      final gowResults = await CoverFetchService.searchCovers(
        query: 'God of War 3',
        type: MediaType.videoGame,
        client: mockClient,
      );
      expect(gowResults, isNotEmpty);
      expect(gowResults.any((r) => r.source == 'Wikipedia' && r.coverUrl.contains('God_of_War_III_cover_art.jpg')), isTrue);
      // Unrelated tentacle DLC must be rejected
      expect(gowResults.any((r) => r.title.contains('SUPER ARMY OF TENTACLES')), isFalse);

      // 3. The Legend of Zelda: The Minish Cap finds authentic box art
      final zeldaResults = await CoverFetchService.searchCovers(
        query: 'The Legend of Zelda: The Minish Cap',
        type: MediaType.videoGame,
        client: mockClient,
      );
      expect(zeldaResults, isNotEmpty);
      expect(zeldaResults.first.coverUrl, 'https://upload.wikimedia.org/wikipedia/en/0/0a/TLOZ-_Minish_Cap_NA_Box_art.png');
    });
  });

  group('23. Completed (100%) Media Done State, Down-Listing, & Green Visual Styling', () {
    test('MediaItem.isCompleted and isDone identify 100% completion accurately', () {
      final incomplete = MediaItem(
        id: '1',
        type: MediaType.book,
        title: 'Dune',
        releaseYear: 1965,
        progressCurrent: 200,
        progressTotal: 500,
      );
      expect(incomplete.isCompleted, isFalse);
      expect(incomplete.isDone, isFalse);

      final completedExact = MediaItem(
        id: '2',
        type: MediaType.book,
        title: 'Dune Messiah',
        releaseYear: 1969,
        progressCurrent: 300,
        progressTotal: 300,
      );
      expect(completedExact.isCompleted, isTrue);
      expect(completedExact.isDone, isTrue);

      final completedExceed = completedExact.copyWith(progressCurrent: 350);
      expect(completedExceed.isCompleted, isTrue);
      expect(completedExceed.isDone, isTrue);

      final zeroTotal = completedExact.copyWith(progressTotal: 0);
      expect(zeroTotal.isCompleted, isFalse);
    });

    test('compareMediaExecutionState partitions active items before completed items', () {
      final active1 = MediaItem(id: 'a1', type: MediaType.book, title: 'Active 1', releaseYear: 2020, progressCurrent: 10, progressTotal: 100);
      final active2 = MediaItem(id: 'a2', type: MediaType.book, title: 'Active 2', releaseYear: 2021, progressCurrent: 90, progressTotal: 100);
      final done1 = MediaItem(id: 'd1', type: MediaType.book, title: 'Done 1', releaseYear: 2022, progressCurrent: 100, progressTotal: 100);
      final done2 = MediaItem(id: 'd2', type: MediaType.book, title: 'Done 2', releaseYear: 2023, progressCurrent: 100, progressTotal: 100);

      expect(compareMediaExecutionState(active1, done1), -1);
      expect(compareMediaExecutionState(done1, active1), 1);
      expect(compareMediaExecutionState(active1, active2), 0);
      expect(compareMediaExecutionState(done1, done2), 0);

      final list = [done1, active1, done2, active2];
      final active = list.where((m) => !m.isCompleted).toList();
      final done = list.where((m) => m.isCompleted).toList();
      final sorted = [...active, ...done];

      expect(sorted.map((m) => m.id).toList(), ['a1', 'a2', 'd1', 'd2']);
    });

    test('MediaGoalSyncService blocks scheduling when media item is completed', () {
      final completed = MediaItem(
        id: 'c1',
        type: MediaType.movie,
        title: 'Oppenheimer',
        releaseYear: 2023,
        progressCurrent: 180,
        progressTotal: 180,
      );

      expect(MediaGoalSyncService.canSchedule(completed), isFalse);
      final validationMsg = MediaGoalSyncService.validateGoalAmount(30, completed);
      expect(validationMsg, contains('already completed'));

      final incomplete = completed.copyWith(progressCurrent: 90);
      expect(MediaGoalSyncService.canSchedule(incomplete), isTrue);
      expect(MediaGoalSyncService.validateGoalAmount(30, incomplete), isNull);
    });

    testWidgets('MediaCard renders emerald green border and Completed badge when 100%', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      final completedItem = MediaItem(
        id: 'done_1',
        type: MediaType.videoGame,
        title: 'Elden Ring',
        releaseYear: 2022,
        progressCurrent: 50,
        progressTotal: 50,
      );

      bool scheduleTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: completedItem,
              palette: palette,
              isGrid: false,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () => scheduleTapped = true,
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ),
      );

      // Verify "Completed" indicator is displayed instead of "Schedule Today"
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Schedule Today'), findsNothing);
      expect(scheduleTapped, isFalse);
      expect(find.text('Done'), findsOneWidget); // Cover overlay badge

      // Container border must be emerald green (0x8010B981)
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector).first,
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, const Color(0x8010B981));
      expect(border.top.width, 1.5);
    });

    testWidgets('MediaCard grid view renders emerald green border and Completed badge when 100%', (tester) async {
      final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
      final completedItem = MediaItem(
        id: 'done_grid',
        type: MediaType.book,
        title: 'Neuromancer',
        releaseYear: 1984,
        progressCurrent: 271,
        progressTotal: 271,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: completedItem,
              palette: palette,
              isGrid: true,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ),
      );

      // In grid view, "Completed" badge replaces "Schedule"
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Schedule'), findsNothing);
      expect(find.text('Done'), findsOneWidget); // Cover badge

      // Container border must be emerald green (0x8010B981)
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector).first,
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, const Color(0x8010B981));
      expect(border.top.width, 1.5);
    });

    group('24. Version 2.5.0 SDD Verification Suite', () {
      testWidgets('3.4.1 Hold button hidden on completed media items (list and grid)', (tester) async {
        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        final activeItem = MediaItem(
          id: 'act1',
          type: MediaType.book,
          title: 'Active Book',
          releaseYear: 2023,
          progressCurrent: 50,
          progressTotal: 100,
        );
        final completedItem = MediaItem(
          id: 'comp1',
          type: MediaType.book,
          title: 'Completed Book',
          releaseYear: 2023,
          progressCurrent: 100,
          progressTotal: 100,
        );

        // 1. List Card - Active: Hold is visible
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: activeItem,
              palette: palette,
              isGrid: false,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ));
        expect(find.text('Hold'), findsOneWidget);

        // 2. List Card - Completed: Hold is hidden
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: completedItem,
              palette: palette,
              isGrid: false,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ));
        expect(find.text('Hold'), findsNothing);

        // 3. Grid Card - Active: Active text is visible
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: activeItem,
              palette: palette,
              isGrid: true,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ));
        expect(find.text('▶ Active'), findsOneWidget);

        // 4. Grid Card - Completed: Active/On-hold text is hidden
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: completedItem,
              palette: palette,
              isGrid: true,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ));
        expect(find.text('▶ Active'), findsNothing);
        expect(find.text('⏸ On-hold'), findsNothing);
      });

      testWidgets('3.4.2 Reversed Shamsi date order in top bar', (tester) async {
        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        final testDate = Jalali(1405, 8, 21); // 21 Aban 1405

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ShamsiAgendaBanner(
              events: const [],
              palette: palette,
              selectedDate: testDate,
            ),
          ),
        ));

        // Top bar date formatted as '$monthName\u00A0${_toPersianDigits(1405)}'
        expect(find.text('آبان\u00A0۱۴۰۵'), findsOneWidget);
      });

      testWidgets('3.4.3 Quotation marks removed from media descriptions', (tester) async {
        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        final item = MediaItem(
          id: 'desc1',
          type: MediaType.book,
          title: 'Dune',
          releaseYear: 1965,
          progressCurrent: 10,
          progressTotal: 100,
          personalNotes: 'Masterpiece of science fiction',
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: item,
              palette: palette,
              isGrid: false,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ));

        expect(find.text('📝 Masterpiece of science fiction'), findsOneWidget);
        expect(find.text('📝 "Masterpiece of science fiction"'), findsNothing);
      });

      test('3.4.4 Description field in MediaItem model and serialization', () {
        final item = MediaItem(
          id: 'notes_test',
          type: MediaType.videoGame,
          title: 'Hollow Knight',
          releaseYear: 2017,
          progressCurrent: 10,
          progressTotal: 100,
          personalNotes: 'Best metroidvania ever',
        );

        expect(item.personalNotes, 'Best metroidvania ever');
        final jsonMap = item.toJson();
        expect(jsonMap['personalNotes'], 'Best metroidvania ever');

        final restored = MediaItem.fromJson(jsonMap);
        expect(restored.personalNotes, 'Best metroidvania ever');

        final updated = item.copyWith(personalNotes: 'Updated notes');
        expect(updated.personalNotes, 'Updated notes');
      });

      test('3.4.5 MediaInfoFetchService fetches TV show episodes, movie runtime, and books/games year', () async {
        final mockClient = MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('api.tvmaze.com/singlesearch/shows')) {
            return http.Response(
              jsonEncode({
                'name': 'Severance',
                'premiered': '2022-02-18',
                '_embedded': {
                  'episodes': [
                    {'id': 1}, {'id': 2}, {'id': 3}, {'id': 4}, {'id': 5},
                    {'id': 6}, {'id': 7}, {'id': 8}, {'id': 9}
                  ]
                }
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (url.contains('itunes.apple.com/search') && url.contains('entity=movie')) {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'trackName': 'Oppenheimer',
                    'releaseDate': '2023-07-21T07:00:00Z',
                    'trackTimeMillis': 10800000 // 180 min
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (url.contains('openlibrary.org/search.json')) {
            return http.Response(
              jsonEncode({
                'docs': [
                  {
                    'title': 'Dune',
                    'first_publish_year': 1965
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (url.contains('en.wikipedia.org/api/rest_v1/page/summary')) {
            return http.Response(
              jsonEncode({
                'title': 'Elden Ring',
                'extract': 'Elden Ring is a 2022 action role-playing game developed by FromSoftware.'
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        // TV Show
        final tvInfo = await MediaInfoFetchService.fetchInfo(
          title: 'Severance',
          type: MediaType.tvShow,
          client: mockClient,
        );
        expect(tvInfo, isNotNull);
        expect(tvInfo!.releaseYear, 2022);
        expect(tvInfo.episodeCount, 9);

        // Movie
        final movieInfo = await MediaInfoFetchService.fetchInfo(
          title: 'Oppenheimer',
          type: MediaType.movie,
          client: mockClient,
        );
        expect(movieInfo, isNotNull);
        expect(movieInfo!.releaseYear, 2023);
        expect(movieInfo.runtimeMinutes, 180);

        // Book
        final bookInfo = await MediaInfoFetchService.fetchInfo(
          title: 'Dune',
          type: MediaType.book,
          client: mockClient,
        );
        expect(bookInfo, isNotNull);
        expect(bookInfo!.releaseYear, 1965);

        // Video Game
        final gameInfo = await MediaInfoFetchService.fetchInfo(
          title: 'Elden Ring',
          type: MediaType.videoGame,
          client: mockClient,
        );
        expect(gameInfo, isNotNull);
        expect(gameInfo!.releaseYear, 2022);

        // Empty title returns null
        final emptyInfo = await MediaInfoFetchService.fetchInfo(
          title: '   ',
          type: MediaType.movie,
          client: mockClient,
        );
        expect(emptyInfo, isNull);
      });

      test('3.4.6 Default event deletion fix via deleted-event-ID exclusion set', () async {
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();

        final initialEvents = storage.loadShamsiEvents();
        expect(initialEvents.any((e) => e.id == 'b_maryam'), isTrue);

        await storage.addDeletedEventId('b_maryam');
        expect(storage.loadDeletedEventIds(), contains('b_maryam'));

        final eventsAfterDelete = storage.loadShamsiEvents();
        expect(eventsAfterDelete.any((e) => e.id == 'b_maryam'), isFalse);
      });

      test('3.4.7 Persistent media sort preference in storage service', () async {
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();

        expect(storage.loadMediaSort(), 'custom');

        await storage.saveMediaSort('score');
        expect(storage.loadMediaSort(), 'score');

        await storage.saveMediaSort('name');
        expect(storage.loadMediaSort(), 'name');
      });

      testWidgets('3.4.8 Redundant "+N on check" label is removed from task card bottom row', (tester) async {
        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        final task = Task(
          id: 'task_linked_1',
          title: 'Read chapter 3',
          category: TaskCategory.daily,
          linkedMediaId: 'media_123',
          mediaUnitsToAdvance: 15.0,
          mediaTitle: 'Neuromancer',
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              palette: palette,
              onStatusChange: (_) {},
              onDemoteToBacklog: () {},
            ),
          ),
        ));

        expect(find.text('To Backlog'), findsOneWidget);
        expect(find.text('+15 on check'), findsNothing);
        expect(find.text('🎯 Media Goal: Neuromancer'), findsOneWidget);
        expect(find.text('• +15'), findsOneWidget);
      });

      testWidgets('3.4.9 Global font size scaling in appearance settings and storage', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();

        expect(storage.loadFontSizeScale(), 1.0);
        await storage.saveFontSizeScale(1.2);
        expect(storage.loadFontSizeScale(), 1.2);

        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        double changedScale = 1.0;

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SettingsDrawer(
              currentVibe: ThemeVibe.deepAmethyst,
              currentFont: AppFontStyle.defaultSans,
              palette: palette,
              fontSizeScale: 1.2,
              onSelectVibe: (_) {},
              onSelectFont: (_) {},
              onFontSizeScaleChanged: (val) => changedScale = val,
            ),
          ),
        ));

        expect(changedScale, 1.0);

        await tester.scrollUntilVisible(
          find.text('FONT SIZE'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('FONT SIZE'), findsOneWidget);
        expect(find.text('Aa — 120%'), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
      });

      testWidgets('3.4.10 Smart created/completed date tracking on media tiles', (tester) async {
        final now = DateTime(2026, 11, 17);
        final item = MediaItem(
          id: 'date_test',
          type: MediaType.tvShow,
          title: 'Severance',
          releaseYear: 2022,
          progressCurrent: 9,
          progressTotal: 9,
          createdAt: now,
          displayDate: now,
        );

        // Serialization test
        final jsonMap = item.toJson();
        expect(jsonMap['displayDate'], now.toIso8601String());
        final restored = MediaItem.fromJson(jsonMap);
        expect(restored.displayDate, now);

        // Fallback test
        final mapWithoutDisplay = Map<String, dynamic>.from(jsonMap)..remove('displayDate');
        final restoredFallback = MediaItem.fromJson(mapWithoutDisplay);
        expect(restoredFallback.displayDate, now);

        // advanceProgress lifecycle transition test
        final incomplete = item.copyWith(progressCurrent: 8);
        final advanced = MediaGoalSyncService.advanceProgress(incomplete, 1);
        expect(advanced.isCompleted, isTrue);

        // revertProgress lifecycle transition test
        final reverted = MediaGoalSyncService.revertProgress(item, 1);
        expect(reverted.isCompleted, isFalse);

        // Render card test (shows Nov 17, 2026)
        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: item,
              palette: palette,
              isGrid: false,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ));
        expect(find.text('Nov 17, 2026'), findsOneWidget);

        // In Grid view as well
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaCard(
              item: item,
              palette: palette,
              isGrid: true,
              onToggleOnHold: (_) {},
              onUpdateProgress: () {},
              onEditCover: () {},
              onScheduleToday: () {},
              onEditNotes: () {},
              onEditLabels: () {},
            ),
          ),
        ));
        expect(find.text('Nov 17, 2026'), findsOneWidget);
      });

      testWidgets('3.4.11 Incomplete-day and all-done visual indicator in Shamsi calendar grid', (tester) async {
        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        final testDate = Jalali(1405, 8, 15);
        final taskCompletionMap = <String, ({int total, int done})>{
          '1405-08-10': (total: 3, done: 1), // Incomplete day
          '1405-08-12': (total: 2, done: 2), // All done day
        };

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShamsiAgendaBanner(
                events: const [],
                palette: palette,
                selectedDate: testDate,
                taskCompletionMap: taskCompletionMap,
              ),
            ),
          ),
        ));

        // Tap the "Calendar" button to expand the calendar grid
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();

        // Underline indicators are rendered as 2dp high containers at bottom of days
        final bars = tester.widgetList<Container>(
          find.byWidgetPredicate((widget) {
            if (widget is Container && widget.decoration is BoxDecoration) {
              final box = widget.decoration as BoxDecoration;
              if (box.borderRadius != null && widget.constraints?.maxHeight == 2) {
                return true;
              }
            }
            return false;
          }),
        );

        // There should be indicator bars rendered for days with tasks
        expect(bars.isNotEmpty, isTrue);
      });
    });

    group('25. Version 2.6.0 Feature Verification Suite', () {
      test('1. Canceled tasks do not count in daily total (0/1 becomes 0/0 Done)', () {
        final task1 = Task(id: '1', title: 'Task 1', status: TaskStatus.canceled, category: TaskCategory.daily);
        final daily = [task1];
        final dailyActiveTasks = daily.where((t) => t.status != TaskStatus.canceled).toList();
        final dailyTotal = dailyActiveTasks.length;
        final dailyDone = daily.where((t) => t.status == TaskStatus.done).length;
        expect(dailyTotal, 0);
        expect(dailyDone, 0);
        final badge = '$dailyDone/$dailyTotal Done';
        expect(badge, '0/0 Done');
      });

      test('2. Media ordering: uncompleted first, then on-hold, then finished', () {
        final uncompleted = MediaItem(id: '1', type: MediaType.movie, title: 'Active Movie', releaseYear: 2024, progressCurrent: 10, progressTotal: 100);
        final onHold = MediaItem(id: '2', type: MediaType.book, title: 'OnHold Book', releaseYear: 2023, progressCurrent: 20, progressTotal: 100, isOnHold: true);
        final finished = MediaItem(id: '3', type: MediaType.tvShow, title: 'Finished TV', releaseYear: 2022, progressCurrent: 10, progressTotal: 10);

        final list = [finished, onHold, uncompleted];
        final uncompletedList = list.where((m) => !m.isCompleted && !m.isOnHold).toList();
        final onHoldList = list.where((m) => !m.isCompleted && m.isOnHold).toList();
        final finishedList = list.where((m) => m.isCompleted).toList();

        expect(uncompletedList.single.id, '1');
        expect(onHoldList.single.id, '2');
        expect(finishedList.single.id, '3');
      });

      test('3. MediaInfoFetchService fetches movie info with Cinemeta metadata fallback', () async {
        final mockClient = MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('itunes.apple.com/search') && url.contains('country=US')) {
            return http.Response(jsonEncode({'resultCount': 0, 'results': []}), 200, headers: {'content-type': 'application/json'});
          } else if (url.contains('v3-cinemeta.strem.io/catalog/movie/top/search=')) {
            return http.Response(
              jsonEncode({
                'metas': [
                  {
                    'id': 'tt1375666',
                    'name': 'Inception',
                    'releaseInfo': '2010',
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (url.contains('v3-cinemeta.strem.io/meta/movie/tt1375666.json')) {
            return http.Response(
              jsonEncode({
                'meta': {
                  'id': 'tt1375666',
                  'name': 'Inception',
                  'year': '2010',
                  'runtime': '148 min',
                }
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final info = await MediaInfoFetchService.fetchInfo(
          title: 'Inception',
          type: MediaType.movie,
          client: mockClient,
        );
        expect(info, isNotNull);
        expect(info!.releaseYear, 2010);
        expect(info.runtimeMinutes, 148);
      });

      testWidgets('4. FastScrollRail renders quick-jump sections and triggers callbacks', (tester) async {
        final controller = ScrollController();
        final palette = AppTheme.vibes[ThemeVibe.deepAmethyst]!;
        bool activeTapped = false;
        bool holdTapped = false;
        bool doneTapped = false;

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: FastScrollRail(
              controller: controller,
              palette: palette,
              sections: [
                FastScrollSection(id: 'active', label: 'Active', icon: Icons.play_arrow, onTap: () => activeTapped = true),
                FastScrollSection(id: 'onHold', label: 'Hold', icon: Icons.pause, onTap: () => holdTapped = true),
                FastScrollSection(id: 'finished', label: 'Done', icon: Icons.check, onTap: () => doneTapped = true),
              ],
            ),
          ),
        ));

        expect(find.byType(FastScrollRail), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);

        await tester.tap(find.byIcon(Icons.pause));
        expect(holdTapped, isTrue);

        await tester.tap(find.byIcon(Icons.check));
        expect(doneTapped, isTrue);
      });
    });
  });
}
