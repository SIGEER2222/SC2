# 7v1 compatible remaster unpack

## Result

- Editable package: `解包数据/母巢之战兼容更新.SC2Map`
- Source header: `C:\ProgramData\Blizzard Entertainment\Battle.net\Cache\94\02\9402f1f6d72a29532402d1a58ed2fe6a3c74122d36620222a9b7aad22ff7e19f.s2mh`
- Source package: `C:\ProgramData\Blizzard Entertainment\Battle.net\Cache\23\0a\230a7b1fb9717fb7840db1e9fe284830ddabdbba9203a658d1dc82e63c87b4ec.s2ma`
- Unpack tool: `C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\tools\mpq\mpqeditor\x64\MPQEditor.exe`

## Identity

The `.s2mh` header names the package as `母巢之战兼容更新.SC2Map`.

The unpacked `zhCN.SC2Data/LocalizedData/GameStrings.txt` identifies the playable title as `7v1母巢之战 兼容重制版`.

## Package Type

`解包数据/母巢之战兼容更新.SC2Map` is a map package, not a mod. It includes:

- `DocumentInfo`
- `DocumentHeader`
- `MapInfo`
- `MapScript.galaxy`
- `Objects`
- `Regions`
- terrain blobs such as `t3Terrain.xml`, `t3HeightMap`, and `t3TextureMasks`
- `Base.SC2Data`
- `zhCN.SC2Data`

The top-level `DocumentInfo` declares:

```xml
<ModType>
    <Value>Interface</Value>
</ModType>
```

Its declared dependency is:

```text
bnet:虚空之遗 (Mod)/0.0/999,file:Mods/Void.SC2Mod
```

## Notes

The local extraction was written under `解包数据/`, which is intentionally ignored by git in this repository. This document is the tracked provenance record for the unpacked local working copy.
