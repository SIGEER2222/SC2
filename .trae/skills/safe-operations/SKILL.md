---
name: "safe-operations"
description: "安全执行危险操作（删除文件/目录、git checkout/restore/clean）。必须调用此 Skill 而不是直接执行原始命令。"
---

# 安全操作规范

**严禁直接执行以下命令，必须使用对应的包装脚本：**

| 禁止的原生命令 | 包装脚本 | 用法示例 |
|---------------|----------|----------|
| `Remove-Item` | `scripts/trae-rm.ps1` | `powershell -File scripts/trae-rm.ps1 "file.txt"` |
| `Remove-Item -Recurse` | `scripts/trae-rmdir.ps1` | `powershell -File scripts/trae-rmdir.ps1 "dir"` |
| `git checkout <分支>` | `scripts/trae-checkout.ps1` | `powershell -File scripts/trae-checkout.ps1 "dev"` |
| `git checkout -- <文件>` | `scripts/trae-checkout-file.ps1` | `powershell -File scripts/trae-checkout-file.ps1 "file.txt"` |
| `git restore <文件>` | `scripts/trae-restore.ps1` | `powershell -File scripts/trae-restore.ps1 "file.txt"` |
| `git clean -fd` | `scripts/trae-clean.ps1` | `powershell -File scripts/trae-clean.ps1` |
| `git add <文件>` | `scripts/trae-add.ps1` | `powershell -File scripts/trae-add.ps1 "file.txt"` |

### 暂存文件
```powershell
powershell -File scripts/trae-add.ps1 "path/to/file.txt"
# 支持多个文件
powershell -File scripts/trae-add.ps1 "file1.txt" "file2.txt" "file3.txt"
```

**注意**：请勿使用 `git add .`、`git add -A` 或 `git add *`，必须明确指定要暂存的具体文件路径。

## 删除操作

### 删除单个文件
```powershell
powershell -File scripts/trae-rm.ps1 "path/to/file.txt"
```

### 删除目录及其内容
```powershell
powershell -File scripts/trae-rmdir.ps1 "path/to/directory"
```

## Git 操作

### 切换分支
```powershell
powershell -File scripts/trae-checkout.ps1 "branch-name"
```

### 恢复文件（checkout 方式）
```powershell
powershell -File scripts/trae-checkout-file.ps1 "path/to/file.txt"
```

### 恢复文件（restore 方式）
```powershell
powershell -File scripts/trae-restore.ps1 "path/to/file.txt"
```

### 清理未跟踪文件
```powershell
powershell -File scripts/trae-clean.ps1
```

## 何时调用此 Skill

- 用户要求删除文件或目录时
- 用户要求切换 git 分支时
- 用户要求恢复/撤销文件修改时
- 用户要求清理未跟踪文件时
- 任何涉及上述 6 个危险命令的操作

## 重要提示

- **绝对禁止**直接使用 `Remove-Item`、`git checkout`、`git restore`、`git clean` 等原生命令
- 必须使用项目中的 `scripts/trae-*.ps1` 包装脚本
- 包装脚本路径相对于当前工作区根目录
- 执行前确认工作区位置，确保使用正确的脚本路径
