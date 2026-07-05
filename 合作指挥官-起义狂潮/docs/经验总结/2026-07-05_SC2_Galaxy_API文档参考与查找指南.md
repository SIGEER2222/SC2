# SC2 Galaxy API 文档参考与查找指南

> 创建时间: 2026-07-05
> 更新时间: 2026-07-05（新增 mapster.talv.space 在线 API 参考）
> 背景: 在实现 `-setcolor` 指令时遇到 `PlayerSetColorIndex` 参数类型、`EventChatMessage` 参数缺失、`IntToText` vs `IntToString` 等问题，发现缺少官方 API 文档一直在抓瞎，整理可用的文档资源。

## 零、首选在线 API 参考：mapster.talv.space（强烈推荐）

**网址**: https://mapster.talv.space/galaxy/reference

这是 SC2Mapster 社区维护的 **最完整的 Galaxy API 在线参考文档**，由 `SC2Mapster/docs-generator` 工具从游戏数据自动生成。每个 API 页面包含：

1. **GUI 语法描述**（自然语言描述，如 "Set player **player** color to **color** (**changeUnits** the color of existing units)"）
2. **Flags** - `Native` / `Action` / `Function` / `Predicate` 等标识
3. **函数用途说明** - 文字描述函数做什么
4. **参数列表** - 带类型和预设（preset）链接，如 `int<playercolor>` / `bool<preset::ChangeRetainOption>`
5. **返回值类型**
6. **native 函数签名** - 完整声明
7. **Supported triggers** - 该函数支持哪些触发器事件
8. **Related** - 同分类下的所有相关函数列表（便于发现同类 API）

**比 natives.galaxy 的优势**：
- 有参数语义说明（natives.galaxy 只有类型，没有语义）
- 有 GUI 语法描述（便于理解参数含义）
- 有预设类型链接（点击 `ChangeRetainOption` 可查看所有可选值）
- 有相关函数导航（同分类函数一键跳转）
- 有函数用途说明

**覆盖范围**（53 个主分类，302 个子分类）：
```
Ability, Actor, AI, AI Advanced, Animation, Bank, Behavior, BitMask, Camera,
Catalog, Cinematics, Conversation, Conversion, Cutscene, Data Table, Debug,
Dialog, Effect History, Environment, Item, Game, Game User, General,
Leaderboard, Loot, Logic, Math, Melee, Objective, Order, Ping, Player,
Player Group, Point, Portrait, Region, Selection, Sound, Story, String,
Talent Tree, Tech Tree, Text Tag, Timer, Transmission, Trigger, UI, Unit,
Unit Group, Validator, User Data, Visibility, Template
```

**站点其他文档**：
- Scripting (.galaxy) - Galaxy 脚本 API 参考
- UI (.SC2Layout) - UI 布局参考（Frame types / Frame classes / Basic types / Complex types）
- Data (.xml) - GameData XML 参考
- Star Tools (.M3) - M3 模型工具参考

**使用示例**：
- 查找 `PlayerSetColorIndex` 完整说明：https://mapster.talv.space/galaxy/reference/player-set-color-index
- 查找 `EventChatMessage` 完整说明：https://mapster.talv.space/galaxy/reference/event-chat-message
- 浏览 Player 分类所有函数：https://mapster.talv.space/galaxy/reference#player
- 浏览 Unit 分类所有函数：https://mapster.talv.space/galaxy/reference#unit

**相关 GitHub 仓库**：
- https://github.com/SC2Mapster/SC2GameData - GameData/UI/Galaxy 源数据（已停止更新）
- https://github.com/SC2Mapster/docs-generator - API 参考生成器（已归档）

> 注：原 SC2Mapster Wiki (sc2mapster.com/wiki/galaxy/) 已下线 301 重定向到 CurseForge，但 mapster.talv.space 是其归档镜像，完整保留了 API 参考内容。

## 一、最权威的 API 来源：游戏自带的 natives.galaxy

