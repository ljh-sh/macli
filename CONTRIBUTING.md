# Contributing to macli

Thanks for your interest! macli is a small, focused tool. Please read this short guide before opening an issue or PR.

## Reporting issues

Open a [GitHub issue](../../issues) and include:

- macOS version
- macli version (`macli --version`)
- The exact command you ran
- Expected vs actual output
- If relevant, the full JSON output (`macli <cmd> --json`)

## Feature requests

macli deliberately stays small. We only add things that are hard or slow to do from shell, Python, or AppleScript. If your idea fits, open an issue and explain the use case.

## Building from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
```

The binary will be at `.build/release/macli`.

## Running tests

```sh
./runtest
```

## Pull requests

- Keep the change minimal and focused.
- Follow the existing Swift style.
- Update README examples if your change affects CLI behavior.
- Do not add heavy dependencies.

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.
