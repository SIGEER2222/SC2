# 还原文件（绕过 TRAE git restore 确认）
# 用法: powershell -File scripts/trae-restore.ps1 "<文件路径>"
git restore $args[0]