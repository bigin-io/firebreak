# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
