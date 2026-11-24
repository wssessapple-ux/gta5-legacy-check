# GTA5 老版本环境体检

一个 PowerShell 脚本，把你游戏目录里「版本对不上、必备文件缺失」的坑一次性列清楚。

适用场景：GTA V 老版本（1.0.463.1 一类），装了 ScriptHookV、ASI Loader、OpenIV、修改器之后，**进游戏没反应 / 按 F3 没菜单 / 一加载就崩**，又不知道是哪一环出的问题。

```
pwsh -File Check-GTA.ps1 -GameDir 'D:\Games\Grand Theft Auto V'
```

输出是分级结论：`[X] 致命` / `[!] 隐患` / `[i] 信息` / `[OK]`，每条都带「怎么修」，退出码 `2/1/0` 便于脚本判断。加 `-OutFile report.md` 出中文报告，`-Json` 出机器可读结果。

## 它检查什么

| 检查 | 判断依据 | 为什么重要 |
|---|---|---|
| GTA5.exe 版本 | 文件版本资源 | 所有后续结论的基准 |
| ScriptHookV.dll | 版本号 + 大小 | 版本与游戏不一致时，asi 根本不加载，或进游戏直接崩 |
| 版本配套 | exe 版本 vs dll 版本逐段比对 | 这是老版本玩家最常错的一环 |
| dinput8.dll | 是否存在 | ASI Loader，缺了所有 `.asi` 都不生效 |
| mods 目录 | 是否有 `OpenIV.asi` | 有 mods 没 OpenIV.asi，替换内容等于没装 |
| OpenIV.log | 日志里的 Game version | 和当前 exe 交叉核对，识别「日志是旧的」 |
| 修改器 | `.asi` 名单 + 自报版本串 | 例如 Simple Trainer 1.9 配 1.0.505 之后的版本基本不可用 |
| ScriptHookV.log | 是否存在 | 崩了之后这是第一手线索 |

脚本不验哈希、不写文件、不联网——只读游戏目录。

## 版本矩阵

`versions.csv` 是参照表。**只有 `1.0.463.1` 是本机实测过的**（依据是 OpenIV.log 记录），其余按「ScriptHookV 构建名 = 游戏版本号」这个约定整理，供定位用，不作哈希校验：

| 游戏版本 | 对应 ScriptHookV | 修改器现状 |
|---|---|---|
| 1.0.393.4 | 1.0.393.4 | Simple Trainer 1.9 可用 |
| **1.0.463.1** | **1.0.463.1** | **Simple Trainer 1.9 可用（本仓库实测）** |
| 1.0.505.2 | 1.0.505.2 | 1.9 后期版本勉强可用 |
| 1.0.678.1 | 1.0.678.1 | 需当代修改器 |
| 1.0.1032.1 | 1.0.1032.1 | 需当代修改器 |
| 1.0.2060.0 | 1.0.2060.0 | 需当代修改器 |
| 1.0.2845.0 | 1.0.2845.0 | 需当代修改器 |

完整表见 `versions.csv`（24 个版本）。要新增一行，直接在 CSV 末尾加，脚本会自动命中。

## 最小可运行组合

从零到「进游戏按 F3 出菜单」，顺序别乱：

1. **GTA5.exe** 确认版本（脚本第一行就告诉你）
2. **ScriptHookV.dll** —— 版本必须与游戏一致，去 dev-c.com 下对应历史构建
3. **dinput8.dll** —— Ultimate ASI Loader，改名后放根目录
4. **修改器 .asi** —— 例如 `TrainerV.asi`，与游戏版本同期
5. （可选）**OpenIV.asi + mods/** —— 要换 rpf 资源才需要
6. （可选）**修改器的 ini** —— 例如 `trainerv.ini`，按键与字体设置都在里面

前 4 步缺任何一环，表现都是「进游戏像什么都没装」。

## 常见症状对照

| 现象 | 大概率原因 |
|---|---|
| 进游戏完全没反应，按 F3 无菜单 | ScriptHookV 版本不对，或没有 dinput8.dll |
| 加载故事模式直接崩 | 修改器版本与游戏不匹配；或某条被改坏的串（见下方项目） |
| 菜单能开但显示方块 | 字体只有繁体字形，写简体码位必然方块 |
| 装了 mods 但游戏里没变化 | 缺 `OpenIV.asi`，或 rpf 没带 `{M}` 标记 |
| 改完 ini 没效果 | 有些项要游戏内菜单重载，有些要重启 |

## 局限

- **不验哈希**：文件可以被重新打包，只靠版本号判断会漏。需要严格校验的话用具体项目的校验脚本（见下）。
- 破解版 `GTA5.exe` 常常没有版本资源，脚本会标 `[!]` 而不是硬猜。
- `mods` 里的 rpf 是否真的带 `{M}`，得看 `OpenIV.log`，脚本只能提示不一致，不能替你验证内容。

## 相关项目

- **[simple-trainer-1.9-zh-community](https://github.com/wssessapple-ux/simple-trainer-1.9-zh-community)** —— 同作者的 Simple Trainer 1.9 中文菜单工具（偏移表 + 打补丁 + 逐字节校验）。那边演示了「字符串层面的严格校验」长什么样。
- **[TACZ-Legacy](https://github.com/wssessapple-ux/TACZ-Legacy)** —— 同作者的 Minecraft 1.12.2 模组移植项目。

## 免责

- 单机自用。带 ScriptHookV 上 GTA Online 违反 Rockstar 服务条款，封号与此无关但风险自负。
- 本项目与 Rockstar Games、Alexander Blade（ScriptHookV）、OpenIV 团队均无关联。
- 脚本只读取文件，不修改任何内容；判断结论供参考，最终以游戏实际表现为准。

## License

MIT（见 `LICENSE`）。
