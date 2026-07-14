import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/supabase_service.dart';
import 'tabs/nutrition_tab.dart';
import 'tabs/training_tab.dart';
import 'widgets/confetti.dart';

/// Tab shell. The confetti overlay is stacked above the tabs at the very top of
/// the tree, so a burst fired from the Training tab paints across the whole
/// screen rather than being clipped inside a card.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.service});

  final SupabaseService service;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _confetti = ConfettiController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bench Tracker',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: widget.service.signOut,
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
              TrainingTab(service: widget.service, confetti: _confetti),
              NutritionTab(service: widget.service),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center, color: AppColors.accentDim),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant, color: AppColors.accentDim),
            label: 'Nutrition',
          ),
        ],
      ),
    );
  }
}
