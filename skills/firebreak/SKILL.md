---
name: firebreak
description: Reviews a change set for runaway cost and irreversible real-world harm — a metered operation reachable with no working upper bound — and reports in money rather than severity words. Three surfaces, two units of work: the working tree before a commit, a branch or PR under review, and a headless CI gate. Use when about to commit, when reviewing a branch, when asked "can this change run away", "check this for cost risk", "will this burn money", "review this PR for spend risk", or whenever a change touches payments, SMS, email, LLM/AI, cloud storage, geocoding, search, or the code that feeds them.
---

# Firebreak

Read a **change set** and answer one question: **could this change burn money or cause
irreversible real-world harm at scale before anyone notices?**

## The one rule that decides whether this works

**Firebreak reviews a change set. It never audits a repository.**

This is not a performance optimisation — it is the difference between finding the bug and
missing it. It was measured on a real incident:
asked to audit a whole service, a reader found the affected file, observed that the send
function was a no-op stub, concluded "spend is not driven from this codebase," and filed it
under *properly bounded, no action*. Asked about a specific change touching the same routes,
a reader made the identical observation and traced it to the exact defect.

Same model. Same repository. Same facts. Opposite conclusion.

So: **anchor every finding to a changed line. Read unlimited surrounding code to judge it.**
Broad sweeps produce confident all-clears on live bugs.

## The other rule: report, never edit

**Firebreak is read-only. It does not change code, ever — not even an obvious one-line fix,
not even when asked nicely mid-review.**

Describe the fix in the report and stop there. Three reasons, and the third is the one that
matters:

1. Findings carry uncertainty. A confident edit built on a misread mechanism is worse than the
   bug, because it looks resolved.
2. The person who owns the code owns the fix. A reviewer that edits is no longer a reviewer.
3. **The value is the author understanding why.** An applied patch teaches nothing; the same
   shape reappears in the next service. A traced mechanism is the deliverable.

If the user explicitly asks for the fix to be applied *after* reading the report, that is a
separate task they have chosen — not part of this one. Finish the review first.

## Modes

Resolve the change set first. `scope.sh` does this; run it before anything else.

| Mode | Invocation | Change set |
|---|---|---|
| **Pre-commit** (developer) | `firebreak` with no argument | Staged + unstaged working tree |
| **Review** (branch or PR) | `firebreak <ref>` — a branch, PR number, or commit range | Diff vs the merge base with the default branch |
| **CI gate** | Non-interactive, `--ci` | Same as Review, plus an exit-code contract and a baseline |

```bash
./scope.sh              # working tree
./scope.sh feature/x    # branch vs merge-base
./scope.sh --ci         # branch vs merge-base, machine-readable
```

CI has its own contract — exit codes, baselines, and how to avoid a flaky gate. Read
`ci.md` before running that mode. Do not invent an exit-code convention.

## Procedure

1. **Scope.** Run `scope.sh`. If the change set is empty, say so and stop.
2. **Triage.** Discard changed files with no path to a metered operation. Most changes are
   nothing; saying so quickly is correct behaviour, not laziness.
3. **For each surviving change, ask three questions in order** — this is the whole method,
   and `method.md` explains how to answer each one without the failure modes:
   - **What does this change make reachable?** Not just what it calls — what it *enables*.
   - **What is supposed to bound it?** Name the specific construct. "There's a cap" is not
     an answer; `send_count < 3`, checked in the eligibility query, is.
   - **Can that bound fail independently of the spend?** This is the question that catches
     the expensive bugs. Trace *what writes the bound's state*.
4. **Price it.** Look the operation up in `catalog.md`, and in `.firebreak/catalog.md` in the
   repository under review if that file exists — house vendors live there. Give a range with
   the arithmetic shown, or say the figure is not derivable — never invent one.

   **A vendor missing from both catalogs is not a reason to drop the finding.** The catalogs
   price findings; they do not define what counts as one. An operation you can see is metered
   — it bills per call, per unit, per event, or per byte scanned — is in scope whether or not
   anyone has written its rate down. Report the mechanism and say the money is not derivable.
   Silently skipping an unpriced vendor is the failure mode that matters here, because the
   vendors most likely to be missing are the industry-specific ones that dominate a real bill.
5. **Report.** Format below.

**Read `method.md` before step 3 on any change that survives triage.** It carries the
anti-patterns that produced measured false all-clears, and the technique for question 3.

## Output

**Verdict first, one line.** Then findings ranked by exposure, worst first.

