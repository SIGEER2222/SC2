# Hex coop pvp 0.110 unpack

## Result

- Editable package: `解包数据/海克斯合作PVP0.110.SC2Mod`
- Source file: `C:\Users\22448\Downloads\海克斯合作PVP0.110.sc2mod`
- Local ASCII copy used for extraction: `E:\tmp\hexcoop_pvp_0110.SC2Mod`
- Unpack tool: `C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\tools\mpq\mpqeditor\x64\MPQEditor.exe`

## Identity

The package is a mod package, not a map. The unpacked `DocumentInfo` declares:

```xml
<Flags>
    <Value>ExtensionMod</Value>
</Flags>
```

The unpacked `zhCN.SC2Data/LocalizedData/GameStrings.txt` exposes coop commander and mutation related localized strings. The source filename is `海克斯合作PVP0.110.sc2mod`.

## Package Shape

`解包数据/海克斯合作PVP0.110.SC2Mod` includes:

- `DocumentInfo`
- `DocumentHeader`
- `Attributes`
- `Base.SC2Data`
- `Triggers`
- localized data under `zhCN.SC2Data`, `zhTW.SC2Data`, `enUS.SC2Data`, and other locales

Its declared dependencies are:

```text
bnet:Void Multi (Mod)/0.0/999,file:Mods/VoidMulti.SC2Mod
bnet:Co-op Mission/0.0/999,file:Mods/StarCoop/StarCoop.SC2Mod
file:Mods\starcoop/commanders/arcturusmengsk.sc2mod
file:Mods\starcoop/commanders/egonstetmann.sc2mod
```

## Notes

The extracted working copy lives under `解包数据/`, which is intentionally ignored by git. This document is the tracked provenance record for the unpacked local mod copy.
