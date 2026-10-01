# app/controllers - generation guide

Read this before generating `app/controllers/CLAUDE.md` in the target app. Derive every statement from that app's code; skip any question the app has no answer to. Only generate the file if the directory qualified in Phase 1.

## Questions to answer from the code

- **Authentication**: mechanism (session, token, magic link), which base controller enforces it, and what a new controller must inherit or include to be behind it.
- **Authorization**: policy library or hand-rolled checks, and where they're enforced (base class, per-action, route constraints).
- **Namespace map**: what each controller namespace is *for* (admin, api, internal, webhooks…), which base class each uses, and its default response format. Describe the meaning of the namespaces, not the list of controllers in them.
- **Strong params**: the app's style - `params.expect` vs `require/permit`, private method naming.
- **Response conventions**: when turbo_stream vs redirect, flash usage, error rendering (422 re-render? JSON error shape?), redirect-after-POST.
- **The thin-controller line**: what this app actually keeps in controllers vs pushes to models/services - state the boundary as a rule.
- **Webhooks**: signature verification pattern, idempotency, response expectations.
- **Routing constraints**: if `app/constraints/` exists, what each constraint gates (multi-domain, subdomain routing) - cover it here rather than giving constraints its own file.
- **Rate limiting**: rack-attack or controller-level throttles a new endpoint must respect.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
## Conventions
- Public pages inherit `ApplicationController`; anything behind login inherits
  `AuthenticatedController` (session auth, redirects to sign-in). `Admin::*`
  inherits `Admin::BaseController`, which adds a role check - never skip it.
- Strong params: one private `<model>_params` method per controller, using
  `params.expect`.
- HTML flows redirect with a flash on success and re-render with status 422 on
  failure. turbo_stream responses only where the page needs live updates - not
  as the default.

## Gotchas
- `app/constraints/` routes by hostname (main site vs customer domains). Every
  new public route must decide which constraint it lives under.
- Webhook controllers verify signatures in a before_action and must stay
  idempotent - providers retry.
```
