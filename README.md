# 原始人大作战 · 荒野交锋

手绘羊皮纸风格的生存战斗游戏。移动躲避、自动攻击，收集金币与经验，选择宝箱奖励，在营地购买和更换武器。

## 下载 v0.25.0

无需安装 Godot，下载对应平台的发行包即可。

| 平台 | 下载 | 开始游玩 |
| --- | --- | --- |
| Windows 64 位 | [下载 Windows ZIP](https://github.com/xutongxue62-a11y/kb/releases/download/v0.25.0/PrimitiveWildfrontier-v0.25.0-Windows-x64.zip) | 完整解压后运行 `PrimitiveWildfrontier.exe`，保留旁边的 PCK 文件 |
| Linux x86_64 | [下载 Linux tar.gz](https://github.com/xutongxue62-a11y/kb/releases/download/v0.25.0/PrimitiveWildfrontier-v0.25.0-Linux-x86_64.tar.gz) | 解压后运行 `启动游戏.sh` 或 `PrimitiveWildfrontier.x86_64` |
| Android 7.0+ ARM | [下载安卓 APK](https://github.com/xutongxue62-a11y/kb/releases/download/v0.25.0/PrimitiveWildfrontier-v0.25.0-Android.apk) | 安装 APK，横屏游玩 |

[查看全部版本](https://github.com/xutongxue62-a11y/kb/releases) · [当前发布页](https://github.com/xutongxue62-a11y/kb/releases/tag/v0.25.0) · [SHA-256 校验文件](https://github.com/xutongxue62-a11y/kb/releases/download/v0.25.0/SHA256SUMS.txt)

## 本版更新

- 新增七个角色专属天赋，调整角色选择提示、武器成长和附魔平衡。
- 扩展后期怪物和 Boss 招式，改善战斗飘字，加入红描边精英的宝箱保底。
- 支持三个独立存档位，兼容旧档，并调整商店保底、高级武器价格和战斗回血。

## 操作

- 电脑：WASD／方向键移动，自动攻击；Shift 闪避，Esc 暂停，B 查看属性，空格切换阵型，Q 打开武器背包拖拽联动，E 切换目标优先，F5 保存。
- 安卓：左侧摇杆移动，右侧按钮闪避，其他功能点击游戏内按钮。
- 装备最多六把武器；宝箱可领取一份奖励，也可出售选中的奖励换金币。营地可购买、强化及更换武器。

## 试玩说明

当前为开发中的 v0.25.0 试玩版本，支持离线游玩。自动更新服务尚未启用。

旧版玩家请手动下载新版；安卓可直接覆盖安装，保留应用数据。

Windows 已完成实际启动、画面及触控输入模拟检查；Linux 已完成导出、架构和执行权限检查；安卓已完成 APK 签名、资源和架构检查。Linux／安卓仍需对应设备试玩确认。

发现问题可在本仓库的 Issues 说明平台、游戏版本和复现步骤。

## 源码

本仓库已包含游戏源码。用 [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) 打开根目录的 `project.godot`，即可直接修改美术、系统与 UI。

- 也可双击 `启动样板.cmd`，或在编辑器中运行主场景试玩。
- 回归测试：`tools/run_tests.ps1`。
- 仓库不包含 Godot 编辑器、导出模板、本地缓存（`.godot/`）、玩家存档（`runtime/`）、预览视频和签名私钥。
- 历史开发记录见 `docs/`。