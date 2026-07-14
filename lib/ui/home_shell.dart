import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';
import 'tabs/nutrition_tab.dart';
import 'tabs/training_tab.dart';
import 'widgets/confetti.dart';

/// Tab shell. The confetti overlay is stacked above the tabs at the very top of
/// the tree, so a burst fired from the Training tab paints across the whole
/// screen rather than being clipped inside a card.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _confetti = ConfettiController();
  int _index = 0;

  void _openSettings() {
    final state = widget.state;
    Navigator.of(context).push(MaterialPageRoute<void>(
      // A pushed route is a new subtree: AppScope has to be re-established
      // above it, or Settings could not read — or change — the profile.
      builder: (_) => AppScope(state: state, child: const SettingsScreen()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: s.settings,
            icon: const Icon(Icons.tune, size: 20),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: s.signOut,
            icon: const Icon(Icons.logout, size: 20),
            onPressed: widget.state.service.signOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // IndexedStack keeps both tabs alive, so switching away and back does
          // not refetch or lose the selected calendar day.
          IndexedStack(
            index: _index,
            children: [
              TrainingTab(state: widget.state, confetti: _confetti),
              NutritionTab(state: widget.state),
            ],
          ),
          Positioned.fill(child: ConfettiOverlay(controller: _confetti)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.bgBase,
        indicatorColor: AppColors.accentTint,
        surfaceTintColor: Colors.transparent,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon:
                const Icon(Icons.fitness_center, color: AppColors.accentDim),
            label: s.tabTraining,
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon:
                const Icon(Icons.restaurant, color: AppColors.accentDim),
            label: s.tabNutrition,
          ),
        ],
      ),
    );
  }
}
