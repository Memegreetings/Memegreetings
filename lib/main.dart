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
  final profileStorage = await ProfileStorage.create();
  final profileController = ProfileController(profileStorage);
  await profileController.load();
  runApp(
    MorningRoutineApp(
      feedController: feedController,
      profileController: profileController,
    ),
  );
}

// Root widget that defines the global theme and injects the shared FeedController.
class MorningRoutineApp extends StatelessWidget {
  const MorningRoutineApp({
    super.key,
    required this.feedController,
    required this.profileController,
  });

  final FeedController feedController;
  final ProfileController profileController;

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
      home: HomePage(
        feedController: feedController,
        profileController: profileController,
      ),
    );
  }
}

// The landing page holding the bottom navigation tabs for the four app sections.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.feedController,
    required this.profileController,
  });

  final FeedController feedController;
  final ProfileController profileController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final GlobalKey<MorningRoutineTabState> _routineKey = GlobalKey();
  final GlobalKey<_AlarmTabState> _alarmKey = GlobalKey();
  bool _isOnboarding = false;

  @override
  void initState() {
    super.initState();
    widget.profileController.addListener(_handleProfileChanged);
  }

  @override
  void dispose() {
    widget.profileController.removeListener(_handleProfileChanged);
    super.dispose();
  }

  void _handleProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Triggered when the alarm is dismissed. Navigates to the routine and starts it.
  void _handleAlarmDismissed(List<String> tasks) {
    setState(() => _currentIndex = 1);
    _routineKey.currentState?.startRoutine(fromAlarm: true, taskIds: tasks);
  }

  Future<void> _openProfileOnboarding() async {
    if (_isOnboarding) {
      return;
    }
    setState(() => _isOnboarding = true);
    final result = await Navigator.of(context).push<ProfileOnboardingResult>(
      MaterialPageRoute(
        builder: (context) => const ProfileOnboardingScreen(),
      ),
    );
    if (!mounted) return;
    setState(() => _isOnboarding = false);
    if (result != null) {
      await widget.profileController.saveProfile(result.profile);
      final prefs = await AlarmPreferences.create();
      await prefs.saveAlarm(result.alarm);
      final alarmState = _alarmKey.currentState;
      if (alarmState != null) {
        await alarmState.refreshFromPreferences();
      }
      final timeLabel = result.profile.wakeTime.format(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile ready! Alarm set for $timeLabel.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = widget.profileController.profile != null;
    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                  AlarmTab(
                    key: _alarmKey,
                    onAlarmDismissed: _handleAlarmDismissed,
                  ),
                  MorningRoutineTab(
                    key: _routineKey,
                    feedController: widget.feedController,
                  ),
                  FeedTab(feedController: widget.feedController),
                  ProfileTab(
                    profileController: widget.profileController,
                    onEditProfile: _openProfileOnboarding,
                  ),
                ],
              ),
            ),
          ),
          if (!hasProfile && !_isOnboarding)
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xAA311B92), Color(0xAA9575CD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 64, color: Colors.deepPurple),
                          const SizedBox(height: 16),
                          Text(
                            'Create your profile to begin',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'I\'ll learn your name, schedule and morning rituals, then craft alarms and routines that fit your vibe.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openProfileOnboarding,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Create Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: IgnorePointer(
        ignoring: !hasProfile,
        child: Opacity(
          opacity: hasProfile ? 1 : 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2)),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (!hasProfile) {
                  return;
                }
                setState(() => _currentIndex = index);
              },
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
        ),
      ),
    );
  }
}

// Alarm tab: handles iPhone-style time picker and scheduling a simulated alarm tone.
class AlarmTab extends StatefulWidget {
  const AlarmTab({super.key, required this.onAlarmDismissed});

  final void Function(List<String> tasks) onAlarmDismissed;

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
  AlarmPreferences? _alarmPreferences;
  List<String> _savedMorningTasks = [];

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
  void initState() {
    super.initState();
    unawaited(_loadSavedAlarm());
  }

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

