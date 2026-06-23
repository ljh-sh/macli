# macli — Agent Notes

This file captures project-specific conventions and current improvement focus.

## Current focus

Reach and maintain OpenSSF Scorecard 9.0+ by:

- Requiring code-owner review for every `main` branch change.
- Running required CI status checks before merge.
- Publishing npm packages and signed GitHub releases.
- Maintaining an OpenSSF Best Practices badge at Passing or higher.

Organization-wide defaults (CODEOWNERS, CONTRIBUTING, SECURITY, issue/PR templates)
are maintained in [`ljh-sh/.github`](https://github.com/ljh-sh/.github).

The repository-level ruleset `ljh-sh-default-main` enforces:

- Pull-request-based merges to `main`.
- At least one approving review, including a code-owner review.
- No force pushes or branch deletions on `main`.
- No administrator bypass.

See [CODEOWNERS](./CODEOWNERS), [CONTRIBUTING.md](./CONTRIBUTING.md), and
[SECURITY.md](./SECURITY.md) for operational details.
