# SDD ledger — plan: docs/superpowers/plans/2026-11-14-six-weapons.md

Ruling: 用户“你自己设计一下，下一步”授权本轮样板实现；采用本会话 inline 执行，不重复询问执行方式。
Ruling: 父目录不是 Git 仓库；新建独立原始人大作战_Godot_v0.1 工程，旧灰模不动。
Ruling: 六武器按同时六槽解释，初始仍一把；六件清单和具体联动是本轮设计方案。
Pre-flight: Task 1 的 gait_pose 由 Task 2 消费，equip/target/combo 由 Task 3 消费，函数名以本计划为准。
Task 1: complete — 规则先 RED，后 49/49 GREEN。
Task 2: complete — 五个独立角色部件、四恐龙和六武器透明 atlas；只读分析生成区域，不改 PNG。
Task 3: complete — 场景先 RED，后 18/18 GREEN；键盘事件与完整 60 秒模拟另有 10/10 GREEN。
Review: 独立只读审查发现最后一帧弹丸死亡会被胜利覆盖。回归先 17 checks / 1 failure，增加弹丸阶段结束后的退出检查后通过。
Ruling: Godot 用本工程 runtime 目录作为进程级 APPDATA/LOCALAPPDATA，避免改写其他应用数据。
Ruling: 本机 ffmpeg CLI 连版本查询也无输出；不修改该工具，改用已存在的 PyAV/libx264 编码引擎 AVI。
Task 4: in progress — 引擎已录出 390 帧动作与 660 帧战斗，正在编码、画面核对和交付记录。
