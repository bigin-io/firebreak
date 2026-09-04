---
name: firebreak-setup
description: One-time setup for Firebreak in a repository. Inventories which metered third-party vendors the codebase actually bills against, separates the ones the shipped catalog already prices from the ones needing a negotiated contract rate, and writes a pre-filled .firebreak/catalog.md with the rates left blank for a human. Use when setting up Firebreak in a new repository, when asked to "set up firebreak", "add a firebreak catalog", "what does this repo spend money on", or after Firebreak reports a finding it could not price.
---

# Firebreak setup

Firebreak's shipped `catalog.md` carries public SaaS list prices. The vendor that dominates a
given bill is usually not one of them — it is an industry-specific API billed per call under a
negotiated contract, often one to three orders of magnitude more expensive.

This finds what *this* repository actually spends money on, and writes a catalog stub for it.

**It writes exactly one file: `.firebreak/catalog.md`. It never touches source code.**

## Why this sweeps the repository when review never does

Firebreak's review skill is forbidden from auditing a whole repository, for a measured reason.
This is a different task and the rule does not transfer.

Review looks for **defects**, where a broad sweep produces confident false all-clears — the
measured failure. Setup builds an **inventory**, where breadth is the point and the failure
mode is mild and self-correcting: a vendor missed here shows up the first time Firebreak
reports a finding it cannot price, and gets added then.

Different task, different failure cost. Do not read this as licence to sweep during a review.

## 1. Find the vendors

Look in this order — the earlier sources are denser and cheaper to read.

| Source | What to look for |
|---|---|
| `.env.example`, `.env.sample`, config templates | The highest-signal file in most repos. `TWILIO_ACCOUNT_SID`, `STRIPE_SECRET_KEY`, `OPENAI_API_KEY`, `SENDGRID_*`, `AWS_*`, and — more importantly — the unfamiliar ones |
| Dependency manifests | `go.mod`, `package.json`, `requirements.txt`, `Gemfile`, `composer.json`, `*.csproj`. Vendor SDKs name themselves |
| Deployment and secret config | `serverless.yml`, Terraform, Helm values, GitHub Actions secrets, `wrangler.toml` |
| Outbound base URLs in source | `https://api.<vendor>.com` in HTTP clients — catches vendors used without an SDK, which is common for the expensive contractual ones |
| Existing docs | `README`, `docs/`, architecture notes often name integrations no manifest mentions |

**Pay most attention to what you do not recognise.** A familiar SDK is probably already priced.
An unfamiliar vendor with an API key in `.env.example` is exactly the entry this file exists
for, and is disproportionately likely to be the expensive one.

Also flag **spend initiated outside this codebase** — a workflow tool, a scheduler, a queue
consumer, a Lambda in another repository. If this repo sets the eligibility or hands out the
work list, it drives that spend even though it never makes the call. Record it, and say where
the sending actually happens.

## 2. Classify

Three buckets:

- **Already priced** — in the shipped `catalog.md`. Do not duplicate it. Note it and move on.
- **Needs a house rate** — metered, not in the shipped catalog. These are the point of the
  exercise.
- **Not metered** — flat-fee SaaS, self-hosted, free tier with a hard ceiling rather than
  overage billing. Record briefly with the reason, so nobody re-investigates it next quarter.

When you cannot tell whether something bills per call, **say so rather than guessing**. "Unclear
— confirm against the contract" is a useful catalog entry. An invented rate is not.

## 3. Write the file

Create `.firebreak/catalog.md` in the same shape as the shipped catalog, with rates blank:

```markdown
# House vendors — <repo name>

Rates here take precedence over Firebreak's shipped catalog.

## Needs a rate

**AcmeRecords** — `POST /v2/search`, called from `internal/search/client.go:88`.
Rate: **UNKNOWN — needs the contract.**
Unit: unclear whether billed per search or per result returned — confirm.
Retries: unclear whether a retry after timeout bills again — confirm.
Source: _(who confirmed, and when)_

## Already priced by the shipped catalog

- Twilio SMS — `apps/api/internal/notify/`
- Stripe — `apps/api/internal/billing/`

## Not metered

- Sentry — flat plan, no per-event overage on the current tier (checked 2026-09-04)
```

For each entry that needs a rate, record **where it is called from**, so whoever fills in the
number can see what it costs per call site.

## 4. Hand it back

Do not stop at writing the file. Tell the user, plainly:

1. **Which entries need a number**, and roughly who would know — contract owner, finance,
   whoever signed the vendor.
2. **Which unit questions need answering** — per call or per result, do retries bill, do
   failures bill. This is where the surprises live: Twilio bills failed messages, and S3 bills
   `LIST` at the PUT rate rather than the GET rate.
3. **That Firebreak works now regardless.** An unpriced vendor is still reported; it carries no
   dollar figure rather than a guessed one. Filling in rates upgrades findings from a mechanism
   to a number — it does not unblock anything.

Then stop. Do not offer to guess a rate, and do not estimate one from public pricing pages for a
vendor whose pricing is contractual.
