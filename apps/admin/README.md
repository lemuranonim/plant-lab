# Plant + Lab Admin Web

Next.js administration and reporting client for Advanta Plant/Lab.

Required local variables belong in `.env.local` and must not be committed:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_xxx
PLANT_LAB_APP_VARIANT=LAB
PLANT_LAB_WRITES_ENABLED=false
```

`PLANT_LAB_APP_VARIANT` is required and accepts exactly `PLANT` or `LAB`.
It controls branding, metadata, navigation, dashboard data, module access, and
route isolation. Do not use a combined value in a production deployment.

`PLANT_LAB_WRITES_ENABLED` is server-only and defaults to `false`. Keep it
disabled until the separately approved P0-B database hardening and UAT gates
have passed. A service-role/secret key must never be added to this browser-facing
application.

```powershell
npm run lint
npm run build
```

## Separate web deployments

Use the same repository and `apps/admin` root directory for two Vercel
projects. Both projects use the same `advanta-cc` Supabase URL and publishable
key, but each project has its own variant value and domain.

| Deployment | `PLANT_LAB_APP_VARIANT` | Suggested domain |
| --- | --- | --- |
| Advanta Plant | `PLANT` | `plant.advantaindonesia.com` |
| Advanta Lab | `LAB` | `lab.advantaindonesia.com` |

Keep `PLANT_LAB_WRITES_ENABLED=false` until the write workflow has passed its
separate UAT gate. Add both final web domains to the Supabase Auth redirect URL
allowlist before enabling password reset or email-link flows.
