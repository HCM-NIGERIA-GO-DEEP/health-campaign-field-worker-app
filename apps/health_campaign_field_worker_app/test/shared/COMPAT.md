# Kit ↔ app-branch compatibility

Record here which kit commit/tag runs green on which app branches, and any
known deliberate reds (config lints failing on a campaign are findings, not
incompatibilities).

| Kit commit/tag | App branch | Configs branch | Result | Notes |
|---|---|---|---|---|
| (seed+engine, 2026-08-20) | smc-mc-base-ledger | feat/smc-mc-base @ bc89c38 | 55 unit/self-tests green, 1 skip (no localization dump), 2 config lints RED — both real findings | (1) REGISTRATION.json: both ineligibleConfig blocks missing cycleIndex stamp (stuck-ineligible bug pattern, fix in HCM-SOLUTION-CONFIG). (2) Configs reference fn:getAllStockBalances (INVENTORY) and fn:filterRecordsWithinCurrentCycle (STOCKREPORTS) which are registered NOWHERE in this app branch's code — config branch is ahead of app branch; don't ship together. |
| (+flow-graph lints, 2026-08-20) | smc-mc-base-ledger | feat/smc-mc-base @ bc89c38 | 63 green, 1 skip, 5 RED — all real findings pending triage | Previous 2 findings still open, plus: (3) 10 dead NAVIGATION targets ("No route found" at runtime) — REGISTRATION: DELIVERY/REDOSE/CHECKLIST→household-acknowledgement (one is a submit button: deliveryChecklistSubmitButton), DELIVERY→DeliveryChecklist, HOUSEHOLD→beneficiary-details/householdDetails, REFER_BENEFICIARY→acknowledgement, UNABLETODELIVER→household-overview; HFREFERRAL: REFERRAL_CREATE→ReferralReconAcknowledgement/referralDetails. Names look like other-campaign screens carried over. (4) REGISTRATION.json has actionType "field.value==true ? SEARCH_EVENT : CLEAR_STATE" — expressions in actionType are never evaluated, silent no-op. (5) INVENTORY.json orphan screens scanStockReceipt + RECORDLESSEXCESS (defined, referenced nowhere). |
