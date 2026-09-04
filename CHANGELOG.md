# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-09-04

### Changed

- **Exposure must always carry a worst case. "Not derivable from static analysis" can no longer
  be the exposure line** — it is a precision note and belongs in a parenthetical. A reader given
  a disclaimer instead of a number learns nothing about whether to panic, which was the actual
  complaint behind "the report doesn't make the risk clear."

  Build order is now: a recorded prior incident of the shape, else recorded scale facts (worst
  case computed), else a **named assumption** stated in the same sentence as the figure.

- **A stated assumption is not an invented multiplier.** The prior rule against inventing one
  was making reviews dodge the number entirely. The real line: never present an assumed figure
  *as measured*. Naming it is what makes it honest and lets the reader correct it at a glance.

- **The out-of-scope rule is scoped to files, not defects.** v1.4.0 said "nothing outside the
  change set," and a review consequently dropped an unused-import build break that was *inside*
  the diff. Files outside the diff stay out; a real defect inside it earns one line even at the
  cost of a few words.

### Added

- **`## Scale` in `.firebreak/catalog.md`** — population sizes, scheduler intervals, batch
  sizes. The multiplier is almost never in the code: it lives in the database and in
  infrastructure config. Recording it once turns every worst case from assumed into computed.
  `firebreak-setup` now asks for these, and for any prior incident, while it is already asking
  about vendors and triggers.

- **A gate before writing a finding heading.** v1.4.0's template has labelled slots, and a form
  with blanks invites filling them — a review promoted a deliberate, bounded design decision to
  a finding with a Fix. Two gates now mean say clean and stop: exposure is bounded and the bound
  is deliberate; or you are about to write "this may not be a finding at all," which means it
  isn't one.

## [1.4.0] - 2026-09-04

### Changed

- **Reports are now budgeted: under 200 words per finding, under 400 per review.** Measured
  output was running 700–1,400 words for one or two findings. A reader decides in the first
  fifteen seconds whether to keep reading, and the detail is available on request anyway. Six
  compression rules, the load-bearing one being: cut any sentence that would not change what
  the reader does next.

- **Exposure replaces "money", and it is a ceiling rather than a rate.** A unit rate reads as
  trivial and buries the risk — "$4.45 per client per year" is accurate and tells the reader
  nothing about whether to panic. Findings now lead with the worst case and name what bounds
  it, saying **unbounded** plainly when nothing in code stops it. The unit rate is supporting
  detail, given once.

- **"Time to notice" is a required field.** A slow leak under the alarm threshold is worse than
  a fast spike, because the spike gets caught. When the answer is "an invoice, next month" — or
  "the existing alert cannot see this shape" — that now belongs in the first three lines rather
  than a closing caveat.

### Added

- **Known incidents in `.firebreak/catalog.md`.** Rates are estimates; a prior incident in the
  repository is a measurement. A finding matching a recorded shape leads with it: "this shape
  cost $1,600 and ran 36 hours before anyone noticed" beats any derived figure, because nobody
  can argue the multiplier. Time-to-detection is called out as the field people forget and the
  one that predicts the next incident.

## [1.3.0] - 2026-09-04

### Added

- **`firebreak-setup` now configures how Firebreak is triggered**, and asks rather than
  choosing: on demand, a commit-time reminder via a `PreToolUse` hook, a blocking pre-commit
  hook, or a CI gate. It writes the config for whichever is picked — merging into an existing
  `.claude/settings.json` hooks block rather than overwriting it — and ships a
  `.github/workflows/firebreak.yml` template.

  The CI template sets `fetch-depth: 0`, which is not optional and is the single most common
  way this breaks: a shallow clone has no merge base, `scope.sh` exits 2, and the job passes
  green having reviewed nothing.

- **An honest warning against the most obvious choice.** A review takes minutes, because
  reading surrounding code and tracing writers is the work. A hook that blocks every commit for
  several minutes gets bypassed within a day and removed within a week, leaving the repository
  with no coverage while everyone believes it has some. Setup states this before wiring one up,
  and wires it up anyway if the user still wants it — defaulting to advisory and non-blocking.

### Changed

