---
name: firebreak-setup
description: One-time setup for Firebreak in a repository. Inventories which metered third-party vendors the codebase actually bills against and writes a pre-filled .firebreak/catalog.md with rates left blank for a human, then asks how Firebreak should be triggered — on demand, from a commit hook, or as a CI gate — and wires up the choice. Use when setting up Firebreak in a new repository, when asked to "set up firebreak", "add a firebreak catalog", "run firebreak on every commit", "add firebreak to CI", "what does this repo spend money on", or after Firebreak reports a finding it could not price.
---

# Firebreak setup

Firebreak's shipped `catalog.md` carries public SaaS list prices. The vendor that dominates a
given bill is usually not one of them — it is an industry-specific API billed per call under a
negotiated contract, often one to three orders of magnitude more expensive.

This finds what *this* repository actually spends money on, and writes a catalog stub for it.

**It writes only configuration, and only what it names below: `.firebreak/catalog.md`, plus
whichever trigger the user picks in step 4. It never touches source code.**

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

## 3b. Ask for scale facts

While you have their attention. **This is the difference between a finding that says "unbounded,
population unknown" and one that says "$2,500 per accidental run."**

Ask for whatever they know, and write it under `## Scale` in `.firebreak/catalog.md`:

- Roughly how many active users / customers / patients?
- Largest batch or segment a job processes in one run?
- How often does each scheduled job fire?
- Any population that grows unboundedly — a queue, a backlog, a retry table?

**Coarse and dated beats precise and stale.** An order of magnitude is enough; nobody maintains
a number they have to update weekly. If they do not know, write the question down as an open
item rather than guessing — a recorded unknown is useful, an invented figure is not.

Also ask whether the codebase has **already had a cost incident**. If so, record it under
`## Known incidents` with the amount, how long it ran before anyone noticed, and the mechanism
in one sentence. A bill already paid is the most credible number a review can cite, and
time-to-detection is the field people forget.

## 4. Ask how it should be triggered

**Ask. Do not pick for them.** The right answer depends on team size, review culture, and how
much latency people will tolerate before they route around it.

Present these four, with the trade-offs stated honestly — including the one that argues against
the most obvious choice:

| Option | What it costs | Wire-up |
|---|---|---|
| **On demand** *(recommended starting point)* | Nothing. Runs when someone types `firebreak` | No config |
| **Commit-time reminder** | Nothing at commit time — it prompts, it does not review | A `PreToolUse` hook in `.claude/settings.json` matching `git commit` |
| **Blocking pre-commit hook** | **Minutes per commit.** See the warning below | `.husky/pre-commit` or `.git/hooks/pre-commit` running `claude -p` |
| **CI gate** *(the real enforcement point)* | A job per PR | `.github/workflows/firebreak.yml` |

### The warning to give before they choose the pre-commit hook

**A review takes minutes, not seconds.** It reads surrounding code, traces writers, and prices
findings — that is the work, and it is why the review is any good. A hook that blocks every
commit for several minutes gets `--no-verify`'d within a day and uninstalled within a week, and
then the repository has *no* coverage while everyone believes it has some.

Say this plainly if they ask for it. If they still want it, wire it up — it is their call — but
default it to advisory and non-blocking, and suggest scoping it to commits that touch paths with
known sinks rather than every commit.

**Most teams should take on demand plus CI.** On demand puts it where a developer wants a second
opinion; CI puts it where the whole team sees the result and nobody has to remember.

### Wiring each one

**Commit-time reminder** — add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "grep -q 'git commit' <<< \"$CLAUDE_TOOL_INPUT\" && echo 'Consider running firebreak on these changes first.' || true"
      }]
    }]
  }
}
```

Merge into an existing `hooks` block rather than overwriting it. Read the file first.

**CI gate** — `.github/workflows/firebreak.yml`:

```yaml
name: firebreak
on: pull_request

jobs:
  cost-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # REQUIRED — scope.sh needs the merge base
      - name: Firebreak cost review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # Invoke Claude Code non-interactively against the PR branch.
          # Check the current claude-code CI action or CLI flags before relying on this.
          claude -p "Run the firebreak skill in review mode on this PR, with --ci" \
            --allowed-tools "Read,Grep,Glob,Bash"
```

`fetch-depth: 0` is not optional and is the single most common way this breaks — a shallow
clone has no merge base, `scope.sh` exits 2, and the job passes green having reviewed nothing.

Confirm the exact invocation against current Claude Code CI documentation rather than trusting
this template verbatim; the surrounding structure is the durable part.

Then set the gate to advisory. In `.firebreak.yml`:

```yaml
block_at: none
baseline: .firebreak-baseline.json
```

**Run advisory for at least one sprint before moving `block_at` off `none`.** Precision is
unmeasured on this repository, and a gate that blocks a release on a finding the team disagrees
with is a gate that gets deleted.

## 5. Hand it back

Do not stop at writing files. Tell the user, plainly:

1. **Which catalog entries need a number**, and roughly who would know — contract owner,
   finance, whoever signed the vendor.
2. **Which unit questions need answering** — per call or per result, do retries bill, do
   failures bill. This is where the surprises live: Twilio bills failed messages, and S3 bills
   `LIST` at the PUT rate rather than the GET rate.
3. **What you wired up**, and how to undo it. A trigger someone cannot find to remove is a
   trigger they will work around instead.
4. **That Firebreak works now regardless.** An unpriced vendor is still reported; it carries no
   dollar figure rather than a guessed one. Filling in rates upgrades findings from a mechanism
   to a number — it does not unblock anything.

Then stop. Do not offer to guess a rate, and do not estimate one from public pricing pages for a
vendor whose pricing is contractual.
