# AI 开发 SC2 Mod 指南

> 本文档专为 AI 辅助开发星际争霸2银河编辑器 Mod 而编写，汇总了 AI 开发时最需要的核心知识、常见坑点、开发模式和参考资源。
> 整理日期：2026-06-28

---

## 一、AI 开发核心认知

### 1.1 银河编辑器 Mod 开发的本质

银河编辑器 Mod 开发 = **数据定义（XML）** + **触发器逻辑（GUI / Galaxy 脚本）** + **演算体系统（Actor）**

三者关系：
- **数据层**：定义"有什么"——单位、技能、效果、行为、武器等，存储为 XML
- **逻辑层**：定义"什么时候做什么"——触发器 ECA（事件-条件-动作），或 Galaxy 脚本
- **表现层**：定义"看起来/听起来怎么样"——Actor 演算体系统，控制模型、动画、音效、特效

### 1.2 AI 最适合做的工作

1. **Galaxy 脚本编写**：AI 擅长写类 C 语言代码，Galaxy 是类 C 语言
2. **数据分析与对照**：对比不同单位/技能的数据差异，找出规律
3. **批量生成 XML 数据**：根据模板批量生成单位、技能等数据
4. **错误排查**：根据错误码快速定位问题
5. **代码重构**：整理已有脚本，优化结构

### 1.3 AI 不擅长/需要注意的

1. **GUI 触发器操作**：AI 无法直接操作编辑器 GUI，需要用脚本或 XML 替代
2. **视觉效果调试**：Actor 系统需要可视化调试，AI 只能基于经验推理
3. **平衡性调整**：需要实际游戏测试反馈
4. **原生函数记忆**：Galaxy 原生函数数量多，需要查阅 API 文档

---

## 二、Galaxy 脚本开发速查

### 2.1 语言核心特性（与 C 的区别）

```galaxy
// 1. 数组维度写在类型后面
int[5] myArray;       // 正确
int myArray[5];       // 错误！

// 2. 不支持 ++/--，用赋值代替
int x = 0;
x = x + 1;            // 正确
x++;                  // 错误！

// 3. 不支持 for 循环，用 while
int i = 0;
while (i < 10) {
    // ...
    i = i + 1;
}

// 4. 不支持 switch，用 if/else if
if (x == 1) {
}
else if (x == 2) {
}
else {
}

// 5. 只用 // 注释，不支持 /* */
// 这是注释
/* 这会报错 */

// 6. 没有预处理器，没有 #define / #include
include "TriggerLibs/MeleeNotHardAI";  // 正确，无 # 号，无后缀

// 7. 所有 if/while 体必须用 {}
if (x > 0) {
    doSomething();     // 正确
}
if (x > 0)
    doSomething();     // 错误！单行也必须大括号

// 8. 变量必须声明在函数顶部
void myFunc() {
    int a;
    int b;
    // 然后才是代码
    a = 1;
}

// 9. 用 fixed 代替 float/double
fixed f = 1.5;

// 10. 不支持隐式类型转换
int i = 5;
fixed f = IntToFixed(i);  // 必须显式转换
```

### 2.2 基本数据类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `int` | 整数 | `int x = 10;` |
| `fixed` | 定点小数（替代 float） | `fixed f = 3.14;` |
| `bool` | 布尔值 | `bool b = true;` |
| `string` | 字符串 | `string s = "hello";` |
| `text` | 游戏内文本（多语言） | `text t = StringToText("你好");` |
| `unit` | 单位句柄 | `unit u = CreateUnit(...);` |
| `unitgroup` | 单位组 | `unitgroup g = CreateUnitGroup();` |
| `point` | 点/位置 | `point p = Point(0, 0);` |
| `region` | 区域 | `region r = RegionFromPoint(...);` |
| `player` | 玩家 | `player p = Player(1);` |
| `trigger` | 触发器 | `trigger t = CreateTrigger();` |
| `timer` | 计时器 | `timer tm = CreateTimer();` |

