# NEEDS_SENIOR_REVIEW - 验证日志与文档盘点 batch-01

## Doctor 警告

- **PATH_NON_ASCII**: 项目路径包含非 ASCII 字符，银河编辑器/组件保存/旧工具可能失败
- **INVALID_NESTED_GIT**: 项目目录内存在非 Git 仓库的 .git 目录
- **RUNTIME_DUAL_SOURCE_DIVERGED**: CoreRuntime 与 CoopZeroPop 有 13 个同路径 Galaxy 文件已分叉
  - 相同: 36 个文件
  - 分叉: 13 个文件 (Lib67C0F0E7, LibE0EAE146, LibKMIS, LibKPVP_Commander, CampaignAI 等)

## 文档路径失效

7 个文档路径失效（详见 stale-doc-candidates.csv），其中 2 个文件完全不存在：
- scripts/export-commander-power-metadata.ps1
- kit_mutations.SC2Mod/Base.SC2Data/GameData/Mutators.xml

## 检查结果

所有检查通过（exit 0），无需进一步处理。

## 原始证据

- raw/toolkit.stdout.txt
- raw/galaxy-checker.stdout.txt
- raw/doctor.stdout.txt
- raw/diff-check.stdout.txt