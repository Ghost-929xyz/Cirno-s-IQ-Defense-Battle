extends Node

## 跨场景切换保留的会话状态。
## 使用静态变量而非 autoload，保证任何运行方式（编辑器、命令行、烟测）下都可用。

static var tutorial_done := false
