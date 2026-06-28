#!/usr/bin/env python3
"""启动游戏测试雷诺兵营/重工厂修复"""
import subprocess
import time
import shutil
from pathlib import Path

# 路径配置
BANK_PATH = Path(r"C:\Users\22448\Documents\StarCraft II\Banks\CampaignXCore.SC2Bank")
SWITCHER = Path(r"E:\SC2\SC2new\StarCraft II\Support64\SC2Switcher_x64.exe")
MAP_PATH = Path(r"E:\SC2\SC2new\StarCraft II\Maps\7vs1\ttosh01_7vs1.SC2Map")
SCREENSHOT_PATH = Path(r"E:\Code\MyMod\SC2\test_screenshot.png")
GAME_LOG_DIR = Path(r"C:\Users\22448\Documents\StarCraft II\GameLogs")

def kill_sc2():
    """杀掉 SC2 进程"""
    for proc_name in ["SC2_x64", "SC2Switcher_x64"]:
        try:
            subprocess.run(["taskkill", "/F", "/IM", f"{proc_name}.exe"], capture_output=True)
        except:
            pass

def set_bank_commander(commander):
    """设置银行中的指挥官"""
    import xml.etree.ElementTree as ET

    tree = ET.parse(BANK_PATH)
    root = tree.getroot()
    section = root.find("Section[@name='Ach']")
    if section is None:
        section = ET.SubElement(root, "Section")
        section.set("name", "Ach")

    for key_name in ["CommanderP1", "PrimaryCommander", "Commander"]:
        key = section.find(f"Key[@name='{key_name}']")
        if key is None:
            key = ET.SubElement(section, "Key")
            key.set("name", key_name)
        value = key.find("Value")
        if value is None:
            value = ET.SubElement(key, "Value")
        value.set("string", commander)
        if "int" in value.attrib:
            del value.attrib["int"]

    tree.write(BANK_PATH, encoding="utf-8", xml_declaration=True)

def take_screenshot():
    """截图"""
    script = r'''
Add-Type -AssemblyName System.Windows.Forms
$screenshot = [System.Windows.Forms.Screen]::PrimaryScreen
$bmp = [System.Drawing.Bitmap]::new($screenshot.Bounds.Width, $screenshot.Bounds.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($screenshot.Bounds.Location, [System.Drawing.Point]::Empty, $screenshot.Bounds.Size)
$bmp.Save("E:\Code\MyMod\SC2\test_screenshot.png")
$graphics.Dispose()
$bmp.Dispose()
'''
    subprocess.run(["powershell", "-Command", script], capture_output=True)

def get_latest_log():
    """获取最新日志文件"""
    if not GAME_LOG_DIR.exists():
        return None
    logs = sorted(GAME_LOG_DIR.glob("*.txt"), key=lambda x: x.stat().st_mtime, reverse=True)
    return logs[0] if logs else None

# 主测试流程
print("=" * 50)
print("开始雷诺兵营/重工厂修复测试")
print("=" * 50)

# 1. 设置银行
print("\n[1/5] 设置银行为 Raynor...")
set_bank_commander("Raynor")
print("银行设置完成")

# 2. 杀掉旧进程
print("\n[2/5] 杀掉旧进程...")
kill_sc2()
time.sleep(3)
print("进程清理完成")

# 3. 检查地图是否存在
print(f"\n[3/5] 检查地图: {MAP_PATH}")
if not MAP_PATH.exists():
    print(f"错误: 地图不存在!")
    print(f"请确认地图路径: {MAP_PATH}")
    exit(1)
print("地图存在")

# 4. 启动游戏
print(f"\n[4/5] 启动游戏...")
print(f"地图: {MAP_PATH}")
subprocess.Popen([str(SWITCHER), str(MAP_PATH)])
print("游戏启动中，等待 150 秒让地图完全加载...")

# 等待游戏加载
time.sleep(150)

# 5. 截图
print("\n[5/5] 截图...")
take_screenshot()
print(f"截图已保存: {SCREENSHOT_PATH}")

# 检查日志
print("\n检查游戏日志...")
latest_log = get_latest_log()
if latest_log:
    print(f"最新日志: {latest_log.name}")
    with open(latest_log, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        if "UI.txt" in content or "Alerts.txt" in content:
            print("✓ 地图加载成功 (有UI/Alerts日志)")
        else:
            print("✗ 地图加载可能失败 (无UI/Alerts日志)")

print("\n" + "=" * 50)
print("测试完成! 请查看截图验证兵营/重工厂建造按钮")
print("=" * 50)
