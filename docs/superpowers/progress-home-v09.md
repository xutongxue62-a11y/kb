# v0.9 执行记录

- 用户明确要求先改首页，暂不重做战斗HUD；另修精英红圈与宝箱拾取。
- 当前工程比v0.8快照多出精英预算/蛋形敌人/宝箱逻辑；以当前202文件快照为基线，避免覆盖其他AI已有修改。快照路径见docs/home_v09_baseline.json。
- 首页旧悬停来自ui_button_fx.gd的角框与下划线；旧title按钮为完整矩形StyleBoxFlat。宝箱offer_elite_chest直接chest_queue+=1，地面标记未参与收集。
- 当前原生v0.8窗口PID20008保留，无输入发送。音频输入能力不可用，不声称主观听音。
- 使用dispatching-parallel-agents：root只改首页/转场/整合，音频与游戏拾取/精英为独立文件域。无Git仓库，以快照保存当前版本。

- Task1 complete：首页RED16checks13failures，加入HomeAction/HomeStage后GREEN28/0。原生检查发现旋转武器可贴到脚，扩大椭圆到205×193；旧矩形/角框仅在首页移除，其他界面布局不动。新背景用内置image_gen提取空场景，实际选中文件及完整提示词见docs/home_v09_notes.md。
- 返回曲面首次RED43/1，最终动效79/0；首次独立命令忘设APPDATA而触发沙盒数据目录错误，该日志不算干净GREEN证据。正式runner设置APPDATA/runtime后完整通过。初次HomeAction的icon成员与Button原生成员冲突已改为paper_icon；原生与最终全套无编译错误。
- Task2 complete：v09为7种短促模态弹拨/敲击，112音频检查通过；新旧A/B试听保留。模型不支持音频输入，未评判音色是否好听。
- Task3 complete：精英用atlas边界红描边、蛋沿壳轮廓，无装饰圈；宝箱接触28px收集立即移除，奖励与地面箱可存读/跨关，旧档兼容。初始RED22/17，GREEN28/0。
- Final read-only review found1P2：敌人可在英雄可达区域外死亡，箱子可能不可达。新增12位置死亡/旧档恢复回归RED88/48，统一掉落/恢复落点与英雄移动边界后GREEN88/0。无其他阻塞发现。
- Task4 complete：正式最终runner17groups1435checks0failures，无ERROR/SCRIPT ERROR/Parse Error/FAIL。原生v2流程0失败、无运行/渲染错误；467frames/30fps/15.567s，实际混音peak0.223724/RMS0.006216，首页前3.2秒音轨0。已查看11张过程图和不同时刻首页、返回、燃烧/精英/宝箱；v1死亡FX因暂停遮挡箱，v2正常推进后确认清晰。证据docs/home_v09_verification.json。
- 重启前与202文件快照对照：38个旧素材、4个基线runtime JSON哈希不变；旧预览/音效/快照保留。测试与录像全部注入独立数据。
- Ruling: 完成后对本任务旧v0.8窗口正常重启 — 同工程新版需要重新载入，先正常关闭保存再打开，避免两个版本竞争同一存档；核对PID20008、完整路径/标题后仅CloseMainWindow，观察正常退出，无强杀。
- v0.9已按正常玩家路径打开：exec session64967，桌面只读核对PID20988、标题原始人大作战 · 灵动首页 v0.9 (DEBUG)、句柄2164338、正确工程引擎路径。logs/play_v09.log无错误，窗口保留，无后续输入。
