# v0.8 动效与音效 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for root integration; applicable superpowers:dispatching-parallel-agents delegates isolated audio and weapon spacing domains.

**Goal:** 让页面、弹窗、卷轴和燃烧在实际运行中明显不同，替换难听的UI音效，改善按钮和武器可读性。
**Architecture:** UITransition负责真正二维烧蚀及轻翻页/淡入，Paper负责不同展开轴和卷轴端帽，ButtonFx负责墨线反馈。UIAudio独立维护音色/冷却/声部。现有Main控制流程与存档保持。
**Tech Stack:** Godot4.7.2、GDScript CanvasItem绘图、Python波形生成、Godot Movie Maker与PyAV。
**Spec:** docs/superpowers/specs/2026-11-15-ui-motion-audio-design.md

## Global Constraints

保留玩家存档/旧素材/旧预览；单角色默认弹弓；音频仅测量不等于听感；动画必须用原生动态录制核验，不能只用截图证明节奏；依赖已有引擎与Python库，无新增下载。

## Review Focus

- 页面的动画类型不得又都归为横向擦除。
- 燃烧必须在正常出发触发且产生二维扩散轮廓，不能只是细线。
- 卷轴及弹窗的裁切区域和输入锁必须一致，不能穿透点击。
- UI声音各语义只播放一次，悬停静音，不能叠加旧音。
- 武器瞄准/枪口/发射位置使用同一挂点，近身目标仍可命中。

### Task1 独立子任务（并行）
- [x] audio agent: 新音效与UIAudio、技术QC与41项回归；不动HUD和旧素材。
- [x] weapon agent: rules挂点及真实精灵/碰撞回归；不动Main和HUD。

### Task2 根代理UI/动效
- [x] 新建test_ui_motion.gd，观察原版缺少分型、二维烧蚀、真实卷轴/箭头反馈失败。
- [x] 修改ui_transition.gd、ui_paper.gd，新增ui_button_fx.gd；几何有效、纹理UV正确。
- [x] HUD/UIFrontend接入不同语义、动画及新声音；重做箭头和选人武器间距，避免改已认可的主体画风。

### Task3 整合与验收
- [x] 合并音效/间距子任务，导入新WAV，完整回归。
- [x] 原生窗口实际点击并录制动态/混音演示，检查多帧烧蚀、卷轴、按钮、弹窗和战斗挂点。
- [x] 独立只读审查，处理重要发现，记录素材和玩家存档哈希保留。
- [x] 打开新版供用户试玩，提供试听/动态演示，不声称主观听感已验收。

