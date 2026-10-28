#!/usr/bin/env bash
# Verifies that the partial-accept localisations (added for THIS campaign,
# long after the previous one) are present in the seeded base modules.
#
# Why these codes: they exist only in CMP-2026-10-12-001274. If they are in
# hcm-base-inventory-bednet, the base module was seeded from the current
# campaign and nothing was reverted to the old one. If they are absent, the
# seed read stale content and the base modules need re-running.
set -euo pipefail

HOST="${HOST:-https://sierraleone-hcm-uat.digit.org}"
TENANT="${TENANT:-si}"
LOCALE="${LOCALE:-en_NG}"
MODULE="${1:-hcm-base-inventory-bednet}"

CODES='INVENTORY_PARTIALLY_ACCEPT_STOCK_LABEL
INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID
INVENTORY_ACTUAL_QUANTITY_RECEIVED_LABEL
INVENTORY_SHORTFALL_QUANTITY_LABEL
INVENTORY_REJECT_CONFIRMATION_TITLE
INVENTORY_REJECT_COMMENT_LABEL
INVENTORY_DISCREPANCY_REASON_LABEL
INVENTORY_DISCREPANCY_REASON_IN_TRANSIT
INVENTORY_DISCREPANCY_REASON_STOCK_LOSS
INVENTORY_DISCREPANCY_REASON_STOCK_DAMAGE
INVENTORY_STOCK_REJECTED_SUCCESS
ITN'

echo "Module: $MODULE"
echo "Host:   $HOST   tenant=$TENANT locale=$LOCALE"
echo

curl -s -X POST \
  "$HOST/localization/messages/v1/_search?tenantId=$TENANT&locale=$LOCALE&module=$MODULE" \
  -H 'Content-Type: application/json' -d '{"RequestInfo":{}}' \
| CODES="$CODES" python3 -c '
import json, os, sys

payload = json.load(sys.stdin)
messages = payload.get("messages") or []
found = {m["code"]: m["message"] for m in messages if m.get("code")}
wanted = [c for c in os.environ["CODES"].split("\n") if c]

print(f"total messages in module: {len(found)}\n")
missing = []
for code in wanted:
    if code in found:
        print(f"  OK       {code} => {found[code]!r}")
    else:
        missing.append(code)
        print(f"  MISSING  {code}")

print()
if not found:
    print("Module is EMPTY - the seed never ran, or ran against another host.")
    sys.exit(2)
if missing:
    print(f"{len(missing)} of {len(wanted)} partial-accept codes missing.")
    print("The base module was seeded from stale content - re-run the copy.")
    sys.exit(1)
print("All partial-accept codes present - base module holds current-campaign content.")
'
