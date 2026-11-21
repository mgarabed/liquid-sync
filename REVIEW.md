# Review instructions

## Passes
Run three passes and tag each finding with its pass:
- **Bugs**: logic errors, broken edge cases, error handling, concurrency, subtle regressions.
- **Security**: injection, authn/authz gaps, secrets or PII in code/logs, unsafe deserialization,
  over-broad permissions/entitlements.
- **Compliance**: the diff matches the work item's `spec.md` acceptance criteria and `plan.md`
  (files, order, proof); conventions in CLAUDE.md and the sdlc standards skills are followed.

## Severity
- **Important**: would break behavior, lose/leak data, breach a policy, or misses an acceptance criterion.
- **Nit**: style, naming, minor readability. Report at most five; summarize the rest as a count.

## Do not report
- Generated files, lockfiles, `*.xcodeproj/**`, anything `sdlc verify` (lint/format/tests) already enforces.

## Output
A ranked list (Important first). Each finding: pass, severity, `file:line`, the defect, a concrete
failure scenario, and a suggested fix. End with a one-line verdict: ready / needs changes.
