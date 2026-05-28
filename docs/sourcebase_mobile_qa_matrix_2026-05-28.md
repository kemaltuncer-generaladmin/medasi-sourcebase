# SourceBase Mobile QA Matrix - 2026-05-28

Scope: UI + flow polish for iPhone 14, iPhone SE, and Android gesture navigation.

## Devices

| Device | Viewport | Purpose |
| --- | --- | --- |
| iPhone 14 | 390x844 | Primary visual quality target |
| iPhone SE | 375x667 | Compact height and keyboard stress test |
| Android Gesture | 412x915 | Gesture safe-area and bottom nav sanity |

## Smoke Scenarios

| Area | Checks |
| --- | --- |
| App shell | Bottom nav visible, selected state readable, no content hidden under home indicator |
| Auth | Login/register/profile setup scroll with keyboard open; CTA remains reachable |
| Drive | Home, search, upload, file detail, empty/error/loading states remain readable |
| Upload | Uploading/processing/ready/failed badges remain distinct and non-overlapping |
| BaseForce | Home/source picker/factory/result scroll to final CTA without bottom nav collision |
| SourceLab | Home/source picker/builder/result use one-column mobile flow where needed |
| Central AI | Composer is keyboard-aware; message list and source chips remain reachable |
| Profile/Store | Package cards are single-column on mobile; price and CTA are visible |

## Required Commands

- `flutter analyze`
- `flutter test`
- `flutter build web`

## Protected Flows

- Auth routing and Supabase calls
- Drive upload and `complete_upload`
- Generation job behavior
- MC balance and store purchase behavior
- Backend API contracts and database schema
