# XM 原版地图加载 Alenger3 指挥官 — CommanderAch 实例缺失修复

## 日期
2026-07-06

## 背景
在起义狂潮项目中，Alenger3（3疯批帝国）指挥官已整合为 7vs1 框架的正式指挥官。
用户要求将 adapter mod（Alenger3Adapter.SC2Mod）应用到 XM 原版地图（如 thanson02 欢迎来到丛林），
让这些地图也能使用 Alenger3 指挥官进行游戏。

## 问题现象
thanson02_xm.SC2Map 加装 adapter mod 依赖后，游戏能正常加载（无致命错误），
但 ScriptError.txt 报告 `gt_IntroSequence_Func` 触发器在创建初始单位时失败：

```
'gt_IntroSequence_Func'出现触发器错误：无法找到目录条目''
   Near line 5125 in libNtve_gf_CreateUnitsWithDefaultFacing() in TriggerLibs/NativeLib.galaxy
'gt_IntroSequence_Func'出现触发器错误：指定的单位类型无效: ''
   Near line 5132 in libNtve_gf_CreateUnitsWithDefaultFacing() in TriggerLibs/NativeLib.galaxy
```

错误重复多次（CommandCenter、Worker、SecondUnit 各一次，Worker 还在循环中重复）。
这正是用户提醒的"注意初始化的基地和单位"——初始基地和单位未能创建。

## 根本原因

### 两套 InitializeBase 实现的差异

项目中有两个版本的 `libE0EAE146_gf_InitializeBase`：

| 来源 | 文件位置 | 获取单位方式 |
|------|---------|-------------|
| **XM mod** | `XMFinal.SC2Mod/.../LibE0EAE146.galaxy:144` | `UserDataGetUnit("CommanderAch", lib67C0F0E7_gf_StrToUserinstance(libE0EAE146_gv_commander), "CommandCenter", 1)` |
| **7vs1 CoopZeroPop** | `CoopZeroPop.SC2Mod/.../LibE0EAE146.galaxy:1604` | `libE0EAE146_gf_CommanderAchUnit("CommandCenter")` — 有 Alenger3 分支的包装函数 |

XM 版直接从 `CommanderAch` User Data 目录查询单位 ID；
7vs1 版用包装函数 `libE0EAE146_gf_CommanderAchUnit`，内含 Alenger3 到 `3diguo*` 单位的硬编码映射。

### 指挥官变量来源
`libE0EAE146_gv_commander` 由 `libE0EAE146_gf_Initialize()` 从 Bank `CampaignXCore` 的 `Ach/Commander` 键读取。
Bank 中已正确设置为 `Alenger3`。

### 缺失的 CommanderAch 实例
`lib67C0F0E7_gf_StrToUserinstance()` 是恒等函数（直接返回输入字符串）。
所以 `UserDataGetUnit("CommanderAch", "Alenger3", "CommandCenter", 1)` 需要在 `CommanderAch` User Data 目录中找到 `Id="Alenger3"` 的实例。

但 XM mod 的 CommanderAch 目录只有以下指挥官实例：
- Tychus, Stukov, Dehaka, Swann, Mengsk, Mira, Nova, Stetmann 等

**Alenger3 不在 XM mod 的 CommanderAch 目录中**，导致 `UserDataGetUnit` 返回空字符串，
`libNtve_gf_CreateUnitsWithDefaultFacing` 收到空单位类型，报"无法找到目录条目''"错误。

Alenger3.SC2Mod 本身只有 UnitData/AbilData 等，没有 UserData.xml，
7vs1 框架靠 `libE0EAE146_gf_CommanderAchUnit` 的 galaxy 代码硬编码映射绕过了目录查询。

## 修复方案

在 adapter mod（Alenger3Adapter.SC2Mod）中添加 `UserData.xml`，
为 CommanderAch 目录补上 Alenger3 实例。

### 文件：`Base.SC2Data/GameData/UserData.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<Catalog>
    <CUser id="CommanderAch">
        <Instances Id="Alenger3">
            <Unit Unit="3diguoqianshaojidi">
                <Field Id="CommandCenter"/>
            </Unit>
            <Unit Unit="3diguolaogong">
                <Field Id="Worker"/>
            </Unit>
            <Unit Unit="3diguojianzhengzhe">
                <Field Id="SecondUnit"/>
            </Unit>
        </Instances>
    </CUser>
</Catalog>
```

### 为什么这样就够了
- SC2 引擎自动加载 `GameData/` 目录下所有 `*Data.xml` 文件
- `CUser id="CommanderAch"` 是对已有 User 类型的扩展，新增 `Instances Id="Alenger3"` 不会覆盖其他指挥官
- `UserDataGetUnit("CommanderAch", "Alenger3", "CommandCenter", 1)` 现在返回 `3diguoqianshaojidi`
- InitializeBase 中的 Upg/Poi/TitU/TitP 等成就字段为空时只是跳过升级，不报错

## 验证结果

修复后重新启动 thanson02_xm.SC2Map：
- SC2 进程稳定运行 143+ 秒（超过 120 秒门槛）
- 新会话（23:00:27 Alerts.txt）**无 ScriptError.txt**
- 之前的 `gt_IntroSequence_Func` 触发器错误完全消失

## 关键经验

1. **XM mod 与 7vs1 框架的 InitializeBase 实现不同**：
   - XM 用 `UserDataGetUnit` 直接查目录
   - 7vs1 用 `libE0EAE146_gf_CommanderAchUnit` 包装函数（有硬编码映射）
   - 在 XM 地图上用 7vs1 框架的指挥官时，必须补齐 CommanderAch 目录实例

2. **CommanderAch 是 User Data 目录**：
   - 定义在 XMCore.SC2Mod 的 `UserData.xml` 中（CUser id="CommanderAch"）
   - 各指挥官 mod（XMTychus、XMStukov 等）通过 `<Instances Id="XXX">` 追加实例
   - 字段：CommandCenter、Worker、SecondUnit（Unit 类型）+ Upg、Poi、TitU、TitP 等

3. **adapter mod 的职责扩展**：
   - 原本只负责解锁建造能力（LibA3ADAPTER.galaxy 中的 TechTreeAbilityAllow）
   - 现在还需补齐 User Data 目录实例，让 XM mod 的 InitializeBase 能正确创建初始单位

4. **通用工具 append_docheader_dep.py**：
   - 向地图 DocumentHeader 二进制追加 mod 依赖
   - 同时同步更新 DocumentInfo XML
   - 已成功用于 abathur_test_map、AbathurHeartTest_unpacked、Home_Soil、traynor01_xm、thanson02_xm

5. **测试地图的完整流程**：
   - 用 `append_docheader_dep.py` 追加 adapter 依赖
   - 用 `trae-cp.ps1` 复制到游戏目录
   - 用 `SC2Switcher_x64.exe` 直接加载（非 7vs1 地图禁止用 launch-7vs1-coop-test.ps1）
   - 运行 `wait-for-game-ready.ps1` 等待加载
   - 检查 ScriptError.txt 内容确认无致命错误
   - 确认 SC2 进程稳定运行 >120 秒

## 涉及文件

- `Mods/7vs1/Alenger3Adapter.SC2Mod/Base.SC2Data/GameData/UserData.xml`（新建）
- `Mods/7vs1/Alenger3Adapter.SC2Mod/Base.SC2Data/GameData/GameData.xml`（已有，无需修改）
- `Maps/thanson02_xm.SC2Map/DocumentHeader` + `DocumentInfo`（追加 adapter 依赖）
- `scripts/append_docheader_dep.py`（通用工具，追加 DocumentHeader 依赖）
