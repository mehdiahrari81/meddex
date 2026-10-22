# Admin dashboard · 2026-10-12

> Historical report for an earlier installation. The current `meddex` portal is **http://localhost:3000**, with the existing legitimate catalogue registered and connected to mobile publication. Use your own named administrator and private password. Follow [Admin → database → mobile content flow](ADMIN_MOBILE_DATA_FLOW.md) for the current setup; the demo accounts, port, and counts below do not describe the current installation.

The updated local portal runs at **http://localhost:13001**. Use the current named admin credentials recorded in the private, ignored `CREDENTIALS.md`. This local account signs in with email and password only. The authenticator input appears only after selecting **Use an authenticator code**, for accounts that have enrolled. Production requires named MFA administrators.

## Interface and behavior

- A branded sidebar, workspace search, account header, and consistent cards, tables, and status badges extend across the admin portal and login screen.
- Dashboard totals come from the full database rather than a shortened recent-record list. The dashboard includes editorial activity over 7, 14, or 30 days, a content-state chart, recent content, a report inbox, audit activity, and observed service health.
- Management tables support text search, status filtering where applicable, sorting, and pagination. Recent content has separate state filters. Workspace search opens permitted administration pages.
- Report inbox links select a real report and prefill its ID in the review form. Resolution still requires confirmation, records an audit event, and refreshes dashboard counts.
- Navigation and dashboard data respect backend permissions. For example, support users cannot see editorial content or audit activity through the dashboard endpoint.
- Responsive navigation and contained tables work on phone and desktop widths. Database and provider indicators use actual observations; zero provider calls display as no activity.

## Demonstration data

The running development database contains the following additional, clearly labeled examples:

| Records | Count | Initial state |
| --- | --- | --- |
| Editorial content | 24 | 9 published, 6 in review, 6 draft, 3 approved |
| Governance reports | 6 | 3 open, 2 in review, 1 resolved |
| Import examples | 2 | Validation failed; no staged products |
| Synthetic editorial audit events | 24 | Spread across seven days |

Content comprises 8 terminology records, 4 morphology records, 4 abbreviations, 2 lessons, 3 quiz questions, and 3 Urdu interface translations. The examples use the bundled development corpus and synthetic report summaries. Their identifiers start with `demo.fyp.` and their metadata marks them as demonstration data without production approval.

These records are editorial exercises. Their individual lifecycle states do not install a canonical reference release or replace the mobile dataset. The import examples cannot apply fictional products. The demo author is inactive, has no administrative membership, and has no usable supplied login. Provider traffic and availability are not fabricated.

Counts will change as you review or edit examples through the portal. Seeding is explicit, allowed only in development/testing, and preserves existing records and your edits on repeated runs. It is never invoked automatically at startup.

To add the same examples to the existing local Compose instance:

```sh
docker compose -p mediexplain-local exec -T api python -m app.cli seed-demo \
  --actor-email fyp.admin@example.com \
  --path /opt/mediexplain/reference/starter_dataset_v1.json
```

For a different instance, replace the project name and actor email with an existing active administrator. The first run here added 24 content records, 6 reports, and 2 import jobs. A second run returned zero additions for all three categories.

## Executed verification

- API lint, formatting, strict typing, and **75 tests** passed. Added checks cover full counts, permissions, activity periods, demo markers, seed idempotency, edit preservation, and rejection in production.
- Admin lint, TypeScript, navigation unit test, and production build passed.
- **9 Chrome browser workflows** passed against a disposable database, including persisted dashboard totals, activity periods, filters, search, pagination, and confirmed report resolution with updated totals.
- The rebuilt local Docker portal was checked separately with the existing account. Its initial metric cards showed **24 content records / 6 awaiting review / 5 reports to resolve / 0 provider requests**. No browser page errors occurred.
- Actual page widths matched viewports at **390, 768, 1024, and 1440 pixels**, with no page-wide horizontal overflow. Desktop and phone screenshots were visually inspected.
- All four local containers remained healthy. This update preserves the existing database and login credentials.

Evidence: [desktop dashboard](smoke-evidence/2026-10-12/admin-dashboard-desktop.png), [phone dashboard](smoke-evidence/2026-10-12/admin-dashboard-mobile.png), and [login screen](smoke-evidence/2026-10-12/admin-login.png).

The [smoke report](SMOKE_TEST_REPORT.md) records mobile coverage and remaining device checks. Production requirements remain in the [production checklist](PRODUCTION_CHECKLIST.md).
