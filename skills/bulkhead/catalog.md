# Sink catalog

`firebreak`'s catalog carries **prices**. This one carries **required controls** — for each
sink, what must stand between it and attacker-influenced input, and which checks look like that
control but are not.

Not a rule list to match against. Use it to answer question 2 once a path is traced.

---

## Outbound requests with a caller-influenced destination

`http.Get`, `fetch`, `requests.get`, webhook senders, URL previewers, image proxies, feed
readers, anything resolving a user-supplied link.

**Required:** validation of the **resolved IP at connection time**, rejecting loopback, private,
link-local and unspecified ranges — plus the same check re-applied after every redirect, or
redirects refused outright.

**False boundaries:** hostname string checks of any kind (`Contains(host, ".")`, suffix
allowlists, regex); blocking `localhost` by name while `127.0.0.1` passes; validating before DNS
resolution, which loses to rebinding.

> `169.254.169.254` is the target that matters — cloud instance metadata. On AWS with IMDSv1 it
> returns live IAM credentials. GCP and Azure have equivalents. Enforcing IMDSv2 is a strong
> second layer and does not replace the first.

**Severity hinges on one question: is the response body surfaced to the caller?** Surfaced is
read-SSRF and exfiltration; discarded is blind SSRF — still usable for internal port scanning
and triggering internal state changes. Say which, or say you could not tell.

## Injection

| Sink | Required control | Not a control |
|---|---|---|
| SQL | Parameterised queries | Escaping, quoting, ORM used with raw string building |
| Shell / `exec` | Argument arrays, never a string | Quoting, denylists of metacharacters |
| Templates | Context-correct escaping | HTML-escaping something interpolated into JS or a URL |
| `eval`, deserialisation | Do not accept attacker input at all | Type checks, "it's only internal" |
| LDAP, XPath, NoSQL | Parameterisation for that grammar | SQL escaping reused |

**Prompt injection belongs here.** Text an LLM generated from user-influenced input is
attacker-influenced. If a model's output reaches a tool call, a URL, a query, or a shell, the
model is an injection vector, and "the prompt says not to" is not a control.

## Authentication and authorisation

**Required:** an explicit authorisation decision comparing *this actor* to *this object*,
distinct from authentication.

**False boundaries:** authentication alone; role checks that never scope to the tenant; an
identifier from the request body used as the subject; client-supplied role or tenant claims.

**Check registration, not intent** — a route added outside a guarded group has no control at
all, however well the group is written.

## Path handling

**Required:** resolve, then verify the result is inside the intended root. In Go, `fs.ValidPath`
after `path.Clean`; elsewhere, compare the canonicalised absolute path against the root prefix.

**False boundaries:** stripping `../` (defeated by `....//`); checking before decoding; checking
the request path when the filesystem sees a different resolved one; symlinks crossing the root.

## Secrets and credentials

**Required:** out of source, out of logs, out of error messages, out of anything sent to a third
party.

**Watch specifically for:** raw request or response objects placed into error-tracker `extra`
fields — a login request body contains credentials; tokens in URLs, which land in access logs
and `Referer` headers; credentials in client bundles.

## Data disclosure to third parties

Any SDK that ships data off the device or server — error trackers, analytics, session replay,
support widgets, LLM APIs.

**Required:** know what the payload actually contains, not just that it is sent. Masking or
scrubbing configured for anything capturing a screen or a DOM.

**False boundaries:** "it's only errors" (errors carry state); "the vendor scrubs it" (their
scrubbing is text-based and does **not** touch image attachments); "it's sampled" (sampling
reduces volume, not the sensitivity of what gets through).

> The concrete shape to look for: a screenshot or view-hierarchy attachment enabled globally,
> combined with error capture on an ordinary path. Whatever is on screen when it fires leaves
> the device — one-time passcodes, credentials, addresses.

## Cryptography and sessions

**Required:** constant-time comparison for secrets; signature verification actually invoked on
every webhook path; tokens with expiry and single use where the flow implies it; randomness from
a CSPRNG.

**False boundaries:** `==` on a token; signature verification present in the file but commented
out or behind a disabled flag; `math/rand` or `Math.random()` for anything security-bearing;
`Date.now()` as an identifier.

---

## `.bulkhead/catalog.md` — the house file

Bulkhead reads a repository-local catalog if present. Record what only this codebase knows:

```markdown
## Trust model
- Public, unauthenticated: /healthz, /webhooks/*, the marketing site
- Authenticated, single-tenant: everything under /api
- Admin-only: /admin/* — enforced by RequireRole in router.go, not per-handler
- Deployment: behind Cloudflare; the origin is NOT reachable directly

## Known incidents
**2026-03-11 — tenant data leak.** A report endpoint took tenant_id from the request body
rather than the session. Found by a customer. Shape: **authorisation subject taken from
attacker-controlled input.**
```

The **trust model** is what makes reachability answerable — without it, every finding stalls at
"depends whether this route is public." The **known incidents** carry the same weight they do in
`firebreak`: a shape that has already been exploited here outranks any rating, and
time-to-detection predicts the next one.
