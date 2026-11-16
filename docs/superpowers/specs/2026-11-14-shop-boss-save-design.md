# v0.6 关卡商店、Boss、武器与存档

用户最新要求：Boss关不限时或延长；取消免费过关成长；金币掉落与每关商店；升级放慢；移除角色蓝圈/敌人红圈；丰富武器；完善UI、开始、玩法、按键、属性与存档设置。已授权直接实现并再次打开试玩。

## 已选方案
- 普通关30秒；每5关Boss，不限时间，必须击杀才结束。关卡无限推进。Boss有独立血条、冲锋和有预警的范围攻击。
- 普通关/Boss结束后打开营地商店，战斗完全暂停，收集剩余掉落。没有免费过关升级或自动送装备。
- 普通敌人掉经验和金币，精英/Boss金币更多。商店用金币买武器/升级、Buff/伙伴或治疗。已买标记售罄，钱不够不能购买；不自动扣经验、不白送治疗。
- 首次升级需8经验，之后8+玩家等级×3；经验升级保留原有三选一。一次最多6把武器，武器等级仍5，Buff上限保留。
- 新增骨矛定向贯刺、石槌范围重击、回旋骨镖往返、雷鸣图腾连锁攻击。原6种与新4种共10种；F2基础六武器，F3新武器试用，试用模式不覆盖正常存档。
- 移除主角、怪物和伙伴常驻脚下圈，保留克制轮廓、主角顶部标记、伙伴十字和敌人血条。功能性的攻击预警/爆炸范围仍对应真实攻击。
- 开始页包含开始游戏/木棒开局、继续存档、玩法说明、按键/属性、存档设置。B显示角色实际数值；Esc暂停页可保存、回首页和继续。
- 自动存档可开关，在进商店/购买/离开商店保存；F5手动保存。保存当前关卡、计时、血量、金币、经验、装备/Buff、敌人剩余生命和掉落。恢复时清理飞行攻击并给短暂保护，避免读档瞬间受伤；不承诺逐帧复现。
- 保存失败须提示，不把失败当成功。JSON带版本，写临时文件后替换，保留上一有效备份；读取校验，损坏时尝试有效备份。死亡记录结束本局，保留文件但首页不继续已结束局。
- 全部旧原图、音效、录像、代码和快照保留。新武器图标用代码内SVG绘制，无需重画现有美术。

## 固定接口
SaveStore（src/save_store.gd）：new(storage_dir="user://saves")，write_run(state)->{ok,error}，read_run()->{ok,state,error,recovered?}，has_run()->bool，read_settings()->Dictionary，write_settings(settings)->{ok,error}。settings.autosave默认true；state.finished禁止继续，state.version=1。

Armory（src/armory.gd）：Node2D，reset()；advance(delta,hero,enemies,inventory,stats,prefer_elite,views)->Array。只处理spear/hammer/boomerang/totem，修改对应Sprite2D视图，返回命令：type=hit（enemy,damage,weapon_id,direction），area（position,radius,damage,weapon_id），beam（start,end,color）。伤害最后由main.hurt_enemy统一处理Buff/暴击。自身states保存冷却/飞行/刺击状态。

WeaponArt（src/weapon_art.gd）：static texture(key)->Texture2D，支持四个新ID，透明背景128方形、粗深色描边、大色块，复用内存纹理。

武器数据：spear伤害9/cd0.72/range185/size58；hammer16/1.4/140/50；boomerang4.5/1.05/300/speed540/size42；totem3.5/0.95/320/48；kind均special。catalog由主会话修改，Armory/Store代理不得修改共享源文件。

## 验证
测试真实金币拾取/购买扣款与售罄、无钱不买、过关没有免费成长、Boss超30秒不结束/击杀开商店、升级节奏、10武器不破坏6槽、实际新攻击、主菜单与属性/帮助、存档保存/恢复/设置与损坏备份。测试存档必须注入runtime/tests路径，不能覆盖玩家进度。原生截图检查菜单/商店/Boss/新武器和去圈后辨识；最终打开实际可玩版本。