### 2.3 常用原生函数分类索引

#### 单位操作
```galaxy
unit CreateUnit(player p, int unitType, point p, fixed face);
void UnitKill(unit u);
void UnitSetLife(unit u, fixed life, bool cull);
fixed UnitGetLife(unit u);
fixed UnitGetLifeMax(unit u);
void UnitSetEnergy(unit u, fixed energy);
fixed UnitGetEnergy(unit u);
int UnitGetTypeId(unit u);
player UnitGetOwner(unit u);
bool UnitIsDead(unit u);
bool UnitIsAlive(unit u);
point UnitGetPosition(unit u);
void UnitMoveOrder(unit u, point target);
void UnitIssueOrder(unit u, int abilityId, int orderId, ...);
```

#### 玩家操作
```galaxy
player Player(int playerId);
int PlayerGetController(player p);
bool PlayerIsHuman(player p);
bool PlayerIsComputer(player p);
bool PlayerIsEnemy(player p1, player p2);
bool PlayerIsAlly(player p1, player p2);
int PlayerCountAllUnits(player p, unitfilter filter);
```

#### 触发器与事件
```galaxy
trigger CreateTrigger();
void TriggerAddAction(trigger t, void func());
void TriggerAddEventUnitDeath(trigger t, unit u);
void TriggerAddEventUnitBorn(trigger t, unit u, player p);
void TriggerAddEventTimer(trigger t, timer tm);
void TriggerAddEventChatMessage(trigger t, player p, string text, bool exact);
bool TriggerRun(trigger t, bool checkConditions);
```

#### 计时器
```galaxy
timer CreateTimer();
void TimerStart(timer t, fixed duration, bool periodic);
void TimerPause(timer t);
void TimerResume(timer t);
void TimerDestroy(timer t);
fixed TimerGetRemaining(timer t);
fixed TimerGetElapsed(timer t);
```

#### UI 与消息
```galaxy
void UIDisplayMessage(player p, int msgType, text message);
void UIPrintText(text t, int duration);
void DialogSetText(dialog d, text t);
dialog DialogCreate(player p, fixed width, fixed height, int anchor, ...);
```

#### 数学与转换
```galaxy
int FixedToInt(fixed f);
fixed IntToFixed(int i);
fixed FixedSin(fixed angle);
fixed FixedCos(fixed angle);
fixed FixedSqrt(fixed x);
fixed FixedAbs(fixed x);
int IntAbs(int x);
string IntToString(int i);
string FixedToString(fixed f);
text StringToText(string s);
string TextToString(text t);
```

> 注：以上为常用函数示例，完整 API 参考 mapster.talv.space 或项目内 sc2-data-trigger 目录

### 2.4 库与 include 机制

```galaxy
// 引入标准库（路径相对于 TriggerLibs/，不加 .galaxy 后缀）
include "TriggerLibs/MeleeNotHardAI";
include "TriggerLibs/Natives";

// 引入自定义库（Mod 中的触发器库）
include "TriggerLibs/LibE0EAE146_h";

// 库命名规范：Lib + 库ID + _h / _Runtime
// 例：LibE0EAE146_h.galaxy 是头文件，LibE0EAE146_Runtime.galaxy 是实现
```

**库文件结构**：
- `LibXXX_h.galaxy`：头文件，声明全局变量、函数原型、常量
- `LibXXX_Runtime.galaxy`：运行时实现，包含具体函数代码
- `LibXXX.galaxy`：GUI 触发器自动生成的代码

### 2.5 变量作用域与生命周期

```galaxy
// 全局变量 - 在库头文件中声明
global int g_playerCount = 0;

// 局部变量 - 在函数顶部声明
void myFunc() {
    int localVar;          // 栈分配，函数结束自动释放
    unit u;                // 本地类型有垃圾回收
    // ...
}

// static 变量 - 仅当前文件可见
static int s_fileLocal = 0;

// const 常量 - 必须在声明时初始化
const int MAX_COUNT = 100;
```