  Future<AlarmPreferences> _ensurePreferences() async {
    final existing = _alarmPreferences;
    if (existing != null) {
      return existing;
    }
    final prefs = await AlarmPreferences.create();
    _alarmPreferences = prefs;
    return prefs;
  }

  Future<void> _loadSavedAlarm() async {
    final prefs = await _ensurePreferences();
    final saved = await prefs.loadAlarm();
    if (!mounted || saved == null) {
      return;
    }

    final tone = alarmToneOptions.firstWhere(
      (option) => option.id == saved.toneId,
      orElse: () => alarmToneOptions.first,
    );

    final challenges = saved.challengeIds
        .map(_challengeFromId)
        .whereType<AlarmChallengeType>()
        .toSet();

    if (mounted) {
      setState(() {
        _selectedTime = TimeOfDay(hour: saved.hour, minute: saved.minute);
        if (saved.days.isNotEmpty) {
          _selectedDays
            ..clear()
            ..addAll(saved.days);
        }
        _selectedTone = tone;
        _selectedChallenges
          ..clear()
          ..addAll(challenges.isEmpty ? {AlarmChallengeType.tap} : challenges);
        _savedMorningTasks = List.of(saved.morningTasks);
      });
    }
  }

  Future<void> refreshFromPreferences() async {
    await _loadSavedAlarm();
  }

  AlarmChallengeType? _challengeFromId(String id) {
    try {
      return AlarmChallengeType.values.firstWhere((value) => value.name == id);
    } catch (_) {
      return null;
    }
  }

  ScheduledAlarm _buildCurrentAlarmConfiguration({List<String>? morningTasks}) {
    final time = _selectedTime ?? TimeOfDay.now();
    final selectedDays = _selectedDays.isEmpty
        ? {DateTime.now().weekday}
        : _selectedDays;
    final challenges = _selectedChallenges.isEmpty
        ? {AlarmChallengeType.tap}
        : _selectedChallenges;
    return ScheduledAlarm(
      hour: time.hour,
      minute: time.minute,
      days: selectedDays.toList()..sort(),
      toneId: _selectedTone.id,
      challengeIds: challenges.map((type) => type.name).toList(),
      morningTasks: List<String>.from(morningTasks ?? _savedMorningTasks),
    );
  }

  Future<void> _saveAlarmConfiguration({List<String>? morningTasks}) async {
    final prefs = await _ensurePreferences();
    final config = _buildCurrentAlarmConfiguration(morningTasks: morningTasks);
    await prefs.saveAlarm(config);
  }

  Future<void> _promptMorningRoutineSetup() async {
    if (!mounted) return;
    final shouldSetup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Morning Routine'),
        content: const Text('Would you like to set up your Morning Routine now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Set Up Now'),
          ),
        ],
      ),
    );

    if (shouldSetup == true && mounted) {
      await _openMorningRoutineSetup();
    }
  }

  Future<void> _openMorningRoutineSetup() async {
    final selections = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => MorningRoutineSetupScreen(
          initialSelection: _savedMorningTasks,
        ),
      ),
    );

    if (selections != null && mounted) {
      setState(() {
        _savedMorningTasks = List.of(selections);
      });
      await _saveAlarmConfiguration(morningTasks: selections);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Morning routine saved for this alarm.')),
      );
    }
  }

  // Creates a timer to simulate the alarm going off at the selected time.
  Future<void> _scheduleAlarm() async {
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

    await _saveAlarmConfiguration();
    await _promptMorningRoutineSetup();
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
    final prefs = await _ensurePreferences();
    final saved = await prefs.loadAlarm();
    final tasks = saved?.morningTasks ?? _savedMorningTasks;
    widget.onAlarmDismissed(List<String>.from(tasks));
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

class MorningRoutineSetupScreen extends StatefulWidget {
  const MorningRoutineSetupScreen({super.key, required this.initialSelection});

  final List<String> initialSelection;

  @override
  State<MorningRoutineSetupScreen> createState() => _MorningRoutineSetupScreenState();
}

class _MorningRoutineSetupScreenState extends State<MorningRoutineSetupScreen> {
  late Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection.toSet();
  }

  void _toggleSelection(String id, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selection.add(id);
      } else {
        _selection.remove(id);
      }
    });
  }

  void _save() {
    Navigator.of(context).pop(List<String>.from(_selection));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Morning Routine Builder'),
        foregroundColor: Colors.deepPurple,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Choose the habits that make your mornings shine. We’ll launch them as soon as your alarm is dismissed.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          ...morningTaskOptions.map((option) {
            final isSelected = _selection.contains(option.id);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (value) => _toggleSelection(option.id, value ?? false),
                title: Text('${option.emoji} ${option.title}'),
                subtitle: Text(option.description),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
          if (_selection.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No tasks selected. The default routine will run until you add your own steps.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Save Routine'),
          ),
        ),
      ),
    );
  }
}

