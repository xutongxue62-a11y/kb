# v0.9 灵动首页接入记录

2026-11-15。优先修改首页；选人、成长、营地和战斗HUD布局沿用现有版本，等待用户下一轮反馈。

## 已接入

- 首页四个操作使用斜切、缺口纸片，真实命中区域跟随纸片；保留键盘焦点和可访问文本。悬停仅轻抬/明暗/阴影变化，无角框和长下划线，按下短压。
- 首页纯视觉舞台复用原主角、六武器和六个怪物素材：武器椭圆旋转，角色呼吸，怪物独立小跳、摆动，轻微鼠标视差。离开首页整棵舞台回收，不推进关卡或写入进度。
- 返回转场采用20条曲面纸带、正弦缓入缓出和渐隐，0.58秒；不把整个页面快速压成一条线。出发仍为中心烧穿，增加48组分层火舌、微烟、余烬和翻面纸灰，1.08秒；成长仍为卷轴。
- 7种UI声音改成短促衰减弹拨/敲击，保留语义、独立冷却、4声部与悬停静音。实际增益峰值为-14/-14/-15/-15/-15/-20/-13 dBFS，长度60/130/200/300/95/460/150ms。新素材在assets/sfx/ui_v09/，旧素材保留。
- 精英用贴合透明轮廓的红边，蛋沿蛋壳真实轮廓描红，移除装饰性红圆环；真实攻击预警保留。
- 精英死亡只掉地面箱，英雄接触28px内才收集；地面箱立即消失，之后打开奖励，一次奖励。暂停/成长/商店/出发期间不拾取；未捡箱跨关保留。地面箱和已收集待领奖励均可存读，旧档可读。新箱和旧档恢复的箱均限制在英雄可达范围，防止场外/边缘掉箱无法捡。

## 原生证据与边界

- tools/run_tests.ps1：17组1435项、0失败。动效79、音频112、首页28、宝箱88项，另保留原战斗/经济/存档/导航回归。
- 独立只读审查发现1项P2：场地边缘掉箱不可达。12种边缘/角落/场外死亡与旧箱恢复夹具先失败（88checks/48failures），修复后88/0，随后全套通过。
- previews/home_v09_native_v2.mp4：1280×800，30fps，467帧，15.567秒，双声道48kHz实际引擎混音；峰值0.223724、RMS0.006216，无削波。首页静置与悬停前3.2秒音轨峰值为0。音轨测量不能证明听感，本轮模型不支持听音。
- tests/capture_home_v09.gd 用实际鼠标输入事件导航、返回与出发，并通过正常simulate移动走到宝箱；logs/v09_native_v2.log流程0失败、无运行/渲染错误。11张过程图已检查：首页静置/旋转后/悬停、返回曲面、燃烧多帧、蛋与实体精英红边、远处宝箱、拾取后的奖励和空地。v1图中死亡特效被暂停所以遮挡箱子，v2改为正常推进后确认箱子可见；v1保留。
- 测试/录像均注入独立runtime/tests。正常试玩重启前，38个旧素材与4个基线JSON文件哈希与202文件快照一致；快照位置见home_v09_baseline.json。原图片、旧声音、旧演示未改写。
- 在确认旧窗口PID20008及其工程路径/标题后，仅发送正常关闭事件并观察退出，再启动同工程正常玩家路径v0.9；只读桌面进程核对PID20988、标题“原始人大作战 · 灵动首页 v0.9 (DEBUG)”、句柄2164338。保留新版窗口，无后续输入。

## 试听与演示

- previews/home_v09_native_v2.mp4：原生有声演示。
- assets/sfx/ui_v09/ui_v09_preview.wav：仅新版7种音效。
- assets/sfx/ui_v09/ui_v08_v09_ab_preview.wav：每种动作先旧版、后新版，确切时序见同目录README.txt。
- home_v09_verification.json：机器可读回归、素材保留和原生核验。

## 新背景与完整提示词

使用内置image_gen编辑，未使用CLI/API备用路径。原图assets/ui/title_arena_clean_v01.png保持，选中结果复制为assets/ui/title_empty_v09.png；生成原件仍留在Codex generated_images。背景是空场景，画面人物和武器来自现有素材实时绘制。

完整提示词：

> Use case: precise-object-edit / clean background plate. Edit the supplied 2D hand-painted game title illustration for production layering, not a new composition. Remove ALL foreground actors and equipment: the central caveman and all body parts, every dinosaur, all six weapons, all coins and green crystals, all weapon swipe trails, dust puffs, stars, speed marks and object drop shadows. Reconstruct the missing areas as the same warm ivory ochre parchment floor with subtle grain, sparse tiny grass tufts and small flat rocks. KEEP the left dark ink-navy empty menu region and its torn diagonal brush boundary, KEEP overall composition, palette, paper texture and corner foliage/rocks exactly in the same flat hand drawn style. Maintain wide 16:9 framing. Right three quarters must become an open empty arena suitable for animated character sprites on top, leave the central area uncluttered. Absolutely no characters, no weapons, no props for items, no coins, no gems, no shadows of removed objects, no text, no UI, no decorative swirls. This is an editable-game background extraction; do not redesign or add architecture, mountains, doors, scenery beyond the original sparse grass/rocks.
