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
4. **Price it.** Look the operation up in `catalog.md`. Give a range with the arithmetic
   shown, or say the figure is not derivable — never invent one.
5. **Report.** Format below.

**Read `method.md` before step 3 on any change that survives triage.** It carries the
anti-patterns that produced measured false all-clears, and the technique for question 3.

## Output

Findings ranked by money at risk, worst first. For each:

- `file:line` — **repo-relative path from the repository root**, not from a module or package
  root, anchored to a **changed** line. A path the reader cannot paste into an editor is a
  path they will not check.
- **Mechanism** — what triggers the operation, what bounds it, why the bound can fail. In
  prose, specific to this code. Not a rule name.
- **Money** — a range with arithmetic, or an explicit "not derivable from static analysis,
  because…"
- **Fix** — concrete and minimal.
- **Confidence** — and what you would need to check to raise it.

Then a one-line verdict.

**Reporting nothing is a valid, useful result.** Most changes carry no cost risk. A review
that manufactures a concern to look thorough is worse than useless: it trains people to skip
the next one. Never inflate a marginal finding to fill a report.

## Scope

**In:** metered third-party operations — payments, SMS and voice, email, LLM and AI, cloud
storage and egress, geocoding, search, and analytics billed per event. Also irreversible
real-world effects at scale, whether or not they cost money: messages to real people, record
deletion, external state changes.

**Out:** general code quality, security findings with no spend consequence, performance work,
and cloud infrastructure sizing. If something serious turns up outside scope, mention it in
one line at the end under **Noticed, out of scope** — do not rank it with the findings.
