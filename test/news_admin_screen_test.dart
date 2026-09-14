import 'dart:async';

import 'package:cricket_admin/screens/dashboard/news_admin_screen.dart';
import 'package:cricket_admin/services/news_admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NewsItem _item(String id, String title,
        {bool hidden = false, bool pinned = false, List<String> teams = const [], int hoursAgo = 1}) =>
    NewsItem(
      id: id,
      title: title,
      description: 'summary',
      context: 'More Trouble',
      type: 'News',
      url: 'https://www.cricbuzz.com/cricket-news/1/x',
      teams: teams,
      publishedAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
      hidden: hidden,
      pinned: pinned,
    );

Future<void> _pump(WidgetTester tester, List<NewsItem> items, {bool enabled = true}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 2000,
        child: NewsAdminScreen(
          source: Stream.value(items),
          enabledSource: Stream.value(enabled),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('empty state explains how to start', (tester) async {
    await _pump(tester, const [], enabled: false);
    expect(find.textContaining('Turn on auto-fetch'), findsOneWidget);
    expect(find.textContaining('Off — nothing new'), findsOneWidget);
  });

  testWidgets('pinned story is listed first, hidden ones flagged', (tester) async {
    await _pump(tester, [
      _item('cbz_2', 'Newest story', hoursAgo: 1),
      _item('cbz_1', 'Pinned older story', pinned: true, hoursAgo: 20, teams: ['India']),
      _item('cbz_3', 'Hidden story', hidden: true, hoursAgo: 2),
    ]);
    final pinnedY = tester.getTopLeft(find.text('Pinned older story')).dy;
    final newestY = tester.getTopLeft(find.text('Newest story')).dy;
    expect(pinnedY, lessThan(newestY));
    expect(find.text('HIDDEN'), findsOneWidget);
    expect(find.text('India'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden filter shows only hidden stories', (tester) async {
    await _pump(tester, [
      _item('cbz_2', 'Visible story'),
      _item('cbz_3', 'Hidden story', hidden: true),
    ]);
    await tester.tap(find.text('Hidden').first);
    await tester.pump();
    expect(find.text('Hidden story'), findsOneWidget);
    expect(find.text('Visible story'), findsNothing);
  });

  testWidgets('notify asks for confirmation before sending', (tester) async {
    await _pump(tester, [_item('cbz_5', 'Big story')]);
    await tester.tap(find.text('Notify'));
    await tester.pumpAndSettle();
    expect(find.text('Send to all users?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Send to all users?'), findsNothing);
  });

  testWidgets('hidden stories cannot be notified', (tester) async {
    await _pump(tester, [_item('cbz_6', 'Hidden one', hidden: true)]);
    expect(find.text('Notify'), findsNothing);
  });

  testWidgets('story without teams says a category card will be used', (tester) async {
    await _pump(tester, [_item('cbz_9', 'Jamieson breaks the game open')]);
    expect(find.textContaining('category card'), findsOneWidget);
  });
}
