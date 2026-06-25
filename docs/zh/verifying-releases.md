---
layout: default
title: 验证发布
lang: zh
nav_order: 6
---

# 验证发布

## Cosign 签名

每个发布产物都在 GitHub Actions 中使用无密钥 Sigstore/cosign 签名。每个 tarball、`SHA256SUMS` 和 `BUILD_INFO.txt` 都会附带 `.sigstore.json` bundle。

示例：

```sh
curl -LO https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz
curl -LO https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz.sigstore.json

cosign verify-blob \
  --bundle macli-darwin-universal.tar.xz.sigstore.json \
  --certificate-identity-regexp '^https://github.com/ljh-sh/macli/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  macli-darwin-universal.tar.xz
```

## SLSA 来源证明

发布还包含由 OpenSSF `slsa-github-generator` 生成的 `.intoto.jsonl` SLSA 来源证明。可用 [`slsa-verifier`](https://github.com/slsa-framework/slsa-verifier) 验证：

```sh
slsa-verifier verify-artifact macli-darwin-universal.tar.xz \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/ljh-sh/macli \
  --source-versioned-tag "$(macli --version | head -1)"
```
