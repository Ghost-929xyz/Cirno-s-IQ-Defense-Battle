extends Node

## 跨场景切换保留的会话状态。
## 使用静态变量而非 autoload，保证任何运行方式（编辑器、命令行、烟测）下都可用。

static var tutorial_done := false

## 当前使用的存档槽位（-1 = 未启用存档）。
static var current_slot := -1

## 进入游戏场景时若 >= 0，则从该槽位读档恢复。
static var pending_load_slot := -1
