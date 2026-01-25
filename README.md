# project_e_menu — Digital Menu (Flutter)

Minimal Flutter scaffold for a digital menu app.

Getting started

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. From this project folder run:

```bash
flutter pub get
flutter run
```

Files of interest

- `lib/main.dart`: Simple UI that loads `assets/menu.json` and shows categories.
- `assets/menu.json`: Sample menu data.
- `pubspec.yaml`: Declares the `assets/menu.json` asset.

Next steps (suggested)

- Replace `assets/menu.json` with your restaurant's menu.
- Add images for items and list them under `flutter.assets` in `pubspec.yaml`.
- Implement ordering, cart, and backend sync if needed.

Supabase integration

- Create a `.env` file at the project root (do NOT commit it) using `.env.example` as a template and fill `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- The app will try to load the menu from Supabase (table `categories` with related `items`) if the `.env` values are present; otherwise it uses `assets/menu.json`.

Example Supabase schema (simple):

 - `categories` table: `id`, `name`
 - `items` table: `id`, `category_id` (references `categories.id`), `name`, `price`, `description`

After adding credentials, fetch packages and run (web):

```bash
flutter pub get
flutter run -d chrome
```