---

## 三、数据编辑器开发指南

### 3.1 核心数据类型与关系

数据编辑器中最核心的 6 种类型及其关系：

```
Unit（单位）
  ├── Abilities（技能）数组
  │     ├── Button（按钮）- 命令面板显示
  │     ├── Effect（效果）- 技能实际效果
  │     │     ├── Damage - 伤害
  │     │     ├── Apply Behavior - 施加行为
  │     │     ├── Search Area - 范围搜索
  │     │     ├── Set - 组合多个效果
  │     │     ├── Create Persistent - 创建持续效果
  │     │     └── ...
  │     ├── Behavior（行为）- BUFF/DEBUFF
  │     └── Requirement（需求）- 施放条件
  ├── Weapons（武器）数组
  └── Actor（演算体）- 视觉/音效表现
```

### 3.2 数据链接机制（重要！）

银河编辑器数据通过**字段引用**建立关联，不是继承关系。复制对象时要注意选择"共享"还是"复制"链接对象。

**对象浏览器（Object Explorer）**是理解数据关系的关键工具：
- 显示当前对象引用了哪些其他对象
- 显示哪些对象引用了当前对象
- 右键节点 → "Explain Link"（解释连接）可查看具体链接字段

### 3.3 常见数据类型说明

| 类型 | 英文名 | 用途 | 关键子类型 |
|------|--------|------|-----------|
| 单位 | Unit | 可交互的游戏对象 | 可移动单位、建筑、发射物、可摧毁物 |
| 技能 | Ability | 单位可执行的动作 | Effect-target、Instant、Behavior、Toggle |
| 效果 | Effect | 技能的具体实现 | Damage、Apply Behavior、Search、Set、Create Persistent |
| 行为 | Behavior | 单位上的状态效果 | Buff、Debuff、Modify Unit、Charge |
| 武器 | Weapon | 单位的攻击方式 | 即时、弹道、导弹 |
| 演算体 | Actor | 视觉/音效表现 | Unit Actor、Effect Actor、Sound Actor |
| 按钮 | Button | 命令面板按钮 | 普通按钮、能力按钮、建造按钮 |
| 需求 | Requirement | 技能施放条件 | 生命、能量、冷却、升级等级 |

### 3.4 XML 结构示例

数据编辑器底层存储为 XML。以下是单位数据的简化示例：

```xml
<?xml version="1.0" encoding="utf-8"?>
<CActorUnit id="Marine">
    <Cost v="0"/>
    <Flags index="Hero" value="0"/>
    <LifeMax v="45"/>
    <ShieldsMax v="0"/>
    <EnergyMax v="0"/>
    <Abilities>
        <Abil id="Attack"/>
        <Abil id="Move"/>
        <Abil id="Stop"/>
        <Abil id="HoldPosition"/>
        <Abil id="Patrol"/>
        <Abil id="AttackMove"/>
    </Abilities>
    <Weapons>
        <Weapon id="GaussRifle" link="GaussRifle"/>
    </Weapons>
    <CardLayouts>
        <Layout #="1">
            <Column #="1">
                <Button Type="Ability" Abil="Stimpack" CardLayoutCmd="Execute"/>
            </Column>
        </Layout>
    </CardLayouts>
</CActorUnit>
```

---

## 四、触发器（Trigger）开发模式

### 4.1 ECA 结构

每个触发器由三部分组成：
- **Event（事件）**：何时触发
- **Condition（条件）**：满足什么条件才执行
- **Action（动作）**：执行什么操作

### 4.2 常用事件类型

| 事件分类 | 示例 |
|----------|------|
| 单位事件 | 单位死亡、单位创建、单位受伤、单位升级 |
| 玩家事件 | 玩家聊天、玩家离开、玩家资源变化 |
| 计时器事件 | 计时器到期 |
| 游戏事件 | 游戏开始、游戏胜利/失败 |
| 对话框事件 | 按钮点击、对话框关闭 |
| 区域事件 | 单位进入区域、单位离开区域 |

