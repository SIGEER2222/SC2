# 任务：MPQ 地图结构清单

## 参数

- `{{BATCH_ID}}`：本批次名称。
- `{{MAPS_FILE}}`：UTF-8 文本，每行一个 `.SC2Map` MPQ 文件。

## 目标

只读枚举 MPQ 内部文件，提取依赖和脚本存在性线索。不要启动地图，不要修改或重新打包
MPQ。

## 执行约束

1. 源文件只读，不得修改、覆盖或重新打包原始 MPQ。
2. 输出目录：
   `合作指挥官-起义狂潮/docs/低成本模型产物/mpq-inventory/{{BATCH_ID}}/`
3. 使用 `mpyq` 只读打开。
4. 不全量解压二进制资源。仅允许把以下文本文件提取到产物目录：
   - `DocumentInfo`
   - `DocumentHeader`
   - `MapScript.galaxy`
   - `Base.SC2Data/GameData/*.xml`
   - `Base.SC2Data/*.galaxy`
5. 单地图提取总量超过 20 MB 时停止提取，但继续保存文件名清单。

## 推荐脚本

使用临时内联 Python，不在源码目录创建脚本：

```python
from mpyq import MPQArchive

archive = MPQArchive(r"<map>")
names = []
for name_bytes in archive.files:
    name = name_bytes.decode("utf-8", errors="replace")
    names.append(name)
```

所有提取内容写入本任务产物目录，保留原始内部路径。

## 输出

### `raw/<序号>.json`

```json
{
  "map": "",
  "sizeBytes": 0,
  "fileCount": 0,
  "files": [],
  "hasDocumentInfo": false,
  "hasMapScript": false,
  "gameDataXmlCount": 0,
  "galaxyFileCount": 0,
  "extractedTextBytes": 0,
  "errors": []
}
```

### `map-summary.csv`

```text
map,sizeBytes,fileCount,hasDocumentInfo,hasMapScript,gameDataXmlCount,galaxyFileCount,extractedTextBytes,errorCount
```

### `dependency-text.md`

逐地图附上提取后的 `DocumentInfo` 路径。可以列出其中出现的 `file:` 依赖字符串，但
不要解释实际有效依赖。

### `run-summary.json`

记录地图数、成功数、损坏/无法打开数、总文件数和总提取字节。

## 停止条件

- 单地图损坏：记录后继续。
- `mpyq` 不可用：停止批次并报告 `MPYQ_REQUIRED`，不要安装依赖。
- 不运行 `SC2Switcher_x64.exe` 或任何进图脚本。
