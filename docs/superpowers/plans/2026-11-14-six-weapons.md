# 六武器与协调动作 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 交付主角手脚真实运动、六武器二/三联动的 Godot 可操作战斗样板和引擎录像。
**Architecture:** 纯规则与数据独立于场景；ActorView 管五部分动作；Main 管战斗生命周期；Hud 管输入提示、升级和六槽显示。透明 atlas 仅在运行时分区引用。
**Tech Stack:** Godot 4.7.2 standard / GDScript / Godot Movie Maker / FFmpeg.
**Spec:** ../../design.md

## Global Constraints
- 保留当前原始人和简单非像素平面画风。
- 同时最多六武器、初始一武器，原武器和等级不因组合消失。
- 每把远程先查射程，默认最近；精英优先仅看射程内。
- 二/三组合不重复占用同一武器，不让联动自触发。
- 身体、左手、右手、左脚、右脚独立驱动；停下回位。
- 新工程独立，原图、旧工程及其他项目不覆盖。

## Review Focus
- 满六槽时同名升级仍可用，未知武器不能污染状态。
- 射程外精英不能抢目标，死亡目标不再受选。
- 暂停和升级窗口停止全部战斗时钟，重开清空状态。
- 步态随实际位移推进，静止不滑步；受伤保留完整四肢。
- 联动爆炸造成伤害后不能递归制造下一次爆炸。

## Task 1: 规则与六武器数据
Files: src/rules.gd, src/catalog.gd, tests/test_rules.gd.
Interfaces: equip(inventory,id), choose_target(origin,range,candidates,elite), combo_groups(ids,mode), advance_combos(counters,event,groups), gait_pose(phase,dir,amplitude), advance_gait(phase,distance).
- [ ] 先写并运行失败的六槽、升级、射程、组合与步态行为测试。
- [ ] 实现纯规则和数据，再运行同一测试到全绿。

## Task 2: 透明素材与协调动作
Files: assets/*.png, assets/regions.json, src/actor_view.gd, src/asset_library.gd.
Interfaces: ActorView.animate(velocity,distance,dt), recoil(direction), AssetLibrary.texture(category,id).
- [ ] image_gen 生成透明素材并只读分析 alpha 和区域。
- [ ] 用独立身体/手/脚 Sprite2D 实现步态、停步、受击和攻击回摆。
- [ ] 运行规则测试与引擎动作预览，检查四肢实际运动。

## Task 3: 可操作战斗
Files: main.tscn, src/main.gd, src/hud.gd, src/effects.gd.
Interfaces: Hud signals start_requested, choice_selected, formation_requested, combo_requested, trial_requested; Main orchestrates six weapon slots and enemies.
- [ ] 实现移动、四类恐龙、六武器攻击、二/三联动、经验升级、暂停、失败、重开。
- [ ] 用真实场景检查暂停、目标优先、六武器试用及生命周期。

## Task 4: 审查与交付
Files: README.md, 启动样板.cmd, 动作预览.cmd, previews/*.mp4, docs/verification.md.
- [ ] 全套规则测试、解析导入检查、独立代码审查。
- [ ] 运行引擎实际操作检查，录制动作与战斗演示，编码可预览 MP4。
- [ ] 更新最新六武器约束与验证边界，保留旧版本。
