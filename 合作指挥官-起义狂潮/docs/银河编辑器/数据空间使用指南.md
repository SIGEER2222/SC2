# SC2 数据空间 (Custom Data Space) 使用指南

> 来源：贴吧 ID：XDTW2 的大佬（nskxp）教程 + 合作数据空间.SC2Map 实例分析

## 一、定义

**数据空间 (Custom Data Space)** 是星际争霸 II 虚空之遗版本引入的银河编辑器功能（最早用于风暴英雄），是一种**将地图游戏数据按 XML 文件分类组织**的机制。

本质上是通过 `GameData.xml` 主入口文件显式 `<Includes>` 引用多个独立 XML 文件，每个被引用的 XML 文件就是一个"数据空间"。

## 二、作用

1. **数据分类管理** - 把属于同一单位/技能/Actor 等相关数据放在一个独立 XML 文件中，集中编辑
2. **避免前缀混乱** - 不必再用 `Prefix_Name` 方式区分电脑单位、玩家单位、防御塔、雇佣兵等
3. **跨地图复用** - 可做成"单位库"、"技能库"，在多个地图间迁移数据
4. **可视化迁移** - 编辑器中右键数据 → 「移动」→ 选择目标数据空间，可批量迁移

## 三、优点

| 优点 | 说明 |
|------|------|
| **组织清晰** | 按功能/类别分文件，避免单个 XML 文件膨胀 |
| **无损复制** | 本质是 XML 复制，只要 ID 唯一即可在地图间迁移 |
| **批量管理** | 编辑器支持批量移入数据空间 |
| **解耦复用** | 单位库、技能库可被多个地图依赖引用 |
| **不影响运行时** | 纯编辑期组织方式，对游戏运行性能无影响 |

## 四、使用方法

### 步骤 1：地图另存为组件文件夹

在银河编辑器中对地图「另存为」，保存类型选择「组件文件夹」(Component Folder)，关闭原地图。

### 步骤 2：创建 GameData.xml 主入口

在 `Base.SC2Data/` 下新建 `GameData.xml`：

```xml
<?xml version="1.0" encoding="us-ascii"?>
<Includes>
    <Catalog path="GameData/TestDataSpace.xml"/>
</Includes>
```

- 多个数据空间加多个 `<Catalog>` 标签
- **文件名不能中文**，需用 ASCII
- 如需中文内容，切换 `utf-8` 编码，用专业文本编辑器（不要用记事本）

```xml
<?xml version="1.0" encoding="utf-8"?>
<Includes>
    <Catalog path="GameData/HaloData.xml"/>
    <Catalog path="GameData/PsiShadowData.xml"/>
    <Catalog path="GameData/MarineData.xml"/>
</Includes>
```

### 步骤 3：创建数据空间文件

在 `Base.SC2Data/GameData/` 下创建对应的 XML 文件，初始内容：

```xml
<?xml version="1.0" encoding="us-ascii"?>
<Catalog/>
```

### 步骤 4：编辑器中迁移数据

用编辑器重新打开地图后：
1. 右键点击想放进数据空间的数据（单位、技能等）
2. 选择「移动」
3. 对话框中选择目标数据空间
4. 支持批量移入（选择多个）

### 注意事项

- **文件名不要与原有重名** - 不要起 `Unit.xml`、`Actor.xml` 这样的通用名
- **ID 必须唯一** - 跨地图迁移时这是硬性要求
- **编码** - ASCII 文件名，内容如含中文须用 utf-8
- **不要用记事本** - 用 VSCode/Notepad++ 等专业编辑器

## 五、数据空间作为独立 SC2Map（扩展用法）

数据空间机制可扩展为独立 SC2Map 文件作为「数据容器」：

### 实例：合作数据空间.SC2Map

```
合作数据空间.SC2Map
├── Base.SC2Data/
│   ├── GameData.xml            # 主入口，<Includes> 指向 CustomDataSpace.xml
│   └── GameData/
│       └── CustomDataSpace.xml # 实际数据（单位/武器/Actor/模型/音效）
├── DocumentInfo                # ModType=Interface, 依赖 StarCoop 等
└── ...
```