**Budget: under 200 words per finding, under 400 for a typical review.** A reader decides in
the first fifteen seconds whether to keep reading, and length spends that. Everything you cut
is available on request anyway.

```
### <one-line claim> — `path/from/repo/root.go:123`

<Mechanism. 2–4 sentences: what triggers the spend, what bounds it, why the bound fails.>

**Exposure:** <ceiling, not unit rate — see below>
**Time to notice:** <what catches this, and how long it takes>
**Fix:** <one line>
**Unknown:** <only what would change the verdict>
```

Paths are **repo-relative from the repository root**, not from a module root, anchored to a
**changed** line. A path the reader cannot paste into an editor is a path they will not check.

### Exposure: always a worst case, never "not derivable"

**A finding must show the largest defensible dollar figure.** "Not derivable from static
analysis" is a precision note, not an answer — it can appear in a parenthetical, never as the
exposure line. A reader who gets a disclaimer instead of a number learns nothing about whether
to panic, and a unit rate does the same: *"$4.45 per client per year"* is accurate and reads as
trivial.

Build it in this order:

1. **A prior incident of this shape**, if `.firebreak/catalog.md` records one. *"This shape cost
   $1,600 and ran 36 hours"* beats anything you can derive — it already happened here and nobody
   can argue the multiplier.
2. **Scale facts**, if recorded (`## Scale` in `.firebreak/catalog.md`) — population sizes,
   scheduler intervals, batch sizes. Then the worst case is **computed**, and say so.
3. **A named assumption**, when neither exists. Pick a plausible figure, state it in the same
   sentence, and point at where to make it exact.

Say **unbounded** whenever nothing in code stops it — that word is the single most important
fact in the finding — and then still give the number.

**A stated assumption is not an invented multiplier.** The rule against inventing one means:
never present an assumed figure *as measured*. Naming it is what makes it honest and lets the
reader correct it at a glance. Dodging the number entirely is the worse failure.

```
✅ Worst case: ~$250 every time it runs at 10,000 active users — $2,500 at 100,000 —
   and nothing stops it running twice. (Population assumed; record your real count in
   .firebreak/catalog.md and this becomes exact.)

❌ Unbounded. Active-user count is not derivable from static analysis.
❌ $4.45 per client per year.
```

Give the unit rate once, as supporting detail. When a bound does hold, say **bounded at $X**
and name the bound.

### Time to notice decides severity

A slow leak under the alarm threshold is worse than a fast spike, because the spike gets
caught. Say what would detect this and how long that takes.

If the answer is *"an invoice, next month"* — or worse, *"the existing alert cannot see this
shape"* — that belongs in the first three lines of the finding, not in a closing caveat.

### Compression rules

- **Triage in one line:** `N files, M triaged out (reason)`. Never a paragraph per file.
- **Conclusions, not derivations.** "3 segments, not 1" — not the septet arithmetic.
- **One scenario, not three.**
- **Say it once.** Confidence caveats live in **Unknown**. There is no closing confidence
  section.
- **Nothing about files outside the change set** — not even to say they were checked and are
  fine. But a real defect *inside* the diff that is not a cost risk still earns one line under
  **Noticed, out of scope** — a branch that does not compile is worth saying even at the cost of
  a few words.
- **Cut any sentence that would not change what the reader does next.**

Close with: *Ask for the full trace, the arithmetic, or the alternatives considered.*

### Before you write a finding heading

The template above has slots, and a form with blanks invites filling them. Two gates, both of
which mean **say clean and stop**:

- **Exposure is bounded and the bound is deliberate.** A design you would not change is not a
  finding. Mention it in the clean verdict if it is genuinely interesting; do not give it a
  heading and a Fix.
- **You are about to write "this may not be a finding at all."** If that sentence is true, it
  isn't one. Ask the question in the verdict line, or say nothing.

**Reporting nothing is a valid, useful result.** Most changes carry no cost risk. A review that
manufactures a concern to look thorough is worse than useless: it trains people to skip the next
one. Never inflate a marginal finding to fill a report.

## Scope

**In:** metered third-party operations — payments, SMS and voice, email, LLM and AI, cloud
storage and egress, geocoding, search, and analytics billed per event. Also irreversible
real-world effects at scale, whether or not they cost money: messages to real people, record
deletion, external state changes.

**Out:** general code quality, security findings with no spend consequence, performance work,
and cloud infrastructure sizing. If something serious turns up outside scope, mention it in
one line at the end under **Noticed, out of scope** — do not rank it with the findings.
