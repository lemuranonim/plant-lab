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

## Hosted pilot (production build, read-only)

Set these build-time variables separately on the Plant and Lab **pilot** deployments:

- `NEXT_PUBLIC_PLANT_LAB_HOSTED_PILOT=true`
- `NEXT_PUBLIC_SUPABASE_URL`: the HTTPS URL of Advanta-CC
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: that project's `sb_publishable_…` key
- `PLANT_LAB_APP_VARIANT=PLANT` or `LAB` per deployment

Do not set `NEXT_PUBLIC_PLANT_LAB_LOCAL_PREVIEW=true` for this build. Hosted
pilot uses `plantlab_api` for access context and the read-only request queue;
unavailable RPCs fail closed. Only accounts with active, matching Plant/Lab
assignments can enter the corresponding pilot. This does not change their
existing permissions elsewhere in Advanta-CC.

After the real-data/role checks, `NEXT_PUBLIC_PLANT_LAB_HOSTED_WRITES_ENABLED=true`
opts the canonical workflow into the production build. It never enables legacy
write routes. Current online-UAC submission UI offers Germination (Sand), whose
sample, observation and independent-review workflow is implemented. Imported
history is not automatically converted into new requests or approved results.
