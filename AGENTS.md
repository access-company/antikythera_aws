# AGENTS.md

Guidelines for AI agents and developers working on **AntikytheraAws**.

## References

- [`README.md`](./README.md) — project introduction, components, and dependencies
- [`CHANGELOG.md`](./CHANGELOG.md) — release history
- [Antikythera `STYLE_GUIDE.md`](https://github.com/access-company/antikythera/blob/master/STYLE_GUIDE.md) — coding rules
- [Antikythera Framework](https://github.com/access-company/antikythera) — the framework this library plugs into

## Overview

AntikytheraAws is a **plugin library** that provides implementations of some of the pluggable modules in the [Antikythera Framework](https://github.com/access-company/antikythera), using AWS services.

Main components:

- `AntikytheraAws.Ec2.ClusterConfiguration` — callback module of `AntikytheraEal.ClusterConfiguration.Behaviour`
- `AntikytheraAws.S3.LogStorage` — callback module of `AntikytheraEal.LogStorage.Behaviour`
- `AntikytheraAws.S3.AssetStorage` — callback module of `AntikytheraEal.AssetStorage.Behaviour`
- and some more AWS-related utilities

Dependencies beyond the standard mix dependencies:

- [aws-cli](https://github.com/aws/aws-cli) — interactions with AWS APIs are delegated to `aws-cli`, assuming AWS-related features are not frequently used.
- [EC2 instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) — the IAM role stored in the EC2 instance profile is used when making requests to AWS APIs (via `aws-cli`).

See [`README.md`](./README.md) for details.

## Commands

| Purpose               | Command                  |
| --------------------- | ------------------------ |
| Setup                 | `mix deps.get`           |
| Format                | `mix format`             |
| Test                  | `mix test`               |
| Typecheck             | `mix dialyzer`           |
| Static code analysis  | `mix credo -a --strict`  |

## Development Rules

- Follow the coding rules described in the Antikythera [`STYLE_GUIDE.md`](https://github.com/access-company/antikythera/blob/master/STYLE_GUIDE.md). Highlights:
    - Keep the style consistent with the surrounding code.
    - Use CamelCase for module names, even acronyms (e.g. `Antikythera.Url`, not `Antikythera.URL`).
    - Always use parentheses in function calls and definitions.
    - Order aliases from general to specific: External → Antikythera → AntikytheraCore → AntikytheraEal.
    - Restrict `import`; limit its scope with the `:only` option.
    - Declare typespecs explicitly, especially for public functions; prefer `Croma.Defun`.
    - Use the pipe operator (`|>`) only when it improves readability; avoid it when the first argument is simple.
- Keep the code formatted with `mix format`.
- Record notable changes in [`CHANGELOG.md`](./CHANGELOG.md).

## Definition of Done

- [ ] The code is formatted (`mix format`).
- [ ] All tests pass (`mix test`).
- [ ] Typecheck passes (`mix dialyzer`).
- [ ] Static code analysis passes (`mix credo -a --strict`).
- [ ] The code is reviewed in accordance with the [Development Rules](#development-rules).
- [ ] [`CHANGELOG.md`](./CHANGELOG.md) is updated when applicable.
