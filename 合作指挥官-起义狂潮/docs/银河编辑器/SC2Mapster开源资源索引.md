# SC2Mapster 开源资源索引

> 本文档整理 SC2Mapster GitHub 组织、Talv 等社区开发者的开源工具、数据仓库和开发资源，供 AI 和开发者参考使用。
> 整理日期：2026-06-28

---

## 一、SC2Mapster 组织概述

**SC2Mapster** 是星际争霸2模组开发社区的核心组织，维护着多个重要的开源项目，包括官方游戏数据镜像、API 文档生成器、教程等。

- GitHub 组织地址：https://github.com/SC2Mapster
- 社区网站：https://sc2mapster.com
- API 文档站：https://mapster.talv.space
- Discord 社区：SC2Mapster Discord（模组开发者交流）

---

## 二、核心数据仓库

### 2.1 SC2GameData

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/SC2GameData |
| **描述** | GameData, UI and Galaxy files —— 星际争霸2官方游戏数据的完整镜像 |
| **更新频率** | 持续更新（随游戏版本更新） |
| **主要内容** | GameData XML、UI 布局、Galaxy 脚本文件 |

**目录结构**：
```
SC2GameData/
├── mods/           # 各 mod 的数据（核心）
│   ├── core.SC2Mod/
│   ├── liberty.SC2Mod/
│   ├── swarm.SC2Mod/
│   ├── void.SC2Mod/
│   └── ...
├── campaigns/      # 战役数据
├── docs/           # 文档
└── .vscode/        # VS Code 工作区设置
```

**用途**：
- 查阅官方原生函数定义
- 参考官方数据结构
- 对比不同版本的数据变化
- 提取游戏内文本、常量等

**更新方式**：使用 Lua 辅助脚本 + stormex 工具从 CASC 中提取

### 2.2 sc2-data-trigger（项目本地）

| 项目 | 信息 |
|------|------|
| **本地路径** | `E:\Code\MyMod\SC2\sc2-data-trigger` |
| **描述** | 完整官方触发器/GameData 镜像（core/swarm/void/liberty） |
| **用途** | 触发器逻辑参考、GameData XML 参考 |

> 这是项目本地已有的数据镜像，开发时优先查阅本地版本

---

## 三、Talv 开发工具库（核心开发者）

**Talv** 是 SC2 模组开发社区的核心开发者，维护着 mapster.talv.space API 文档站和多个高质量开发工具。以下是其主要项目：

### 3.1 plaxtony — Galaxy 脚本核心库

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/Talv/plaxtony |
| **描述** | Set of libraries to work with StarCraft II map files: Galaxy Script, Triggers scheme, Game Data XML |
| **技术栈** | TypeScript |
| **许可证** | MIT |
| **状态** | 维护中（最后更新 2022） |

**功能模块**：
- **Galaxy Script Parser** — 高度容错的 Galaxy 脚本解析器（受 TypeScript 解析器启发）
- **Static Analysis** — 静态分析、符号表构建、类型检查
- **Language Server Protocol (LSP)** — 实现了完整的 LSP 提供者：
  - Document symbols（文档符号）
  - Workspace symbols（工作区符号）
  - Code completions（代码补全）
  - Function signature help（函数签名帮助）
  - Symbol definitions（符号定义跳转）
  - Hover documentation（悬停文档）
  - Find all references（查找引用）
  - Rename symbol（重命名符号）
  - Format code（代码格式化）
- **Triggers 解析** — 解析 Triggers/TriggerLib/SC2Lib XML 文件
  - 元素列表及其元数据
  - 将触发器元素与自动生成的 Galaxy 符号关联
  - 从 TriggerStrings.txt 提取文档
- **GameData catalogs** — 游戏数据目录解析

**应用项目**：
- vscode-sc2-galaxy — VS Code 扩展

### 3.2 vscode-sc2-galaxy — VS Code Galaxy 脚本扩展

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/Talv/vscode-sc2-galaxy |
| **VS Marketplace** | https://marketplace.visualstudio.com/items?itemName=talv.sc2galaxy |
| **描述** | Visual Studio Code extension providing language support for StarCraft 2 Galaxy Script |
| **技术栈** | TypeScript（基于 plaxtony） |
| **许可证** | MIT |
| **版本** | v1.10.5（2022-03） |

