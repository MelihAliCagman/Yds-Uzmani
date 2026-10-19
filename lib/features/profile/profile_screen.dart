import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/ai/gemini_client.dart';
import '../../core/providers.dart';
import '../../core/reminders.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final totalAnswered = p.topics.values.fold<int>(0, (a, s) => a + s.total);
    final totalCorrect = p.topics.values.fold<int>(0, (a, s) => a + s.correct);
    final rate = totalAnswered == 0 ? 0 : (totalCorrect / totalAnswered * 100).round();
    final hasKey = geminiKey.isNotEmpty;
    final exam = ref.watch(examDateProvider);
    final left = daysUntilExam(exam);
    final reminder = ref.watch(reminderProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const ScreenTitle('Profil', subtitle: 'İstatistiklerin ve ayarların.'),
        const SizedBox(height: 20),
        Row(
          children: [
            StatTile(value: '$totalAnswered', label: 'Çözülen'),
            const SizedBox(width: 12),
            StatTile(value: '%$rate', label: 'Başarı'),
            const SizedBox(width: 12),
            StatTile(value: '${p.xp}', label: 'XP'),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          color: AppColors.accent,
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: exam ?? now.add(const Duration(days: 60)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 730)),
              helpText: 'Sınav tarihi',
            );
            if (d != null) ref.read(examDateProvider.notifier).set(d);
          },
          child: Row(
            children: [
              const Icon(Icons.event_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(exam == null
                    ? 'Sınav tarihini seç: tekrar aralıkları sınava göre ayarlanır.'
                    : 'Sınav: ${exam.day}.${exam.month}.${exam.year} · ${left! < 0 ? 'geçti' : '$left gün kaldı'}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          color: AppColors.warning,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: reminder == null
                      ? null
                      : () async {
                          final t = await showTimePicker(context: context, initialTime: reminder);
                          if (t != null) ref.read(reminderProvider.notifier).set(t);
                        },
                  child: Text(reminder == null
                      ? 'Günlük hatırlatma kapalı'
                      : 'Her gün ${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')} · saati değiştirmek için dokun'),
                ),
              ),
              Switch(
                value: reminder != null,
                onChanged: (on) async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (!on) {
                    await ref.read(reminderProvider.notifier).set(null);
                    return;
                  }
                  final ok = await ref
                      .read(reminderProvider.notifier)
                      .set(const TimeOfDay(hour: 20, minute: 0));
                  if (!ok) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Bildirim izni verilmedi. Telefon ayarlarından açabilirsin.')));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          color: hasKey ? AppColors.success : AppColors.warning,
          child: Row(
            children: [
              Icon(hasKey ? Icons.check_circle_rounded : Icons.key_off_rounded,
                  color: hasKey ? AppColors.success : AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(hasKey
                    ? 'Gemini API anahtarı tanımlı.'
                    : 'Gemini anahtarı yok. env.json içine ekleyip --dart-define-from-file=env.json ile çalıştır.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          color: AppColors.danger,
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('İlerleme sıfırlansın mı?'),
                content: const Text('XP, seri ve konu istatistikleri silinir.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sıfırla')),
                ],
              ),
            );
            if (ok == true) {
              final prefs = ref.read(prefsProvider);
              await prefs.remove('progress');
              ref.invalidate(progressProvider);
            }
          },
          child: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              SizedBox(width: 12),
              Text('İlerlemeyi sıfırla'),
            ],
          ),
        ),
      ],
    );
  }
}
