# 0008 — Billable commits at AWB assignment, not at order creation

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** Aditya Bharadwaj (operator); Claude Opus 4.7 (author).

## Context

Shiprocket's order lifecycle is multi-step:

1. **Create an order record** (`POST /orders/create/adhoc`) — sits in the system, no carrier committed.
2. **Quote serviceability** (`GET /courier/serviceability`) — read-only.
3. **Assign an AWB** (`POST /courier/assign/awb`) — picks a courier and *commits* the booking. **This is where Shiprocket actually charges.**
4. **Generate label/invoice/manifest** (`POST /courier/generate/{label,invoice,manifest}`) — paid per pull on most plans.
5. **Schedule pickup** (`POST /courier/generate/pickup`) — paid on some plans.

The naive classification would be "creating an order costs money" → mark `POST /orders/create/adhoc` as `billable`. That's wrong: the order record is free; the carrier booking at AWB assign is what spends real money.

Why this matters: if the AI / operator misidentifies the billable step, they will pass `--i-understand-billing` at the wrong time and skip the confirmation prompt at the moment that actually costs money.

## Decision

In `_BILLABLE_EXACT`:

- `POST /courier/assign/awb` — yes, billable (the financial commit).
- `POST /courier/assign/awb/return` — yes, billable (return shipments).
- `POST /courier/generate/{pickup,label,invoice,manifest}` — yes, billable (paid artifact generation).
- `POST /shipments/create/{forward-shipment,return}` — yes, billable (these book carrier capacity).
- `POST /orders/print/{label,invoice,manifest}` — yes, billable (alternate printing endpoints).

In `_MUTATING_EXACT` (explicitly *not* billable):

- `POST /orders/create/adhoc` — mutating only; creating the order record is free.
- `POST /orders/update`, `POST /orders/address/update` — free metadata updates.
- `POST /settings/company/addpickup` — free pickup-location config.

The SKILL.md explicitly tells the AI: order creation is free; the billable moment is AWB assignment. The CHANGELOG flags this as a deliberate design choice.

## Consequences

- **The AI's confirmation prompt fires at the right time.** "Confirm I should book courier X at rate Y" lands on AWB assign, not on order creation.
- **An operator running an unusual Shiprocket plan may disagree.** If their plan charges at order-create time, they need to extend `_BILLABLE_EXACT` locally and submit a PR.
- **Cancellation after AWB assign is `destructive`, not `billable`.** Cancellation may incur fees, but the primary effect is destruction of a booking. The SKILL.md flags the fee risk explicitly ("if AWB assigned, this may incur cancellation / RTO fees").

## Related

- [[0002-safety-classifier-six-tiers]]
- [[0010-conservative-classifier-under-undocumented-surface]]
