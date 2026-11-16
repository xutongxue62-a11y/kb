# Opening Impact Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 让开局迅速进入有击杀反馈的战斗，保证近战风险回报并提高阵营辨识度。

**Architecture:** 在现有 Catalog/Main 调整真实攻击与开局节奏；在 AssetLibrary 复用阵营轮廓材质，Actor/Dino/Companions 添加不同标记；Effects 扩充有界的拖尾、命中和击杀。

**Tech Stack:** Godot 4.7.2 / GDScript，已有图片和声音，无新依赖。

**Spec:** `docs/superpowers/specs/2026-11-14-opening-impact-design.md`

最新补充同时采用 `docs/superpowers/specs/2026-11-14-endless-balance-design.md`；其中无限30秒关卡覆盖原先三波90秒限制，其余开局和表现要求保留。

## Global Constraints
- 保留六武器、正常单武器、远程固定身旁及有代价的两两联动。
- 保留全部旧图片、音效、录像和历史快照，不修改无关工程。
- 三波各 30 秒，暂停/成长冻结战斗，致死帧优先于胜利。
- 特效最多 200 项；震动限幅，不引入全局停帧。

## Review Focus
- 提速后的近战路径不能漏过真实碰撞；三个近战与三种远程都在同一可触及目标上比较。
- 初期密度增加时避免敌人直接出生在玩家身上，普通小怪与精英/重甲不能混淆。
- Shader 的 AtlasTexture 边界不能串入图集其他角色；材质缓存按种类复用。
- 暂停/成长期间特效、震动和计时一起冻结；重开恢复零偏移。
- 轮廓和大特效不能遮住敌方尖刺弹；主角标记保持在人物上方。

### Task 1: 真实输出与开局节奏
**Files:** `tests/test_impact.gd`, `src/catalog.gd`, `src/main.gd`, `src/growth.gd`, `tests/test_growth.gd`, `tests/test_feedback.gd`.
- [x] 写真实攻击输出/击杀/开局/射速测试并观察失败。
- [x] 调整武器伤害、各自挥击速度、射速、开局敌人和成长拾取。
- [x] 运行 impact 和已有成长测试，检查数值及行为。

### Task 2: 阵营识别与战斗特效
**Files:** `src/asset_library.gd`, `src/actor_view.gd`, `src/dino_view.gd`, `src/companions.gd`, `src/effects.gd`, `src/main.gd`.
- [x] 扩展场景回归验证阵营材质、攻击拖尾、死亡表现、暂停/重开。
- [x] 实现青/红轮廓和标记、弧面拖尾、方向冲击、烟火/符文、击杀反馈与限幅震动。
- [x] 所有旧回归及新增 impact 测试通过。

### Task 3: 核验与打开试玩
**Files:** `README.md`, `docs/design_v0.4.md`, `docs/verification.md`, `tools/run_tests.ps1`.
- [x] 按 requesting-code-review 做一次独立只读检查并修复实质问题。
- [x] 比较 assets 哈希，原生检查画面和日志，更新实际测试结果。
- [x] 打开最终版本供用户操作，保留窗口和可回退快照。

### Task 4: 最新补充——无限关卡和怪物数值
**Files:** Create `src/progression.gd`, `tests/test_progression.gd`; modify `src/main.gd`, `src/growth.gd`, `src/effects.gd`, `src/hud.gd`, `tests/test_controls.gd`, `tools/run_tests.ps1`.
- [x] 先运行缺失无限成长的失败回归。
- [x] 估计配装输出、分离怪物血量/伤害/闪避成长，每5关有限修正并保留残血比例。
- [x] 移除固定结束，更新关卡HUD、伤害数字和鹰眼抵消闪避。
- [x] 全部回归与原生运行验证；更新最终文档并打开游戏。

