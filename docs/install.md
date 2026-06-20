---
layout: default
title: Install
---

# Install macli

## Homebrew (recommended)

```sh
brew install ljh-sh/cli/macli
```

Or tap once, then use the short name:

```sh
brew tap ljh-sh/cli
brew install macli
```

Homebrew 6 added a trust step for third-party taps. If you see a trust prompt, run:

```sh
brew trust ljh-sh/cli
brew install ljh-sh/cli/macli
```

The Homebrew formula automatically strips the `com.apple.quarantine` attribute for you.

## Direct binary

```sh
curl -L https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz | tar xJ -
sudo mv bin/macli /usr/local/bin/
```

The `universal` tarball is a fat Mach-O (arm64 + x86_64) — works on Apple Silicon and Intel Macs.

Because macli ships with an ad-hoc signature, macOS Gatekeeper may block the direct download. Strip the quarantine attribute:

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

## eget

Via [x-cmd eget](https://x-cmd.com/mod/eget):

```sh
x eget use ljh-sh/macli              # install latest to ~/.local/bin
x eget use --tag v0.4.2 ljh-sh/macli # install a specific release
```

## npm

```sh
npm install -g @ljh-sh/macli
```

The npm package downloads the universal macOS binary from the GitHub release during install.

## Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
```

## First-run permissions

The first time you run a calendar or reminders command, macOS TCC will prompt for access. Subsequent calls are instant.

```sh
macli cal ls
```

If you miss the prompt, go to **System Settings → Privacy & Security → Calendars** (or **Reminders**) and enable the terminal you're running macli from.

## Verify the binary

After downloading a release tarball, verify its cosign signature:

```sh
cosign verify-blob \
  --bundle macli-darwin-universal.tar.xz.sigstore.json \
  --certificate-identity-regexp '^https://github.com/ljh-sh/macli/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  macli-darwin-universal.tar.xz
```
