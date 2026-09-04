# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
