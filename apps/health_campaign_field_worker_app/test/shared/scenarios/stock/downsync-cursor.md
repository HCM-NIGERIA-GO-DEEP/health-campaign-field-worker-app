# Stock downsync cursor never poisons itself

**Area:** stock downsync (`lib/utils/stock_downsync_cursor.dart`)
**Bug it guards:** cursor-poisoning (fixed 2026-07-27) — a cursor written from
the device clock after an empty server page permanently hid national→state
stock dispatches.

## Scenarios (plain English)

1. Given a stored cursor and a cycle start date, the download cutoff is the
   stored cursor (stored wins).
2. Given no stored cursor (fresh install / post storage-clear), the cutoff
   falls back to the cycle start date.
3. Given neither, the cutoff is null (no campaign cycles configured).
4. Given the server returns an empty page, the next cursor is null — the
   caller must keep the old cursor, never write "now".
5. Given downloaded records where none carry server audit details, the next
   cursor is null (same as empty page).
6. Given downloaded records with server lastModifiedTime 1500, 3000, 2000,
   the next cursor is exactly 3000 (max of the page).
7. Given a stored cursor of 5000 and a page whose max lastModifiedTime is
   4000, the next cursor stays 5000 (never moves backward).
8. Cursor keys must differ across users and across cycles on the same
   device+project (shared-device multi-CDD bug).

## Generated test

`test/stock/stock_downsync_cursor_test.dart`