### 4.3 GUI 触发器转 Galaxy 脚本

GUI 触发器会自动转换为 Galaxy 脚本，规律如下：
- 每个触发器 = 一个 `void` 函数
- 触发器变量 = 函数内局部变量
- 自定义动作 = 自定义函数
- 自定义条件 = 返回 bool 的函数
- 库 = 一组相关函数的集合

### 4.4 触发器调试

**触发器调试窗口**（Trigger Debugger）功能：
- Variables 标签：查看变量值
- Triggers 标签：查看所有触发器
- Threads 标签：查看当前运行的线程
- Profiling 标签：性能分析（触发器/函数执行时间）
- Script Code 标签：查看生成的 Galaxy 代码
- 支持设置断点

---

## 五、Mod 开发最佳实践

### 5.1 项目结构规范

```
MyMod.SC2Mod/
├── Base.SC2Data/
│   ├── GameData/          # 游戏数据 XML
│   │   ├── Unit.xml
│   │   ├── Ability.xml
│   │   ├── Effect.xml
│   │   ├── Behavior.xml
│   │   └── ...
│   ├── TriggerLibs/       # 触发器库（Galaxy脚本）
│   │   ├── LibXXX_h.galaxy
│   │   ├── LibXXX_Runtime.galaxy
│   │   └── ...
│   ├── UI/                # UI 布局
│   └── ...
└── DocumentInfo/
```

### 5.2 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 库 ID | 8位十六进制（编辑器自动生成） | `E0EAE146` |
| 库文件 | `Lib` + ID + `_h`/`_Runtime` | `LibE0EAE146_h.galaxy` |
| 全局变量 | `g_` 前缀 + 驼峰 | `g_playerData` |
| 静态变量 | `s_` 前缀 + 驼峰 | `s_initialized` |
| 局部变量 | 驼峰 | `unitIndex` |
| 常量 | 全大写 + 下划线 | `MAX_UNIT_COUNT` |
| 函数 | 库前缀 + 驼峰 | `LibE0EAE146_Init()` |

### 5.3 性能优化要点

1. **减少单位组遍历**：单位组遍历是 O(n)，频繁调用会影响性能
2. **合理使用 Wait**：最短等待时间是 1/16 秒（0.0625s），也就是一帧
3. **及时清理计时器**：不用的计时器要 Destroy，避免内存泄漏
4. **避免每帧触发器**：尽量用事件驱动而不是轮询
5. **合理使用本地变量**：全局变量过多会增加全局数据区大小
6. **触发器分析器**：用 Trigger Profiler 找出性能瓶颈

### 5.4 调试技巧

1. **编译期错误**：
   - 看错误行号和错误码
   - 从错误位置往上检查语法
   - 参考 `Galaxy脚本错误码参考.md`

2. **运行期错误**：
   - 查看 `C:\Users\用户名\Documents\StarCraft II\GameLogs` 目录
   - 用 `UIDisplayMessage()` 打印调试信息
   - 用触发器调试器设置断点

3. **数据问题**：
   - 用对象浏览器检查链接是否正确
   - 用"解释连接"查看数据关系
   - 对比能正常工作的同类数据

---

## 六、AI 开发工作流

### 6.1 编写新功能的步骤

1. **明确需求**：确定要实现什么功能
2. **查找参考**：在官方数据或其他Mod中找类似实现
3. **设计方案**：确定用触发器还是数据，还是两者结合
4. **编写代码/数据**：按规范编写
5. **静态检查**：检查语法、命名、include 等
6. **编译测试**：运行 quick-compile-check
7. **进图测试**：实际运行验证功能
8. **修复问题**：根据测试反馈调整

### 6.2 调试错误的步骤

