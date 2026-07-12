"""RuntimeProbe Bank 文件 IO 模块

负责解析和写入 RuntimeProbe.SC2Bank XML 文件。
与 Neuro 项目的 bank_file_io.py 保持一致的值类型约定。
"""

import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


def parse_bank_value(value_node: ET.Element | None) -> Any:
    """解析 Bank Value 节点，返回 Python 值。

    支持的 XML 属性: flag, int, fixed, string, text
    """
    if value_node is None:
        return None

    if "flag" in value_node.attrib:
        return value_node.get("flag") == "1"
    if "int" in value_node.attrib:
        try:
            return int(value_node.get("int"))
        except (ValueError, TypeError):
            return 0
    if "fixed" in value_node.attrib:
        try:
            return float(value_node.get("fixed"))
        except (ValueError, TypeError):
            return 0.0
    if "string" in value_node.attrib:
        return value_node.get("string")
    if "text" in value_node.attrib:
        return value_node.get("text")
    return None


def parse_bank_file(bank_file: Path) -> dict[str, dict[str, Any]]:
    """解析 Bank 文件，返回 {section: {key: value}} 结构。"""
    if not bank_file.exists():
        return {}

    try:
        tree = ET.parse(bank_file)
    except ET.ParseError:
        return {}

    root = tree.getroot()
    parsed: dict[str, dict[str, Any]] = {}

    for section in root.findall("Section"):
        section_name = section.get("name", "")
        if not section_name:
            continue
        section_dict: dict[str, Any] = {}
        for key in section.findall("Key"):
            key_name = key.get("name", "")
            if not key_name:
                continue
            value_node = key.find("Value")
            section_dict[key_name] = parse_bank_value(value_node)
        parsed[section_name] = section_dict

    return parsed


def write_bank_values(bank_file: Path, updates: dict[str, dict[str, Any]]) -> None:
    """原子写入 Bank 值（先写临时文件再重命名）。

    Args:
        bank_file: Bank 文件路径
        updates: {section: {key: value}} 更新内容
    """
    if bank_file.exists():
        try:
            tree = ET.parse(bank_file)
        except ET.ParseError:
            tree = ET.ElementTree(ET.Element("Bank"))
    else:
        tree = ET.ElementTree(ET.Element("Bank"))

    root = tree.getroot()
    if root.tag != "Bank":
        root = ET.Element("Bank")
        tree = ET.ElementTree(root)

    for section_name, section_updates in updates.items():
        section = root.find(f"Section[@name='{section_name}']")
        if section is None:
            section = ET.SubElement(root, "Section")
            section.set("name", section_name)

        for key_name, value in section_updates.items():
            key = section.find(f"Key[@name='{key_name}']")
            if key is None:
                key = ET.SubElement(section, "Key")
                key.set("name", key_name)

            value_node = key.find("Value")
            if value_node is None:
                value_node = ET.SubElement(key, "Value")

            if isinstance(value, bool):
                value_node.set("flag", "1" if value else "0")
            elif isinstance(value, int):
                value_node.set("int", str(value))
            elif isinstance(value, float):
                value_node.set("fixed", f"{value:.6f}")
            elif isinstance(value, str):
                value_node.set("string", value)
            else:
                value_node.set("string", str(value))

    # 原子写入
    tmp_file = bank_file.with_suffix(".tmp")
    tree.write(str(tmp_file), encoding="utf-8", xml_declaration=True)
    tmp_file.replace(bank_file)


def parse_unit_value(value: str) -> dict[str, Any]:
    """解析 probe_units 的 value 字符串。

    格式: count:5,completed:5,in_progress:0,life_avg:45.0,...
    """
    result: dict[str, Any] = {}
    if not value or not isinstance(value, str):
        return result

    for field in value.split(","):
        if ":" not in field:
            continue
        k, v = field.split(":", 1)
        k = k.strip()
        v = v.strip()
        if k in ("count", "completed", "in_progress", "owner", "scan_id"):
            try:
                result[k] = int(v)
            except ValueError:
                result[k] = 0
        elif k in ("life_avg", "energy_avg"):
            try:
                result[k] = float(v)
            except ValueError:
                result[k] = 0.0
        elif k in ("is_structure", "is_worker"):
            result[k] = v in ("1", "true", "True")
        else:
            result[k] = v

    return result


def parse_upgrade_value(value: str) -> dict[str, Any]:
    """解析 probe_upgrades 的 value 字符串。"""
    result: dict[str, Any] = {}
    if not value or not isinstance(value, str):
        return result

    for field in value.split(","):
        if ":" not in field:
            continue
        k, v = field.split(":", 1)
        k = k.strip()
        v = v.strip()
        if k in ("researched", "in_progress", "available"):
            try:
                result[k] = int(v)
            except ValueError:
                result[k] = 0
        else:
            result[k] = v

    return result


def parse_producer_value(value: str) -> dict[str, Any]:
    """解析 probe_producers 的 value 字符串。

    格式: producer_count:1,trainable:BarracksTrainRaynor:0,blocked:,queue:,last_order:None
    trainable 字段可能包含冒号分隔的 abil:cmd 对，用分号分隔多对。
    """
    result: dict[str, Any] = {
        "producer_count": 0,
        "trainable": "",
        "blocked": "",
        "queue": "",
        "last_order": "None",
    }
    if not value or not isinstance(value, str):
        return result

    # 先提取已知字段前缀，再分割
    remaining = value
    for prefix in ("producer_count:", "trainable:", "blocked:", "queue:", "last_order:"):
        idx = remaining.find(prefix)
        if idx < 0:
            continue
        # 找到下一个字段的位置
        after = idx + len(prefix)
        next_idx = len(remaining)
        for next_prefix in ("producer_count:", "trainable:", "blocked:", "queue:", "last_order:"):
            ni = remaining.find(next_prefix, after)
            if ni >= 0 and ni < next_idx:
                next_idx = ni
        field_val = remaining[after:next_idx].rstrip(",").strip()
        key = prefix.rstrip(":")
        if key == "producer_count":
            try:
                result[key] = int(field_val)
            except ValueError:
                result[key] = 0
        else:
            result[key] = field_val
        remaining = remaining[:idx] + remaining[next_idx:]

    return result
