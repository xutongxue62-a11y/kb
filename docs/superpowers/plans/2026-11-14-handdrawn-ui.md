# 手绘 UI 与出发缓冲 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 接入已认可的手绘首页/选人/弹窗，增加卷轴和有缓冲的出发流程，并打开原生游戏。
**Architecture:** HUD保留现有战斗与商店接口，新建UI前台、纸张和转场三个小模块；Main只增加真人入口的准备状态与真实存档摘要。复用原有角色/武器贴图。
**Tech Stack:** Godot 4.7.2 / GDScript / 原生Control与Node2D
**Spec:** docs/superpowers/specs/2026-11-14-handdrawn-ui-design.md

## Global Constraints

1280×800；保留玩家存档、原素材及旧预览；测试只注入runtime/tests路径；无虚构角色；默认弹弓；燃烧仅重要切换；程序化旧start_run接口保持立即初始化。用户已明确直接接入、验证并启动，无需再次请求执行批准。

## Review Focus

- 连点确认、Enter重复或转场中按键不能多次开始或跳过准备期。
- 准备期不能推进计时、移动、攻击、刷怪或掉血。
- 设置/帮助从选人或暂停进入后返回正确页面，暂停不应被意外解除。
- 无效/结束存档不能“继续”出新局；摘要必须来自实际存档。
- 单角色箭头可见且不产生错误角色；卷轴未展开时输入不应穿透。

### Task 1: 测试与可复用纸张/转场
Files: tests/test_frontend.gd, src/ui_paper.gd, src/ui_transition.gd
- [x] 写真实UI导航/准备状态回归，运行并观察缺失行为失败。
- [x] 实现可裁切的左到右卷轴纸面、无边框手绘纸纹与整页卷轴/少量焦边转场。
- [x] 完成准备遮罩与输入锁定检查。

### Task 2: 首页、选人与弹窗
Files: src/ui_frontend.gd, src/hud.gd, assets/ui/title_arena_clean_v01.png, tests/test_hud_navigation.gd
- [x] 原首页概念去字背景另存新素材；真实控件搭建首页与单角色选人，保留未来前后导航。
- [x] 原生设置、继续存档和帮助/属性入口接入现有信号，维护返回来源与实时状态。
- [x] 统一成长/商店纸张与按钮风格，更新有意改变的旧导航断言，不删战斗/经济覆盖。
- [x] 跑HUD和新流程回归。

### Task 3: 准备缓冲与真实存档摘要
Files: src/main.gd, tests/test_frontend.gd
- [x] start_requested与continue_requested走有缓冲的真人入口；departure_left独立于旧wave_buffer。
- [x] 准备期间冻结全部simulate；阶段结束恢复既有模拟；处理快捷键、重复触发和返回。
- [x] SaveStore读取结果给继续弹窗真实摘要，失败保持当前页面和明确提示。
- [x] 跑完整tools/run_tests.ps1。

### Task 4: 原生核验与交付
Files: tests/capture_frontend.gd, docs/verification.md, README.md, docs/superpowers/progress-handdrawn-ui.md
- [x] 使用隔离测试存档打开原生窗口检查首页、选人、弹窗、Buff页、卷轴和出发倒计时。
- [x] 修正可见布局/输入问题；做一次独立只读代码审查，处理重要发现。
- [x] 验证素材和玩家存档保留，记录证据边界。
- [x] 按原启动方式打开新版供用户试玩。

