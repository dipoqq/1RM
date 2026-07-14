# Bench Tracker

Cross-platform port of `bench_tracker.py`, with the local JSON file replaced by
Supabase so training and nutrition sync across devices.

Flutter 3.44.6 · Dart 3.12.2

---

## 1. Run the SQL migrations

Supabase dashboard → **SQL Editor** → **New query**, paste each file in
`supabase/migrations/` in numeric order, run it.

- [`001_init.sql`](supabase/migrations/001_init.sql) creates `workouts`, `meals`
  and `profiles`, enables Row Level Security on all three, and adds a trigger
  that gives every new signup a profile row. Read the comments first — it
  deviates from the original two-table spec in three places, each explained
  inline.
- [`002_seed_history.sql`](supabase/migrations/002_seed_history.sql) imports the
  existing `workout_data.json` history.
- [`003_profile_bmr.sql`](supabase/migrations/003_profile_bmr.sql) adds `age`,
  `height_cm` and `activity_level` to `profiles`. **Required even on an existing
  database** — the daily targets are now Mifflin-St Jeor BMR × activity, and the
  app writes those three columns on every profile save.

## 2. Get your keys

**Supabase** → Project Settings:
- **Data API** → Project URL → `SUPABASE_URL`
- **API Keys** → the *publishable* (anon) key → `SUPABASE_ANON_KEY`

Use the publishable key, never the `service_role` secret key. `service_role`
bypasses RLS entirely and would hand anyone holding the app binary full access to
your database.

**Gemini** → [aistudio.google.com/apikey](https://aistudio.google.com/apikey) →
`GEMINI_API_KEY`.

## 3. Run

Nothing is hardcoded; all three values are injected at build time.

Set them once per PowerShell session, then the launch commands stay short:

```powershell
$env:SB_URL  = "https://xxxxx.supabase.co"
$env:SB_KEY  = "eyJhbGci..."
$env:GEM_KEY = "..."

$defines = @(
  "--dart-define=SUPABASE_URL=$env:SB_URL",
  "--dart-define=SUPABASE_ANON_KEY=$env:SB_KEY",
  "--dart-define=GEMINI_API_KEY=$env:GEM_KEY"
)
```

**Windows desktop**
```powershell
flutter run -d windows @defines
```

**Android** (device plugged in with USB debugging on, or an emulator running)
```powershell
flutter devices          # find your device id
flutter run -d <device-id> @defines
```

**Web** — works today with no extra toolchain
```powershell
flutter run -d chrome @defines
```

**Release builds**
```powershell
flutter build windows --release @defines
flutter build apk     --release @defines   # build\app\outputs\flutter-apk\app-release.apk
```

If a define is missing, the app boots to a "Configuration missing" screen rather
than a blank page.

## 4. Sign in

The app opens on a sign-in screen. Create an account on first run; using the same
account on phone and desktop is what makes the data sync. RLS keys every row to
`auth.uid()`, so an account is not optional.

---

## Platform support on this machine

| Target | Status |
|---|---|
| Web | ✅ Verified — builds and runs. |
| Developer Mode | ✅ Enabled (native plugins can symlink). |
| Windows desktop | ❌ `Unable to find suitable Visual Studio toolchain` |
| Android | ❌ `No Android SDK found` |
| iOS | ❌ Not possible on Windows. Requires macOS + Xcode. |

Both remaining installs need **administrator elevation**, so run these yourself
from an **elevated** terminal. Roughly 7 GB and 10 GB respectively.

```powershell
# Windows desktop — C++ toolchain
winget install --id Microsoft.VisualStudio.2022.BuildTools `
  --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet"

# Android — SDK, platform tools, emulator
winget install --id Google.AndroidStudio
```

Then launch Android Studio once (its first-run wizard downloads the SDK), and:

```powershell
flutter doctor --android-licenses   # interactive: accept each with 'y'
flutter doctor                      # should now be all green except iOS
```

The app code is already correct for both targets — these are toolchain installs,
not code changes.

---

## Architecture

```
lib/
  core/         constants, theme, progression math (pure — no IO, no Flutter)
  models/       Workout, Meal, Profile — parsing and domain rules
  services/     SupabaseService, GeminiService — the only code that does IO
  ui/
    tabs/       TrainingTab, NutritionTab
    widgets/    CalendarStrip, ConfettiOverlay, shared cards
```

The rules of the program live in `core/progression.dart` and on the models, not
in widgets. `test/progression_test.dart` covers them directly — plate rounding,
Epley 1RM, the warm-up ramp, plateau detection, and the `[DATA]` parser.

```bash
flutter test
```

## Things worth knowing

**The 80 kg confetti is armed, not spent.** `workout_data.json` carried
`"celebrated_milestones": [80.0]`, but the logged history peaks at a 72.3 kg
estimated 1RM (70 kg × 1) — that entry was a test fire, not a real lift. So
`002_seed_history.sql` leaves `celebrated_milestones` **empty**, and the first
session that genuinely pushes your estimated 1RM past 80 kg earns the burst.

`SupabaseService.claimMilestone` writes the claim to the database *before*
firing, so it then celebrates exactly once — across restarts and across devices.

**Gemini falls back through a model chain.** `gemini-3-flash-preview` leads,
backed by `gemini-flash-latest` → `gemini-2.5-flash` → `gemini-2.0-flash`.

`gemini-2.5-flash` cannot lead: it 404s for newly-created API keys ("no longer
available to new users"), which is what broke the app after the key rotation —
the same trap `bench_tracker.py` documents at its `GEMINI_MODEL` constant. It
stays at the back of the chain rather than being removed, so an older key that
still has access can use it.

A 404/503 advances the chain; a bad key or quota error surfaces immediately
rather than being silently retried.

**Meal dates are calendar days, not timestamps.** `meals.date` is a SQL `DATE`.
A meal logged at 23:30 belongs to that evening — as a `timestamptz` it would be
stored as the next day in UTC and disappear from the strip. The Python app already
worked this way (`"2026-07-14"` for meals, full ISO timestamps for workouts).

**The Gemini key is not a secret.** `--dart-define` compiles it into the binary,
where anyone with the app can extract it. Acceptable for a private personal app;
if this ever ships, move the call behind a Supabase Edge Function and keep the key
server-side.

**Your history import is `002_seed_history.sql`.** Set your email at the top, run
it in the SQL Editor *after* signing up in the app once. It is idempotent — every
insert is guarded, so running it twice cannot duplicate rows, and its profile
upsert deliberately never overwrites `celebrated_milestones`.

`bench_tracker.py` and `workout_data.json` are otherwise untouched; the Python app
still runs (it now reads `GEMINI_API_KEY` from the environment instead of a
hardcoded constant).