**DocumentInfo 关键字段**：
```xml
<ModType><Value>Interface</Value></ModType>
<Dependencies>
    <Value>bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod</Value>
</Dependencies>
```

- `ModType=Interface` 表示这是数据接口而非可玩地图
- 其他地图/Mod 通过依赖关系引用此数据空间
- 适合合作模式新指挥官、新单位数据承载

## 六、当前光晕测试地图分析

### 现状

光晕测试地图 (`光晕测试 by Pirate.SC2Map`) 当前**未使用数据空间机制**，使用默认自动加载（`Base.SC2Data/GameData/*.xml` 全部自动加载）。

当前数据文件分布：

| 文件 | 大小 | 条目数 | 内容 |
|------|------|--------|------|
| AbilData.xml | 1231 B | 1 | SquadMagazine 能力 |
| ActorData.xml | 8911 B | 31 | 28 个 SceneHalo 配置 + PsiShadowModel + PsiShadow + 其他 |
| BehaviorData.xml | 99 B | 1 | PsiShadow 行为 |
| ButtonData.xml | 335 B | 1 | 按钮 |
| UnitData.xml | 166 B | 1 | Marine 单位 |

### 优化建议

**结论：当前地图数据量小，数据空间优化的实际收益有限，但可作为未来扩展的结构准备。**

#### 可行的优化方案

创建 `GameData.xml` 主入口，按功能分类：

```
Base.SC2Data/
├── GameData.xml                    # 主入口
└── GameData/
    ├── HaloSceneData.xml           # SceneHalo 颜色/发射/宽度/类型/光栅模式 Actor
    ├── PsiShadowData.xml           # PsiShadow 残影相关 (Behavior + Actor)
    └── MarineTestData.xml          # Marine 测试单位相关 (Unit + Abil + Button)
```

**GameData.xml**：
```xml
<?xml version="1.0" encoding="utf-8"?>
<Includes>
    <Catalog path="GameData/HaloSceneData.xml"/>
    <Catalog path="GameData/PsiShadowData.xml"/>
    <Catalog path="GameData/MarineTestData.xml"/>
</Includes>
```

#### 分类建议

| 数据空间 | 包含内容 | 原文件 |
|---------|---------|--------|
| HaloSceneData.xml | SceneHalo_Color_*, SceneHalo_Emission_*, SceneHalo_Width_*, SceneHalo_Type_*, SceneHalo_RasterMode_* | ActorData.xml 中的 28 个 |
| PsiShadowData.xml | CBehaviorBuff PsiShadow + CActorModel PsiShadowModel + CActorSimple PsiShadow | BehaviorData.xml + ActorData.xml 中的 2 个 |
| MarineTestData.xml | CUnit Marine + CAbil SquadMagazine + Button | UnitData.xml + AbilData.xml + ButtonData.xml |

#### 收益评估

- ✅ **结构清晰** - 按功能分离，便于理解
- ✅ **便于扩展** - 后续添加新功能时可直接新建数据空间
- ✅ **复用潜力** - PsiShadowData.xml 可直接复制到其他地图使用
- ⚠️ **编辑器依赖** - 完整迁移需在编辑器中操作（右键 → 移动）
- ⚠️ **小地图收益有限** - 当前 5 个文件 35 个条目，自动加载已够用

#### 不建议优化的场景

- 数据量小（< 50 个条目）
- 单一功能地图
- 不需要跨地图复用
- 不需要多人协作编辑

## 七、相关资源

- 原始教程：`C:\Users\22448\Downloads\数据空间使用说明\数据空间使用说明\教程 By 贴吧ID：XDTW2的大佬.docx`
- 实例地图：`C:\Users\22448\Downloads\合作数据空间.SC2Map`
- 另一实例：`C:\Users\22448\Downloads\万用型残影Buff~~纯数据编辑器~~ .SC2Map`（纯数据编辑器，类似数据空间思想）
