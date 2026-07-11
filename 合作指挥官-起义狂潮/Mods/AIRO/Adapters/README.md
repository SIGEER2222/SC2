# AIRO 指挥官适配器架构说明

## 目录结构
```
Mods/AIRO/
├── AIROAdapter.SC2Mod/          # 核心调度器
│   └── Base.SC2Data/
│       ├── LibAIROAdapterInterface_h.galaxy  # 适配器接口定义
│       ├── LibAIROAdapter_h.galaxy
│       └── LibAIROAdapter.galaxy
└── Adapters/
    ├── ZergKerriganAdapter.SC2Mod/     # 凯瑞甘适配器
    ├── ProtossArtanisAdapter.SC2Mod/   # 阿塔尼斯适配器
    └── ...                              # 其他指挥官适配器
```

## 接口规范

每个指挥官适配器必须实现以下函数：

### 1. `libAIROAdapterInterface_CommanderName()`
返回当前适配器对应的指挥官名称，例如 "ZergKerrigan"

### 2. `libAIROAdapterInterface_GetReplacementUnit(string originalUnit)`
根据原版单位返回对应的指挥官单位名称

### 3. `libAIROAdapterInterface_OnUnitCreated(unit createdUnit)`
当单位被创建时的回调，可用于自定义行为

### 4. `libAIROAdapterInterface_OnGameStart()`
游戏启动时的回调，可用于初始化操作

## 创建新的适配器

复制 ZergKerriganAdapter.SC2Mod 文件夹，修改文件名和内部逻辑即可。

## 工作流程

1. 启动器根据选择的指挥官，加载对应的 CommanderUnits_X.SC2Mod
2. 同时加载对应的 CommanderXAdapter.SC2Mod
3. AIROAdapter 作为调度器，调用当前适配器的函数
4. 实现单位替换和自定义行为
