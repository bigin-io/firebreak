---
name: bulkhead-audit
description: Audits a whole repository for security risk by fanning out into many narrow investigations — one per entry point — rather than one broad sweep. Expensive and periodic, not per-PR. Use when asked to "audit this repo for security", "find vulnerabilities in X", "how exposed is this codebase", or before a pentest, a compliance review, or onboarding an unfamiliar service. For reviewing a single change before it merges, use `bulkhead` instead.
---

# Bulkhead audit

**This is not the gate.** `bulkhead` reviews a change set and answers *"does this make things
worse?"* This answers *"what is already wrong?"* Both are legitimate; they are different jobs and
this one is an order of magnitude more expensive.

A gate held on a codebase nobody has audited defends a line that was already lost.

## Why fan-out, and not a bigger prompt

A single broad sweep **has been measured to fail**. Asked to audit a 79k-line service, a reader
reached the affected file, made a correct surface observation, concluded "no action", and moved
on. Breadth forced shallowness — one pass at fixed effort produces a shallow read everywhere.

The fix is not to avoid auditing. It is to **decompose the audit into narrow questions**, because
narrow is what the measurement rewarded. A rule engine that finds real bugs is not asking "look
at this repo and find problems" — it is asking twenty specific questions.

**So: never investigate more than one entry point at a time.** If you find yourself holding the
whole system in view, you have already reverted to the shape that failed.

## Phase 1 — inventory, which is mechanical and cheap

Breadth is correct here. The failure mode is a missed route, which self-corrects the moment
someone notices; it is not the shallow-read failure above.

Produce four lists, each entry with `file:line`:

1. **Entry points.** Every route, handler, webhook, queue consumer, scheduled job, CLI command,
   and public API method. Group by router/prefix so grouping-level controls are visible.
2. **Controls.** Every auth/authz middleware, guard, policy, signature check, and where each is
   applied — **per route and per group**. Note anything registered on the root engine rather
   than inside a protected group; that gap is where real findings live.
3. **Sinks.** Per `../bulkhead/catalog.md` — outbound requests, SQL, templating, file paths,
   deserialisation, secrets, third-party SDKs that ship data off the box.
4. **Trust boundaries.** Where untrusted input enters and what it is trusted for.

Write the inventory down before investigating anything. It is the artifact the rest depends on,
and it is what lets a finding connect three files with no textual link between them.

## Phase 1b — shape hunts

Some vulnerability classes are cheap to find candidates for and expensive to confirm. **Grep for
candidates, then investigate each properly.** A grep hit is never a finding.

Run at least these. The first has been observed **four times across two codebases** and is the
highest-yield check known here:

```
# a control that exists and is switched off — verification commented out
grep -rnE '^\s*(//|#|/\*).*(verify|validate|signature|hash_equals|ConstructEvent|checkSig|authenticate)'

# authorisation keyed on attacker-supplied identity
grep -rnE '(request|req|params|body)[^;]*\b(user_?id|tenant_?id|org_?id|account_?id|role)\b'

# mass assignment
grep -rnE 'fill\(\$request->all|\.\.\.(req\.body)|ShouldBind\w*\(&|Object\.assign\([^,]+, *req'

# raw interpolation into SQL
grep -rnE 'orderByRaw|whereRaw|Raw\(|fmt\.Sprintf\(.*(SELECT|WHERE|ORDER BY)'

# static/unauthenticated file serving next to user content
grep -rnE 'Static\(|express\.static|StaticFiles|serve_static'

# weak randomness where it matters
grep -rnE 'math/rand|Math\.random\(\)|rand\.Intn|uniqid\('
```

**Secrets need history, not just the tree** — a secret committed two years ago is still live:

```
git log --all -p -S 'SECRET' -- '*.env*' | head -200
git ls-files | grep -iE '\.env|credential|secret|\.pem$|\.p12$'
```

## Phase 2 — one narrow investigation per entry point

For each entry point worth the effort, ask `../bulkhead/method.md`'s three questions **scoped to
that one entry point**: what it exposes, what control stands in the way, whether that control can
be bypassed or simply does not apply on this path.

Prioritise by: unauthenticated first, then anything touching money, personal data, or auth
itself, then everything else. Say plainly which entry points you did not investigate — an audit
that implies coverage it does not have is worse than one that admits its edges.

## Prior context — read it before you start

- **`.bulkhead/catalog.md`** — the trust model above all. Half of all real findings are
  authorisation, and authorisation is unjudgeable without knowing which routes are public and
  who the principals are. If it is absent, say so in the report: it is the single biggest thing
  limiting the audit's confidence.
- **Existing SARIF, security reports, or a `security-reports/` directory.** Read them. Do not
  re-report what is already known — **go past it.** A rule engine finds known shapes at scale;
  your edge is the reasoning bugs no rule describes, and duplicating its output wastes the one
  thing you are better at.

## Output

Findings ranked by reachability, worst first — the same per-finding format as `bulkhead`,
including quoting the source text of every cited line.

Then two sections a gate does not need:

- **Coverage.** Entry points enumerated, investigated, and skipped, with the reason. Somebody
  will act on this report's silence as much as on its findings.
- **What limits confidence.** Missing trust model, out-of-repo controls, deployment topology you
  could not see.

**Do not pad to look thorough.** An audit that reports thirty findings of which four matter is
how security tooling became ignorable. The reachability gate applies unchanged: if you cannot say
who triggers it and from where, it is a question, not a finding.
