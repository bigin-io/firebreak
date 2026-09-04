# Method

How to answer the three questions without the failure modes that were measured.

---

## Question 1 — What does this change make reachable?

Not "what does this code call." What does it *enable*.

Three categories, and the second two are where the money hides:

| | Example |
|---|---|
| **Introduces** a metered operation | The diff adds a `messages.Create()` |
| **Amplifies** an existing one | Loop bound widened, page size raised, batch cap removed, cron interval tightened, a flag rolled to 100% |
| **Makes reachable** an operation that was previously bounded | The diff changes something *else* — auth, config, a callback contract, an error path — and a bound elsewhere stops working |

The third category is the one that costs the most and looks the most innocent. The change and
the damage are in different files, often different systems. A diff can contain **no metered
call, no loop, and no removed guardrail** and still be the direct cause of a runaway.

**So never triage a change out because "it doesn't call anything expensive."** Triage it out
when nothing it touches has a path to a metered operation — which requires following the path,
not glancing at the diff.

## Question 2 — What is supposed to bound it?

Name the specific construct, in code, with a line number.

- ✅ `send_count < 3`, checked in the eligibility query at `handler.go:95`
- ✅ `MaxRetryAttempts = 3` with exponential backoff at `config.go:34`
- ❌ "there's a rate limit somewhere"
- ❌ "the cap should handle it"

If you cannot name the bound, that is itself the finding — an unbounded metered operation.
Say so plainly rather than assuming a bound exists off-screen.

Bounds that look like bounds and are not:

- A **change detector** mistaken for a rate limit — "only fires when the field differs" bounds
  nothing if a user can toggle the field.
- A **cap that resets** — a counter another code path sets back to zero.
- A **per-process throttle** — a `sync.Map` or in-memory limiter multiplies by replica count
  and resets on every deploy.
- A **fail-open guard** — a check that returns "allow" when its own lookup errors.
- **`LIMIT` on a query** that bounds rows returned, not calls made, and not bytes scanned.

## Question 3 — Can the bound fail independently of the spend?

**This is the question that catches the expensive bugs, and it has a mechanical technique.**

> Find the bound's state. Then find **every writer** of that state. Then ask: can the spend
> happen while a writer does not?

Work it as a two-column table:

| | |
|---|---|
| **What the bound reads** | `send_count`, `next_send_at` |
| **Every writer of it** | one callback handler, reached over HTTP from an external system |
| **Can spend occur without that writer running?** | **Yes** — the send happens in the external system before the callback is attempted |

When the answer is yes, the bound is decorative. The cap can be correct, tested, and
unreachable at the same time.

Failure shapes worth checking for by name:

- **Bound advanced by a separate call that can fail** — a callback, a webhook, a second
  request. Any independent failure mode unbinds the spend.
- **Read-then-act with no claim** — the query selects eligible rows but writes nothing to mark
  them in flight, so a retry, a delay, or a concurrent run re-selects the same rows.
- **Guard written after the paid call** — the persist that would prevent a repeat happens
  after the money is spent, so a crash in between repeats it forever.
- **Error path that discards the write** — `db.Save(&x)` whose error is ignored, so the bound
  silently fails to advance.
- **Retry machinery on the caller's side** — returning a non-2xx to a provider webhook makes
  *them* retry the paid operation for you, for days.

---

## Anti-patterns — measured, not hypothetical

Each of these produced a confident all-clear on a real live bug.

### 1. "The sink isn't in this codebase, so there's no risk"

The most expensive mistake available. A service can drive spend it never calls: it returns the
work list, sets the eligibility, holds the counter, or feeds the queue that another system
sends from.

**Test:** if this code went wrong, would the bill move? If yes, it is in scope, whatever the
call graph says.

A no-op stub, a mock, or a feature-flagged-off path is **not** evidence of safety. Ask what
sends in production.

### 2. Right file, wrong bug

Finding the affected file and reporting the wrong mechanism is not a save. An engineer told
"this query has no `LIMIT`" adds a `LIMIT` and is still billed, because the defect was that
nothing advanced the counter. **The mechanism is the deliverable, not the location.**

If you are not sure you have the mechanism, say which of two readings you hold and what would
distinguish them.

### 3. Deprioritising by unit cost alone

A $0.0125 SMS with no bound beats a $5.00 geocode with a working cap. Rank by
**unit cost × plausible executions × how the bound fails**, not by the price of one call.

### 4. Concluding from a bound you did not trace

"There's a limit of 4" is where the analysis starts. Question 3 is where it ends.

---

## Reading context

The diff is the anchor, never the evidence base.

For each changed hunk that survives triage, read: the whole enclosing function; every caller;
the definition of anything the change tests, reads, or writes; and **every writer of state the
change depends on**. Grep for the column, field, or key by name — do not assume the writer you
found first is the only one.

Read config, schedulers, and job definitions when the change touches something they drive.
Say so explicitly when the multiplier lives outside the repository — an interval in a
scheduler, a fan-out in a workflow tool, a provider's retry policy. **"The bound is
out-of-repo" is a finding, not a reason to stop.**

Budget: prefer following one path completely over sampling five paths shallowly. A traced
mechanism beats five hedged observations.

---

## Calibration

**Report** an operation that costs money or causes irreversible real-world effect, reachable
along a path this change introduces, amplifies, or unbinds, where you can name the bound and
say why it fails.

**Do not report** theoretical reachability with no trigger; a bound you have not actually
traced; general quality issues; or anything you would not want to be woken up for.

**Uncertainty is reportable** when the money is large and the path is real — say what you
could not determine and what would settle it. That is different from padding.
