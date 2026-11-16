# 原始人大作战 · Godot 战斗样板 v0.1

日期：2026-11-14。当前原始人角色与简单平面画风沿用，六武器配置与二/三联动已接入一轮 60 秒战斗。

## 启动

在资源管理器中双击 [启动样板.cmd](启动样板.cmd)。已附 Godot 4.7.2 便携版，程序数据和日志写在本工程目录中。

- **正常开始**：一把木棒，击败恐龙获得经验，成长时三选一；选到同名武器则升级，最多同时六把。
- **六武器试用**：菜单按钮或 F2 直接开始六槽配置，便于比较武器与组合。
- [动作预览.cmd](动作预览.cmd)：独立放大演示原始人的静止、行走、停步与攻击回摆。

## 操作

| 操作 | 按键 |
| --- | --- |
| 移动 | WASD / 方向键 |
| 展开扫荡 / 收束集火 | 空格 |
| 优先三联动 / 两两联动 | Q |
| 最近目标 / 射程内精英优先 | E |
| 选择成长 | 鼠标或 1 / 2 / 3 |
| 六武器试用 | F2 |
| 暂停 / 继续 | Esc |
| 以当前正常/试用模式重开 | R |

## 动作与武器

主角保留一个圆润身体和四个分离手脚。运行时是五个独立精灵：脚随位移交替，手与同侧脚反相摆动，身体轻微起伏；停步归位，攻击时手部短促回摆。

六武器为木棒、石斧、骨刃、投石索、木质火药筒、魔法杖。前三件环绕近战，后三件自动远程。木质火药筒具有爆炸落点，魔法杖的散射覆盖随阵型改变。每把武器仍先独立检查射程并选目标。

两两组合：裂地重击、猎手追击、符火爆破。三件组合：碎骨震波、巫火齐射。原武器和等级保留；每把武器在同一模式只计入一组；联动伤害不能再触发联动。

具体清单、数值和 Q 切换入口是本轮样板设计，后续仍可根据试玩调整。

## 引擎录像

- [13 秒动作近景](previews/动作预览.mp4)
- [22 秒六武器战斗](previews/六武器战斗.mp4)

两段均由 Godot 实际运行后用 Movie Maker 录制，再转为 MP4。动作模式使用同一 ActorView；战斗录像为自动走位、免伤的展示模式，用来检查表现，不代表正常模式难度或手感已经验收。

## 验证与源码

[验证记录](docs/verification.md)区分自动检查、实际窗口观察和待试玩内容。

源码在 src/，测试在 tests/，制作计划与状态在 docs/。透明素材及[完整生成提示词](assets/generation_prompts.json)在 assets/；原始参考图和旧工程均未覆盖。武器 atlas 的柔和外缘通过运行时 alpha 材质处理，PNG 源文件不修改。

当前是首个战斗样板，不是完整发行版。完整长局、技能槽、支援、Boss、存档和音效尚未接入，数值与动作幅度仍需实际试玩调整。

## 开发检查

以本工程目录为 APPDATA/LOCALAPPDATA 运行，避免向其他应用目录写入：

```powershell
$env:APPDATA = Join-Path $PWD 'runtime'
$env:LOCALAPPDATA = Join-Path $PWD 'runtime/local'
$engine = './tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path . --log-file ./logs/rules.log --script res://tests/test_rules.gd
& $engine --headless --path . --log-file ./logs/scene.log --script res://tests/test_scene.gd
& $engine --headless --path . --log-file ./logs/controls.log --script res://tests/test_controls.gd
```

引擎来源：[Godot 官方 Windows 下载](https://godotengine.org/download/windows/)。录像方式：[Godot Movie Maker 官方文档](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)。本工程未发布到外部服务。