**功能特性**：
- 代码语法高亮
- 基础代码片段补全
- 实时代码诊断（语法验证 + 类型检查）
- 上下文感知代码补全
- 函数签名帮助
- 文档和工作区符号导航
- 符号定义跳转（Ctrl+Click）
- 悬停文档提示
- 查找所有符号引用
- 符号重命名
- **触发器方案索引** — 解析 Trigger 元数据，提供本地化文档和预设值补全
- **游戏数据索引** — 索引 *Data.xml，提供 gamelink 类型补全（如 UnitCreate 的单位列表）

**开发工作流建议**：
1. 将地图保存为 `.SC2Components`（解包格式），可直接通过文件系统访问
2. 不要直接写 `MapScript.galaxy`（可能被触发器模块覆盖）
3. 创建**自定义脚本元素**（Custom script element）来引入你的脚本
4. 脚本可以保存在地图内任意目录，无需手动重新导入
5. GUI 触发器和自定义脚本可以混合使用：在触发器模块中声明 `Native` 函数/动作，然后在 Galaxy 脚本中实现

**相关文档**：
- SC2 Editor workflow tips: `docs/SC2_EDITOR.md`（仓库内）

### 3.3 nectan — Python Galaxy 脚本工具（已弃用）

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/Talv/nectan |
| **描述** | Utilities for parsing and manipulating SC2 galaxy script |
| **技术栈** | Python |
| **状态** | Archived（已弃用，替代方案：plaxtony） |

**功能**：
- 代码 linting（语法检查）
- 代码混淆（obfuscation）
- 代码反混淆（deobfuscation）
- 代码自动补全索引

**命令行工具**：
- `galaxylint` — Galaxy 代码 linter
- `galaxyobf` — Galaxy 代码混淆器
- `galaxydeobf` — Galaxy 代码反混淆器

### 3.4 sc2-layouts — VS Code SC2Layout 扩展

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/Talv/sc2-layouts |
| **描述** | Visual Studio Code extension introducing extensive support for SC2Layout language |
| **技术栈** | TypeScript + LSP |
| **许可证** | MIT |
| **版本** | v1.1.0（2024-07） |

**功能特性**：
- 语法高亮
- 代码补全
- 转到定义
- 文档和工作区导航
- 代码诊断
- **自定义缩写（Abbreviations）**：
  - `:` + FrameType — 快速插入帧声明
  - `/` + 路径 — Desc 覆盖（帧/动画/状态组）
  - `.` + 名称 — Desc 扩展/重载
  - `@` + 类名/属性名 — 帧类属性过滤
- **自定义面板**：
  - Desc Tree — 布局文件树状视图
  - Frame Properties — 帧属性信息（原生 hookup 列表、Desc 类型、类类型）

**Schema 来源**：https://github.com/SC2Mapster/sc2layout-schema

### 3.5 stormex — CASC 档案提取工具

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/Talv/stormex |
| **描述** | Command-line application to list and extract files from the CASC (Content Addressable Storage Container) used in Blizzard games |
| **技术栈** | C++ |
| **许可证** | 其他 |
| **用途** | 从暴雪游戏 CASC 存储中列出和提取文件 |

### 3.6 sc2-dood — 地形装饰物导出工具

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/Talv/sc2-dood |
| **描述** | StarCraft II terrain Objects file parser and exporter |
| **技术栈** | TypeScript |
| **用途** | 导出地图中的装饰物（doodads）数据，供触发器使用 |

**输出格式**：
- `galaxy` — Galaxy 脚本格式（性能更好，静态链接）
- `xml` — User Data 格式（XML）

**导出数据字段**：
- actorLink（演算体链接）
- flags、variation
- posX、posY、posZ
- yaw、pitch、roll
- scaleX、scaleY、scaleZ
- tintColor、tintMultiplier
- teamColorIndex

### 3.7 其他 Talv 项目