class MorningTaskOption {
  const MorningTaskOption({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.type,
  });

  final String id;
  final String emoji;
  final String title;
  final String description;
  final RoutineStepType type;

  RoutineStep toRoutineStep() {
    return RoutineStep(
      id: id,
      title: '$emoji $title',
      description: description,
      type: type,
    );
  }
}

const List<MorningTaskOption> morningTaskOptions = [
  MorningTaskOption(
    id: 'meditate',
    emoji: '🧘',
    title: 'Meditate for 10 minutes',
    description: 'Find a calm space, close your eyes, and follow your breath for ten mindful minutes.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'hydrate',
    emoji: '💧',
    title: 'Drink a glass of water',
    description: 'Hydrate right away to wake up your metabolism and refresh your body.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'make_bed',
    emoji: '🛏️',
    title: 'Make the bed',
    description: 'Smooth the sheets, fluff the pillows, and start your day with a quick win.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'brush_teeth',
    emoji: '🦷',
    title: 'Brush teeth',
    description: 'Give your smile a fresh start before you dive into the rest of your routine.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'stretch',
    emoji: '🤸',
    title: 'Stretch or light exercise',
    description: 'Wake up your muscles with gentle stretches or a quick flow to boost circulation.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'make_drink',
    emoji: '☕',
    title: 'Make tea or coffee',
    description: 'Brew your favourite cup and savour the aroma while you plan the day.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'breakfast',
    emoji: '🍳',
    title: 'Eat breakfast',
    description: 'Prepare a nourishing breakfast to fuel your morning momentum.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'affirmations',
    emoji: '📖',
    title: 'Read affirmations or a quote',
    description: 'Read an inspiring affirmation or quote to set a positive tone for the day.',
    type: RoutineStepType.info,
  ),
  MorningTaskOption(
    id: 'journal',
    emoji: '✍️',
    title: 'Journal gratitude',
    description: 'Write down three things you’re grateful for to build a gratitude mindset.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'mirror_love',
    emoji: '🧍',
    title: 'Say “I love you” in the mirror',
    description: 'Face the mirror and tell yourself “I love you” five times with confidence.',
    type: RoutineStepType.task,
  ),
  MorningTaskOption(
    id: 'selfie',
    emoji: '📸',
    title: 'Take morning selfie',
    description: 'Capture your fresh start or simulate a selfie to celebrate your glow-up.',
    type: RoutineStepType.photo,
  ),
  MorningTaskOption(
    id: 'playlist',
    emoji: '🎧',
    title: 'Play morning playlist',
    description: 'Hit play on a feel-good playlist and move to the music as you get ready.',
    type: RoutineStepType.info,
  ),
];

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
  List<RoutineStep> _steps = RoutineStep.defaultSteps();
  bool _isRunning = false;
  bool _isCompleted = false;
  int _currentIndex = 0;
  Uint8List? _pendingPhotoBytes;
  RoutineEntry? _pendingEntry;
  final List<RoutineStepResult> _results = [];

  // Public method invoked when the alarm dismisses to reset and begin automatically.
  void startRoutine({bool fromAlarm = false, List<String>? taskIds}) {
    final nextSteps =
        (taskIds != null && taskIds.isNotEmpty) ? RoutineStep.fromTaskIds(taskIds) : RoutineStep.defaultSteps();
    setState(() {
      _steps = nextSteps;
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
  const ProfileTab({
    super.key,
    required this.profileController,
    required this.onEditProfile,
  });

  final ProfileController profileController;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: profileController,
      builder: (context, _) {
        final profile = profileController.profile;
        if (profile == null) {
          return _buildEmptyState(context);
        }

        final theme = Theme.of(context);
        final tasks = profile.routineTaskIds
            .map(_findTaskOption)
            .whereType<MorningTaskOption>()
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 32,
                              backgroundColor: Color(0xFFEDE7F6),
                              child: Icon(Icons.wb_sunny_outlined, color: Colors.deepPurple, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Good morning, ${profile.name}!',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Routine crafted on ${_formatDate(profile.createdAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildInfoRow('Age', '${profile.age} years'),
                        if (profile.occupation.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildInfoRow('Daytime focus', profile.occupation),
                        ],
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'Wake-up time',
                          profile.wakeTime.format(context),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Morning vibe', profile.morningSummary),
                        const SizedBox(height: 24),
                        Text(
                          'Morning routine steps',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        if (tasks.isEmpty)
                          Text(
                            'We\'ll run the default glow-up routine until you add more rituals.',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final task in tasks)
                                Chip(
                                  label: Text('${task.emoji} ${task.title}'),
                                  backgroundColor: Colors.deepPurple.shade50,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit),
                    label: const Text('Update Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 64, color: Colors.deepPurple),
                const SizedBox(height: 16),
                Text(
                  'No profile yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start by creating your profile so Lumi can schedule the perfect wake up and routine for you.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Create Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MorningTaskOption? _findTaskOption(String id) {
    for (final option in morningTaskOptions) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  static Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple),
        ),
        const SizedBox(height: 6),
        Text(value),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}


class ProfileOnboardingResult {
  ProfileOnboardingResult({required this.profile, required this.alarm});

  final UserProfile profile;
  final ScheduledAlarm alarm;
}

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  State<ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  final List<_ChatMessage> _messages = [];
  late final List<_OnboardingStep> _steps = _buildSteps();
  final Map<String, String> _answers = {};
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentStepIndex = 0;
  bool _isProcessing = false;
  bool _isComplete = false;
  ProfileOnboardingResult? _result;

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        sender: MessageSender.bot,
        text: "Hey there! I’m Lumi, your AI morning co-pilot. Let’s design mornings that feel amazing.",
      ),
    );
    _messages.add(
      _ChatMessage(
        sender: MessageSender.bot,
        text: _steps.first.prompt,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendAnswer() {
    if (_isProcessing || _isComplete) {
      return;
    }
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) {
      return;
    }

    final step = _steps[_currentStepIndex];
    setState(() {
      _messages.add(_ChatMessage(sender: MessageSender.user, text: rawText));
      _controller.clear();
    });
    _scrollToBottom();

    final error = step.validate(rawText);
    if (error != null) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _addBotMessage(error);
      });
      return;
    }

    final value = step.normalise(rawText);
    _answers[step.id] = value;

    if (_currentStepIndex + 1 < _steps.length) {
      setState(() => _isProcessing = true);
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() {
          _currentStepIndex += 1;
          _messages.add(_ChatMessage(sender: MessageSender.bot, text: _steps[_currentStepIndex].prompt));
          _isProcessing = false;
        });
        _scrollToBottom();
      });
    } else {
      setState(() => _isProcessing = true);
      Future.delayed(const Duration(milliseconds: 480), () async {
        if (!mounted) return;
        await _completeOnboarding();
      });
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(sender: MessageSender.bot, text: text));
      _isProcessing = false;
    });
    _scrollToBottom();
  }

  Future<void> _completeOnboarding() async {
    FocusScope.of(context).unfocus();
    final result = _buildResult();
    if (result == null) {
      _addBotMessage("Hmm, I lost the thread there. Could you try that again?");
      return;
    }
    final timeLabel = result.profile.wakeTime.format(context);
    setState(() {
      _isProcessing = false;
      _isComplete = true;
      _result = result;
    });
    _addBotMessage("Amazing! Your wake-up call is locked for $timeLabel and your routine is tailored to your vibe.");
    _addBotMessage("Tap “Finish Setup” to save everything.");
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF4ECFF),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isBot = message.sender == MessageSender.bot;
                  return Align(
                    alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: isBot ? Colors.white : Colors.deepPurple,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isBot ? 4 : 20),
                          bottomRight: Radius.circular(isBot ? 20 : 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isBot ? Colors.deepPurple.shade700 : Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isComplete && _result != null)
            _buildCompletionActions()
          else
            _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildCompletionActions() {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).pop(result),
        icon: const Icon(Icons.rocket_launch),
        label: const Text('Finish Setup'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isProcessing,
              onSubmitted: (_) => _sendAnswer(),
              decoration: InputDecoration(
                labelText: 'Type your reply…',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isProcessing ? null : _sendAnswer,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              minimumSize: const Size(56, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  List<_OnboardingStep> _buildSteps() {
    return [
      _OnboardingStep(
        id: 'name',
        prompt: 'First up, what should I call you?',
        validator: (value) => value.trim().isEmpty
            ? "I didn't catch your name. What should I call you?"
            : null,
        normaliser: _formatName,
      ),
      _OnboardingStep(
        id: 'age',
        prompt: 'Great! And how many years of awesome experience do you have?',
        validator: (value) {
          final trimmed = value.trim();
          final age = int.tryParse(trimmed);
          if (age == null) {
            return 'Could you give me your age as a number?';
          }
          if (age < 5 || age > 120) {
            return "That doesn't sound right. What's your actual age?";
          }
          return null;
        },
        normaliser: (value) => int.parse(value.trim()).toString(),
      ),
      _OnboardingStep(
        id: 'occupation',
        prompt: 'What do you spend most of your day doing? Work, study, parenting, something else?',
        validator: (value) => value.trim().isEmpty
            ? 'Tell me a little about your day so I can plan a morning that supports it.'
            : null,
        normaliser: _sentenceCase,
      ),
      _OnboardingStep(
        id: 'wake_time',
        prompt: 'What time do you need to wake up? (Try 6:30 AM or 07:00)',
        validator: (value) => _parseTimeOfDay(value) == null
            ? 'Let me know a specific time like 6:45 AM.'
            : null,
        normaliser: (value) => value.trim(),
      ),
      _OnboardingStep(
        id: 'habits',
        prompt: 'Paint me a picture of your must-do morning moves. Coffee, journaling, workouts?',
        validator: (value) => value.trim().isEmpty
            ? 'Share at least one thing you love to do in the morning.'
            : null,
        normaliser: _sentenceCase,
      ),
    ];
  }

  ProfileOnboardingResult? _buildResult() {
    final name = _answers['name'] ?? '';
    final age = int.tryParse(_answers['age'] ?? '');
    final occupation = _answers['occupation'] ?? '';
    final wakeInput = _answers['wake_time'] ?? '';
    final habits = (_answers['habits'] ?? '').trim();
    final wakeTime = _parseTimeOfDay(wakeInput);

    if (name.isEmpty || age == null || wakeTime == null) {
      return null;
    }

    final taskIds = _inferTasks(habits);
    final profile = UserProfile(
      name: name,
      age: age,
      occupation: occupation,
      wakeHour: wakeTime.hour,
      wakeMinute: wakeTime.minute,
      morningSummary: habits.isEmpty ? 'Keeping it flexible this morning.' : habits,
      routineTaskIds: taskIds,
      createdAt: DateTime.now(),
    );

    final alarm = ScheduledAlarm(
      hour: wakeTime.hour,
      minute: wakeTime.minute,
      days: List<int>.generate(7, (index) => index + 1),
      toneId: alarmToneOptions.first.id,
      challengeIds: const [AlarmChallengeType.tap.name],
      morningTasks: taskIds,
    );

    return ProfileOnboardingResult(profile: profile, alarm: alarm);
  }

  TimeOfDay? _parseTimeOfDay(String input) {
    final text = input.trim().toLowerCase();
    final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(text);
    if (match == null) {
      return null;
    }
    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (hour == null) {
      return null;
    }
    final period = match.group(3);
    if (period != null) {
      if (hour == 12) {
        hour = period == 'am' ? 0 : 12;
      } else if (period == 'pm') {
        hour += 12;
      }
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  List<String> _inferTasks(String description) {
    final lower = description.toLowerCase();
    final Map<String, List<String>> keywordMap = {
      'meditate': ['meditat', 'breathe', 'calm', 'mindful'],
      'hydrate': ['water', 'hydrate', 'drink'],
      'make_bed': ['bed', 'tidy', 'make the bed'],
      'stretch': ['stretch', 'yoga', 'workout', 'exercise', 'run'],
      'make_drink': ['coffee', 'tea', 'brew', 'latte'],
      'breakfast': ['breakfast', 'meal', 'eat', 'smoothie'],
      'journal': ['journal', 'write', 'gratitude', 'notes'],
      'mirror_love': ['affirm', 'mirror', 'self love'],
      'selfie': ['selfie', 'photo', 'picture'],
      'playlist': ['music', 'playlist', 'song', 'tune'],
      'brush_teeth': ['brush', 'teeth', 'tooth'],
    };

    final matches = <String>{};
    keywordMap.forEach((id, keywords) {
      if (keywords.any((keyword) => lower.contains(keyword))) {
        matches.add(id);
      }
    });

    if (matches.isEmpty) {
      matches.addAll(morningTaskOptions.take(3).map((option) => option.id));
    }
    return matches.take(5).toList();
  }

  String _formatName(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '';
    }
    return parts
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String _sentenceCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lower = trimmed.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

enum MessageSender { bot, user }

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});

  final MessageSender sender;
  final String text;
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.id,
    required this.prompt,
    this.validator,
    this.normaliser,
  });

  final String id;
  final String prompt;
  final String? Function(String value)? validator;
  final String Function(String value)? normaliser;

  String? validate(String value) => validator?.call(value.trim());

  String normalise(String value) => normaliser != null ? normaliser!(value.trim()) : value.trim();
}

