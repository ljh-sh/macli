---
layout: default
title: 安装
lang: zh
---

# 安装 macli

## Homebrew（推荐）

```sh
brew install ljh-sh/cli/macli
```

也可以先 tap，再用短名安装：

```sh
brew tap ljh-sh/cli
brew install macli
```

Homebrew 6 对第三方 tap 增加了信任步骤。如果看到 trust 提示，执行：

```sh
brew trust ljh-sh/cli
brew install ljh-sh/cli/macli
```

Homebrew 公式会自动去除 `com.apple.quarantine` 属性。

## 直接下载二进制

```sh
curl -L https://github.com/ljh-sh/macli/releases/latest/download/macli-darwin-universal.tar.xz | tar xJ -
sudo mv bin/macli /usr/local/bin/
```

`universal` 压缩包是 fat Mach-O（arm64 + x86_64），在 Apple Silicon 和 Intel Mac 上都能运行。

由于 macli 使用 ad-hoc 签名，macOS Gatekeeper 可能阻止直接下载。去除隔离属性：

```sh
xattr -dr com.apple.quarantine /usr/local/bin/macli
```

## eget

通过 [x-cmd eget](https://x-cmd.com/mod/eget)：

```sh
x eget use ljh-sh/macli              # 安装最新版到 ~/.local/bin
x eget use --tag v0.4.0 ljh-sh/macli # 安装指定版本
```

## 源码编译

需要 Swift 5.10+ / macOS 12+。

```sh
git clone https://github.com/ljh-sh/macli
cd macli
swift build -c release
```

## 首次运行权限

第一次运行日历或提醒命令时，macOS TCC 会弹出权限请求。后续调用瞬间完成。

```sh
macli cal ls
```

如果错过了弹窗，前往 **系统设置 → 隐私与安全性 → 日历**（或 **提醒事项**），开启你正在使用的终端。