**位置**: `E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod\base.sc2data\TriggerLibs\natives.galaxy`

这是 SC2 引擎原生函数的完整声明文件，包含所有 native 函数的签名（参数类型、返回类型）。

**查找方法**:
```powershell
# 查找某个函数的签名
Grep "native.*PlayerSetColorIndex" "E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod\base.sc2data\TriggerLibs\natives.galaxy"
# 输出: native void PlayerSetColorIndex (int inPlayer, int inIndex, bool inChangeUnits);

# 查找某类函数
Grep "native.*String" "...\natives.galaxy"
```

**常用函数签名速查**:
| 函数 | 签名 | 备注 |
|------|------|------|
| PlayerSetColorIndex | `native void PlayerSetColorIndex (int inPlayer, int inIndex, bool inChangeUnits)` | 第三个参数 true=同步改变已存在单位颜色 |
| EventChatMessage | `native string EventChatMessage (bool matchedOnly)` | **必须传 bool 参数**，false=返回完整消息 |
| TriggerAddEventChatMessage | `native void TriggerAddEventChatMessage (trigger t, int player, string inText, bool exact)` | exact=false 可前缀匹配 |
| StringToInt | `native int StringToInt (string x)` | 转换失败返回 0 |
| IntToString | `native string IntToString (int x)` | int → string |
| IntToText | `native text IntToText (int x)` | int → text（**不能拼接 string**）|
| StringSub | `string StringSub (string s, int start, int end)` | 1-based 索引，含两端 |
| StringLength | `native int StringLength (string x)` | |
| StringWord | 取第 N 个单词 | 替代不存在的 StringTrim |

## 二、SC2 触发器库源码（含封装函数）

**位置**: `E:\Code\MyMod\SC2\sc2-data-trigger\`

包含完整官方 mod 源码，可参考实际用法：
- `mods/core.sc2mod/base.sc2data/TriggerLibs/NativeLib.TriggerLib` - NativeLib 封装函数定义
- `mods/liberty.sc2mod/base.sc2data/TriggerLibs/LibertyLib.galaxy` - 自由之战库
- `mods/void.sc2mod/base.sc2data/TriggerLibs/` - 虚空之遗库
- `campaigns/swarmstory.sc2campaign/base.sc2data/TriggerLibs/SwarmCampaignLib.galaxy` - 虫群之战库
- `mods/missionpacks/novacampaign.sc2mod/base.sc2data/LibNovC.galaxy` - 诺娃战役库

**查找实际用法示例**:
```powershell
# 查找 PlayerSetColorIndex 的实际调用方式
Grep "PlayerSetColorIndex" "E:\Code\MyMod\SC2\sc2-data-trigger"
# 找到: PlayerSetColorIndex(1, libSwaC_gf_CampaignKerriganZergPlayerColor(), true);
```

## 三、本地 mod 库源码

**位置**: `E:\SC2\SC2new\StarCraft II\Mods\`

包含合作指挥官、战役等 mod 的源码：
- `StarCoop/StarCoop.SC2Mod/base.sc2data/libcooc.galaxy` - 合作模式库
- `StarCoop/StarCoop.SC2Mod/base.sc2data/libcomu.galaxy` - 合作通用库
- `RevolutionOverdrive.SC2Mod/Base.SC2Data/Lib6B3CCD85.galaxy` - 缝合 mod 库（皮肤替换参考）
- `crys_the_swarm_reborn.SC2Mod/Base.SC2Data/Lib48DF4533.galaxy` - 虫心重生 mod 库

## 四、社区文档资源（部分可用）

| 资源 | 链接 | 状态 | 说明 |
|------|------|------|------|
| **mapster.talv.space** | https://mapster.talv.space/galaxy/reference | **可用（首选）** | SC2Mapster 归档镜像，53 个主分类的完整 API 参考，见上方第零节 |
| SC2Mapster Wiki | sc2mapster.com/wiki/galaxy/ | 原站已下线 | 301 重定向到 CurseForge，但内容被 mapster.talv.space 归档 |
| 银河编辑器维基 | gewiki.huijiwiki.com | 有反爬 | 中文社区 wiki，需手动访问 |
| 《Galaxy 教程》PDF | book118.com / docin.com | 预览可访问 | 疯人￠衰人写的 96 页中文教程，涵盖语法基础（完整内容需 VIP） |
| Galaxy 语言百科 | m.baike.com/wiki/galaxy/19375308 | 可访问 | 介绍 Galaxy 与 C 的区别、官方 FAQ |
| Galaxy 错误信息翻译 | http://m.962.net/s/10483 | 可访问 | 70+ 条 Galaxy 编译/运行时错误码中文翻译 |

## 五、Galaxy 语言关键约束（血泪总结）

### 类型系统
- **没有 float/double**，只有 `fixed`（定点小数）
- `text` 和 `string` 是不同类型，不能直接拼接：
  - `"abc" + IntToText(1)` → 错误（text + string）
  - `"abc" + IntToString(1)` → 正确（string + string）
- 不支持 `(int)1.23` 强制转换，必须用 native 函数

### 变量声明
- **必须声明在函数顶部**（老式 C 语法）
- 不能在 if 块内声明局部变量
- 数组大小写在类型后面：`int[10] arr;` 而不是 `int arr[10];`
- `const int` 不能作为数组大小

### 语法限制
- 不支持 `++` / `--` 操作符
- 不支持 `for` 循环，只能用 `while`
- 不支持 `switch`，只能用 `if-else if`
- 不支持 `/* */` 块注释，只有 `//` 行注释
- 不支持 `#include`，用 `include "TriggerLibs/xxx"`（无 #，无 .galaxy 后缀）
- 不支持 `continue` 语句（会导致编译失败，用 if 块包裹）
- 所有 if/while 体必须用 `{}` 包裹，即使只有一行