class UserProfile {
  UserProfile({
    required this.name,
    required this.age,
    required this.occupation,
    required this.wakeHour,
    required this.wakeMinute,
    required this.morningSummary,
    required this.routineTaskIds,
    required this.createdAt,
  });

  final String name;
  final int age;
  final String occupation;
  final int wakeHour;
  final int wakeMinute;
  final String morningSummary;
  final List<String> routineTaskIds;
  final DateTime createdAt;

  TimeOfDay get wakeTime => TimeOfDay(hour: wakeHour, minute: wakeMinute);

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'occupation': occupation,
        'wakeHour': wakeHour,
        'wakeMinute': wakeMinute,
        'morningSummary': morningSummary,
        'routineTaskIds': routineTaskIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final routine = (json['routineTaskIds'] as List<dynamic>? ?? [])
        .map((value) => value.toString())
        .toList();
    return UserProfile(
      name: (json['name'] as String? ?? '').trim(),
      age: json['age'] as int? ?? int.tryParse(json['age']?.toString() ?? '') ?? 18,
      occupation: (json['occupation'] as String? ?? '').trim(),
      wakeHour: json['wakeHour'] as int? ?? 7,
      wakeMinute: json['wakeMinute'] as int? ?? 0,
      morningSummary: (json['morningSummary'] as String? ?? '').trim(),
      routineTaskIds: routine,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ProfileStorage {
  ProfileStorage._(this._preferences);

  static const _key = 'user_profile';
  final SharedPreferences _preferences;

  static Future<ProfileStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProfileStorage._(prefs);
  }

  Future<UserProfile?> loadProfile() async {
    final jsonString = _preferences.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return UserProfile.fromJson(decoded);
      }
      if (decoded is Map) {
        return UserProfile.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final encoded = jsonEncode(profile.toJson());
    await _preferences.setString(_key, encoded);
  }
}

class ProfileController extends ChangeNotifier {
  ProfileController(this._storage);

