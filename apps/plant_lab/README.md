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

After a separately approved production release, writes can be enabled with:

```text
--dart-define=OPERATIONAL_WRITES_ENABLED=true
```

Never pass a Supabase secret/service-role key to this client.
