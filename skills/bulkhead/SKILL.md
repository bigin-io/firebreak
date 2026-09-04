---
name: bulkhead
description: Reviews a change set for security risk — what it exposes, to whom, and whether the control between an attacker and it actually holds. Reports reachability ("an unauthenticated internet caller can reach X") rather than severity ratings. Three surfaces - the working tree before a commit, a branch or PR under review, and a headless CI gate. Use when about to commit, when reviewing a branch, or when asked "is this safe", "review this for security", "can this be exploited", "check this change for vulnerabilities" — and whenever a change touches authentication, authorisation, outbound requests, file paths, deserialisation, templating, SQL, secrets, or user-supplied input reaching any of them.
---

# Bulkhead

Read a **change set** and answer one question: **what does this expose, to whom, and does the
control between them actually hold?**

Sibling to `firebreak`, which asks the same shape of question about money. The two overlap on
purpose — the construct that bounds spend is usually the construct that bounds reach.

## Read this first: these rules are inherited, not yet measured

`firebreak`'s rules were each written after a measured run went wrong. **Bulkhead's are
transplanted from it and reasoned about, not earned.** The anti-patterns in `method.md` are
plausible, not observed.

Treat findings accordingly until this has been run against known-vulnerable diffs and its own
failures recorded. **Do not gate a build on it yet.**

## The two rules

**1. Reviews a change set. Never audits a repository.**

Measured for `firebreak`: asked to audit a whole service, a reader cleared the affected file;
asked about a specific change, a reader traced the defect — from the same observation. Accuracy
scaled inversely with the breadth of the question.

It matters more here. A repository-wide security audit produces hundreds of findings nobody
reads, which is the entire history of static analysis. Anchor every finding to a changed line;
read unlimited surrounding code to judge it.

**2. Reports, never edits.** A confident wrong security patch is worse than the bug, because it
looks resolved. Describe the fix and stop.

## Modes

Resolve the change set with `firebreak`'s `../firebreak/scope.sh` — it is generic.

| Mode | Invocation | Change set |
|---|---|---|
| Pre-commit | no argument | Staged + unstaged working tree |
| Review | `bulkhead <ref>` | Diff vs merge base with the default branch |
| CI | `--ci` | Same, non-interactive. **Advisory only for now** |

## Procedure

1. **Scope.** Resolve the change set. Empty → say so and stop.
2. **Triage.** Discard changed files with no path to a sink (`catalog.md`). Most changes are
   nothing. Saying so in one line is correct, not lazy.
3. **For each survivor, three questions** — `method.md` explains how to answer each without the
   known failure modes:
   - **What does this expose?** Not what it calls — what an attacker can now reach or influence.
   - **What control stands in the way?** Named, with a line and its source text. "It's
     authenticated" is not an answer; *which* middleware, on *which* route, for *which* method,
     is.
   - **Can the control be bypassed, or does it simply not apply on this path?** The second is
     more common and easier to miss.
4. **Establish reachability.** Who triggers it, from where, with what pre-conditions. **If you
   cannot answer that, you do not have a finding yet** — see the gate below.
5. **Report.**

**Read `method.md` before step 3** on anything that survives triage.

## Output

**Verdict first, one line.** Then findings, most reachable first.

**Under 200 words per finding, under 400 per review.**

```
### <one-line claim> — `path/from/repo/root.go:123`
`<the actual source text of that line>`

<Mechanism. 2–4 sentences: what is exposed, what should stop it, why it doesn't.>

**Reachable by:** <who, from where, authenticated or not>
**Doing:** <the concrete action — a request, an input, a sequence>
**Getting:** <what they obtain or achieve>
**Pre-conditions:** <what must also be true; "none" is a strong statement, make it deliberately>
**Fix:** <one line>
**Unknown:** <only what would change the verdict>
```

**Quote the line you cite.** Line numbers drift — measured at 8–23 lines off on real
repositories while the claims themselves were correct. A quoted line is self-locating, and you
cannot quote a line that does not exist, which makes it the cheapest check against citing
something you inferred rather than read.

### Reachability replaces severity, deliberately

**Do not emit CVSS scores or severity words as the headline.** A rating assigned from a matrix
is disconnected from consequence and inflates on analyser uncertainty — the exact failure that
got a severity model withdrawn twice in this project's history.

State reachability as fact instead:

```
✅ Reachable by: an unauthenticated caller on the public internet
   Doing: POST /api/topics with a body containing 169.254.169.254
   Getting: whatever the cloud metadata endpoint returns, if the probe body is surfaced
   Pre-conditions: IMDSv1 enabled; service internet-facing

❌ CVSS 9.1 — Critical — SSRF
```

Every line of the first is checkable, and a reader can disagree with a specific claim rather
than with a number. If a rating is required downstream, derive it from the reachability
statement — never in place of it.

### Before you write a finding heading

Three gates. Each means **say clean and stop**:

- **You cannot say who triggers it and from where.** Unreachable-in-practice findings are what
  made security tooling ignorable. Not a finding yet — a question.
- **The control is deliberate and adequate**, even if unusual. A design you would not change is
  not a finding.
- **You are about to write "this may not be exploitable."** If that is true, it isn't a finding.
  Ask it in the verdict line, or say nothing.

**Reporting nothing is a valid, useful result.** A review that manufactures a concern to look
thorough trains people to skip the next one.

## Scope

**In:** authentication and authorisation, injection of every kind, outbound requests with
caller-influenced destinations, path handling, deserialisation, secrets and credentials,
cryptographic misuse, session handling, and **data disclosure — including personal data reaching
third parties**.

**Out:** dependency CVEs (a scanner does that better), infrastructure hardening, and anything
with no attacker in the story. If something serious turns up outside scope, one line at the end
under **Noticed, out of scope** — do not rank it with the findings.
