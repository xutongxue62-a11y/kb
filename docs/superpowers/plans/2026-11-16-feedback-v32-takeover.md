# v32 接续收尾 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成用户已确认的 v32 改动并修复半完成工作中的回归。

**Architecture:** 保留当前 Godot 实现，按现有 LootRules/LootDrops、SaveStore/SessionState、HUD/FrontUI 边界局部修正。以接手时的轻量快照为依据，不覆盖其他 Agent 的整体工作。

**Tech Stack:** Godot 4.7.2 / GDScript、Windows PowerShell、Python 标准库。

**Spec:** `docs/superpowers/specs/2026-11-16-feedback-v32-takeover-design.md`

## Global Constraints

- 3% 血包、回血 2、掉落系数 0.75、XP 15/20/25/...、精英宝箱 0.6 均沿用现值。
- 用户确认保留现有 Buff 上限、价格与敌人/Boss 自适应。
- 720p 使用现有 1280×800 等比界面；不重新设计美术。
- 不写真实玩家存档、不改原素材、不删除其他目录、不发布或覆盖发行包。
- 延后项按 spec 处理；内部名称延期时保留旧存档命名空间。

## Review Focus

- 地上未拾取血包能否保存、读回并在原位置只恢复一次。
- 低数值四舍五入是否抵消了金币/XP 降幅；蛋/石头是否错误产生血包。
- 增长曲线变化后关卡结束时仍先升级、再宝箱、再商店，且不重复结算。
- 六武器与长等级名称在存档页/720p 是否溢出；角色预览是否误提交。
- 默认存档目录是否因工程名变化而失联；正式键位文案是否仍误导使用 R/F2/F3。

### Task 1: 接手基线与回归定位
- [x] 只读比对另一 Agent 修改，备份当前源码和存档、记录素材哈希。
- [x] 重现 settlement_v14 的 3 项失败；feedback_balance_v32 的 70 项通过。
- [x] 执行完整继承测试，收集所有失败，不在第一个失败处隐藏后续问题。

### Task 2: 数据与掉落缺口
**Files:** `src/loot_rules.gd`、`src/loot_drops.gd`、`src/save_store.gd`、`src/main.gd`、`project.godot`、`tests/test_feedback_takeover_v32.gd`。
- [x] 用真实掉落、存档写读与目录解析复现缺口；观察红灯。
- [x] 最小修正血包存档/位置、实际掉落减量、未孵化蛋边界和存档命名空间。
- [x] 运行相关测试，保留已确认的其余平衡数值。

### Task 3: 界面与测试衔接
**Files:** `src/ui_frontend.gd`、相关 tests、必要的 native 验证工具。
- [x] 用六武器/长等级名称复现存档页越界，并验证正式按键说明与预览行为。
- [x] 局部修正存档布局和失效的快捷键文案，保留既有纸面与按钮样式。
- [x] 把 settlement 的旧 8 XP 数据改成独立手算的 15 XP 测例；把两批拾取渲染断言扩展到血包第三批，并检验三批清空。
- [x] 补齐飘字数量、吸附、战斗中宝箱以及怪/蛋/石头边界行为验证。

### Task 4: 完成验证与交付
- [x] 完整测试命令通过；原生 720p/存档/战斗反馈截图验证并目视检查。
- [x] 新上下文只读复核，修复实际重要问题并重复相关验证。
- [x] 再核对素材、真实存档和签名身份；写交接与已知限制，提供截图。
