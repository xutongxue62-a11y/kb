# Shop Boss Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans and dispatching-parallel-agents for independent modules. Steps use checkbox (`- [x]`) syntax.

**Goal:** 完成Boss/金币商店/放慢经验/去圈/十武器/菜单与真实存档，并打开试玩。
**Architecture:** SaveStore和Armory独立实现；Main整合关卡/商店/存档，HUD呈现菜单/商店/帮助/设置，Economy提供价格和合法库存。
**Tech Stack:** 现有Godot4.7.2/GDScript/SVG，无新依赖。
**Spec:** docs/superpowers/specs/2026-11-14-shop-boss-save-design.md

## Global Constraints
- 最多6武器；原两两联动及代价保留，原素材文件不替换。
- 普通关30秒，Boss不限时，结算只进商店，无免费过关成长。
- 测试存档注入runtime/tests；试用/演示不覆盖玩家存档。
- 不动无关工程/应用；已保存v0.5快照。

## Review Focus
- 同帧死亡/过关/Boss击杀必须保留死亡，商店期间无攻击/计时。
- 购买无钱/售罄/满槽/满级不能扣款或卡死；治疗不超上限。
- 读档不能丢金币/等级/商店售罄状态；损坏存档不能让首页崩溃。
- 新武器统一走实际伤害管线并尊重暂停；十种池不突破六槽。
- 去常驻圈后，攻击范围预警依旧真实；中文菜单不溢出。

### Task 1: 独立存档和新武器（并行）
Files: src/save_store.gd,tests/test_save_store.gd; src/armory.gd,src/weapon_art.gd,tests/test_armory.gd.
- [x] 各自失败回归后实现固定接口，独立测试通过，不改共享源文件。

### Task 2: 商店、Boss和存档整合
Files: src/main.gd,src/economy.gd,src/catalog.gd,src/progression.gd,src/asset_library.gd,tests/test_campaign.gd.
- [x] 写过关/金币/购买/Boss/存档的失败测试。
- [x] 实现战斗→商店→下一关，经验放慢与金币掉落。
- [x] 接入独立模块和Boss行为/血条；真实恢复关卡、商店和装备。

### Task 3: UI和去圈
Files: src/hud.gd,src/actor_view.gd,src/dino_view.gd,src/companions.gd.
- [x] 首页/暂停/玩法/按键/属性/设置及商店可点击，存档状态清楚。
- [x] 移除三种常驻脚下圈，收敛轮廓与顶部标记，保留真实预警。

### Task 4: 验证与交付
- [x] 更新受新规则影响的旧回归、加入新组，运行全部测试。
- [x] 独立只读审查，修复实质问题；原生截图并查看布局。
- [x] 更新README/设计/验证与进度，原素材哈希核对，打开实际版本供玩。

