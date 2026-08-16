# Plant + Lab Admin Web

Next.js administration and reporting client for Advanta Plant/Lab.

Required local variables belong in `.env.local` and must not be committed:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_xxx
PLANT_LAB_WRITES_ENABLED=false
```

`PLANT_LAB_WRITES_ENABLED` is server-only and defaults to `false`. Keep it
disabled until the separately approved P0-B database hardening and UAT gates
have passed. A service-role/secret key must never be added to this browser-facing
application.

```powershell
npm run lint
npm run build
```
