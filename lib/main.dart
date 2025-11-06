// main.dart - The Morning Routine Flutter app
// This file contains the entire implementation for the production-ready demo app
// that guides users through energising morning rituals.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_tone.dart';

// Entry point: load persistent storage before starting the app so the feed is ready.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await FeedStorage.create();
  final feedController = FeedController(storage);
  await feedController.load();
  runApp(MorningRoutineApp(feedController: feedController));
}

// Root widget that defines the global theme and injects the shared FeedController.
class MorningRoutineApp extends StatelessWidget {
  const MorningRoutineApp({super.key, required this.feedController});

  final FeedController feedController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Morning Routine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F2FF),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Roboto', fontSize: 16),
          bodyMedium: TextStyle(fontFamily: 'Roboto', fontSize: 14),
        ),
      ),
      home: HomePage(feedController: feedController),
    );
  }
}

// The landing page holding the bottom navigation tabs for the four app sections.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.feedController});

  final FeedController feedController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final GlobalKey<MorningRoutineTabState> _routineKey = GlobalKey();

  // Triggered when the alarm is dismissed. Navigates to the routine and starts it.
  void _handleAlarmDismissed() {
    setState(() => _currentIndex = 1);
    _routineKey.currentState?.startRoutine(fromAlarm: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB388FF), Color(0xFFEDE7F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              AlarmTab(onAlarmDismissed: _handleAlarmDismissed),
              MorningRoutineTab(key: _routineKey, feedController: widget.feedController),
              FeedTab(feedController: widget.feedController),
              const ProfileTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey.shade500,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarms'),
            BottomNavigationBarItem(icon: Icon(Icons.sunny), label: 'Routine'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// Alarm tab: handles iPhone-style time picker and scheduling a simulated alarm tone.
class AlarmTab extends StatefulWidget {
  const AlarmTab({super.key, required this.onAlarmDismissed});

  final VoidCallback onAlarmDismissed;

  @override
  State<AlarmTab> createState() => _AlarmTabState();
}

class _AlarmTabState extends State<AlarmTab> {
  TimeOfDay? _selectedTime;
  Timer? _alarmTimer;
  final AudioPlayer _player = AudioPlayer();
  bool _alarmScheduled = false;
  DateTime? _nextAlarmTime;
  final Set<int> _selectedDays = {DateTime.now().weekday};
  AlarmToneOption _selectedTone = alarmToneOptions.first;
  bool _vibrationEnabled = true;
  final Set<AlarmChallengeType> _selectedChallenges = {AlarmChallengeType.tap};

  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  // Opens a Cupertino-style picker for the user to select a time-of-day.
  void _pickTime() {
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, _selectedTime?.hour ?? now.hour,
        _selectedTime?.minute ?? now.minute);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        DateTime tempTime = initial;
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.deepPurple.withOpacity(0.1), blurRadius: 12),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initial,
                  use24hFormat: false,
                  onDateTimeChanged: (value) => tempTime = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedTime = TimeOfDay.fromDateTime(tempTime);
                    });
                  },
                  child: const Text('Set Time'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Creates a timer to simulate the alarm going off at the selected time.
  void _scheduleAlarm() {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time before setting the alarm.')),
      );
      return;
    }

    _alarmTimer?.cancel();
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day for the alarm.')),
      );
      return;
    }

    if (_selectedChallenges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one wake-up challenge.')),
      );
      return;
    }

    final now = DateTime.now();
    final scheduled = _findNextAlarmDate(now);
    final delay = scheduled.difference(now);
    _alarmTimer = Timer(delay, _handleAlarmFire);
    setState(() {
      _nextAlarmTime = scheduled;
      _alarmScheduled = true;
    });

    final label = _weekdayLabels[scheduled.weekday - 1];
    final timeLabel = TimeOfDay.fromDateTime(scheduled).format(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alarm set for $label at $timeLabel.')),
    );
  }

  // Plays the alarm audio and shows a dismiss dialog.
  Future<void> _handleAlarmFire() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(BytesSource(_selectedTone.bytes));

    if (_vibrationEnabled) {
      unawaited(HapticFeedback.heavyImpact());
    }

    if (!mounted) return;
    final completed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlarmChallengeDialog(
            challenges: _selectedChallenges.toList(),
          ),
        ) ??
        false;
    if (!mounted) return;
    if (completed) {
      await _dismissAlarm();
    }
  }

  // Stops the audio and notifies the parent to open the routine tab.
  Future<void> _dismissAlarm() async {
    await _player.stop();
    _alarmTimer?.cancel();
    setState(() {
      _alarmScheduled = false;
      _nextAlarmTime = null;
    });
    widget.onAlarmDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Rise & Shine',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Set an alarm to kickstart your personalised routine. When it rings, dismissing it instantly launches your curated sequence of morning wins.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _buildTimeCard(context),
          const SizedBox(height: 24),
          _buildDaySelector(),
          const SizedBox(height: 24),
          _buildChallengeSelector(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Pick Time'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scheduleAlarm,
                  icon: const Icon(Icons.alarm_on),
                  label: const Text('Activate'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
          if (_alarmScheduled && _nextAlarmTime != null) ...[
            const SizedBox(height: 32),
            _buildCountdownCard(context),
          ],
        ],
      ),
    );
  }

  // Displays the currently selected time with a subtle glassmorphism card.
  Widget _buildTimeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Next Alarm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _selectedTime?.format(context) ?? '--:--',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Tap “Pick Time” to adjust'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildToneDropdown(context),
              _buildVibrationToggle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Repeat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_weekdayLabels.length, (index) {
              final dayIndex = index + 1;
              final isSelected = _selectedDays.contains(dayIndex);
              return FilterChip(
                label: Text(_weekdayLabels[index]),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedDays.add(dayIndex);
                    } else {
                      _selectedDays.remove(dayIndex);
                    }
                  });
                },
                showCheckmark: false,
                selectedColor: Colors.deepPurple.shade100,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.deepPurple : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wake-up Challenges',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the tests you must finish before the alarm can be dismissed.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AlarmChallengeType.values.map((challenge) {
              final isSelected = _selectedChallenges.contains(challenge);
              return FilterChip(
                label: Text(challenge.label),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedChallenges.add(challenge);
                    } else {
                      _selectedChallenges.remove(challenge);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToneDropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: DropdownButton<AlarmToneOption>(
          value: _selectedTone,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: (tone) {
            if (tone == null) return;
            setState(() => _selectedTone = tone);
          },
          items: [
            for (final tone in alarmToneOptions)
              DropdownMenuItem(
                value: tone,
                child: Text(tone.label),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVibrationToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.vibration, color: Colors.deepPurple),
          const SizedBox(width: 8),
          const Text('Vibration'),
          Switch(
            value: _vibrationEnabled,
            onChanged: (value) => setState(() => _vibrationEnabled = value),
            activeColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  DateTime _findNextAlarmDate(DateTime from) {
    final time = _selectedTime!;
    for (var offset = 0; offset < 14; offset++) {
      final candidate = DateTime(
        from.year,
        from.month,
        from.day,
        time.hour,
        time.minute,
      ).add(Duration(days: offset));
      final isValidDay = _selectedDays.contains(candidate.weekday);
      if (!isValidDay) {
        continue;
      }
      if (!candidate.isBefore(from)) {
        return candidate;
      }
    }
    // Fallback: schedule one week later on the first selected day.
    final sortedDays = _selectedDays.toList()..sort();
    final firstDay = sortedDays.first;
    final daysUntil = (firstDay - from.weekday + 7) % 7;
    final scheduled = DateTime(
      from.year,
      from.month,
      from.day,
      time.hour,
      time.minute,
    ).add(Duration(days: daysUntil == 0 ? 7 : daysUntil));
    return scheduled;
  }

  // Stylish card summarising when the alarm will chime.
  Widget _buildCountdownCard(BuildContext context) {
    final next = _nextAlarmTime!;
    final time = TimeOfDay.fromDateTime(next).format(context);
    final formattedDate =
        '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    final weekdayLabel = _weekdayLabels[next.weekday - 1];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alarm Scheduled',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$weekdayLabel • $formattedDate • $time',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep your device awake or nearby – we will gently remind you when it is go-time.',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

enum AlarmChallengeType { tap, math, copy }

extension AlarmChallengeTypeX on AlarmChallengeType {
  String get label {
    switch (this) {
      case AlarmChallengeType.tap:
        return 'Rapid Taps';
      case AlarmChallengeType.math:
        return 'Quick Maths';
      case AlarmChallengeType.copy:
        return 'Copy the Phrase';
    }
  }

  String get description {
    switch (this) {
      case AlarmChallengeType.tap:
        return 'Tap the button 10 times to prove you are awake.';
      case AlarmChallengeType.math:
        return 'Solve three random addition problems in a row.';
      case AlarmChallengeType.copy:
        return 'Type the displayed sentence perfectly to finish.';
    }
  }

  IconData get icon {
    switch (this) {
      case AlarmChallengeType.tap:
        return Icons.touch_app;
      case AlarmChallengeType.math:
        return Icons.calculate;
      case AlarmChallengeType.copy:
        return Icons.text_fields;
    }
  }
}

class AlarmChallengeDialog extends StatefulWidget {
  const AlarmChallengeDialog({super.key, required this.challenges});

  final List<AlarmChallengeType> challenges;

  @override
  State<AlarmChallengeDialog> createState() => _AlarmChallengeDialogState();
}

class _AlarmChallengeDialogState extends State<AlarmChallengeDialog> {
  late final Map<AlarmChallengeType, bool> _completed = {
    for (final challenge in widget.challenges) challenge: false,
  };

  bool get _allComplete => _completed.values.every((done) => done);

  void _markComplete(AlarmChallengeType type) {
    if (_completed[type] == true) {
      return;
    }
    setState(() {
      _completed[type] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Complete Your Wake-up Tests'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.challenges.map((type) {
                final isComplete = _completed[type] ?? false;
                return _buildChallengeCard(type, isComplete);
              }).toList(),
            ),
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _allComplete ? () => Navigator.of(context).pop(true) : null,
            icon: const Icon(Icons.check),
            label: const Text('Dismiss Alarm'),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(AlarmChallengeType type, bool isComplete) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type.icon, color: isComplete ? Colors.green : Colors.deepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type.label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isComplete
                      ? const Icon(Icons.check_circle, color: Colors.green, key: ValueKey('done'))
                      : const SizedBox.shrink(key: ValueKey('pending')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(type.description),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isComplete
                  ? Text(
                      'Completed! Nice work.',
                      key: ValueKey('${type.name}-completed'),
                    )
                  : _buildChallengeBody(type),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeBody(AlarmChallengeType type) {
    switch (type) {
      case AlarmChallengeType.tap:
        return TapToWakeChallenge(
          key: ValueKey(type),
          onCompleted: () => _markComplete(type),
        );
      case AlarmChallengeType.math:
        return MathWakeChallenge(
          key: ValueKey(type),
          onCompleted: () => _markComplete(type),
        );
      case AlarmChallengeType.copy:
        return CopySentenceWakeChallenge(
          key: ValueKey(type),
          onCompleted: () => _markComplete(type),
        );
    }
  }
}

class TapToWakeChallenge extends StatefulWidget {
  const TapToWakeChallenge({super.key, required this.onCompleted, this.tapGoal = 10});

  final VoidCallback onCompleted;
  final int tapGoal;

  @override
  State<TapToWakeChallenge> createState() => _TapToWakeChallengeState();
}

class _TapToWakeChallengeState extends State<TapToWakeChallenge> {
  int _tapCount = 0;
  bool _reported = false;

  void _increment() {
    if (_reported) {
      return;
    }
    setState(() {
      _tapCount += 1;
    });
    if (_tapCount >= widget.tapGoal && !_reported) {
      _reported = true;
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_tapCount / widget.tapGoal).clamp(0.0, 1.0).toDouble();
    final remaining = (widget.tapGoal - _tapCount).clamp(0, widget.tapGoal).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 8),
        Text('Taps remaining: $remaining'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _increment,
          icon: const Icon(Icons.touch_app),
          label: const Text('Tap me!'),
        ),
      ],
    );
  }
}

class MathWakeChallenge extends StatefulWidget {
  const MathWakeChallenge({super.key, required this.onCompleted, this.requiredCorrect = 3});

  final VoidCallback onCompleted;
  final int requiredCorrect;

  @override
  State<MathWakeChallenge> createState() => _MathWakeChallengeState();
}

class _MathWakeChallengeState extends State<MathWakeChallenge> {
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();
  int _a = 0;
  int _b = 0;
  int _correctAnswers = 0;
  String? _feedback;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateQuestion() {
    setState(() {
      _a = _random.nextInt(10) + 1;
      _b = _random.nextInt(10) + 1;
    });
    _controller.clear();
  }

  void _submit() {
    if (_reported) {
      return;
    }
    final answerText = _controller.text.trim();
    final expected = _a + _b;
    final parsed = int.tryParse(answerText);
    if (parsed == expected) {
      setState(() {
        _correctAnswers += 1;
        final remaining = widget.requiredCorrect - _correctAnswers;
        _feedback =
            remaining > 0 ? 'Correct! $remaining to go.' : 'All questions solved!';
      });
      if (_correctAnswers >= widget.requiredCorrect) {
        _reported = true;
        widget.onCompleted();
      } else {
        _generateQuestion();
      }
    } else {
      setState(() {
        _feedback = 'Not quite. Try again!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_a + $_b = ?'),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter answer',
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: _submit,
              child: const Text('Check'),
            ),
            const SizedBox(width: 12),
            Text('Solved: $_correctAnswers / ${widget.requiredCorrect}'),
          ],
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 4),
          Text(_feedback!),
        ],
      ],
    );
  }
}

