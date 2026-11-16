# Playtest Feedback and Buffs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成六项试玩反馈、独立属性和伙伴成长，打开可玩版本供用户体验。

**Architecture:** 复用现有场景及全部资源；新增纯规则 growth.gd 和跟随支援 companions.gd，main.gd 负责战斗接入，hud.gd 负责选择和属性，effects.gd 负责受击信息。

**Tech Stack:** 已附 Godot 4.7.2 / GDScript，原生绘制，不新增依赖。

**Spec:** `docs/superpowers/specs/2026-11-14-playtest-buffs-design.md`

## Global Constraints
- 六武器、远程固定身旁、可选且有损失的两两联动，保留原始人与恐龙画风。
- 默认弹弓，允许木棒；三波各 30 秒，暂停/选择不计时，致死伤害先于胜利。
- 非武器成长不占武器槽；全部旧图片与录像保持不变。
- 非 Git 工程使用已保留的快照，不运行 Git 写操作；进度记录留在 docs/superpowers。
- 测试以工程内 Godot console 运行，APPDATA/LOCALAPPDATA 指向 runtime，日志仅写 logs。

## Review Focus
- 六武器满槽且多种 Buff 满级：选项仍然有效，不会卡在成长面板。
- 同一帧击杀/升级/波次奖励/致死：不丢免费奖励、不覆盖死亡、不重复扣经验。
- 穿透和弹射对同一目标：不重复命中、不漏失新弹丸，不影响火药爆炸。
- 重开、F2、暂停和 B 面板：清除支援、经验石和临时效果，正确恢复计时和音频。
- 成长卡和属性列表：中文不溢出，手动选卡与键盘 1/2/3 行为一致。

### Task 1: 独立成长规则
**Files:** Create `src/growth.gd`, `tests/test_growth.gd`.
**Interfaces:** `Growth.stats(levels: Dictionary) -> Dictionary`; `Growth.apply(levels, id) -> bool`; `Growth.choices(inventory, levels, rng) -> Array`; `Growth.BUFFS`。
- [ ] 先写并运行缺失功能的失败测试。
- [ ] 实现三级属性/二级穿透弹射、成长合法性与混合选项。
- [ ] 重跑 growth，确认无失败，记录结果。

### Task 2: 实际战斗和反馈接入
**Files:** Create `src/companions.gd`, `tests/test_feedback.gd`; modify `src/main.gd`, `src/effects.gd`, `src/catalog.gd`.
**Interfaces:** `main.apply_buff(id) -> bool`; `main.set_start_weapon(id)`; `main.toggle_stats()`; `companions.advance(delta, player_position, enemies, levels, stats, prefer_elite) -> Array`; effects 飘字与命中保留真实数据。
- [ ] 新场景测试先因方法未实现而失败。
- [ ] 接入伤害/暴击/减伤/移速等属性、经验石、穿透/弹射和两个跟随伙伴。
- [ ] 更新弹丸区分、伤害数字、爆炸/命中、三波与免费补给。
- [ ] 更新旧场景/完整回合测试的已改变约定：默认弹弓、90 秒；其余旧回归保留。
- [ ] 运行反馈与全部既有测试，记录结果。

### Task 3: 操作界面、验证和试玩交付
**Files:** Modify `src/hud.gd`, `README.md`, `docs/verification.md`; create `docs/design_v0.3.md`, `tools/run_tests.ps1`.
**Interfaces:** 保留现有信号；新增开局选择和属性面板信号；`hud.update_growth(levels, stats, wave)` 显示实际属性。
- [ ] 场景测试覆盖真实开局按钮、Buff 卡、B 面板和暂停/恢复。
- [ ] 卡片明确“武器/属性/支援”和提升数值，加入 Buff 属性列表及支援图例。
- [ ] 最终运行四组旧测试和两组新测试，原生窗口查看开始/升级/属性及实际战斗。
- [ ] 按 requesting-code-review 派发一次只读审查；修复实质问题后重跑相关与全部测试。
- [ ] 核对 assets 哈希未变，更新验证记录，再使用正常启动脚本打开给用户，保留窗口。
