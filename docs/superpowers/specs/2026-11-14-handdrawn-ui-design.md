# 手绘 UI 接入设计

2026-11-14。用户已审阅首页 v02、选人页、设置/继续弹窗与燃烧关键帧，并明确要求在现有游戏中完成接入后打开试玩。沿用当前磁盘工程；不重新确认已授权方向。

- 首页直接进入选人页；保留原始人大作战名称及已认可的深蓝/米白/砖红手绘风，英雄及恐龙继续用现有素材。文字/按钮使用真实 Godot 控件，不把整张概念图当可点击界面。
- 选人页有前后箭头、角色计数、默认弹弓和现有技能说明。当前只有一个角色时箭头可见但禁用；角色目录增多时按目录切换。不新增虚构角色和武器。
- 设置和单份继续存档弹窗使用一致的卷轴纸面；显示真实存档摘要，禁用/失败状态保持准确，返回恢复打开前页面。继续、保存与自动存档仍使用现有 SaveStore。
- 左到右的卷轴展开用于选人、常用弹窗、经验/Buff三选一及营地商店。燃烧仅用于确认出发这样的重要切换，不每个页面播放。
- 确认出发初始化战斗后约2.4秒准备缓冲，显示3/2/1；期间不推进战斗计时、移动、攻击、刷怪与伤害，重复点击不会重开。直接测试用 start_run 接口保持立即初始化；真人 UI 入口走准备流程。继续旅程同样先缓冲。
- 保留旧图片、预览、源码快照、玩家存档及现有战斗/商店/Boss功能；所有测试/截图使用 runtime/tests 独立存储。
- 独立绘制的纸张与卷边/焦边保持高度2D，无门、写实人体或无关新场景。保持1280×800原生视口。
- 验证覆盖页面路由、单角色箭头、弹窗返回、真实存档摘要、准备期冻结、重复确认、现有12组回归以及原生引擎图像和实际UI操作。

Approaches: considered using static full-screen image hotspots versus native controls with reusable paper/transition drawing. Use native controls plus one clean background plate: controls stay readable, real save data stays live, and animations remain editable. The current project is not a Git repository, so use the preserved snapshot rather than creating a new repository or worktree.

