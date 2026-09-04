# Method

How to answer the three questions. **Every anti-pattern below is reasoned, not measured** —
unlike `firebreak`'s, which were each written after a run failed in that exact way. Expect this
file to be wrong in ways nobody has found yet.

---

## Question 1 — What does this expose?

Not what the code calls. What an attacker can now **reach or influence**.

| | Example |
|---|---|
| **Introduces** a sink | The diff adds a `fetch` with a caller-supplied URL |
| **Widens** an existing one | A route moves from admin-only to authenticated; a parameter becomes user-controlled; a filter drops a case |
| **Un-guards** something previously covered | The diff changes something *else* — middleware order, a route group, a config default — and a control elsewhere stops applying |

The third is the one that costs most and looks most innocent, exactly as in `firebreak`. The
change and the exposure live in different files.

**Attacker-influenced is broader than "user input."** It includes anything crossing a trust
boundary: webhook bodies, headers, filenames, values read back from a database that a user wrote
earlier, and — increasingly — **text an LLM generated from a prompt a user controls.**

## Question 2 — What control stands in the way?

Name it, with a line number and its source text.

- ✅ `r.Use(middleware.RequireAuth)` at `router.go:88`, applied to the group this route joins
- ❌ "the endpoint is authenticated"
- ❌ "input is validated" — against what, and does that check bind this field?

If you cannot find a control, that is the finding. Say so plainly rather than assuming one
exists off-screen.

**Controls that look like controls and are not:**

- **A typo guard mistaken for a security boundary.** Real example: `strings.Contains(host, ".")`
  written to catch `localhost`, which passes `127.0.0.1`, `169.254.169.254`, and every private
  range. Read the comment — if it explains a *usability* problem, it is not a boundary.
- **Client-side validation** with no server counterpart.
- **A check on the wrong layer** — path-based auth in front of a router that normalises paths
  afterwards.
- **An allowlist that is really a denylist**, or a regex anchored at neither end.
- **A control applied per-route** where a sibling route is registered without it.
- **Encoding mistaken for escaping**, or escaping for the wrong context (HTML-escaping something
  interpolated into JavaScript, SQL, or a shell).

## Question 3 — Can it be bypassed, or does it not apply?

**The second is more common and easier to miss.** A control can be perfectly written and simply
never execute on the path you are looking at.

Work it as a table:

| | |
|---|---|
| **The control** | `RequireAuth` middleware |
| **Where it is applied** | The `/admin` route group |
| **Every path to the sink** | `/admin/export` ✅ · **`/internal/export`, registered separately** ❌ |
| **So** | The control is correct and irrelevant on the second path |

Bypass shapes worth checking by name:

- **Registration order and grouping** — a route added outside the guarded group.
- **Method mismatch** — auth on `POST`, the handler also serving `GET`.
- **Normalisation gaps** — the check sees the raw path, the filesystem sees the resolved one.
- **Redirect-following** — the destination is validated once, then a 302 sends it elsewhere.
- **Name-vs-resolution** — a hostname allowlist checked before DNS resolves it somewhere else
  (DNS rebinding). Validate the **resolved IP at connection time**, not the string.
- **Time-of-check to time-of-use** — validated, then re-read from a mutable source.

---

## Anti-patterns

Each of these produces a confident all-clear on live vulnerabilities. **Unverified — none has
been observed in a measured run yet.**

### 1. "It's behind auth, so it's fine"

Authentication answers *who*, not *what they may do*. An authenticated tenant reaching another
tenant's data is the most common real breach shape and passes every "is it authenticated" check.

**Test:** name the *authorisation* decision — the code comparing this actor to this object. If
there isn't one, authentication is not the control.

### 2. "The input is validated"

Ask what the validation is *for*. Type checks, length caps and format guards are correctness,
not security boundaries. `usableFeedURL` returning `strings.Contains(u.Host, ".")` is validation
that stops none of what matters.

### 3. "It's internal, so it isn't reachable"

Internal means "not documented as public." SSRF, a misconfigured ingress, a compromised
container, and a curious employee all reach it. Say what actually enforces internal-ness, and if
the answer is "nothing, it's just not linked," that is the finding.

### 4. Stopping at the sink instead of the data

A payload is not just a size. Reading `attachScreenshot: true` to price bytes tells you the
bytes are **screenshots of whatever is on screen** — which is how a cost review found a live PII
leak. **Ask what is actually in the thing being sent, not just how much of it there is.**

### 5. Reporting the pattern rather than the path

"Uses `eval`" is not a finding. "A field from an unauthenticated webhook body reaches `eval` at
`x.go:41`, with no sanitisation between" is. **The path is the deliverable**, the same way the
mechanism is `firebreak`'s.

---

## Reading context

The diff is the anchor, never the evidence base. For each surviving hunk: the whole enclosing
function, every caller, the route registration, every middleware between the entry point and the
sink, and the definition of anything the change trusts.

**Trace from the entry point inward, not from the sink outward.** Starting at the sink tells you
what could go wrong; starting at the entry point tells you whether anyone can make it.

Say so explicitly when the control lives outside the repository — an API gateway, a WAF, an
ingress rule. **"The control is out-of-repo" is a finding, not a reason to stop** — and it is
also the most common way a real vulnerability gets dismissed in review.

---

## Calibration

**Report** a sink an attacker can reach along a path this change introduces, widens, or
un-guards, where you can name the control and say why it fails, **and say who triggers it from
where**.

**Do not report** a pattern with no traced path; a control you have not read; a finding whose
reachability you cannot state; or theoretical weaknesses with no attacker in the story.

**Uncertainty is reportable** when the exposure is severe and the path is real — say what you
could not determine and what would settle it. That is different from padding, and different
again from a finding you cannot make reachable.
