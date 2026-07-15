import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';
import 'tabs/nutrition_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/reminders_tab.dart';
import 'tabs/history_tab.dart';
import 'widgets/confetti.dart';
import 'widgets/sync_status_badge.dart';
import 'widgets/achievements_sheet.dart';
import '../models/workout.dart';
import '../core/achievements.dart';

class PlaceholderTab extends StatelessWidget {
  final String title;
  const PlaceholderTab({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: Theme.of(context).textTheme.titleLarge));
  }
}

/// Tab shell. The confetti overlay is stacked above the tabs at the very top of
/// the tree, so a burst fired from the Training tab paints across the whole
/// screen rather than being clipped inside a card.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  final _confetti = ConfettiController();
  int _index = 0;
  List<Workout> _allWorkouts = [];

  // Toast
  late final AnimationController _toastCtrl;
  late final Animation<Offset> _toastAnim;
  String _toastMessage = '';
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _toastCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _toastAnim = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOut));
    _loadWorkouts();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
    final workouts = await widget.state.service.fetchWorkouts();
    if (mounted) {
      setState(() {
        _allWorkouts = workouts.all;
      });
    }
  }

  /// Single-flight: a new toast supersedes whatever is on screen instead of
  /// stacking. Two achievements unlocking in one `_log()` used to fire
  /// overlapping calls whose uncancellable `Future.delayed` timers clobbered
  /// each other — the first one's reversal would yank the second toast off early.
  /// Cancelling and rescheduling a single [Timer] makes the latest message win
  /// and hold its full three seconds.
  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastCtrl.forward(); // idempotent if already forward / animating in
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _toastCtrl.reverse();
    });
  }

  void _showAchievements() {
    // One flat, unified list — no categories or nested tabs. The sheet handles
    // its own ordering (unlocked-first) and mint/greyed styling.
    final achievements =
        AchievementsEngine.evaluate(WorkoutHistory(_allWorkouts), widget.state);
    showAchievementsSheet(context, widget.state, achievements);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 120,
        leading: const Center(
          child: Text('AppLogo', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: const SizedBox.shrink(),
        actions: [
          // Offline / pending-sync pill. Renders nothing when online and fully
          // synced (or when there is no SyncScope, e.g. in tests).
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: SyncStatusBadge()),
          ),
          IconButton(
            tooltip: 'Achievements',
            icon: const Icon(Icons.emoji_events, size: 20),
            onPressed: _showAchievements,
          ),
          IconButton(
            tooltip: s.signOut,
            icon: const Icon(Icons.logout, size: 20),
            onPressed: widget.state.service.signOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: NotificationListener<AchievementUnlockedNotification>(
        onNotification: (notif) {
          _showToast(context.s.achievementUnlockedToast(notif.title));
          return true;
        },
        child: Stack(
          children: [
            // IndexedStack keeps tabs alive.
            IndexedStack(
              index: _index,
            children: [
              TrainingTab(state: widget.state, confetti: _confetti),
              NutritionTab(state: widget.state),
              const RemindersTab(),
              HistoryTab(state: widget.state),
              // Wrap SettingsScreen in AppScope to retain reactivity
              AppScope(state: widget.state, child: const SettingsScreen()),
            ],
          ),
          Positioned.fill(child: ConfettiOverlay(controller: _confetti)),
          // Custom Sliding Toast
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: SlideTransition(
                position: _toastAnim,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: c.bgSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_toastMessage, style: TextStyle(color: c.textMid, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      )),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: c.bgBase,
        indicatorColor: c.accentTint,
        surfaceTintColor: Colors.transparent,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center, color: c.accentDim),
            label: s.tabTraining,
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant, color: c.accentDim),
            label: s.tabNutrition,
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'History',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: c.accentDim),
            label: s.settings,
          ),
        ],
      ),
    );
  }
}