| 项目 | 描述 |
|------|------|
| [sc2-data](https://github.com/Talv/sc2-data) | SC2 游戏文件（已过时，替代：SC2GameData） |
| [subl-sc2-galaxy](https://github.com/Talv/subl-sc2-galaxy) | Sublime Text 3 Galaxy 脚本插件（已过时，替代：vscode-sc2-galaxy） |
| [sc2-repdump](https://github.com/Talv/sc2-repdump) | SC2 录像数据导出工具 |
| [sc2reader](https://github.com/Talv/sc2reader) | SC2 录像解析库（Python） |
| [m3helper](https://github.com/Talv/m3helper) | M3 模型辅助工具 |
| [sc2-texture-scanner](https://github.com/Talv/sc2-texture-scanner) | 地形纹理识别工具 |
| [CascLib](https://github.com/Talv/CascLib) | CascLib 的分支（CASC 存储读取库） |

---

## 四、文档与工具仓库

### 4.1 docs-generator

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/docs-generator |
| **描述** | StarCraft 2 - API Reference generator —— Galaxy 脚本和 SC2Layout 的 API 文档生成器 |
| **技术栈** | TypeScript + Gulp + Node.js |
| **状态** | Archived（归档） |

**功能**：
- 生成 Galaxy 原生函数 API 文档
- 生成 SC2Layout 文档
- 支持本地预览和热重载

**使用命令**：
```bash
yarn run reindex   # 构建索引（生成 Galaxy 文档必需）
yarn run build     # 构建文档页面
yarn run serve     # 启动本地服务器（带热重载）
```

**相关子模块**：
- `sc2layout-schema` — SC2Layout XML Schema
- `sc2-layouts` — SC2 UI 布局参考

### 4.2 mkdocs-sc2

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/mkdocs-sc2 |
| **描述** | SC2 Development Environment Setup guide —— SC2 开发环境设置指南 |
| **技术栈** | MkDocs + Material 主题 |
| **作者** | folk |

**内容**：
- 开发环境搭建指南
- 高效开发工作流建议
- Galaxy 脚本示例

**本地构建**：
```bash
pip3 install --user mkdocs mkdocs-material pygments
git clone <repo-url>
cd <repo>
mkdocs build --clean
mkdocs serve    # 本地预览
```

### 4.3 blizzard-tutorials

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/blizzard-tutorials |
| **描述** | Original tutorials for the Starcraft 2 Editor by Blizzard —— 暴雪官方教程原始文件 |
| **内容** | 暴雪官方发布的编辑器教程（HTML 格式） |

> 这是 `s2editor-guides.readthedocs.io` 的原始数据来源

### 4.4 sc2layout-schema

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/sc2layout-schema |
| **描述** | XML Schema of SC2Layout document from StarCraft II |
| **用途** | UI 编辑器 SC2Layout 文件的 XML Schema，用于验证和自动补全 |

---

## 五、工具仓库

### 5.1 m3addon

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/m3addon |
| **描述** | Blender Addon to import and export m3 files —— Blender M3 模型导入导出插件 |
| **技术栈** | Python |
| **许可证** | GPL-2.0 |
| **状态** | Archived（归档） |

**用途**：
- 将 Blender 模型导出为 SC2 的 M3 格式
- 导入 M3 模型到 Blender 进行编辑
- 自定义模型制作必备工具

### 5.2 tools

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/tools |
| **描述** | Random scripts and tools to work with Blizzard data |
| **技术栈** | Lua |
| **许可证** | MIT |
| **状态** | Archived（归档） |

**包含工具**：
- `update.lua` —— 从 CASC 更新游戏数据的辅助脚本
- 其他处理暴雪数据的脚本

**依赖**：
- `stormex`（https://github.com/Talv/stormex）—— CASC 档案提取工具

### 5.3 sc2mapster-crawler

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/sc2mapster-crawler |
| **描述** | SC2Mapster 网站爬虫 |
| **技术栈** | TypeScript |
| **状态** | Archived（归档） |

---

## 六、网站与文档站

### 6.1 mapster.talv.space

| 项目 | 信息 |
|------|------|
| **地址** | https://mapster.talv.space |
| **维护者** | Talv |
| **内容** | SC2 编辑器 API 文档（持续更新） |
| **最后更新** | 2025-07-03 |

**文档分类**：
- Galaxy Natives —— Galaxy 原生函数
- Data —— 数据编辑器参考
- UI (SC2Layout) —— UI 布局参考

### 6.2 sc2mapster.github.io

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SC2Mapster/sc2mapster.github.io |
| **地址** | https://sc2mapster.github.io/ |
| **描述** | Starcraft 2 Modding Guides —— SC2 模组开发指南 |

### 6.3 s2editor-guides.readthedocs.io

| 项目 | 信息 |
|------|------|
| **地址** | https://s2editor-guides.readthedocs.io |
| **内容** | 暴雪官方编辑器教程（社区维护镜像） |
| **包含** | Classic Tutorials（入门系列）+ New Tutorials（完整指南） |

**教程结构**：
- Classic Tutorials（经典入门）
  - 01 Terrain Module（地形模块）
  - 02 Trigger Module（触发器模块）
  - 03 Data Module（数据模块）
  - 04 Misc（其他：Actor cheats、性能优化等）
- Data Primer（数据入门）
  - Simple Firebolt 等实战教程
- New Tutorials（新完整指南）
  - 01 Introduction（编辑器介绍）
  - 02 Terrain Editor（地形编辑器）
  - 03 Trigger Editor（触发器编辑器）
  - 04+ Data Editor 等

---

## 七、其他相关开源资源

### 7.1 stormex

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/Talv/stormex |
| **作者** | Talv |
| **描述** | CASC archive extraction tool —— 暴雪 CASC 档案提取工具 |
| **用途** | 从游戏文件中提取 GameData、Galaxy 脚本等 |

### 7.2 StarCraft-II-Editor-learning

| 项目 | 信息 |
|------|------|
| **仓库** | https://github.com/SHW007/StarCraft-II-Editor-learning |
| **描述** | 银河编辑器学习笔记 |
| **语言** | 中文 |
| **内容** | 37 条编辑器实用提示等学习笔记 |

### 7.3 StarBox — 单位组合测试 Mod

| 项目 | 信息 |
|------|------|
| **描述** | Mod named StarBox for testing unit compositions. Created with Blizzard's Galaxy Editor. |
| **用途** | 测试单位组合的 Mod |

### 7.4 Galaxy Editor DLL Injection Tool

| 项目 | 信息 |
|------|------|
| **描述** | DLL Injection tool invented for StarCraft 2 Galaxy Editor patching |
| **用途** | 银河编辑器补丁 DLL 注入工具 |

### 7.5 Unity 版银河编辑器风格地图编辑器

| 项目 | 信息 |
|------|------|
| **描述** | A StarCraft 2 Galaxy Editor-like map editor for Unity |
| **功能** | 地形编辑、单位放置、基于 SC2 Galaxy 编辑器的触发器系统 |

---

## 八、外网社区与交流平台

### 8.1 SC2Mapster 社区

| 平台 | 地址 | 说明 |
|------|------|------|
| 官网 | https://sc2mapster.com | 国外最大 SC2 模组社区，论坛、教程、资源下载 |
| Discord | SC2Mapster Discord | 模组开发者实时交流 |
| GitHub | https://github.com/SC2Mapster | 开源项目组织 |

### 8.2 Reddit 社区

| 平台 | 地址 | 说明 |
|------|------|------|
| r/starcraft2editor | https://www.reddit.com/r/starcraft2editor/ | 编辑器开发者社区 |
| r/starcraft2 | https://www.reddit.com/r/starcraft2/ | 主社区，有编辑器相关讨论 |

> 注：Reddit 可能需要登录才能完整访问

### 8.3 视频教程资源

| 平台 | 关键词 | 说明 |
|------|--------|------|
| YouTube | `starcraft 2 editor tutorial` | 大量英文视频教程 |
| YouTube | `sc2 galaxy script tutorial` | Galaxy 脚本视频教程 |
| YouTube | `sc2 data editor tutorial` | 数据编辑器教程 |

### 8.4 合作模式社区资源

| 网站 | 地址 | 说明 |
|------|------|------|
| starcraft2coop.com | https://starcraft2coop.com/ | 合作模式社区，指挥官指南、任务数据等 |

---

## 九、AI 开发推荐资源优先级

### 第一优先级（本地已有，最可靠）
1. `E:\Code\MyMod\SC2\sc2-data-trigger` —— 官方数据镜像
2. 项目内 `游戏数据/官方SC2原始文本镜像` —— 合作指挥官 mod 数据
3. 项目内 `解包数据` —— 第三方 mod 参考

### 第二优先级（在线文档，查阅 API）
1. https://mapster.talv.space —— Galaxy 原生函数 API
2. https://s2editor-guides.readthedocs.io —— 官方教程
3. 灰机 wiki —— 中文概念解释

### 第三优先级（工具与数据仓库）
1. SC2Mapster/SC2GameData —— 最新官方数据（如需对比版本差异）
2. SC2Mapster/docs-generator —— 本地生成 API 文档
3. m3addon —— 自定义模型制作

---

## 十、获取最新数据的方法

如果需要获取最新版本的游戏数据：

**方法一：使用 stormex 提取（推荐给高级用户）**
```bash
# 需要 stormex 工具
stormex extract <casc_path> <output_path> --filters <filter_file>
```

**方法二：直接下载 SC2GameData 仓库**
```bash
git clone https://github.com/SC2Mapster/SC2GameData.git
```

**方法三：使用项目本地数据**
- 直接使用 `E:\Code\MyMod\SC2\sc2-data-trigger` 中的数据
- 已包含 core/swarm/void/liberty 所有资料片数据

---

> 注：本索引整理自 SC2Mapster GitHub 组织公开信息，部分仓库已归档但仍有参考价值。开发时优先使用项目本地的数据和工具。
