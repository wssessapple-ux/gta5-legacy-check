# GTA5 老版本环境体检 + Simple Trainer 按键编辑器

两个 PowerShell 脚本：

- **`Check-GTA.ps1`** —— 扫游戏目录，把「版本对不上、必备文件缺失」一次列清楚。
- **`Edit-Keys.ps1`** —— 给 `trainerv.ini` 换键：列表里选一行，按一下键盘就绑上，不会改坏其它内容。

适用场景：GTA V 老版本（1.0.463.1 一类），装了 ScriptHookV、ASI Loader、OpenIV、修改器之后，**进游戏没反应 / 按 F3 没菜单 / 一加载就崩**，又不知道是哪一环出的问题。

**不想看代码？** 去 [Releases](https://github.com/wssessapple-ux/gta5-legacy-check/releases/latest) 下 `gta5-legacy-check-v0.3.0.zip`，解压到任意文件夹，然后把游戏目录拖到 `Check-GTA.cmd` 上。

**不会命令行？双击就行：**

- **`Check-GTA.cmd`** —— 把游戏文件夹拖上去，或者双击后在窗口里粘贴路径，回车。
- **`Edit-Keys.cmd`** —— 把 `trainerv.ini` 拖上去（放在脚本旁边也行），直接开界面。

**手动跑：**

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

## 按键编辑器 Edit-Keys.ps1

`trainerv.ini` 的按键全是 VK 十进制码（`MenuKey=114 //F3`），手改要查码表，还容易把注释和制表符搞坏。这个脚本只动 `[KeyBindings]` 段里等号右边那个数字。

```
pwsh -File Edit-Keys.ps1 -Ini 'D:\Games\Grand Theft Auto V\trainerv.ini'     # 开界面
pwsh -File Edit-Keys.ps1 -Ini ... -List                                      # 出表（117 项）
pwsh -File Edit-Keys.ps1 -Ini ... -Check                                     # 查共用键
pwsh -File Edit-Keys.ps1 -Ini ... -Set 'MenuKey=F4;MenuKeyCancel=Escape'      # 命令行直接改
```

界面里双击一行 → 弹「请按键」→ 按下去就绑上，黄色是未保存、红色是你改出来的冲突，保存前自动写 `trainerv.ini.bak`。

几个踩过的坑都写进脚本了：

- **写回保字节**：读原文拿换行符，用系统默认编码（GBK）写，测过 28438 字节的 ini 改一行后仍是 28438 字节，注释和制表符一个没动。
- **手柄项单独处理**：`Controller*` 存的是手柄码（201=A、202=B、187/188/189/190=十字键），不是键盘码。键盘 VK 里的 187/188/189 恰好是 `=` `,` `-`，混着翻译会彻底误导人，所以这类项改成手填数字。
- **共用键不当冲突报**：原版里 `LAlt`、`K`、`J` 是组合键前缀，小键盘 `96–105` 被菜单和一堆功能按上下文共用，全标冲突等于噪音。默认只报「你改出来的冲突」，`-Check` 才列出全部共用组。

## 常见问题

**双击 `.ps1` 弹出记事本 / 一闪就没了？** 别双击 `.ps1`，双击同目录的 `.cmd`。`.cmd` 会自己挑 PowerShell、放开本进程的执行策略，不会改你的系统设置。

**提示「无法加载文件，因为在此系统上禁止运行脚本」？** 那也是双击 `.cmd` 就不会出现——它在启动时加了 `-ExecutionPolicy Bypass`，只影响这一次运行。

**输出里中文变成方块或问号？** 用 `.cmd` 启动就好。原因是我第一版踩的坑：PowerShell 7 输出 UTF-8 而中文控制台是 GBK，不改代码页必然乱码；内置的 5.1 输出 GBK，反而不能设成 UTF-8。两个脚本本身都存成 **UTF-8 with BOM**，否则 5.1 会把中文按 GBK 解，直接语法报错。

**没装 PowerShell 7 能用吗？** 能。`Check-GTA.cmd` / `Edit-Keys.cmd` 会先找 `pwsh`，找不到就用系统自带的 Windows PowerShell 5.1，实测两个都在 5.1 下跑通。

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
