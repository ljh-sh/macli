---
layout: default
title: 设计原则
lang: zh
nav_order: 7
---

# 设计原则

1. **原生优先。** 直接使用 Apple framework，而不是包装 shell 工具。
2. **AI 友好。** JSON/TSV 输出、可预测的 schema、最小上下文。
3. **小表面。** 单一二进制、聚焦的子命令、无 GUI。
4. **可复现。** 固定工具链和时间戳，构建可复现。
5. **有审查。** 每个 `main` 分支变更都经过 code-owner 审查。
