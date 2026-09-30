> **Deployment note:** This is a local-only preview, not a live registration service. Do not collect actual volunteer personal information until the Supabase backend, organizer authentication, and secure registration endpoints are connected. No emails or texts are sent.

# Rogue Valley MobilePack — Registration prototype

This is a **working, browser-local demo**, not a production registration system. It uses the uploaded RVMP logo, slate/gold/sage palette, and static HTML/CSS/JS. No npm, build step, server, or Supabase account is required to preview it.

## Upload to GitHub (now)

1. Create a new GitHub repository, e.g. `rvmp-registration`.
2. Upload **all** files and folders in this package to the repository root. Do not upload only `index.html`: `styles.css`, `app.js`, and `assets/rvmp-logo.png` are also needed.
3. In GitHub open **Settings → Pages → Build and deployment → Deploy from a branch**.
4. Choose `main`, folder `/ (root)`, and Save. GitHub will show a Pages URL after deployment.
5. Use the Pages URL **for private demonstration with fictional information only**. Anyone with the URL can see the public demo and open its unprotected demo organizer screen. Do not collect real names, emails, or phone numbers in this version.

The demo persists only in the current browser's `localStorage`; it does not sync devices. Use **Organizer → Groups** to create a group code, assign group allocations per shift, then **Register → I have a group code** to test. Use **Organizer → Shifts** to edit times/capacities and **Settings** to set the actual donation checkout URL, event location, organizer email, and instructions. All starting shift times/capacities are **illustrative placeholders** and must be verified.

## Version 2 changes

- Public registration is a three-step flow: choose shifts, add primary contact and volunteers, review and confirm.
- Add Volunteer appears below the volunteer entry cards. The public registration page no longer shows the donation prompt; it remains on the success page.
- Header logo sits on a light background to preserve its dark artwork, and page sections no longer overlap the hero.
- Organizer Overview includes expandable adult/minor, shift, and group breakdowns with volunteer names.

## What's in the demo

- Five configurable shifts (3 packing, setup, teardown), one packing shift per registration, optional setup/teardown.
- One primary contact per family; volunteer names and 18+ yes/no only for each attendee.
- 10-person public limit, request-more email link, optional future email/text opt-ins.
- Group codes and per-shift reserved allocations; unused allocations are excluded from public availability.
- Local registration confirmation with downloadable `.ics` calendar entries.
- Local-only registration lookup, organizer overview, age demographics, CSV export, cancellation/restoration.
- Suggested $50/$100/Other links all opening the same configurable external donation page.

## Supabase — later

`supabase/schema.sql` contains the **database foundation and RLS policies**, not a ready-to-activate integration. It intentionally disallows public writes to prevent leaking personal data or overbooking. When you have a Supabase project, the remaining engineering work is:

1. Run and review `supabase/schema.sql` in the Supabase SQL editor, configure Supabase Auth, and explicitly designate your organizer user in `rvmp_organizers`.
2. Implement an atomic, transactional registration function (or secure server endpoint) that validates each attendee and capacity *at the database*, locks relevant shift/allocation rows to prevent simultaneous overbooking, and verifies hashed group access codes. Enforce no more than one packing shift **per volunteer**, not just per family registration.
3. Add a safe public availability API that exposes aggregate counts only; do **not** expose registration contacts or group codes.
4. Replace demo `localStorage` reads/writes with authenticated Supabase queries and the secure registration endpoint. Add Supabase Realtime for live aggregate counters.
5. Add authenticated organizer management, secure group-leader editing access, email-verified lookup links, transactional confirmation email, reminder scheduler, and optional SMS provider with compliant consent/opt-out handling.
6. Add anti-spam/rate limiting, data-retention policy, consent records, audit trail, duplicate detection, and an actual check-in workflow if needed.
7. Confirm production event dates, times, capacities, location, donation checkout URL, organizer email, and age/supervision policies. Test concurrency, group releases, cancellations, and phone accessibility before collecting actual data.

**Never** put a Supabase service-role/secret key in `app.js`, GitHub Pages, or any other public client file. A public Supabase anon/publishable key is appropriate only once database security is properly implemented and tested.

## Important limitations

This package is **phase 1 UI/demo + phase 2 database schema groundwork**. It does not send emails or texts, cannot protect organizer data, cannot offer verified registration lookups, and does not collect actual donations. A GitHub Pages deployment is **not ready for live volunteer registrations**.

### Version 4 interface change

The organizer overview no longer includes a separate Volunteer breakdown list. Expanding a shift now shows its adult/minor counts and percentages above the attendee names. Overall adult/minor metric cards remain visible.
