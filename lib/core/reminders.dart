import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'providers.dart';

/// Günlük "kelime tekrarın var" hatırlatması (cihaz içi, internet gerekmez).
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _init = false;
  static const _id = 1;

  static Future<void> _ensureInit() async {
    if (_init) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _init = true;
  }

  /// Bildirim iznini ister; verilmezse false döner.
  static Future<bool> enable(TimeOfDay at) async {
    if (kIsWeb) return false;
    await _ensureInit();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    if (granted == false) return false;
    await schedule(at);
    return true;
  }

  static Future<void> schedule(TimeOfDay at) async {
    if (kIsWeb) return;
    await _ensureInit();
    final now = DateTime.now();
    var first = DateTime(now.year, now.month, now.day, at.hour, at.minute);
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));

    // tz.local varsayılan olarak UTC'dir. Anı koruyup her gün aynı saatte
    // tekrarlatıyoruz (yaz saati uygulayan ülkelerde 1 saat kayabilir).
    await _plugin.zonedSchedule(
      id: _id,
      title: 'YDS Uzmanı',
      body: 'Bugünkü kelime tekrarların seni bekliyor. 5 dakika yeter!',
      scheduledDate: tz.TZDateTime.from(first, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_review',
          'Günlük hatırlatma',
          channelDescription: 'Kelime tekrarı hatırlatması',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> disable() async {
    if (kIsWeb) return;
    await _ensureInit();
    await _plugin.cancel(id: _id);
  }
}

/// Seçili hatırlatma saati (kapalıysa null). Prefs'te "HH:mm" olarak saklanır.
class ReminderNotifier extends Notifier<TimeOfDay?> {
  static const _key = 'reminder_time';

  @override
  TimeOfDay? build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return null;
    final p = raw.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  /// Uygulama açılışında planı yenile (telefon yeniden başlamış olabilir).
  Future<void> restore() async {
    final t = state;
    if (t != null) {
      try {
        await Reminders.schedule(t);
      } catch (_) {}
    }
  }

  Future<bool> set(TimeOfDay? t) async {
    final prefs = ref.read(prefsProvider);
    if (t == null) {
      state = null;
      await prefs.remove(_key);
      await Reminders.disable();
      return true;
    }
    final ok = await Reminders.enable(t);
    if (!ok) return false;
    state = t;
    await prefs.setString(_key, '${t.hour}:${t.minute}');
    return true;
  }
}

final reminderProvider = NotifierProvider<ReminderNotifier, TimeOfDay?>(ReminderNotifier.new);