- Setup's "writes exactly one file" promise corrected to name the full set it may write —
  `.firebreak/catalog.md` plus the chosen trigger config. It still never touches source.

## [1.2.0] - 2026-09-04

### Added

- **`firebreak-setup` skill.** One-off per repository. Inventories which metered vendors the
  codebase actually bills against — reading `.env.example` and config templates first, since
  they are the densest signal — classifies them into already-priced, needs-a-contract-rate, and
  not-metered, and writes a pre-filled `.firebreak/catalog.md` with rates left blank and call
  sites recorded. It writes that one file and never touches source.

  It also flags spend *initiated outside the codebase*: if a repository sets eligibility or
  hands out a work list that another system sends from, it drives that spend without ever
  making the call.

  This sweeps the repository, which the review skill is forbidden from doing. The rule does not
  transfer: review looks for defects, where breadth produces confident false all-clears; setup
  builds an inventory, where breadth is the point and a missed vendor self-corrects the first
  time Firebreak reports a finding it cannot price.

## [1.1.0] - 2026-09-04

### Added

- **Project-local catalog: `.firebreak/catalog.md`.** A repository can now carry its own vendor
  rates, and Firebreak reads them alongside the shipped catalog. House entries take precedence.
  The shipped catalog is public SaaS list pricing; the vendor that dominates a real bill is
  usually an industry-specific API billed per call under a negotiated contract, at a unit cost
  one to three orders of magnitude higher. Those rates belong with the code they describe, not
  in a public file.

### Fixed

- **A vendor missing from the catalog no longer reads as permission to skip the finding.** Step
  4 said "look the operation up in `catalog.md`" and did not say what to do when it was not
  there. The catalogs price findings; they do not define what counts as one. An operation that
  bills per call, per unit, per event or per byte scanned is in scope whether or not anyone has
  written its rate down — report the mechanism and state that the money is not derivable. This
  inverted the tool's behaviour on precisely the vendors that matter most, since those are the
  ones most likely to be missing.

## [1.0.0] - 2026-09-04

First release. Packaged as a Claude Code plugin.

### Added

- **`firebreak` skill** — reads a change set and reports whether it can burn money or cause
  irreversible real-world harm at scale, in money rather than severity words. Three surfaces
  over two units of work: developer pre-commit (working tree), branch or PR review, and a
  headless CI gate (both diff vs merge base).
- **`method.md`** — the review method. Turns *"can the bound fail?"* into a mechanical trace:
  find the bound's state, find every writer of it, ask whether spend can happen while a writer
  does not. Names four anti-patterns, each of which produced a measured false all-clear on a
  real live bug.
- **`catalog.md`** — money-sink catalog with observed provider unit costs and their traps.
  Twilio's all-in US rate is $0.0125/segment, not the $0.0083 base, and a 300-character
  reminder is 2–3 segments. S3 `LIST` bills at the PUT rate. Claude 4.7+ uses a tokenizer
  producing ~30% more tokens, applied *before* the rate. Mixpanel is a metered sink.
- **`ci.md`** — CI contract. Three exit codes, findings fingerprinted on
  `mechanism + path + enclosing symbol` rather than line numbers, gating only on fingerprints
  absent from a committed baseline, and `block_at` defaulting to `none`.
- **`scope.sh`** — resolves the change set. Never scans a whole repository.

### Design decisions worth knowing before you use it

- **Reviews a change set; never audits a repository.** This is measured, not aesthetic. A blind
  reader asked to audit a whole service found the affected file, saw the send function was a
  no-op stub, concluded "spend is not driven from this codebase," and cleared it. A reader
  asked about a specific change touching the same routes made the identical observation and
  traced it to the exact defect. Accuracy scaled inversely with the breadth of the question.
- **Reports; never edits.** Findings carry uncertainty, and a confident edit on a misread
  mechanism looks resolved. The value is the author understanding why — a patch teaches
  nothing, and the same shape reappears in the next service.
- **Start advisory.** `block_at: none` is the default. Precision is unmeasured per repository;
  run for at least one sprint before letting it gate anything, and re-check reproducibility on
  a *marginal* finding before moving off `none`.