  final ProfileStorage _storage;
  UserProfile? _profile;

  UserProfile? get profile => _profile;

  Future<void> load() async {
    _profile = await _storage.loadProfile();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    await _storage.saveProfile(profile);
    notifyListeners();
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

  static List<RoutineStep> fromTaskIds(List<String> ids) {
    if (ids.isEmpty) {
      return defaultSteps();
    }
    final optionsById = {for (final option in morningTaskOptions) option.id: option};
    final steps = <RoutineStep>[];
    for (final id in ids) {
      final option = optionsById[id];
      if (option != null) {
        steps.add(option.toRoutineStep());
      }
    }
    return steps.isEmpty ? defaultSteps() : steps;
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

class ScheduledAlarm {
  const ScheduledAlarm({
    required this.hour,
    required this.minute,
    required this.days,
    required this.toneId,
    required this.challengeIds,
    required this.morningTasks,
  });

  final int hour;
  final int minute;
  final List<int> days;
  final String toneId;
  final List<String> challengeIds;
  final List<String> morningTasks;

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'minute': minute,
        'days': days,
        'toneId': toneId,
        'challenges': challengeIds,
        'morningTasks': morningTasks,
      };

  ScheduledAlarm copyWith({
    int? hour,
    int? minute,
    List<int>? days,
    String? toneId,
    List<String>? challengeIds,
    List<String>? morningTasks,
  }) {
    return ScheduledAlarm(
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      days: days ?? List<int>.from(this.days),
      toneId: toneId ?? this.toneId,
      challengeIds: challengeIds ?? List<String>.from(this.challengeIds),
      morningTasks: morningTasks ?? List<String>.from(this.morningTasks),
    );
  }

  factory ScheduledAlarm.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['days'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value is int ? value : int.tryParse(value.toString()) ?? DateTime.now().weekday)
        .toList();
    final rawChallenges = (json['challenges'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value.toString())
        .toList();
    final rawTasks = (json['morningTasks'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => value.toString())
        .toList();
    return ScheduledAlarm(
      hour: json['hour'] as int? ?? 7,
      minute: json['minute'] as int? ?? 0,
      days: rawDays.isEmpty ? [DateTime.now().weekday] : rawDays,
      toneId: json['toneId'] as String? ?? alarmToneOptions.first.id,
      challengeIds: rawChallenges.isEmpty ? [AlarmChallengeType.tap.name] : rawChallenges,
      morningTasks: rawTasks,
    );
  }
}

class AlarmPreferences {
  AlarmPreferences._(this._preferences);

  static const _key = 'scheduled_alarm_config';
  final SharedPreferences _preferences;

  static Future<AlarmPreferences> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AlarmPreferences._(prefs);
  }

  Future<ScheduledAlarm?> loadAlarm() async {
    final jsonString = _preferences.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return ScheduledAlarm.fromJson(decoded);
      }
      if (decoded is Map) {
        return ScheduledAlarm.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAlarm(ScheduledAlarm alarm) async {
    final encoded = jsonEncode(alarm.toJson());
    await _preferences.setString(_key, encoded);
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
