# Advanta Plant and Advanta Lab Mobile

One shared Flutter codebase produces two independently installable Android apps.
Both use the same authenticated Supabase workflow and canonical database.

| App | Flavor | Entrypoint | Android application ID |
|---|---|---|---|
| Advanta Plant | `plant` | `lib/main_plant.dart` | `com.advantaindonesia.plant` |
| Advanta Lab | `lab` | `lib/main_lab.dart` | `com.advantaindonesia.lab` |

## Safe default

Operational writes are disabled by default. The UI shows a read-only banner,
write controls are disabled, and every repository write method has a second
guard. Do not enable writes until the P0-B database hardening and UAT gates have
passed.

Run or build with a Supabase publishable key:

```powershell
flutter run --flavor lab --target lib/main_lab.dart `
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

Plant/Lab follows the same Android Studio workflow as GOT & FET and Kroscek. A
local ignored `.env` is packaged as a Flutter asset and loaded before Supabase is
initialized. Synchronize it from the existing ignored `apps/admin/.env.local`:

```powershell
cd D:\plant-lab\apps\plant_lab
.\tool\sync_mobile_env.ps1
```

After the one-time sync, select the matching flavor and entrypoint in Android
Studio. The local launcher performs the sync and supplies both values:

```powershell
.\tool\flutter_with_local_config.ps1 -Command run -Flavor plant -DeviceId emulator-5554
.\tool\flutter_with_local_config.ps1 -Command run -Flavor lab -DeviceId emulator-5554
.\tool\build_mobile_flavors.ps1 -Mode release
```

Direct Flutter commands are also supported:

```powershell
flutter run --flavor plant --target lib/main_plant.dart -d emulator-5554
flutter run --flavor lab --target lib/main_lab.dart -d emulator-5554
flutter build apk --release --flavor plant --target lib/main_plant.dart
flutter build apk --release --flavor lab --target lib/main_lab.dart
```

The generated `.env` and the admin source file are both ignored by Git. Only a
modern `sb_publishable_` client key is accepted; never place a service-role key in
either mobile configuration. Operational writes remain disabled by default.

After a separately approved production release, writes can be enabled with:

```text
--dart-define=OPERATIONAL_WRITES_ENABLED=true
```

Never pass a Supabase secret/service-role key to this client.

## Role and site authorization

After authentication, the app loads `pl_get_current_access_context()` and uses
the returned active module, role, company, and site scope to build navigation:

- Advanta Plant accepts Plant-scoped users and enables Receiving and Inspections.
- Advanta Lab accepts Lab-scoped users and enables Lab Test and Sample Tracking.
- Platform administrators may enter either app, but each binary still exposes
  only its own module.
- A valid user assigned only to the other module is redirected to Access
  Restricted and can sign out safely.

These UI guards complement database RLS; they do not replace it. The access
context must always come from the authenticated RPC and must not be inferred from
email addresses or client-side metadata.