class CopySentenceWakeChallenge extends StatefulWidget {
  const CopySentenceWakeChallenge({
    super.key,
    required this.onCompleted,
    this.sentence = 'I earn my morning by waking with purpose.',
  });

  final VoidCallback onCompleted;
  final String sentence;

  @override
  State<CopySentenceWakeChallenge> createState() => _CopySentenceWakeChallengeState();
}

class _CopySentenceWakeChallengeState extends State<CopySentenceWakeChallenge> {
  final TextEditingController _controller = TextEditingController();
  bool _reported = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    if (_reported) {
      return;
    }
    if (value.trim() == widget.sentence) {
      _reported = true;
      widget.onCompleted();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _reported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sentence: "${widget.sentence}"'),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          readOnly: completed,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type the sentence exactly',
          ),
          onChanged: _handleChanged,
        ),
        const SizedBox(height: 8),
        const Text('Match punctuation and case to pass this test.'),
      ],
    );
  }
}

// Morning routine tab: orchestrates interactive steps with animations and progress.
class MorningRoutineTab extends StatefulWidget {
  const MorningRoutineTab({super.key, required this.feedController});

  final FeedController feedController;

  @override
  MorningRoutineTabState createState() => MorningRoutineTabState();
}

class MorningRoutineTabState extends State<MorningRoutineTab> {
  final List<RoutineStep> _steps = RoutineStep.defaultSteps();
  bool _isRunning = false;
  bool _isCompleted = false;
  int _currentIndex = 0;
  Uint8List? _pendingPhotoBytes;
  RoutineEntry? _pendingEntry;
  final List<RoutineStepResult> _results = [];

