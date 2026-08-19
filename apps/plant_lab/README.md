# Plant + Lab Mobile/Web

Flutter client for the Advanta Plant/Lab quality workflow.

## Safe default

Operational writes are disabled by default. The UI shows a read-only banner,
write controls are disabled, and every repository write method has a second
guard. Do not enable writes until the P0-B database hardening and UAT gates have
passed.

Run or build with a Supabase publishable key:

```powershell
flutter run `
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

After the one-time sync, the standard Android Studio Run button and ordinary
Flutter commands work without extra arguments. The optional launcher performs
the sync automatically:

```powershell
.\tool\flutter_with_local_config.ps1 run -DeviceId emulator-5554
.\tool\flutter_with_local_config.ps1 build-apk-release
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

- Plant access enables Receiving and Inspections.
- Lab access enables Lab Test and Sample Tracking.
- Routes outside the active scope are redirected to Access Restricted, including
  direct links.

These UI guards complement database RLS; they do not replace it. The access
context must always come from the authenticated RPC and must not be inferred from
email addresses or client-side metadata.
