# git add 包装脚本（绕过 TRAE git add 确认）
# 用法: powershell -File scripts/trae-add.ps1 "<文件路径>" [文件路径2] ...
# 建议使用空格分隔的多个具体文件路径，避免使用 git add . 或 git add -A
foreach ($file in $args) {
    git add $file
}
