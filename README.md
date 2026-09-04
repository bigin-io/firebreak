# Firebreak

A Claude Code skill that reads a **change set** and answers one question: could this change
burn money or cause irreversible real-world harm at scale before anyone notices?

It reports in money rather than in severity words. **It reports; it never edits.**

## Install

```
/plugin marketplace add bigin-io/firebreak
/plugin install firebreak@firebreak
```

Or copy the skill directly:

```bash
git clone https://github.com/bigin-io/firebreak
cp -r firebreak/skills/firebreak ~/.claude/skills/firebreak
```

## Set up a repository (optional, one-off)

```
firebreak-setup
```

Two things. It inventories which metered vendors this repository actually bills against and
writes a pre-filled `.firebreak/catalog.md` with rates left blank for a human. Then it asks how
Firebreak should be triggered and wires up the choice:

| Option | Cost |
|---|---|
| **On demand** | Nothing — runs when someone types `firebreak` |
| **Commit-time reminder** | Nothing at commit time; it prompts, it does not review |
| **Blocking pre-commit hook** | **Minutes per commit** — see below |
| **CI gate** | A job per PR |

**On demand plus CI is the right default for most teams.** A review takes minutes, because
reading surrounding code and tracing writers is the work that makes it any good. A hook that
blocks every commit for several minutes gets `--no-verify`'d within a day and uninstalled
within a week — and then the repository has no coverage while everyone believes it has some.
Setup will say so before wiring one up, and will still wire it up if you want it.

It writes only configuration — the catalog and whichever trigger you choose — and never touches
source. Skip the whole thing if you like; Firebreak works without it, and unpriced vendors are
still reported, just without a dollar figure.

## Use

In a Claude Code session in the repository you want reviewed:

| You want | Say |
|---|---|
| Check what you're about to commit | `firebreak` |
| Review a branch or PR | `firebreak <branch>` |
| Gate CI | Non-interactive with `--ci` — read [`ci.md`](skills/firebreak/ci.md) first |

## What it looks for

A metered operation reachable along a path with **no working upper bound** — and the emphasis
is on *working*, because the expensive bugs are rarely a missing cap. They are a cap that is
correct, tested, and unreachable.

- A paid call whose loop bound moved
- A guardrail this diff removed
- An idempotency key that isn't set on every path
- A retry that returns non-2xx to a provider, so *they* retry the paid operation for days
- A spend bound whose state is advanced only by a call that can fail independently

It prices findings from a catalog of observed provider rates — Twilio, Stripe, Anthropic,
OpenAI, SES/SendGrid, S3, Google Maps, Algolia, Cloudflare Workers, Mixpanel, BigQuery — and
refuses to invent a multiplier. If executions aren't derivable from the code, it says so and
prices one call.

**The vendor that dominates your bill is probably not in that list.** Industry-specific APIs —
record retrieval, KYC, credit pulls, market data — are billed per call under a negotiated
contract, often orders of magnitude above any public SaaS rate. Put those in
`.firebreak/catalog.md` at your repository root and Firebreak reads them too. A vendor missing
from both catalogs is still reported; it just carries no dollar figure rather than a guessed
one.

## The two rules

**1. It reviews a change set. It never audits a repository.**

This is measured, not aesthetic. Asked to audit a whole service, a blind reader found the
affected file, observed that the send function was a no-op stub, concluded *"spend is not
driven from this codebase,"* and filed it under *properly bounded, no action*. Asked about a
specific change touching the same routes, a reader made the identical observation and traced
it to the exact defect.

Same model, same repository, same facts, opposite conclusion. **Accuracy scaled inversely with
the breadth of the question.** Anything that widens Firebreak back into a repository sweep is a
regression, whatever it is called.

**2. It reports; it never edits.**

Findings carry uncertainty, and a confident edit built on a misread mechanism is worse than the
bug because it looks resolved. The person who owns the code owns the fix. And the value is the
author understanding *why* — a patch teaches nothing, and the same shape reappears in the next
service.

## How it reviews

Three questions, in order, from [`method.md`](skills/firebreak/method.md):

1. **What does this change make reachable?** Not what it calls — what it *enables*. A diff can
   contain no metered call, no loop and no removed guardrail and still be the direct cause of a
   runaway.
2. **What is supposed to bound it?** Named, with a line number. *"There's a rate limit
   somewhere"* is not an answer.
3. **Can that bound fail independently of the spend?** Mechanically: find the bound's state,
   find **every writer** of it, then ask whether the spend can happen while a writer does not.

`method.md` also names four anti-patterns, each of which produced a measured false all-clear on
a real bug. The first is the costliest: *"the sink isn't in this codebase, so there's no risk."*
A service can drive spend it never calls — it returns the work list, sets the eligibility, holds
the counter, or feeds the queue that another system sends from.

## CI

Three exit codes: `0` clean, `1` new blocking finding, `2` tool error — which **passes the
build, loudly**. Failing on a tool error gets the gate removed within days; passing silently
lets it rot into a green check that checks nothing.

Findings are fingerprinted on `mechanism + path + enclosing symbol`, never line numbers, so
they survive reformatting and neighbouring edits. Only fingerprints absent from a committed
baseline can fail a build.

**`block_at` defaults to `none`.** Run advisory for at least one sprint before letting it gate
anything. A repository adopting this has pre-existing findings; blocking on all of them means
the first unrelated PR fails and the gate is gone by Friday.

## Honest limits

- **Precision is unmeasured on your repository.** Validation was a small number of runs against
  one known defect in one codebase. Hence the advisory default.
- **Reproducibility is good, not proven.** Three runs of the same branch produced the same
  finding, anchor and price. Stability on a *marginal* finding — one near the reporting
  threshold — is untested. Re-check before moving `block_at` off `none`.
- **Unit costs go stale.** [`catalog.md`](skills/firebreak/catalog.md) records rates observed on
  a date, with the caveats. Treat it as needing a scheduled refresh, not as ground truth.
- **It sends source to an LLM.** It runs inside Claude Code, so this is the data flow you
  already have — but confirm that's acceptable for the repository before pointing it at client
  code.

## License

MIT
