# Money-sink catalog

Unit costs for pricing a finding. **Observed 2026-08-21, USD.** Every source page is
JS-rendered and at least one summarising fetch hallucinated a rate table on first attempt —
so treat these as needing a scheduled refresh, and **never quote a figure with more precision
than the range below supports.**

Give a range with the arithmetic shown. If executions are not derivable from the code, say
**"not derivable from static analysis"** and price one call instead. Do not invent a
multiplier.

---

## Comms

**Twilio SMS (US long code).** Base $0.0083/segment outbound, **plus A2P 10DLC carrier fees
per segment** — AT&T $0.0035, T-Mobile/Verizon $0.0045, US Cellular $0.0050, other $0.0040.

> **All-in: $0.0118–$0.0133/segment. Use ~$0.0125 blended.** 50,000 segments ≈ **$625**.

MMS out $0.022. **Failed messages are billed** at $0.001 (since 30 Sep 2024) — a loop sending
to a dead number still costs money.

**Segments matter and are routinely undercounted.** GSM-7 is 160 characters alone, **153 when
concatenated**. Characters `[ ] { } \ ~ ^ | €` count as **two**. Any non-GSM character forces
UCS-2: 70 chars, 67 concatenated. A 300-character reminder with a link and a `[STOP]`
instruction is 2–3 segments — so the real rate is **$0.025–$0.0375 per message**, not $0.0125.

**Email — the overage rate is what matters in a runaway, not the bundle price.**

| Provider | Per 1,000 |
|---|---|
| Amazon SES | $0.10–0.16 |
| SendGrid (mid-tier overage) | $0.90 |
| Resend | ~$0.90 |
| Postmark | $1.20–1.80 |

Email is cheap per unit. **Availability and reputation fail before the bill does** — an
unthrottled send loop exhausts connections and gets the sending domain blocked. Price it, but
say that.

## Payments — Stripe

| Item | Fee |
|---|---|
| US domestic online card | 2.9% + $0.30 |
| Manually entered / international / FX | +0.5% / +1.5% / +1% |
| **Dispute or chargeback received** | **$15.00** |
| ACH Direct Debit | 0.8%, $5.00 cap |

> **For idempotency and double-charge findings the blast-radius number is the $15 chargeback
> fee, not the 2.9%.** At low ticket sizes chargebacks dominate the loss.

Also price the **irreversibility**: a duplicate charge on a real customer is a refund, a
support cost, and a trust cost that no fee table captures. Say so.

## AI tokens — per 1M tokens, standard tier

**Anthropic**

| Model | Input | Cache read | Output |
|---|---|---|---|
| Claude Fable 5 | $10 | $1 | $50 |
| Claude Opus 5 | $5 | $0.50 | $25 |
| Claude Sonnet 5 | $2 | $0.20 | $10 |
| Claude Haiku 4.5 | $1 | $0.10 | $5 |

Batch API is a flat 50% off. Cache write multipliers: 5m 1.25×, 1h 2×; read 0.1×.

Three things the per-MTok table hides:

- **Claude 4.7 and later use a tokenizer producing ~30% more tokens for identical text.**
  Affects Fable 5, Opus 5, Sonnet 5. **Not** Haiku 4.5. Apply this **before** the rate, not
  after, or the estimate understates by roughly 30%.
- `inference_geo: "us"` adds **1.1×** on every token category (4.6 and later).
- Sonnet 5 carries **no long-context surcharge** at 1M context, unlike OpenAI.

**OpenAI** — the flagship family is **gpt-5.6**, not gpt-4o.

| Model | Input | Cached in | Output |
|---|---|---|---|
| gpt-5.6-sol | $5.00 | $0.50 | $30.00 |
| gpt-5.6-sol long-context | $10.00 | $1.00 | $45.00 |
| gpt-5.6-terra | $2.00 | $0.20 | $12.00 |
| gpt-5.6-luna | $0.20 | $0.02 | $1.20 |

Batch and Flex exactly 50% off; Fast mode exactly 2×. Regional endpoints +10% for models
released on or after 2026-03-05. Web search **$10.00 per 1,000 calls**.

**Expected guardrails:** `max_tokens`, a turn or iteration cap on any agent loop, prompt
caching actually taking effect, and a total-spend ceiling. **Caching that is configured but
silently inactive is a documented six-figure failure** — if a diff touches caching, check the
cache-read tokens are actually being reported, not just that the parameter is set.

## Cloud — AWS

| Item | Price |
|---|---|
| **S3 PUT / COPY / POST / LIST** | **$0.005 per 1,000** |
| S3 GET / SELECT / other | $0.0004 per 1,000 |
| S3 storage, first 50 TB | $0.023/GB-mo |
| Lambda requests | $0.20 per 1M |
| Lambda duration (x86) | $0.0000166667 per GB-s |

1M PUTs = **$5.00**; 1M GETs = $0.40.