1. **定位错误类型**：编译期还是运行期？
2. **查找错误码**：在错误码参考中找对应说明
3. **缩小范围**：注释掉部分代码，逐步排查
4. **对比参考**：与能正常工作的代码对比
5. **检查常见坑**：数组声明方式、大括号、变量声明位置等

### 6.3 参考资料优先级

1. **项目内已有的代码**：最可靠，符合项目规范
2. **官方 sc2-data-trigger**：最权威，原生实现参考
3. **官方合作指挥官 mod**：合作模式参考
4. **mapster.talv.space**：API 文档
5. **灰机wiki**：中文参考，概念解释
6. **s2editor-guides**：官方教程，入门学习

---

## 七、项目本地参考资源

### 7.1 已有的官方数据镜像

| 路径 | 内容 | 用途 |
|------|------|------|
| `E:\Code\MyMod\SC2\sc2-data-trigger` | 完整官方触发器/GameData 镜像 | 触发器逻辑、GameData XML 参考 |
| `E:\Code\MyMod\SC2\合作指挥官-起义狂潮\游戏数据\官方SC2原始文本镜像\mods\starcoop` | 合作指挥官 starcoop mod | 指挥官天赋/技能定义参考 |
| `E:\Code\MyMod\SC2\解包数据\海克斯合作PVP0.110.SC2Mod` | 海克斯合作 PVP mod 解包 | Hex 天赋/技能系统参考 |

### 7.2 项目文档

| 文档 | 内容 |
|------|------|
| `银河编辑器使用教程汇总.md` | 编辑器各模块使用教程 |
| `学习资源索引.md` | 外部学习资源链接 |
| `Galaxy脚本错误码参考.md` | Galaxy 错误码完整列表 |
| `SC2Mapster开源资源索引.md` | GitHub 开源工具和数据 |

### 7.3 验证脚本

| 脚本 | 用途 |
|------|------|
| `scripts/validate-galaxy-scripts.py` | 静态分析：BOM、括号、include、禁用函数等 |
| `scripts/quick-compile-check.ps1` | 快速编译验证（约20-30秒） |
| `scripts/launch-7vs1-coop-test.ps1` | 完整进图测试 |

---

## 八、常见坑点清单

### Galaxy 语法相关
1. ❌ 数组维度写在变量名后 → ✅ 写在类型后
2. ❌ 使用 `++`/`--` → ✅ 用 `x = x + 1`
3. ❌ 使用 `for` 循环 → ✅ 用 `while`
4. ❌ 使用 `switch` → ✅ 用 `if/else if`
5. ❌ 使用 `/* */` 块注释 → ✅ 只用 `//`
6. ❌ 单行 if/while 省略大括号 → ✅ 必须加 `{}`
7. ❌ 变量在函数中间声明 → ✅ 必须在函数顶部
8. ❌ 隐式类型转换 → ✅ 用显式转换函数
9. ❌ include 加 `#` 或 `.galaxy` 后缀 → ✅ 直接写路径

### 触发器相关
1. ❌ 假设触发器按顺序执行 → 触发器是事件驱动，并发执行
2. ❌ Wait 后变量值不变 → Wait 期间其他触发器可能修改变量
3. ❌ 每帧执行重计算 → 缓存计算结果

### 数据相关
1. ❌ 复制单位时忘记复制关联的 Actor → 单位会显示成白球
2. ❌ Effect 类型选错 → 效果不生效或表现不对
3. ❌ 行为没有正确的周期/持续时间 → 立即消失或永久持续
4. ❌ 按钮没有正确链接到技能 → 命令面板不显示

### 性能相关
1. ❌ 大单位组每帧遍历 → 用事件驱动代替
2. ❌ 大量计时器不销毁 → 内存泄漏
3. ❌ 全局字符串拼接 → 用 text 类型或局部变量

---

> 本文档为 AI 开发提供快速参考，具体细节请配合其他文档和官方数据使用。
