# CI gate

The review unit is identical to branch mode — the diff against the merge base. What changes is
that nothing is interactive, the result has to be stable enough to gate on, and a bad gate gets
switched off within a fortnight.

## Exit codes

Exactly three. Do not add a fourth, and do not overload them.

| Code | Meaning | CI behaviour |
|---|---|---|
| **0** | No findings at or above the blocking threshold | Pass |
| **1** | One or more **new** findings at or above the threshold | **Fail** |
| **2** | Firebreak could not complete — bad ref, empty diff, tool error | **Pass, and surface loudly** |

**Code 2 must never fail the build, and must never be silent.** Failing the build on a tool
error gets Firebreak removed within days. Passing quietly lets it rot into a green check that
checks nothing. Print the reason at the top of the job log and, if the CI supports it, mark
the step as a warning.

## Non-determinism is the real problem

Two runs over the same diff will not produce identical prose, and may not produce an identical
finding set. A gate that fails a PR on Tuesday and passes it on Wednesday will be disabled, and
correctly so.

Three mitigations, all required:

### 1. Fingerprint every finding — never by line number

```
fingerprint = sha256(
    mechanism_class          # e.g. "bound-advanced-by-independent-caller"
  + repo_relative_path
  + normalised_enclosing_symbol   # function or method name, not line
)
```

Line numbers shift on every unrelated edit. Fingerprinting on the symbol makes a finding
survive reformatting and neighbouring changes, so run-over-run comparison means something.
Report the line for humans; key on the fingerprint for machines.

### 2. Gate on new findings only

Keep `.firebreak-baseline.json` in the repository — the fingerprints of findings already
accepted or waived. **Only fingerprints absent from the baseline can produce exit 1.**

A repository adopting Firebreak has pre-existing findings. Blocking on all of them on day one
means the first PR after adoption fails for reasons unrelated to itself, and the gate is gone
by the end of the week. Baseline on adoption; shrink it deliberately.

Adding to the baseline is a normal reviewed change — the diff shows exactly what was accepted
and by whom.

### 3. Threshold, and start it high

Configurable in `.firebreak.yml`; default **blocks nothing**.

```yaml
block_at: none        # none | critical | high    (default: none)
baseline: .firebreak-baseline.json
```

**Run advisory for at least one full sprint before blocking anything.** Precision is unproven
per repository, and the cost of finding that out by blocking a release is the whole tool. Move
to `critical` only once the team has seen the output and agrees with it.

## Output

Write both. Humans read the first; the gate consumes the second.

- **Markdown** to the job log — the same format as interactive mode.
- **JSON** to `firebreak-report.json`:

```json
{
  "schema": 1,
  "ref": "feature/x",
  "merge_base": "a1b2c3d",
  "findings": [{
    "fingerprint": "…",
    "severity": "critical",
    "file": "internal/x/y.go",
    "line": 42,
    "symbol": "ReminderService.claimAndSend",
    "mechanism": "…",
    "money": {"low": 625.0, "high": 1200.0, "currency": "USD", "derivable": true},
    "fix": "…",
    "confidence": "high",
    "new": true
  }],
  "counts": {"total": 3, "new": 1, "blocking": 1},
  "status": "fail"
}
```

When money is not derivable, set `"derivable": false` and omit `low`/`high` rather than
writing zero. Zero reads as free.

## Posting to the PR

Post one comment and **update it in place** on subsequent runs. Never append a new comment per
push — that is how review tools get muted.

Lead with new findings. Put baselined ones behind a collapsed section, or omit them.

## What not to do

- **Do not gate on total finding count.** It is the easiest metric to satisfy by detecting
  nothing, and the fastest way to destroy the tool's value.
- **Do not run on every push to every branch.** Run on PR open and on pushes to the PR head.
- **Do not fail on the tool's own timeout.** That is exit 2.
- **Do not let the baseline grow silently.** Report its size in every run; a growing baseline
  is the gate quietly being turned off one entry at a time.