  // Public method invoked when the alarm dismisses to reset and begin automatically.
  void startRoutine({bool fromAlarm = false}) {
    setState(() {
      _isRunning = true;
      _isCompleted = false;
      _currentIndex = 0;
      _pendingEntry = null;
      _results.clear();
      _pendingPhotoBytes = null;
    });
    if (fromAlarm && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome back! Let’s own this morning.')),
      );
    }
  }

  // Handles completion logic and moves to the next step with animation.
  void _completeStep(RoutineStep step, {String? note, Uint8List? photoBytes}) {
    final result = RoutineStepResult(
      id: step.id,
      type: step.type,
      note: note ?? step.description,
      imageBase64: photoBytes != null ? base64Encode(photoBytes) : null,
    );
    _results.add(result);

    if (_currentIndex + 1 >= _steps.length) {
      final entry = RoutineEntry(timestamp: DateTime.now(), results: List.of(_results));
      setState(() {
        _pendingEntry = entry;
        _isRunning = false;
        _isCompleted = true;
        _pendingPhotoBytes = null;
      });
    } else {
      setState(() {
        _currentIndex += 1;
        _pendingPhotoBytes = null;
      });
    }
  }

  // Allows the user to capture a real photo using the device camera/gallery.
  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    try {
      final source = kIsWeb ? ImageSource.camera : ImageSource.camera;
      final XFile? image = await picker.pickImage(source: source, maxWidth: 1080, imageQuality: 80);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      setState(() => _pendingPhotoBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open camera: $e')),
        );
      }
    }
  }

  // Provides a playful simulated photo when a camera is not available.
  void _simulatePhoto() {
    const base64Pixel =
        'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJ'
        'bWFnZVJlYWR5ccllPAAAABh0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAETSURB'
        'VHja7ZpBCsIwEIYf+/+fK7uEUEbG4CazSSzsprB0hZPpyQsuPhxwsJgEPhgBAAAAAAAAAAAAgA9s'
        'xZ0RulNe5kBGHOThxm+69BNnO1sMkRUYw35vj0IadB1iKsFcEYTmya4A1NVYMcZV8C4D4w3Efr2E'
        'f3kAt2bQVWwtIgMeYgBkYzaPt+F6DRCcIh0b07XAZo2m5wAWXnwD75PwQBGj62LF8A3BnCAAAAAAAAAAA'
        'AAAAAAAADwKPAABi1bBVAAAAAElFTkSuQmCC';
    _pendingPhotoBytes = base64Decode(base64Pixel);
    setState(() {});
  }

  // Submits the completed routine to the feed and shows confirmation.
  Future<void> _postToFeed() async {
    final entry = _pendingEntry;
    if (entry == null) return;
    await widget.feedController.addEntry(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Routine shared! Your community is cheering for you.')),
    );
    setState(() {
      _pendingEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Morning Routine',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Flow through energising tasks, guided affirmations, educational snippets, and photo prompts to document your progress.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (!_isRunning && !_isCompleted)
            _buildIntroCard(theme)
          else if (_isRunning)
            _buildActiveRoutine(theme)
          else
            _buildSummary(theme),
        ],
      ),
    );
  }

  // First view encouraging the user to start the curated routine.
  Widget _buildIntroCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Curated just for you',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Press start and we will guide you step-by-step. Save photos and celebrate your streak when you are done.',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => startRoutine(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Start Morning Routine'),
          ),
        ],
      ),
    );
  }

  // Active routine view with animated transitions and progress tracking.
  Widget _buildActiveRoutine(ThemeData theme) {
    final step = _steps[_currentIndex];
    final progress = (_currentIndex) / _steps.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(24),
            color: Colors.deepPurple,
            backgroundColor: Colors.deepPurple.shade100,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Chip(
                backgroundColor: Colors.deepPurple.shade50,
                label: Text('${_currentIndex + 1}/${_steps.length}'),
              ),
              const SizedBox(width: 12),
              Text(step.type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.1, 0.0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: _buildStepContent(step, theme),
          ),
        ],
      ),
    );
  }

  // Summary card shown when all steps are complete.
  Widget _buildSummary(ThemeData theme) {
    final entry = _pendingEntry;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Routine Complete!',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('You crushed it. Ready to inspire others with your glow?'),
          const SizedBox(height: 16),
          if (entry != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.results
                  .map((result) => Chip(
                        avatar: result.imageBase64 != null
                            ? const Icon(Icons.camera_alt, size: 16)
                            : const Icon(Icons.check_circle, size: 16),
                        label: Text(result.note.length > 22
                            ? '${result.note.substring(0, 22)}…'
                            : result.note),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: entry != null ? _postToFeed : null,
            icon: const Icon(Icons.upgrade),
            label: const Text('Post to Feed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => startRoutine(),
            icon: const Icon(Icons.refresh),
            label: const Text('Start Again'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the individual step UI depending on the type of action required.
  Widget _buildStepContent(RoutineStep step, ThemeData theme) {
    switch (step.type) {
      case RoutineStepType.task:
        return _buildTaskStep(step, theme);
      case RoutineStepType.info:
        return _buildInfoStep(step, theme);
      case RoutineStepType.photo:
        return _buildPhotoStep(step, theme);
    }
  }

  Widget _buildTaskStep(RoutineStep step, ThemeData theme) {
    return Column(
      key: ValueKey(step.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(step.description),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _completeStep(step),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildInfoStep(RoutineStep step, ThemeData theme) {
    return Column(
      key: ValueKey(step.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade100, Colors.deepPurple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Text(step.description),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _completeStep(step),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Next Insight'),
        ),
      ],
    );
  }

  Widget _buildPhotoStep(RoutineStep step, ThemeData theme) {
    final bytes = _pendingPhotoBytes;
    return Column(
      key: ValueKey(step.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(step.description),
        const SizedBox(height: 20),
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(bytes, height: 220, width: double.infinity, fit: BoxFit.cover),
          )
        else
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            alignment: Alignment.center,
            child: const Text('No photo yet – capture or simulate one!'),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.deepPurple,
                  side: BorderSide(color: Colors.deepPurple.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _simulatePhoto,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Simulate'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.deepPurple,
                  side: BorderSide(color: Colors.deepPurple.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: bytes != null
              ? () => _completeStep(step, photoBytes: bytes, note: step.description)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

// Feed tab: displays previous routines stored locally in a modern card layout.
class FeedTab extends StatelessWidget {
  const FeedTab({super.key, required this.feedController});

  final FeedController feedController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: feedController,
      builder: (context, _) {
        final entries = feedController.entries;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          itemCount: entries.isEmpty ? 1 : entries.length,
          itemBuilder: (context, index) {
            if (entries.isEmpty) {
              return _buildEmptyState(context);
            }
            final entry = entries[index];
            return _buildEntryCard(context, entry);
          },
        );
      },
    );
  }

  // Friendly encouragement for first-time users when the feed is empty.
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: const [
          Icon(Icons.self_improvement, size: 64, color: Colors.deepPurple),
          SizedBox(height: 16),
          Text(
            'Your feed is spotless!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Complete a routine and share a photo to see it appear right here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Visual card summarising a routine entry with timestamp and images.
  Widget _buildEntryCard(BuildContext context, RoutineEntry entry) {
    final timestamp = TimeOfDay.fromDateTime(entry.timestamp).format(context);
    final dateLabel = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
    final photos = entry.results.where((r) => r.imageBase64 != null).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.white.withOpacity(0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Routine on $dateLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Completed at $timestamp',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.results
                        .map(
                          (result) => Chip(
                            backgroundColor: Colors.white.withOpacity(0.9),
                            avatar: Icon(
                              result.type.icon,
                              size: 18,
                              color: Colors.deepPurple,
                            ),
                            label: Text(
                              result.note.length > 28
                                  ? '${result.note.substring(0, 28)}…'
                                  : result.note,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final bytes = base64Decode(photos[index].imageBase64!);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(bytes, width: 140, height: 160, fit: BoxFit.cover),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: photos.length,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple placeholder tab for the upcoming profile features.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.person_outline, size: 64, color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              'Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Coming soon: streaks, achievements, and deeper personalisation!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Data model representing a single routine step template.
class RoutineStep {
  const RoutineStep({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
  });

  final String id;
  final String title;
  final String description;
  final RoutineStepType type;

  static List<RoutineStep> defaultSteps() {
    return const [
      RoutineStep(
        id: 'wake_breathe',
        title: 'Wake & Breathe',
        description: 'Sit up tall, inhale for four counts, exhale for six. Repeat five times to oxygenate your morning.',
        type: RoutineStepType.task,
      ),
      RoutineStep(
        id: 'stretch',
        title: 'Full Body Stretch',
        description: 'Reach your arms overhead, interlace your fingers, and stretch side-to-side for one minute.',
        type: RoutineStepType.task,
      ),
      RoutineStep(
        id: 'affirmations',
        title: 'Mirror Affirmations',
        description: 'Look into the mirror and say “I am energised, I am grateful, I am unstoppable” five times.',
        type: RoutineStepType.task,
      ),
      RoutineStep(
        id: 'hydration',
        title: 'Hydration Boost',
        description: 'Sip a glass of water with a squeeze of lemon. Hydration first boosts metabolism and digestion.',
        type: RoutineStepType.info,
      ),
      RoutineStep(
        id: 'sunshine_photo',
        title: 'Sunshine Snapshot',
        description: 'Capture your morning glow near a window or simulate a photo to celebrate your progress.',
        type: RoutineStepType.photo,
      ),
      RoutineStep(
        id: 'mindfulness',
        title: 'Mindful Minute',
        description: 'Close your eyes and follow your breath. Imagine the most confident version of yourself today.',
        type: RoutineStepType.task,
      ),
      RoutineStep(
        id: 'breakfast_tip',
        title: 'Breakfast Inspiration',
        description: 'Choose a protein-rich breakfast: think Greek yogurt with berries or scrambled eggs with greens.',
        type: RoutineStepType.info,
      ),
    ];
  }
}

// Supported routine step types with helper getters for display purposes.
enum RoutineStepType { task, info, photo }

extension RoutineStepTypeDisplay on RoutineStepType {
  String get label {
    switch (this) {
      case RoutineStepType.task:
        return 'Guided Task';
      case RoutineStepType.info:
        return 'Wellness Insight';
      case RoutineStepType.photo:
        return 'Photo Moment';
    }
  }

  IconData get icon {
    switch (this) {
      case RoutineStepType.task:
        return Icons.checklist_rtl;
      case RoutineStepType.info:
        return Icons.menu_book;
      case RoutineStepType.photo:
        return Icons.photo_camera;
    }
  }
}

// Captured data for each completed routine step. Stored as JSON via SharedPreferences.
class RoutineStepResult {
  RoutineStepResult({
    required this.id,
    required this.type,
    required this.note,
    this.imageBase64,
  });

  final String id;
  final RoutineStepType type;
  final String note;
  final String? imageBase64;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'note': note,
        'imageBase64': imageBase64,
      };

  factory RoutineStepResult.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? RoutineStepType.task.name;
    return RoutineStepResult(
      id: json['id'] as String? ?? '',
      type: RoutineStepType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => RoutineStepType.task,
      ),
      note: json['note'] as String? ?? '',
      imageBase64: json['imageBase64'] as String?,
    );
  }
}

// Feed entry storing the timestamp and full list of step results.
class RoutineEntry {
  RoutineEntry({required this.timestamp, required this.results});

  final DateTime timestamp;
  final List<RoutineStepResult> results;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'results': results.map((result) => result.toJson()).toList(),
      };

  factory RoutineEntry.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final resultsJson = (json['results'] as List<dynamic>? ?? [])
        .map((item) => RoutineStepResult.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return RoutineEntry(timestamp: timestamp, results: resultsJson);
  }
}

// Persistent storage helper wrapping SharedPreferences for feed entries.
class FeedStorage {
  FeedStorage._(this._preferences);

  static const _key = 'routine_feed_entries';
  final SharedPreferences _preferences;

  static Future<FeedStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FeedStorage._(prefs);
  }

  Future<List<RoutineEntry>> loadEntries() async {
    final jsonString = _preferences.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => RoutineEntry.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEntries(List<RoutineEntry> entries) async {
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await _preferences.setString(_key, encoded);
  }
}

// Controller bridging UI and storage; notifies listeners when feed data changes.
class FeedController extends ChangeNotifier {
  FeedController(this._storage);

  final FeedStorage _storage;
  List<RoutineEntry> _entries = [];

  List<RoutineEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    _entries = await _storage.loadEntries();
    notifyListeners();
  }

  Future<void> addEntry(RoutineEntry entry) async {
    _entries = [entry, ..._entries];
    await _storage.saveEntries(_entries);
    notifyListeners();
  }
}
