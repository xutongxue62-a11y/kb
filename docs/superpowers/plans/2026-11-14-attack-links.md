# v0.2 Attack Links Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Inline execution continues under the user's current corrections.

**Goal:** 近身固定远程、仅二联动/可关闭、有代价的符火与锁链攻击、有声音的演示。
**Architecture:** Rules/Catalog 定义挂点和配方，Main 驱动炮弹/链条状态，SFX 限声部播放，Hud 明示收益与损失。
**Tech Stack:** Godot 4.7.2 / GDScript / 原创 WAV / Movie Maker / PyAV.
**Spec:** ../../design_v0.2.md

## Global Constraints
- 只两两联动，可关闭，不能纯强化。
- 远程不随环绕相位公转，全部武器靠近角色。
- 六槽、当前画风和四肢协调运动保持。
- 不消耗武器/等级，锁链关闭先收回；保留旧文件。

## Review Focus
- 第三件装备不能追加隐藏的三联动。
- 关闭/重开不能丢武器或留悬空链条。
- 远程瞄准不能成为公转。
- 配方代价必须真正抑制伙伴独立攻击/普通炮弹。
- 声音特效不能无限叠加，暂停冻结战斗。

## Task 1: 规则
- [ ] 回归先 RED：挂点固定、近身、仅二件、可关闭、有代价。
- [ ] 实现挂点与配方并恢复 GREEN。
## Task 2: 攻击
- [ ] 符火弹、短灼烧、锁链出击/回收与安全切换。
- [ ] 真实场景检查弹丸字段、返回、暂停与清理。
## Task 3: 声音
- [ ] 原创限幅短 WAV、限声部 AudioPool、命中/爆炸/锁链/施法接入。
## Task 4: 验证
- [ ] 全套检查、独立审查、引擎画面与音轨检查。
- [ ] 更新文档，交付新版启动入口和有声音演示。
