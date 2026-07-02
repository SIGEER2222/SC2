"""SC2 单位关系图查询工具

给定一个单位 ID，图式地展开所有关联信息（不启动游戏）：

  - 工蜂/SCV/探针：可建造建筑（CAbilBuild.InfoArray.Unit）
  - 幼虫：可变异单位（CAbilTrain.InfoArray.Unit）
  - 建筑：可生产单位（CAbilTrain）+ 可研究科技（CAbilResearch）+ 附件
  - 兵种：拥有的技能（AbilArray）+ 卡牌按钮（CardLayouts）+ 武器
  - 反向：谁生产我 / 谁建造我 / 谁变异成我

数据来源：多层 mod 按 SC2 引擎规则合并
（core → liberty → swarm → void → starcoop → CoopZeroPop → CommanderCatalog → XM）

用法::

    python sc2_unit_explorer.py Larva
    python sc2_unit_explorer.py Drone --depth 2
    python sc2_unit_explorer.py Barracks --format json
    python sc2_unit_explorer.py Marine --mod "E:\\path\\OtherMod.SC2Mod"
    python sc2_unit_explorer.py --list-units --filter "^Larva"
    python sc2_unit_explorer.py --list-abilities --filter "Train$"

限制说明：
  - 仅静态分析 GameData XML，不解析 galaxy 脚本运行时调用
    （如 UnitAbilityAdd / CatalogFieldValueSet 等动态修改无法看到）
  - Actor 数据不解析（仅用于显示模型）
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple, Iterable

# ---------------------------------------------------------------------------
# 路径配置
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[1]
NATIVE_MODS_ROOT = Path(r"E:\Code\MyMod\SC2\sc2-data-trigger\mods")
STARCOOP_NATIVE_ROOT = PROJECT_ROOT / "游戏数据" / "官方SC2原始文本镜像" / "mods" / "starcoop"
XM_DIR = PROJECT_ROOT / "XM"

# 默认加载顺序：后者覆盖前者
DEFAULT_MOD_PATHS: List[Path] = [
    NATIVE_MODS_ROOT / "core.sc2mod",
    NATIVE_MODS_ROOT / "liberty.sc2mod",
    NATIVE_MODS_ROOT / "swarm.sc2mod",
    NATIVE_MODS_ROOT / "void.sc2mod",
    STARCOOP_NATIVE_ROOT / "starcoop.sc2mod",
    PROJECT_ROOT / "Mods" / "7vs1" / "CoopZeroPop.SC2Mod",
    PROJECT_ROOT / "Mods" / "7vs1" / "CommanderCatalog.SC2Mod",
]

# 自动追加 XM 下的所有 *.SC2Mod 子目录（按字母序）
if XM_DIR.is_dir():
    for _child in sorted(XM_DIR.iterdir()):
        if _child.is_dir() and _child.name.upper().endswith(".SC2MOD"):
            DEFAULT_MOD_PATHS.append(_child)
    del _child

# ---------------------------------------------------------------------------
# Catalog 类型表
# ---------------------------------------------------------------------------
# tag 前缀 → catalog 名（用于匹配 CUnit/CAbil* 等）
CATALOG_TAGS: Dict[str, str] = {
    "CUnit": "Unit",
    "CAbilBuild": "Abil",
    "CAbilTrain": "Abil",
    "CAbilResearch": "Abil",
    "CAbilMorph": "Abil",
    "CAbilMorphPlacement": "Abil",
    "CAbilQueue": "Abil",
    "CAbilEffectTarget": "Abil",
    "CAbilEffectInstant": "Abil",
    "CAbilAttack": "Abil",
    "CAbilStop": "Abil",
    "CAbilMove": "Abil",
    "CAbilAcquire": "Abil",
    "CAbilHoldPosition": "Abil",
    "CAbilPatrol": "Abil",
    "CAbilRally": "Abil",
    "CAbilRallyPoint": "Abil",
    "CAbilCargo": "Abil",
    "CAbilLoad": "Abil",
    "CAbilUnload": "Abil",
    "CAbilMerge": "Abil",
    "CAbilBehavior": "Abil",
    "CButton": "Button",
    "CEffect": "Effect",
    "CBehavior": "Behavior",
    "CUpgrade": "Upgrade",
    "CRequirement": "Requirement",
    "CWeapon": "Weapon",
    "CActor": "Actor",
    "CAbilSet": "Abil",
}

# 每种 catalog 顶层元素的 id 关键字
def catalog_for_tag(tag: str) -> Optional[str]:
    """CUnit → Unit, CAbilTrain → Abil, CButton → Button..."""
    if tag in CATALOG_TAGS:
        return CATALOG_TAGS[tag]
    # 通用前缀匹配：CEffectDamage → Effect, CBehaviorBuff → Behavior
    for prefix, cat in (
        ("CEffect", "Effect"),
        ("CBehavior", "Behavior"),
        ("CWeapon", "Weapon"),
        ("CAbil", "Abil"),
        ("CActor", "Actor"),
    ):
        if tag.startswith(prefix):
            return cat
    return None


# ---------------------------------------------------------------------------
# XML 合并语义
# ---------------------------------------------------------------------------
def _key_attrs(elem: ET.Element) -> List[str]:
    """返回该元素用于匹配的关键属性名。

    SC2 数据合并语义：
      - id: 顶层 catalog 元素的标识
      - index: InfoArray/FlagsArray 等的索引覆盖
      - Row+Column: CardLayouts.LayoutButtons 的位置键
      - value: 简单值元素
      - Link: 引用元素
      - 都没有: 视为追加（不合并）
    """
    if "id" in elem.attrib:
        return ["id"]
    if "index" in elem.attrib:
        return ["index"]
    # CardLayouts.LayoutButtons 用 Row+Column 定位
    if "Row" in elem.attrib and "Column" in elem.attrib:
        return ["Row", "Column"]
    if "value" in elem.attrib and not list(elem):
        return ["value"]
    if "Link" in elem.attrib:
        return ["Link"]
    return []


def _match_key(a: ET.Element, b: ET.Element, keys: List[str]) -> bool:
    if not keys:
        # 无关键字段：视为不同元素，总是追加（不合并）
        return False
    return all(a.get(k) == b.get(k) for k in keys)


def merge_element(dst: ET.Element, src: ET.Element) -> None:
    """将 src 子元素合并到 dst，处理 index 覆盖、removed、属性更新。

    合并规则（参考 SC2 编辑器数据合并机制）:
      1. 同 tag + 同关键属性 (id/index/value/Link) → 递归合并
      2. removed="1" → 从 dst 移除匹配子元素
      3. 否则追加到 dst
      4. 属性更新：src 的属性覆盖 dst（removed 除外）
    """
    # 先处理 removed 子元素，避免误匹配
    for src_child in list(src):
        if src_child.get("removed") == "1":
            keys = _key_attrs(src_child)
            for dst_child in list(dst):
                if dst_child.tag == src_child.tag and _match_key(dst_child, src_child, keys):
                    dst.remove(dst_child)
            # 不追加 removed 元素本身
            continue

    for src_child in list(src):
        keys = _key_attrs(src_child)
        match: Optional[ET.Element] = None
        for dst_child in list(dst):
            if dst_child.tag == src_child.tag and _match_key(dst_child, src_child, keys):
                match = dst_child
                break

        if match is not None:
            # 合并属性
            for k, v in src_child.attrib.items():
                if k != "removed":
                    match.set(k, v)
            # 递归
            merge_element(match, src_child)
        else:
            # 追加深拷贝
            dst.append(ET.fromstring(ET.tostring(src_child)))


def merge_catalogs(dst: Dict[str, Dict[str, ET.Element]],
                   src: Dict[str, Dict[str, ET.Element]]) -> None:
    """把 src 合并到 dst。两者结构: {catalog_name: {id: Element}}"""
    for cat, src_map in src.items():
        if cat not in dst:
            dst[cat] = {}
        for elem_id, src_elem in src_map.items():
            if elem_id in dst[cat]:
                # 合并属性 + 递归子元素
                for k, v in src_elem.attrib.items():
                    if k != "removed":
                        dst[cat][elem_id].set(k, v)
                merge_element(dst[cat][elem_id], src_elem)
            else:
                dst[cat][elem_id] = ET.fromstring(ET.tostring(src_elem))


# ---------------------------------------------------------------------------
# Mod 加载
# ---------------------------------------------------------------------------
def _game_data_dir(mod_root: Path) -> Optional[Path]:
    candidate = mod_root / "Base.SC2Data" / "GameData"
    if candidate.is_dir():
        return candidate
    candidate = mod_root / "base.sc2data" / "gamedata"
    if candidate.is_dir():
        return candidate
    return None


def _localized_data_dir(mod_root: Path, lang: str = "zhCN") -> Optional[Path]:
    for variant in (lang, lang.lower(), lang.upper()):
        candidate = mod_root / f"{variant}.SC2Data" / "LocalizedData"
        if candidate.is_dir():
            return candidate
        candidate = mod_root / f"{variant.lower()}.sc2data" / "localizeddata"
        if candidate.is_dir():
            return candidate
    return None


def _read_xml_lenient(path: Path) -> Optional[ET.Element]:
    """宽容地解析 SC2 XML 文件。

    已知问题：
      1. 部分文件 XML 声明为 us-ascii 但内容含中文 → 强制 utf-8 解码并去除 encoding 声明
      2. 部分文件没有 <Catalog> 根包装（多个顶层元素直接并列）→ 自动包装
      3. 注释中含中文标点等非声明的字符 → 由 utf-8 解码后即可正常解析
    """
    try:
        raw = path.read_bytes()
    except OSError:
        return None
    text = raw.decode("utf-8-sig", errors="replace")
    # 去除 XML 声明里的 encoding 属性（避免与实际编码冲突）
    text = re.sub(r'<\?xml[^?]*\?>',
                  '<?xml version="1.0"?>',
                  text, count=1)
    # 检查根元素是否为 <Catalog>。先去除 XML 声明和空白
    body_after_decl = re.sub(r'^\s*<\?xml[^?]*\?>\s*', '', text.lstrip())
    if not body_after_decl.startswith("<Catalog"):
        # 没有 <Catalog> 包装：去除可能存在的尾部 </Catalog>（部分文件开头缺、结尾有）
        body_after_decl = re.sub(r'</Catalog>\s*$', '', body_after_decl.rstrip())
        text = '<?xml version="1.0"?>\n<Catalog>\n' + body_after_decl + '\n</Catalog>'
    try:
        return ET.fromstring(text)
    except ET.ParseError as e:
        print(f"[WARN] 解析失败 {path}: {e}", file=sys.stderr)
        return None


def load_mod_xml(mod_root: Path) -> Dict[str, Dict[str, ET.Element]]:
    """加载一个 mod 的所有 GameData XML，返回 {catalog: {id: Element}}

    同一 mod 内若多个 XML 文件定义了相同 id 的 catalog 条目，按 SC2 引擎规则
    递归合并（而非后者覆盖前者）。
    """
    gd = _game_data_dir(mod_root)
    if gd is None:
        return {}
    catalogs: Dict[str, Dict[str, ET.Element]] = {}
    for xml_file in sorted(gd.glob("*.xml")):
        root = _read_xml_lenient(xml_file)
        if root is None:
            continue
        for elem in root:
            cat = catalog_for_tag(elem.tag)
            if cat is None or "id" not in elem.attrib:
                continue
            # 规范化：CardLayouts 没有 index 时默认为 index="0"
            # （SC2 引擎的隐式默认值，让多个 mod 的 CardLayouts 能正确合并）
            for cl in elem.findall("CardLayouts"):
                if "index" not in cl.attrib:
                    cl.set("index", "0")
            elem_id = elem.attrib["id"]
            cat_map = catalogs.setdefault(cat, {})
            if elem_id in cat_map:
                # 同 mod 内同 id 条目：递归合并（SC2 引擎行为）
                existing = cat_map[elem_id]
                for k, v in elem.attrib.items():
                    if k != "removed":
                        existing.set(k, v)
                merge_element(existing, elem)
            else:
                cat_map[elem_id] = elem
    return catalogs


def load_localization(mod_paths: Iterable[Path], lang: str = "zhCN") -> Dict[str, str]:
    """加载 GameStrings.txt（key=value 格式）"""
    strings: Dict[str, str] = {}
    for mod in mod_paths:
        ld = _localized_data_dir(mod, lang)
        if ld is None:
            continue
        for name in ("GameStrings.txt", "ObjectStrings.txt", "TriggerStrings.txt"):
            f = ld / name
            if not f.is_file():
                continue
            try:
                # SC2 文本通常是 utf-8，少数是 utf-8-sig
                text = f.read_text(encoding="utf-8-sig", errors="replace")
            except OSError:
                continue
            for line in text.splitlines():
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                strings[k.strip()] = v.strip()
    return strings


# ---------------------------------------------------------------------------
# 数据模型
# ---------------------------------------------------------------------------
@dataclass
class AbilityRef:
    """单位拥有的能力引用"""
    abil_id: str
    cmd: Optional[str] = None  # 卡牌按钮指定的命令（如 Move, Build11）
    face: Optional[str] = None  # 按钮图标
    button_id: Optional[str] = None  # 按钮ID（如果通过 Button 字段指定）
    tooltip_key: Optional[str] = None
    runtime: bool = False  # 是否由 galaxy 脚本运行时注入（UnitAbilityAdd）


@dataclass
class TrainEntry:
    """CAbilTrain/CAbilBuild 的 InfoArray 项目"""
    abil_id: str
    cmd_index: str  # 如 Train7, Build21
    unit_id: Optional[str]
    button_face: Optional[str]
    time: Optional[str]
    requirements: Optional[str]
    cost_minerals: Optional[str] = None
    cost_vespene: Optional[str] = None


@dataclass
class ResearchEntry:
    """CAbilResearch 的 InfoArray 项目"""
    abil_id: str
    cmd_index: str  # 如 Research2
    upgrade_id: Optional[str]
    button_face: Optional[str]
    time: Optional[str]
    requirements: Optional[str]
    cost_minerals: Optional[str] = None
    cost_vespene: Optional[str] = None


@dataclass
class MorphEntry:
    """CAbilMorph 的目标"""
    abil_id: str
    target_unit_id: Optional[str]


@dataclass
class UnitNode:
    """单位的完整关联数据"""
    unit_id: str
    name: str = ""
    race: str = ""
    parent: Optional[str] = None
    attributes: List[str] = field(default_factory=list)
    abilities: List[AbilityRef] = field(default_factory=list)
    card_layouts: List[Dict] = field(default_factory=list)
    # 正向（我能做什么）
    trains: List[TrainEntry] = field(default_factory=list)
    builds: List[TrainEntry] = field(default_factory=list)
    researches: List[ResearchEntry] = field(default_factory=list)
    morphs_to: List[MorphEntry] = field(default_factory=list)
    weapons: List[str] = field(default_factory=list)
    # 运行时：科技树锁定状态（galaxy TechTreeAllow 的结果）
    tech_locked: bool = False  # 是否被 TechTreeUnitAllow 禁用
    tech_unlocked: bool = False  # 是否被显式启用
    # 反向（谁能生产/建造/变异成我）
    produced_by: List[TrainEntry] = field(default_factory=list)
    built_by: List[TrainEntry] = field(default_factory=list)
    morphed_from: List[MorphEntry] = field(default_factory=list)
    # 原始元素（debug 用）
    raw_attrs: Dict[str, str] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Catalog 数据库
# ---------------------------------------------------------------------------
class CatalogDB:
    def __init__(self, mod_paths: List[Path], lang: str = "zhCN"):
        self.mod_paths = mod_paths
        self.lang = lang
        # {catalog: {id: Element}}，按 mod 顺序合并
        self.catalogs: Dict[str, Dict[str, ET.Element]] = {}
        # 反向索引：unit_id → [(abil_id, cmd_index, TrainEntry-ish), ...]
        self._reverse_train: Dict[str, List[Tuple[str, str, ET.Element]]] = defaultdict(list)
        self._reverse_build: Dict[str, List[Tuple[str, str, ET.Element]]] = defaultdict(list)
        self._reverse_morph: Dict[str, List[Tuple[str, ET.Element]]] = defaultdict(list)
        self._reverse_research_upgrade: Dict[str, List[Tuple[str, str, ET.Element]]] = defaultdict(list)
        self.strings: Dict[str, str] = {}
        self._loaded = False
        # galaxy 脚本运行时解析结果
        # 单位 → [能力 ID]（通过 UnitAbilityAdd 动态注入）
        self.galaxy_unit_abilities: Dict[str, List[str]] = defaultdict(list)
        # 单位 → True/False（TechTreeUnitAllow 的启用/禁用状态）
        self.galaxy_unit_tech: Dict[str, bool] = {}
        # 能力 → True/False（TechTreeAbilityAllow 的启用/禁用状态）
        self.galaxy_abil_tech: Dict[str, bool] = {}

    # ---- 加载 ----
    def load(self) -> None:
        if self._loaded:
            return
        for mod in self.mod_paths:
            if not mod.is_dir():
                print(f"[WARN] mod 路径不存在: {mod}", file=sys.stderr)
                continue
            data = load_mod_xml(mod)
            merge_catalogs(self.catalogs, data)
        self.strings = load_localization(self.mod_paths, self.lang)
        self._build_reverse_index()
        # 解析 galaxy 脚本的运行时动态修改
        self._load_galaxy_scripts()
        self._loaded = True

    def _build_reverse_index(self) -> None:
        """构建单位 → 谁能生产/建造/变异成它 的反向索引"""
        for abil_id, elem in self.catalogs.get("Abil", {}).items():
            tag = elem.tag
            if tag in ("CAbilTrain", "CAbilBuild"):
                for info in elem.findall("InfoArray"):
                    idx = info.get("index")
                    if idx is None:
                        continue
                    if info.get("removed") == "1":
                        continue
                    # 单位引用：InfoArray.Unit value= 或子元素 <Unit value=...>
                    target_unit = self._extract_unit_ref(info)
                    if target_unit:
                        if tag == "CAbilTrain":
                            self._reverse_train[target_unit].append((abil_id, idx, info))
                        else:
                            self._reverse_build[target_unit].append((abil_id, idx, info))
            elif tag == "CAbilMorph":
                target_unit = elem.get("unit") or self._extract_unit_ref(elem)
                if target_unit:
                    self._reverse_morph[target_unit].append((abil_id, elem))
                # 也检查 InfoArray
                for info in elem.findall("InfoArray"):
                    if info.get("removed") == "1":
                        continue
                    target_unit = self._extract_unit_ref(info) or info.get("unit")
                    if target_unit:
                        self._reverse_morph[target_unit].append((abil_id, info))
            elif tag == "CAbilResearch":
                for info in elem.findall("InfoArray"):
                    if info.get("removed") == "1":
                        continue
                    upg = info.get("Upgrade")
                    if upg:
                        self._reverse_research_upgrade[upg].append((abil_id, info.get("index", ""), info))

    @staticmethod
    def _extract_unit_ref(info: ET.Element) -> Optional[str]:
        """从 InfoArray 提取单位引用。

        优先级：
          1. InfoArray 自身的 Unit 属性
          2. <Unit value="..."/> 子元素，多个时取最后一个非 removed 且 value 非空的
             （SC2 合并语义：后定义的覆盖先定义的，<Unit index="0" removed="1"/> 表示移除）
        """
        u = info.get("Unit")
        if u:
            return u
        result: Optional[str] = None
        for child in info.findall("Unit"):
            if child.get("removed") == "1":
                result = None  # 移除当前默认值
                continue
            v = child.get("value")
            if v:  # 非空才记录（空 value 不覆盖）
                result = v
        return result

    # ---- galaxy 脚本运行时解析 ----
    def _load_galaxy_scripts(self) -> None:
        """扫描所有 mod 下的 galaxy 脚本，解析运行时动态修改。

        解析三类调用：
          1. UnitAbilityAdd(var, "AbilId")       → 单位能力注入
          2. TechTreeUnitAllow(p, "UnitId", bool) → 单位科技树解锁/锁定
          3. TechTreeAbilityAllow(p, AbilityCommand("AbilId", cmd), bool) → 能力科技树解锁/锁定

        UnitAbilityAdd 的单位类型通过上下文推断：
          - 同一函数内最近的 `UnitGetType(var) == "UnitId"` 或 `lv_type == "UnitId"`
          - 支持复合 || 条件中的多个单位类型
        """
        galaxy_files: List[Path] = []
        for mod in self.mod_paths:
            if not mod.is_dir():
                continue
            # galaxy 脚本通常在 Base.SC2Data 根目录
            base_dir = mod / "Base.SC2Data"
            if base_dir.is_dir():
                galaxy_files.extend(sorted(base_dir.glob("*.galaxy")))
        if not galaxy_files:
            return

        total_inject = 0
        total_tech = 0
        for gf in galaxy_files:
            try:
                text = gf.read_text(encoding="utf-8-sig", errors="replace")
            except OSError:
                continue
            n_inj, n_tech = self._parse_galaxy_text(text)
            total_inject += n_inj
            total_tech += n_tech
        if total_inject or total_tech:
            print(f"[INFO] galaxy 脚本解析: {len(galaxy_files)} 个文件, "
                  f"动态注入能力 {total_inject} 项, 科技树解锁/锁定 {total_tech} 项",
                  file=sys.stderr)

    def _parse_galaxy_text(self, text: str) -> Tuple[int, int]:
        """解析单个 galaxy 文件文本，返回 (注入能力数, 科技树操作数)"""
        lines = text.splitlines()
        n_inj = 0
        n_tech = 0
        # 当前上下文中的单位类型集合（由 UnitGetType 条件推断）
        # 用栈处理嵌套 if，但简化为：遇到新的条件就替换，遇到 } 不处理（保守）
        current_units: List[str] = []

        # 正则模式
        # UnitAbilityAdd(var, "AbilId")
        re_add = re.compile(r'UnitAbilityAdd\s*\([^,]+,\s*"([^"]+)"')
        # TechTreeUnitAllow(p, "UnitId", true/false)
        re_unit_allow = re.compile(r'TechTreeUnitAllow\s*\([^,]+,\s*"([^"]+)"\s*,\s*(true|false)')
        # TechTreeAbilityAllow(p, AbilityCommand("AbilId", cmd), true/false)
        re_abil_allow = re.compile(
            r'TechTreeAbilityAllow\s*\([^,]+,\s*AbilityCommand\s*\(\s*"([^"]+)"'
            r'\s*,\s*\d+\s*\)\s*,\s*(true|false)')
        # 封装函数调用（雷诺/凯瑞甘/通用 RuntimeSafety 等）
        # 模式：gf_*Allow*Unit*(..., "UnitId")  → 解锁单位
        #       gf_*Block*Unit*(..., "UnitId")  → 锁定单位
        #       gf_*Allow*Ability*(..., "AbilId", ...)  → 解锁能力
        #       gf_*Block*Ability*(..., "AbilId", ...)  → 锁定能力
        re_wrap_allow_unit = re.compile(r'gf_\w*Allow\w*Unit\w*\s*\([^,]+,\s*"([^"]+)"')
        re_wrap_block_unit = re.compile(r'gf_\w*Block\w*Unit\w*\s*\([^,]+,\s*"([^"]+)"')
        re_wrap_allow_abil = re.compile(r'gf_\w*Allow\w*Abil\w*\s*\([^,]+,\s*"([^"]+)"')
        re_wrap_block_abil = re.compile(r'gf_\w*Block\w*Abil\w*\s*\([^,]+,\s*"([^"]+)"')
        # UnitGetType(var) == "UnitId" 或 lv_type == "UnitId"
        # 注意：UnitGetType(EventUnit()) 有嵌套括号，分两步匹配
        # 1. 行内含 UnitGetType 或 lv_type 关键字
        # 2. 提取所有 == "XXX" 的单位 ID
        for line in lines:
            stripped = line.strip()

            # 跳过注释行
            if stripped.startswith("//"):
                continue

            # 先检测上下文：含 UnitGetType/lv_type 的条件行，提取所有 == "XXX"
            if 'UnitGetType' in line or 'lv_type' in line:
                type_matches = re.findall(r'==\s*"([^"]+)"', line)
                if type_matches:
                    current_units = type_matches  # 替换为当前条件的单位列表

            # TechTreeUnitAllow
            for m in re_unit_allow.finditer(line):
                unit_id, flag = m.group(1), m.group(2) == "true"
                # 后定义覆盖前者
                self.galaxy_unit_tech[unit_id] = flag
                n_tech += 1

            # TechTreeAbilityAllow
            for m in re_abil_allow.finditer(line):
                abil_id, flag = m.group(1), m.group(2) == "true"
                self.galaxy_abil_tech[abil_id] = flag
                n_tech += 1

            # 封装函数：AllowUnit
            for m in re_wrap_allow_unit.finditer(line):
                unit_id = m.group(1)
                self.galaxy_unit_tech[unit_id] = True
                n_tech += 1

            # 封装函数：BlockUnit
            for m in re_wrap_block_unit.finditer(line):
                unit_id = m.group(1)
                self.galaxy_unit_tech[unit_id] = False
                n_tech += 1

            # 封装函数：AllowAbility
            for m in re_wrap_allow_abil.finditer(line):
                abil_id = m.group(1)
                self.galaxy_abil_tech[abil_id] = True
                n_tech += 1

            # 封装函数：BlockAbility
            for m in re_wrap_block_abil.finditer(line):
                abil_id = m.group(1)
                self.galaxy_abil_tech[abil_id] = False
                n_tech += 1

            # UnitAbilityAdd —— 只在上下文有单位类型时关联
            for m in re_add.finditer(line):
                abil_id = m.group(1)
                for uid in current_units:
                    if abil_id not in self.galaxy_unit_abilities[uid]:
                        self.galaxy_unit_abilities[uid].append(abil_id)
                        n_inj += 1

        return n_inj, n_tech

    def get_runtime_abilities(self, unit_id: str) -> List[str]:
        """获取单位通过 UnitAbilityAdd 动态注入的能力 ID 列表"""
        return self.galaxy_unit_abilities.get(unit_id, [])

    # ---- 查询 ----
    def get_unit(self, unit_id: str) -> Optional[ET.Element]:
        return self.catalogs.get("Unit", {}).get(unit_id)

    def get_abil(self, abil_id: str) -> Optional[ET.Element]:
        return self.catalogs.get("Abil", {}).get(abil_id)

    def get_button(self, btn_id: str) -> Optional[ET.Element]:
        return self.catalogs.get("Button", {}).get(btn_id)

    def get_upgrade(self, upg_id: str) -> Optional[ET.Element]:
        return self.catalogs.get("Upgrade", {}).get(upg_id)

    def get_effect(self, eff_id: str) -> Optional[ET.Element]:
        return self.catalogs.get("Effect", {}).get(eff_id)

    def get_behavior(self, bhv_id: str) -> Optional[ET.Element]:
        return self.catalogs.get("Behavior", {}).get(bhv_id)

    # ---- 本地化 ----
    def tr(self, key: str) -> str:
        return self.strings.get(key, "")

    def unit_name(self, unit_id: str) -> str:
        if not unit_id:
            return ""
        # Unit/Name/<id> 是主要键，部分用 Unit/Name/<id>@Hero
        for key in (f"Unit/Name/{unit_id}", f"Unit/Name/{unit_id}@Hero"):
            v = self.tr(key)
            if v:
                return v
        # 备选：Button/Name/<id>
        v = self.tr(f"Button/Name/{unit_id}")
        return v or unit_id

    def button_name(self, face_or_id: str) -> str:
        """根据 button face id 查询名称。只用 Button/Name/* 不用 Tooltip（Tooltip 是详细描述）"""
        if not face_or_id:
            return ""
        for key in (f"Button/Name/{face_or_id}",
                    f"Button/Name/{face_or_id}@Hero"):
            v = self.tr(key)
            if v:
                return v
        return ""  # 找不到返回空，由调用方决定显示 face 还是空

    def upgrade_name(self, upg_id: str) -> str:
        if not upg_id:
            return ""
        for key in (f"Upgrade/Name/{upg_id}",):
            v = self.tr(key)
            if v:
                return v
        return upg_id

    def abil_name(self, abil_id: str) -> str:
        if not abil_id:
            return ""
        for key in (f"Abil/Name/{abil_id}", f"Button/Name/{abil_id}"):
            v = self.tr(key)
            if v:
                return v
        return abil_id


# ---------------------------------------------------------------------------
# 单位关联解析
# ---------------------------------------------------------------------------
def parse_unit(db: CatalogDB, unit_id: str) -> Optional[UnitNode]:
    elem = db.get_unit(unit_id)
    if elem is None:
        return None

    node = UnitNode(unit_id=unit_id)
    node.raw_attrs = dict(elem.attrib)
    node.parent = elem.get("parent")
    node.race = elem.get("Race", "")
    node.name = db.unit_name(unit_id)

    # 属性（Attributes index="Armored" value="1"）
    for a in elem.findall("Attributes"):
        if a.get("value") == "1":
            node.attributes.append(a.get("index", ""))

    # 拥有的能力
    for ab in elem.findall("AbilArray"):
        if ab.get("removed") == "1":
            continue
        link = ab.get("Link")
        if not link:
            continue
        node.abilities.append(AbilityRef(abil_id=link))

    # 武器
    for w in elem.findall("WeaponArray"):
        if w.get("removed") == "1":
            continue
        link = w.get("Link")
        if link:
            node.weapons.append(link)

    # 卡牌布局（CardLayouts）—— 按 (Row, Column) 去重，后者覆盖前者
    seen_pos: Dict[Tuple[str, str], Dict] = {}
    ordered_entries: List[Dict] = []
    for cl in elem.findall("CardLayouts"):
        card_id = cl.get("CardId", "")
        for lb in cl.findall("LayoutButtons"):
            if lb.get("removed") == "1":
                continue
            entry = {
                "card_id": card_id,
                "index": lb.get("index"),
                "face": lb.get("Face"),
                "type": lb.get("Type"),
                "abil_cmd": lb.get("AbilCmd"),
                "row": lb.get("Row"),
                "column": lb.get("Column"),
                "state": lb.get("State"),
            }
            # 关联到能力
            abil_cmd = lb.get("AbilCmd")
            if abil_cmd and "," in abil_cmd:
                aid, cmd = abil_cmd.split(",", 1)
                entry["abil_id"] = aid
                entry["cmd"] = cmd
                # 补全 abilities 列表（卡牌中出现但未在 AbilArray 中显式声明的）
                if not any(a.abil_id == aid for a in node.abilities):
                    node.abilities.append(AbilityRef(
                        abil_id=aid, cmd=cmd, face=lb.get("Face")
                    ))
            # 用 (Row, Column) 去重，后出现的覆盖前者
            pos_key = (entry.get("row") or "", entry.get("column") or "")
            if pos_key in seen_pos:
                seen_pos[pos_key].update(entry)
            else:
                seen_pos[pos_key] = entry
                ordered_entries.append(entry)
    # 没有 Row/Column 的按钮（如纯 index 形式）保留全部
    for e in ordered_entries:
        node.card_layouts.append(e)

    # 解析 Train/Build/Research/Morph 能力
    for ab_ref in node.abilities:
        abil_elem = db.get_abil(ab_ref.abil_id)
        if abil_elem is None:
            continue
        tag = abil_elem.tag
        if tag == "CAbilTrain":
            for info in abil_elem.findall("InfoArray"):
                if info.get("removed") == "1":
                    continue
                idx = info.get("index", "")
                target = CatalogDB._extract_unit_ref(info)
                node.trains.append(TrainEntry(
                    abil_id=ab_ref.abil_id, cmd_index=idx, unit_id=target,
                    button_face=_last_button_face(info), time=info.get("Time"),
                    requirements=_attr_of(info, "Requirements") or _last_button_attr(info, "Requirements"),
                    cost_minerals=_cost_of(info, "Minerals"),
                    cost_vespene=_cost_of(info, "Vespene"),
                ))
        elif tag == "CAbilBuild":
            for info in abil_elem.findall("InfoArray"):
                if info.get("removed") == "1":
                    continue
                idx = info.get("index", "")
                target = info.get("Unit") or CatalogDB._extract_unit_ref(info)
                node.builds.append(TrainEntry(
                    abil_id=ab_ref.abil_id, cmd_index=idx, unit_id=target,
                    button_face=_last_button_face(info), time=info.get("Time"),
                    requirements=_attr_of(info, "Requirements") or _last_button_attr(info, "Requirements"),
                    cost_minerals=_cost_of(info, "Minerals"),
                    cost_vespene=_cost_of(info, "Vespene"),
                ))
        elif tag == "CAbilResearch":
            for info in abil_elem.findall("InfoArray"):
                if info.get("removed") == "1":
                    continue
                idx = info.get("index", "")
                upg = info.get("Upgrade")
                node.researches.append(ResearchEntry(
                    abil_id=ab_ref.abil_id, cmd_index=idx, upgrade_id=upg,
                    button_face=_last_button_face(info), time=info.get("Time"),
                    requirements=_attr_of(info, "Requirements") or _last_button_attr(info, "Requirements"),
                    cost_minerals=_cost_of(info, "Minerals"),
                    cost_vespene=_cost_of(info, "Vespene"),
                ))
        elif tag == "CAbilMorph":
            target = abil_elem.get("unit") or CatalogDB._extract_unit_ref(abil_elem)
            for info in abil_elem.findall("InfoArray"):
                if info.get("removed") == "1":
                    continue
                t = info.get("unit") or CatalogDB._extract_unit_ref(info) or target
                if t:
                    node.morphs_to.append(MorphEntry(abil_id=ab_ref.abil_id, target_unit_id=t))
            if target and not node.morphs_to:
                node.morphs_to.append(MorphEntry(abil_id=ab_ref.abil_id, target_unit_id=target))

    # 反向：谁生产我 / 谁建造我 / 谁变异成我
    for abil_id, cmd_idx, info in db._reverse_train.get(unit_id, []):
        node.produced_by.append(TrainEntry(
            abil_id=abil_id, cmd_index=cmd_idx, unit_id=unit_id,
            button_face=_last_button_face(info), time=info.get("Time"),
            requirements=_attr_of(info, "Requirements") or _last_button_attr(info, "Requirements"),
            cost_minerals=_cost_of(info, "Minerals"),
            cost_vespene=_cost_of(info, "Vespene"),
        ))
    for abil_id, cmd_idx, info in db._reverse_build.get(unit_id, []):
        node.built_by.append(TrainEntry(
            abil_id=abil_id, cmd_index=cmd_idx, unit_id=unit_id,
            button_face=_last_button_face(info), time=info.get("Time"),
            requirements=_attr_of(info, "Requirements") or _last_button_attr(info, "Requirements"),
            cost_minerals=_cost_of(info, "Minerals"),
            cost_vespene=_cost_of(info, "Vespene"),
        ))
    for abil_id, info in db._reverse_morph.get(unit_id, []):
        node.morphed_from.append(MorphEntry(abil_id=abil_id, target_unit_id=unit_id))

    # parent 继承：当单位自身没有定义某类数据时，从父类继承
    # （SC2 数据中 parent="Bunker" 会继承 Bunker 的 AbilArray/CardLayouts/能力等）
    if node.parent and node.parent in db.catalogs.get("Unit", {}):
        parent_node = parse_unit(db, node.parent)
        if parent_node:
            # 继承规则：子类已有的不覆盖，子类没有的从父类继承
            # 能力：合并（子类优先，但保留父类独有的）
            existing_abil_ids = {a.abil_id for a in node.abilities}
            for pa in parent_node.abilities:
                if pa.abil_id not in existing_abil_ids:
                    node.abilities.append(AbilityRef(
                        abil_id=pa.abil_id, cmd=pa.cmd, face=pa.face,
                        button_id=pa.button_id, tooltip_key=pa.tooltip_key
                    ))
                    existing_abil_ids.add(pa.abil_id)
            # 卡牌按钮：合并（子类优先）
            existing_cards = {(c.get("row"), c.get("column"), c.get("abil_id"))
                              for c in node.card_layouts}
            for pc in parent_node.card_layouts:
                key = (pc.get("row"), pc.get("column"), pc.get("abil_id"))
                if key not in existing_cards:
                    node.card_layouts.append(pc)
            # 可生产/可建造/可研究/可变形：子类为空时继承父类
            if not node.trains:
                node.trains = list(parent_node.trains)
            if not node.builds:
                node.builds = list(parent_node.builds)
            if not node.researches:
                node.researches = list(parent_node.researches)
            if not node.morphs_to:
                node.morphs_to = list(parent_node.morphs_to)
            # 武器：合并
            if not node.weapons:
                node.weapons = list(parent_node.weapons)
            # 属性：合并
            if not node.attributes:
                node.attributes = list(parent_node.attributes)

    # 去重：按 unit_id/upgrade_id 保留第一个（多个能力可能指向同一目标）
    node.trains = _dedup_by_unit(node.trains)
    node.builds = _dedup_by_unit(node.builds)
    node.morphs_to = _dedup_by_unit(node.morphs_to, key_field="target_unit_id")
    node.researches = _dedup_by_upgrade(node.researches)

    # galaxy 脚本运行时注入的能力（UnitAbilityAdd）
    existing_abil_ids = {a.abil_id for a in node.abilities}
    for runtime_abil_id in db.get_runtime_abilities(unit_id):
        if runtime_abil_id in existing_abil_ids:
            continue
        node.abilities.append(AbilityRef(abil_id=runtime_abil_id, runtime=True))
        existing_abil_ids.add(runtime_abil_id)

    # 科技树状态（TechTreeUnitAllow）
    if unit_id in db.galaxy_unit_tech:
        if db.galaxy_unit_tech[unit_id]:
            node.tech_unlocked = True
        else:
            node.tech_locked = True

    return node


def _dedup_by_unit(items: List, key_field: str = "unit_id") -> List:
    seen: Set[str] = set()
    out = []
    for x in items:
        k = getattr(x, key_field, None)
        if not k:
            out.append(x)  # 无目标的保留（可能是空 InfoArray）
            continue
        if k in seen:
            continue
        seen.add(k)
        out.append(x)
    return out


def _dedup_by_upgrade(items: List) -> List:
    seen: Set[str] = set()
    out = []
    for x in items:
        k = x.upgrade_id
        if not k:
            out.append(x)
            continue
        if k in seen:
            continue
        seen.add(k)
        out.append(x)
    return out


def _attr_of(info: ET.Element, name: str) -> Optional[str]:
    v = info.get(name)
    if v is None or v == "":
        return None
    return v


def _last_button_attr(info: ET.Element, name: str) -> Optional[str]:
    """从 InfoArray 的多个 <Button> 子元素中取最后一个非空的属性值（覆盖语义）"""
    result: Optional[str] = None
    for b in info.findall("Button"):
        if b.get("removed") == "1":
            result = None
            continue
        v = b.get(name)
        if v:  # 非空才记录
            result = v
    return result


def _last_button_face(info: ET.Element) -> str:
    """取最后一个非空 DefaultButtonFace"""
    result = ""
    for b in info.findall("Button"):
        if b.get("removed") == "1":
            result = ""
            continue
        v = b.get("DefaultButtonFace", "")
        if v:
            result = v
    return result


def _cost_of(info: ET.Element, resource: str) -> Optional[str]:
    """从 <Resource index="Minerals" value="100"/> 或 <Cost><Resource.../></Cost> 提取"""
    # 直接 Resource 子元素
    for r in info.findall("Resource"):
        if r.get("index") == resource and r.get("value"):
            return r.get("value")
    # Cost/Resource 形式
    cost = info.find("Cost")
    if cost is not None:
        for r in cost.findall("Resource"):
            if r.get("index") == resource and r.get("value"):
                return r.get("value")
    return None


# ---------------------------------------------------------------------------
# 输出：文本树
# ---------------------------------------------------------------------------
def render_text_tree(db: CatalogDB, root_unit: str, depth: int = 1) -> str:
    visited: Set[str] = set()
    lines: List[str] = []

    def _name(unit_id: str) -> str:
        n = db.unit_name(unit_id)
        return f"{n} [{unit_id}]" if n != unit_id else f"[{unit_id}]"

    def _abil_desc(abil_id: str) -> str:
        elem = db.get_abil(abil_id)
        tag = elem.tag if elem is not None else "?"
        n = db.abil_name(abil_id)
        return f"{tag}({abil_id})" + (f" «{n}»" if n != abil_id else "")

    def _render_unit(unit_id: str, current_depth: int, prefix: str = "") -> None:
        if unit_id in visited:
            lines.append(f"{prefix}↺ {unit_id} (已展示)")
            return
        visited.add(unit_id)
        node = parse_unit(db, unit_id)
        if node is None:
            lines.append(f"{prefix}? {unit_id} (未找到)")
            return
        # 标题行
        title = f"{node.name} [{unit_id}]" if node.name and node.name != unit_id else f"[{unit_id}]"
        meta: List[str] = []
        if node.race:
            meta.append(f"Race={node.race}")
        if node.parent:
            meta.append(f"parent={node.parent}")
        if node.attributes:
            meta.append("Attrs=" + "+".join(node.attributes))
        if node.raw_attrs.get("LifeMax"):
            meta.append(f"HP={node.raw_attrs['LifeMax']}")
        if node.raw_attrs.get("Sight"):
            meta.append(f"Sight={node.raw_attrs['Sight']}")
        # 科技树状态标记
        if node.tech_locked:
            meta.append("科技树:锁定")
        elif node.tech_unlocked:
            meta.append("科技树:已解锁")
        lines.append(f"{prefix}■ {title}" + (f"  ({', '.join(meta)})" if meta else ""))

        sub_prefix = prefix + "  "

        # 拥有的能力（含卡牌按钮）
        if node.abilities:
            lines.append(f"{sub_prefix}├─ 能力 AbilArray:")
            seen_abil: Set[str] = set()
            for ab in node.abilities:
                if ab.abil_id in seen_abil:
                    continue
                seen_abil.add(ab.abil_id)
                desc = _abil_desc(ab.abil_id)
                runtime_tag = " [运行时注入]" if ab.runtime else ""
                # 找该能力的卡牌按钮（如果有），按 cmd 去重
                card_btns = [c for c in node.card_layouts if c.get("abil_id") == ab.abil_id]
                btn_str = ""
                if card_btns:
                    seen_cmds: Set[str] = set()
                    parts = []
                    for c in card_btns:
                        cmd = c.get("cmd", "")
                        if cmd in seen_cmds:
                            continue
                        seen_cmds.add(cmd)
                        face = c.get("face") or ""
                        face_name = db.button_name(face) if face else ""
                        parts.append(f"{cmd}({face_name or face})")
                    btn_str = " → 卡牌[" + ", ".join(parts) + "]"
                lines.append(f"{sub_prefix}│  • {desc}{runtime_tag}{btn_str}")

        # 卡牌中没有 AbilArray 声明的按钮（如纯 Passive 按钮等）
        orphan_btns = [c for c in node.card_layouts if not c.get("abil_id")]
        if orphan_btns:
            lines.append(f"{sub_prefix}├─ 卡牌按钮（无 AbilCmd）:")
            for c in orphan_btns:
                face = c.get("face") or ""
                face_name = db.button_name(face) if face else ""
                pos = f"R{c.get('row') or 0}C{c.get('column') or 0}"
                lines.append(f"{sub_prefix}│  • [{pos}] {face_name or face}")

        # 可生产单位
        if node.trains:
            lines.append(f"{sub_prefix}├─ 可生产单位 (Train):")
            for t in node.trains:
                if not t.unit_id:
                    continue
                name = _name(t.unit_id)
                cost = _fmt_cost(t.cost_minerals, t.cost_vespene)
                extras = _fmt_extras(t.time, t.requirements, t.button_face, db)
                lines.append(f"{sub_prefix}│  • {name}{cost}{extras}")
                if current_depth > 1:
                    _render_unit(t.unit_id, current_depth - 1, sub_prefix + "│     ")

        # 可建造建筑
        if node.builds:
            lines.append(f"{sub_prefix}├─ 可建造建筑 (Build):")
            for b in node.builds:
                if not b.unit_id:
                    continue
                name = _name(b.unit_id)
                cost = _fmt_cost(b.cost_minerals, b.cost_vespene)
                extras = _fmt_extras(b.time, b.requirements, b.button_face, db)
                lines.append(f"{sub_prefix}│  • {name}{cost}{extras}")
                if current_depth > 1:
                    _render_unit(b.unit_id, current_depth - 1, sub_prefix + "│     ")

        # 可研究科技
        if node.researches:
            lines.append(f"{sub_prefix}├─ 可研究科技 (Research):")
            for r in node.researches:
                if not r.upgrade_id:
                    continue
                name = db.upgrade_name(r.upgrade_id)
                name_str = f"{name} [{r.upgrade_id}]" if name != r.upgrade_id else f"[{r.upgrade_id}]"
                cost = _fmt_cost(r.cost_minerals, r.cost_vespene)
                extras = _fmt_extras(r.time, r.requirements, r.button_face, db)
                lines.append(f"{sub_prefix}│  • {name_str}{cost}{extras}")

        # 可变形
        if node.morphs_to:
            lines.append(f"{sub_prefix}├─ 可变形为 (Morph):")
            for m in node.morphs_to:
                if not m.target_unit_id:
                    continue
                name = _name(m.target_unit_id)
                lines.append(f"{sub_prefix}│  • {name} via {_abil_desc(m.abil_id)}")
                if current_depth > 1:
                    _render_unit(m.target_unit_id, current_depth - 1, sub_prefix + "│     ")

        # 武器
        if node.weapons:
            lines.append(f"{sub_prefix}├─ 武器: " + ", ".join(node.weapons))

        # 反向：谁生产我
        if node.produced_by:
            lines.append(f"{sub_prefix}├─ ← 被生产由:")
            for p in node.produced_by:
                abil_elem = db.get_abil(p.abil_id)
                # 找生产者单位
                producers = _find_producers_of_abil(db, p.abil_id)
                if producers:
                    prod_str = ", ".join(_name(u) for u in producers)
                else:
                    prod_str = f"?({p.abil_id})"
                cmd = p.cmd_index
                lines.append(f"{sub_prefix}│  • {prod_str} via {p.abil_id}[{cmd}]")

        # 反向：谁建造我
        if node.built_by:
            lines.append(f"{sub_prefix}├─ ← 被建造由:")
            for p in node.built_by:
                producers = _find_producers_of_abil(db, p.abil_id)
                if producers:
                    prod_str = ", ".join(_name(u) for u in producers)
                else:
                    prod_str = f"?({p.abil_id})"
                cmd = p.cmd_index
                lines.append(f"{sub_prefix}│  • {prod_str} via {p.abil_id}[{cmd}]")

        # 反向：谁变异成我
        if node.morphed_from:
            lines.append(f"{sub_prefix}├─ ← 被变异由:")
            for m in node.morphed_from:
                producers = _find_producers_of_abil(db, m.abil_id)
                if producers:
                    prod_str = ", ".join(_name(u) for u in producers)
                else:
                    prod_str = f"?({m.abil_id})"
                lines.append(f"{sub_prefix}│  • {prod_str} via {m.abil_id}")

        # 静态分析限制提示
        if not (node.abilities or node.trains or node.builds or
                node.researches or node.morphs_to or node.card_layouts):
            lines.append(f"{sub_prefix}└─ (无静态关联，可能由脚本动态添加)")

    _render_unit(root_unit, depth)
    return "\n".join(lines)


def _fmt_cost(minerals: Optional[str], vespene: Optional[str]) -> str:
    parts = []
    if minerals:
        parts.append(f"矿{minerals}")
    if vespene:
        parts.append(f"气{vespene}")
    return f" ({'/'.join(parts)})" if parts else ""


def _fmt_extras(time: Optional[str], req: Optional[str],
                face: Optional[str], db: CatalogDB) -> str:
    parts = []
    if time:
        parts.append(f"t={time}s")
    if face:
        face_name = db.button_name(face)
        # 找不到名称时显示 face id（避免显示成详细描述）
        parts.append(f"图标={face_name or face}")
    if req:
        parts.append(f"需求={req}")
    return f" {{{', '.join(parts)}}}" if parts else ""


def _find_producers_of_abil(db: CatalogDB, abil_id: str) -> List[str]:
    """找哪些单位的 AbilArray.Link == abil_id"""
    out = []
    for uid, elem in db.catalogs.get("Unit", {}).items():
        for ab in elem.findall("AbilArray"):
            if ab.get("Link") == abil_id and ab.get("removed") != "1":
                out.append(uid)
                break
    return out


# ---------------------------------------------------------------------------
# 输出：JSON
# ---------------------------------------------------------------------------
def to_json(db: CatalogDB, root_unit: str, depth: int = 1) -> str:
    visited: Set[str] = set()

    def _build(unit_id: str, current_depth: int) -> Optional[dict]:
        if unit_id in visited:
            return {"unit_id": unit_id, "circular": True}
        visited.add(unit_id)
        node = parse_unit(db, unit_id)
        if node is None:
            return None
        result = {
            "unit_id": node.unit_id,
            "name": node.name,
            "race": node.race,
            "parent": node.parent,
            "attributes": node.attributes,
            "abilities": [
                {
                    "abil_id": a.abil_id,
                    "abil_tag": db.get_abil(a.abil_id).tag if db.get_abil(a.abil_id) else None,
                    "name": db.abil_name(a.abil_id),
                    "runtime": a.runtime,
                }
                for a in node.abilities
            ],
            "card_layouts": node.card_layouts,
            "trains": [asdict(t) for t in node.trains],
            "builds": [asdict(b) for b in node.builds],
            "researches": [asdict(r) for r in node.researches],
            "morphs_to": [asdict(m) for m in node.morphs_to],
            "weapons": node.weapons,
            "tech_locked": node.tech_locked,
            "tech_unlocked": node.tech_unlocked,
            "produced_by": [asdict(p) for p in node.produced_by],
            "built_by": [asdict(p) for p in node.built_by],
            "morphed_from": [asdict(m) for m in node.morphed_from],
        }
        # 给本地化名称填值
        for t in result["trains"]:
            t["name"] = db.unit_name(t["unit_id"]) if t.get("unit_id") else ""
        for b in result["builds"]:
            b["name"] = db.unit_name(b["unit_id"]) if b.get("unit_id") else ""
        for r in result["researches"]:
            r["name"] = db.upgrade_name(r["upgrade_id"]) if r.get("upgrade_id") else ""
        for m in result["morphs_to"]:
            m["name"] = db.unit_name(m["target_unit_id"]) if m.get("target_unit_id") else ""

        # 递归展开
        if current_depth > 1:
            children = []
            for t in node.trains:
                if t.unit_id:
                    sub = _build(t.unit_id, current_depth - 1)
                    if sub:
                        children.append(("train", t.unit_id, sub))
            for b in node.builds:
                if b.unit_id:
                    sub = _build(b.unit_id, current_depth - 1)
                    if sub:
                        children.append(("build", b.unit_id, sub))
            for m in node.morphs_to:
                if m.target_unit_id:
                    sub = _build(m.target_unit_id, current_depth - 1)
                    if sub:
                        children.append(("morph", m.target_unit_id, sub))
            result["children"] = children
        return result

    data = _build(root_unit, depth)
    return json.dumps(data, ensure_ascii=False, indent=2)


# ---------------------------------------------------------------------------
# 列表查询
# ---------------------------------------------------------------------------
def list_units(db: CatalogDB, pattern: Optional[str] = None) -> None:
    pat = re.compile(pattern) if pattern else None
    units = sorted(db.catalogs.get("Unit", {}).keys())
    count = 0
    for u in units:
        if pat and not pat.search(u):
            continue
        name = db.unit_name(u)
        print(f"  {u}" + (f"  «{name}»" if name and name != u else ""))
        count += 1
    print(f"\n共 {count} 个单位" + (f"（匹配 /{pattern}/）" if pattern else ""))


def list_abilities(db: CatalogDB, pattern: Optional[str] = None) -> None:
    pat = re.compile(pattern) if pattern else None
    abils = sorted(db.catalogs.get("Abil", {}).keys())
    count = 0
    for a in abils:
        if pat and not pat.search(a):
            continue
        elem = db.get_abil(a)
        tag = elem.tag if elem is not None else "?"
        name = db.abil_name(a)
        print(f"  [{tag}] {a}" + (f"  «{name}»" if name and name != a else ""))
        count += 1
    print(f"\n共 {count} 个能力" + (f"（匹配 /{pattern}/）" if pattern else ""))


# ---------------------------------------------------------------------------
# 命令行入口
# ---------------------------------------------------------------------------
def parse_args(argv: Optional[List[str]] = None):
    p = argparse.ArgumentParser(
        description="SC2 单位关系图查询工具（不启动游戏）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
示例:
  python sc2_unit_explorer.py Larva
  python sc2_unit_explorer.py Drone --depth 2
  python sc2_unit_explorer.py Barracks --format json
  python sc2_unit_explorer.py SCV --mod "E:\\path\\OtherMod.SC2Mod"
  python sc2_unit_explorer.py --list-units --filter "^Larva"
  python sc2_unit_explorer.py --list-abilities --filter "Train$"
""",
    )
    p.add_argument("unit_id", nargs="?", help="要查询的单位 ID（如 Larva, Drone, SCV, Barracks）")
    p.add_argument("--depth", type=int, default=1,
                   help="递归展开深度（默认 1，仅展开直接关联）")
    p.add_argument("--format", choices=("text", "json"), default="text",
                   help="输出格式（默认 text 文本树）")
    p.add_argument("--mod", action="append", default=[],
                   help="追加自定义 mod 路径（可多次指定）。会在默认 mod 之后加载，覆盖前者")
    p.add_argument("--only-mod", action="append", default=[],
                   help="只使用指定的 mod 路径（忽略默认路径）")
    p.add_argument("--lang", default="zhCN", help="本地化语言（默认 zhCN）")
    p.add_argument("--list-units", action="store_true", help="列出所有单位 ID")
    p.add_argument("--list-abilities", action="store_true", help="列出所有能力 ID")
    p.add_argument("--filter", help="配合 --list-units/--list-abilities 使用，正则过滤")
    p.add_argument("--out", help="输出到文件（默认 stdout）")
    return p.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)

    # 决定 mod 加载顺序
    if args.only_mod:
        mod_paths = [Path(p) for p in args.only_mod]
    else:
        mod_paths = list(DEFAULT_MOD_PATHS)
        for p in args.mod:
            mod_paths.append(Path(p))

    db = CatalogDB(mod_paths=mod_paths, lang=args.lang)
    print(f"[INFO] 加载 mod 路径（{len(mod_paths)} 个）:", file=sys.stderr)
    for m in mod_paths:
        print(f"  - {m}", file=sys.stderr)
    db.load()
    print(f"[INFO] 已加载: 单位 {len(db.catalogs.get('Unit', {}))} 个, "
          f"能力 {len(db.catalogs.get('Abil', {}))} 个, "
          f"按钮 {len(db.catalogs.get('Button', {}))} 个, "
          f"效果 {len(db.catalogs.get('Effect', {}))} 个, "
          f"行为 {len(db.catalogs.get('Behavior', {}))} 个, "
          f"升级 {len(db.catalogs.get('Upgrade', {}))} 个, "
          f"本地化 {len(db.strings)} 条", file=sys.stderr)

    if args.list_units:
        list_units(db, args.filter)
        return 0
    if args.list_abilities:
        list_abilities(db, args.filter)
        return 0

    if not args.unit_id:
        print("[ERROR] 必须提供 unit_id，或使用 --list-units/--list-abilities",
              file=sys.stderr)
        return 2

    if db.get_unit(args.unit_id) is None:
        print(f"[ERROR] 未找到单位: {args.unit_id}", file=sys.stderr)
        print(f"提示: 用 --list-units --filter {args.unit_id} 查找近似 ID",
              file=sys.stderr)
        return 3

    if args.format == "json":
        out = to_json(db, args.unit_id, depth=args.depth)
    else:
        out = render_text_tree(db, args.unit_id, depth=args.depth)

    if args.out:
        Path(args.out).write_text(out, encoding="utf-8")
        print(f"[INFO] 已写入: {args.out}", file=sys.stderr)
    else:
        print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
