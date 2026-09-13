# My Stories

A responsive Flutter app for reading, creating, organizing, and tracking a personal story library.

## Features

- Browse seeded stories with responsive cards for phone, tablet, and desktop layouts
- Search by title, author, or category
- Filter the library by all stories, favorites, or finished stories
- Read stories in a distraction-free detail view
- Track reading progress and mark stories as finished
- Favorite, create, edit, and delete stories
- Persist the library locally with `shared_preferences`
- Cross-platform targets: Android, iOS, web, Linux, macOS, and Windows

## Run

```bash
flutter pub get
flutter run
```

## Validate

```bash
flutter analyze
flutter test
flutter build apk --debug
```

The app stores library data locally in the platform's shared preferences. Seeded stories are used when no saved library exists.
