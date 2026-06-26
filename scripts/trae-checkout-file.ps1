# checkout 还原文件（绕过 TRAE git checkout -- 确认）
# 用法: powershell -File scripts/trae-checkout-file.ps1 "<文件路径>"
git checkout -- $args[0]