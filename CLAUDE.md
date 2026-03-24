# TimeTracker — Claude Code project memory

## App overview
A personal time tracking Android app for manual logging of time entries against categories.
Built for single user, fully offline, no backend, no cloud, no authentication required.

## Project location
`F:\working\TransformLearning\TimeTracker`

## Tech stack
- **Language**: Dart
- **Framework**: Flutter (latest stable)
- **Database**: SQLite via `sqflite` package
- **State management**: Choose the simplest option that fits — prefer Provider unless
  complexity clearly warrants Riverpod. Document the choice in this file when decided.
- **Target platform**: Android only (Android 11+, API level 30+)
- **Dev machine**: Windows 10

## Constraints (never violate these)
- Fully offline — no HTTP calls, no Firebase, no cloud sync
- No user authentication
- No paid packages or services
- All data stored on device via SQLite
- APK deployed manually via ADB — no Play Store
- Never hard-delete a subcategory that has time entries — archive it instead

## Folder structure
```
lib/
  main.dart
  models/          # Dart data classes (TimeEntry, Category, Subcategory)
  db/              # Database helper and repository classes
  screens/         # One file per screen
  widgets/         # Reusable UI components
  providers/       # State management
  constants/       # App-wide string labels, colors, default data
assets/
test/
```

## Data model

### categories table
| column      | type    | notes                         |
|-------------|---------|-------------------------------|
| id          | INTEGER | primary key, autoincrement    |
| name        | TEXT    | unique, not null              |
| color       | TEXT    | hex color string e.g #1D9E75  |
| created_at  | TEXT    | ISO8601 datetime              |

**Delete rule**: a category can only be deleted if it has zero subcategories.
Enforce this check in the repository before executing any delete.

### subcategories table
| column       | type    | notes                                |
|--------------|---------|--------------------------------------|
| id           | INTEGER | primary key, autoincrement           |
| category_id  | INTEGER | foreign key → categories.id          |
| name         | TEXT    | not null                             |
| is_archived  | INTEGER | 0 = active, 1 = archived (default 0) |
| created_at   | TEXT    | ISO8601 datetime                     |

**Delete rule**: never hard-delete a subcategory that has time entries.
Instead set is_archived = 1. Only show subcategories where is_archived = 0
in entry form dropdowns and category management screens.
Hard delete is only allowed if subcategory has zero time entries.

### time_entries table
| column          | type    | notes                              |
|-----------------|---------|------------------------------------|
| id              | INTEGER | primary key, autoincrement         |
| subcategory_id  | INTEGER | foreign key → subcategories.id     |
| date            | TEXT    | YYYY-MM-DD format                  |
| start_time      | TEXT    | HH:mm format                       |
| end_time        | TEXT    | HH:mm format                       |
| duration_min    | INTEGER | auto-calculated, stored in minutes |
| notes           | TEXT    | nullable, free text                |
| created_at      | TEXT    | ISO8601 datetime                   |

**Category in reports**: derive category by joining time_entries → subcategories → categories.
Never store category_id directly on time_entries.

## Default seed data (load on first app launch)
Load these categories and subcategories when the database is first created:

**Health and fitness** (color: #1D9E75)
- Gym 
- Running / cardio
- Walking
- Yoga 
- Sports
- outdoor activity
- Meditation


**Learning and development** (color: #534AB7)
- AI and machine learning
- App development
- Reading / books
- Online courses
- Research and exploration

**Family and personal life** (color: #BA7517)
- Family time / bonding
- Social activities
- Errands
- Entertainment / leisure
- Travel / outing

**Daily routine** (color: #185FA5)
- Sleep / rest
- Morning routine
- Meals / eating
- Commute / travel
- Household chores
- Evening wind-down

## Screens
1. **Home screen** — defaults to today's date on open, left/right arrows to navigate
   dates, list of time entries for selected date grouped by subcategory, total hours
   for the day at the top, FAB to add new entry
2. **Entry form screen** — manual entry: date (pre-filled with selected date),
   grouped subcategory picker (subcategories shown under parent category heading),
   start time, end time, auto-calculated duration, notes (optional)
3. **Categories screen** — list of categories, expand each to see subcategories,
   add/edit/delete categories, add/edit/delete or archive subcategories
4. **Reports screen** — daily and weekly summary grouped by category with duration
   totals, week runs Monday to Sunday
5. **Export screen** — generate CSV, save to phone Downloads folder

## Entry form — subcategory picker behaviour
Show a grouped dropdown with subcategories listed under their parent category:
```
── Health and fitness ──
   Gym / strength training
   Running / cardio
── Learning and development ──
   AI and machine learning
```
Only show subcategories where is_archived = 0.
Category name is visible as a group header but the actual selection is the subcategory.

## Key behaviours
- Default view is always today's date on app open
- Duration is auto-calculated from start and end time (end - start in minutes)
- Weekly report runs Monday to Sunday
- Export filename format: timetracker_export_YYYYMMDD.csv
- CSV columns: date, category, subcategory, start_time, end_time, duration_min, notes
- Archived subcategories still appear correctly in historical reports and exports
- No internet permission in AndroidManifest.xml

## Dev conventions
- Use async/await throughout — no raw callbacks
- All database operations go through repository classes only — never call sqflite directly from UI
- Three repositories: CategoryRepository, SubcategoryRepository, TimeEntryRepository
- Screen files named *_screen.dart, widget files named *_widget.dart
- No hardcoded strings in UI — use constants file for labels
- Handle null safety strictly — no ! force-unwrap unless genuinely unavoidable
- Duration calculation: duration_min = (end hour * 60 + end minute) - (start hour * 60 + start minute)

## Build and run commands
```bash
# Check setup
flutter doctor

# Get dependencies
flutter pub get

# Run on connected Android device
flutter run

# Build release APK
flutter build apk --release

# Install APK on phone via ADB
adb install build\app\outputs\flutter-apk\app-release.apk
```

## Build order (follow this sequence)
1. Project scaffold + pubspec.yaml dependencies
2. Database helper (DBHelper) — creates all 3 tables, handles versioning
3. CategoryRepository — CRUD + delete protection check
4. SubcategoryRepository — CRUD + archive logic + seed data loader
5. TimeEntryRepository — CRUD + date filter queries + report aggregation queries
6. Home screen with date navigation (hardcoded dummy data first)
7. Wire home screen to real database via Provider
8. Entry form screen with grouped subcategory picker
9. Categories screen — manage categories and subcategories
10. Reports screen — daily and weekly summaries
11. Export screen — CSV generation to Downloads folder
12. Polish — empty states, error handling, loading indicators, confirm dialogs for deletes