### 触发器相关
- `TriggerAddEventChatMessage(trigger, c_playerAny, "cmd", exact)`：
  - `exact=true`：精确匹配，无法传参
  - `exact=false`：前缀匹配，可带参数（用 `EventChatMessage(false)` 获取完整消息）
- `EventChatMessage(matchedOnly)` **必须传 bool 参数**：
  - `false` = 返回完整聊天消息
  - `true` = 只返回匹配的部分
- `TriggerDebugOutput` 在 mod 替换 NativeLib 的环境下不可用

### mod 环境特有限制
- `PlayerSetSkin` / `PlayerSetCommander` / `PlayerAddReward` 无权调用
- `TriggerDebugOutput` / `PlayerSetPropertyInt` / `c_playerPropMinerals` 不可用
- `UnitCreate` 直接调用会编译错误，需用 `libNtve_gf_CreateUnitsWithDefaultFacing`
- `UnitIsHero()` / `UnitIsStructure()` / `PlayerIsEnemy()` 等函数不存在

## 六、推荐的 API 查找工作流

1. **第一步**：访问 https://mapster.talv.space/galaxy/reference 查在线 API 参考
   - 直接搜索函数名，或按分类浏览
   - 能获取参数语义、GUI 语法描述、预设值、相关函数
   - 这是最快、最完整的 API 查找方式

2. **第二步**：在 `natives.galaxy` 中查函数签名（离线场景）
   ```
   Grep "native.*函数名" "E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod\base.sc2data\TriggerLibs\natives.galaxy"
   ```

3. **第三步**：在 `sc2-data-trigger` 中查实际用法
   ```
   Grep "函数名" "E:\Code\MyMod\SC2\sc2-data-trigger"
   ```

4. **第四步**：在本地 mod 中查实战示例
   ```
   Grep "函数名" "E:\SC2\SC2new\StarCraft II\Mods"
   ```

5. **第五步**：查知识库过往经验
   ```
   python kb_cli.py search "SC2 galaxy 函数名"
   ```

6. **第六步**：若仍无答案，进图测试（写诊断触发器，用 TextTagCreate 显示可见文字）