> **A runaway `LIST` loop bills at the PUT rate, not the GET rate.** 10M LISTs = **$50**, not
> $4. Paginators that never terminate are the classic form.

**Egress:** first 100 GB/mo free, then $0.09/GB to 10 TB, $0.085 to 50 TB, $0.07 to 150 TB,
$0.05 above. **1 TB of accidental egress ≈ $83.**

## Classic bill-shock SKUs

- **Google Maps Platform** — Geocoding **$5.00/1k** (0–100k), Places Details $5.00, Dynamic
  Maps $7.00, Aerial View Pro $16.00. **Each SKU now has its own free allowance (10k
  Essentials / 5k Pro); the shared $200 credit is gone.** A 100k-request geocoding loop =
  **$450**.
- **Algolia** — Grow: 10k searches/mo, then **$0.50 per additional 1,000**. Grow Plus $1.75/1k.
- **Cloudflare Workers** — $5/mo, 10M requests included, **+$0.30 per additional million**;
  30M CPU-ms included, +$0.02 per million CPU-ms. A worker bound to the same queue as producer
  and consumer is a documented runaway shape.
- **Mixpanel and event analytics** — billed per event or per tracked user. Easy to miss because
  it looks like telemetry, not spend. An unauthenticated endpoint that fires a `Track` per call
  is a metered sink.
- **BigQuery and scanned-bytes engines** — `LIMIT` does **not** limit bytes scanned. Two
  separate documented incidents: $14,000 for 500 TB, and $10,000 in 22 seconds for 1,576 TB.

---

## House vendors — `.firebreak/catalog.md`

**Everything above is table stakes. The vendor that dominates your bill is probably not in
it.**

The rates here are public SaaS list prices. Industry-specific vendors — clinical record
retrieval, KYC and identity verification, credit bureau pulls, carrier and logistics rate
APIs, background checks, court and title search, market data feeds — are usually billed per
call under a negotiated contract, at unit costs one to three orders of magnitude above
anything on this page. A single call can be dollars, not fractions of a cent.

In one measured audit, the priciest unit cost in the service was a per-search medical-record
retrieval API. It is not in this catalog and could not be: the rate is contractual.

**So Firebreak reads a second catalog if the repository under review provides one.** Create
`.firebreak/catalog.md` at the repository root, in the same shape as this file. Entries there
take precedence over anything here.

```markdown
## House vendors

**AcmeRecords `POST /v2/search`** — $3.50 per search (contract rate, 2026-Q3, renegotiated
annually — confirm before quoting). Billed per *search*, not per result, so a retry after a
timeout bills twice. Expected guardrails: a per-patient dedup key, a daily cap per customer,
and a circuit breaker on the completion webhook.

**FooBureau `/credit/pull`** — $0.85 per pull. Hard-fails at the contract ceiling rather than
billing overage, so the runaway shape is an availability outage, not an invoice.
```

## Known incidents — the most credible number you have

Rates are estimates. **A prior incident in this repository is a measurement.**

If this codebase has already burned money on a shape, record it in `.firebreak/catalog.md`, and
a finding matching that shape leads with it rather than with a derived figure:

```markdown
## Known incidents

**2026-07-31 — SMS reminder runaway.** $1,600 over ~36 hours. A spend cap
(`send_count < 4`) whose only writer was an external callback; the callback started
failing, the counter froze, and every eligible client was re-sent on every poll.
Fixed by claiming the row at send time instead of on callback.
Shape: bound advanced by an independently-failing caller.
```

*"This shape cost $1,600 and ran for 36 hours before anyone noticed"* is worth more to a
reviewer than any per-unit arithmetic. It is not an estimate, nobody can argue the multiplier,
and it tells them what the failure actually looks like from the outside.

Record: the date, the amount, how long it ran before detection, the mechanism in one sentence,
and the shape. **Time-to-detection is the field people forget and the one that predicts the
next incident** — a leak nobody spotted for 36 hours will not be spotted faster next time
unless something changed.

Two rules for house entries, both learned the expensive way:

1. **Record the date and the source.** A contract rate quoted from memory a year later is a
   fabricated number wearing a suit.
2. **Write down what the unit actually is.** Per call or per result, per search or per record,
   per event or per tracked user, whether retries bill, and whether failures bill. That
   distinction is usually where the surprise lives — it is why Twilio's failed-message fee and
   S3's `LIST`-at-PUT-rate are called out above.

**An unpriced vendor is still a finding.** If a metered operation has no entry in either
catalog, report the mechanism and state that the figure is not derivable. Never guess a
contract rate.

---

## Platform guardrails that already exist

Flagging something the platform already stops is a false positive in practice. Check before
reporting a self-triggering cycle:

- **AWS Lambda recursive-loop detection** — on by default since Jul 2023, drops requests after
  ~16 chained invocations; extended to Lambda↔S3 Oct 2024.
- **Twilio error 14107** — loop filtering on inbound-to-outbound message cycles.

These bound *cycles*. They do not bound a scheduler re-triggering the same work, which is the
more common shape.
