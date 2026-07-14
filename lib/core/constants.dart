/// Program constants, ported from bench_tracker.py.
library;

const double kMilestoneKg = 80.0; // first target 1RM
const double kGoalKg = 95.0; // long-term target 1RM

const double kBarbellKg = 20.0; // standard Olympic bar
const double kPlateStepKg = 2.5; // smallest practical jump (2 x 1.25 kg)
const int kPlateauThreshold = 3; // consecutive failed heavy days = plateau
const double kPlateauDeload = 0.10; // forced 10% cut once a plateau is detected

/// Persisted verbatim in `workouts.workout_type`; the SQL CHECK constraint and
/// the plateau detector both depend on these exact strings.
abstract final class WorkoutType {
  static const heavy = 'Heavy Day (Strength)';
  static const volume = 'Volume Day (Hypertrophy/Technique)';
  static const deload = 'Deload (Recovery)';

  static const all = <String>[heavy, volume, deload];
}

/// Milestone 1RMs that trigger confetti, ascending.
const kMilestones = <({double kg, String title, String subtitle})>[
  (kg: kMilestoneKg, title: '80 KG!', subtitle: 'Intermediate milestone cleared.'),
  (kg: kGoalKg, title: '95 KG!', subtitle: 'Final goal smashed.'),
];

/// The lifter, as Gemini should understand him.
const kLifterProfile =
    'an 18-year-old, 197 cm tall, 94 kg lifter';

const kQuotes = <({String text, String author})>[
  (
    text: 'The last three or four reps is what makes the muscle grow. This area '
        'of pain divides a champion from someone who is not a champion.',
    author: 'Arnold Schwarzenegger'
  ),
  (
    text: "Everybody wants to be a bodybuilder, but don't nobody want to lift no "
        'heavy-ass weights.',
    author: 'Ronnie Coleman'
  ),
  (
    text: 'If you train hard enough, long enough, and heavy enough, the results '
        'will come.',
    author: 'Dorian Yates'
  ),
  (
    text: 'The pain you feel today will be the strength you feel tomorrow.',
    author: 'Iron Philosophy'
  ),
  (
    text: "There is no reason to be alive if you can't do the deadlift.",
    author: 'Jon Pall Sigmarsson'
  ),
  (
    text: 'The iron never lies to you. The iron is the great reference point.',
    author: 'Henry Rollins'
  ),
  (
    text: 'Discipline is doing what you hate to do, but doing it like you love it.',
    author: 'Mike Tyson'
  ),
  (
    text: "Failure is not the opposite of success - it's the toll you pay on the "
        'way there.',
    author: 'Iron Philosophy'
  ),
  (
    text: "You don't find willpower. You build it, one rep you didn't want to do "
        'at a time.',
    author: 'Iron Philosophy'
  ),
  (
    text: 'Suffer the pain of discipline or suffer the pain of regret.',
    author: 'Jim Rohn'
  ),
];
