"""
递归收集指挥官的所有可生产/可变异/可建造单位。

从起始单位（如 Larva、Drone）开始，深度优先递归展开：
- trains (CAbilTrain): 单位生产
- builds (CAbilBuild): 建筑建造
- morphs_to (CAbilMorph): 变异/升级目标

对每个新发现的单位递归展开，直到没有新单位。
用 visited 集合避免无限递归。
"""
import json
import subprocess
import sys
import os

# mod 加载参数
BASE_MODS = [
    r"E:\Code\MyMod\SC2\sc2-data-trigger\mods\core.sc2mod",
    r"E:\Code\MyMod\SC2\sc2-data-trigger\mods\liberty.sc2mod",
    r"E:\Code\MyMod\SC2\sc2-data-trigger\mods\swarm.sc2mod",
    r"E:\Code\MyMod\SC2\sc2-data-trigger\mods\void.sc2mod",
]
REBORN_MOD = r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\crys_the_swarm_reborn.SC2Mod"

EXPLORER = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "scripts", "sc2_unit_explorer.py"
)

def build_mod_args():
    args = []
    for m in BASE_MODS + [REBORN_MOD]:
        args += ["--only-mod", m]
    return args

MOD_ARGS = build_mod_args()

def query_unit(unit_id):
    """查询单位的 JSON 数据"""
    cmd = [sys.executable, EXPLORER, unit_id, "--depth", "1", "--format", "json"] + MOD_ARGS
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None

def is_zerg_unit(data):
    """判断单位是否为 Zerg 种族（attributes 含 Biological 且不含 Mechanical）"""
    attrs = data.get("attributes", [])
    has_bio = "Biological" in attrs
    has_mech = "Mechanical" in attrs
    return has_bio and not has_mech


def collect_units(start_units, exclude=None, zerg_only=False):
    """
    从起始单位开始收集所有可达单位。

    策略：
    1. 对起始单位，收集 trains + builds + morphs_to（一级）
    2. 对每个收集到的单位，只递归展开 morphs_to（变异/升级链）
       - 如 Hatchery→Lair→Hive, Zergling→Baneling, Spire→GreaterSpire
       - 不递归 trains/builds，避免收集到其他指挥官/种族的单位

    Args:
        start_units: 起始单位 ID 列表
        exclude: 要排除的单位 ID 集合
        zerg_only: 只保留 Zerg 种族单位（attributes 含 Biological 且不含 Mechanical）

    Returns:
        list: 按发现顺序排列的单位 ID 列表
    """
    if exclude is None:
        exclude = set()

    visited = set()
    result = []

    # 茧态中间单位 - 跳过
    cocoon_patterns = ["Cocoon", "CocoonBaneling", "CocoonBroodLord", "CocoonSwarmHost",
                       "CocoonViper", "CocoonRavager", "CocoonOverseer", "CocoonOverlord"]

    def should_skip(uid):
        if not uid or uid in exclude:
            return True
        if any(uid.endswith(p) for p in cocoon_patterns):
            return True
        return False

    def add_unit(uid, force_zerg=False):
        if should_skip(uid) or uid in visited:
            return False
        # 种族过滤：非 Zerg 单位跳过
        # force_zerg=True 时跳过检查（从 Larva/Corruptor 产出的肯定都是 Zerg）
        if zerg_only and not force_zerg:
            data = query_unit(uid)
            if data is None:
                return False
            if not is_zerg_unit(data):
                print(f"  Skip (non-Zerg): {uid}")
                return False
        visited.add(uid)
        result.append(uid)
        return True

    def collect_morphs_recursive(uid, force_zerg=False):
        """递归收集 morphs_to 链（变异/升级）"""
        data = query_unit(uid)
        if data is None:
            return
        for m in data.get("morphs_to", []):
            tid = m.get("target_unit_id")
            if tid and tid not in visited and not should_skip(tid):
                if add_unit(tid, force_zerg=force_zerg):
                    print(f"  Found (morph): {tid} (from {uid}, total: {len(result)})")
                    collect_morphs_recursive(tid, force_zerg=force_zerg)

    # 第一步：收集起始单位本身
    for uid in start_units:
        if add_unit(uid):
            print(f"  Found (start): {uid}")

    # 第二步：对每个起始单位，收集 trains + builds + morphs_to
    for uid in start_units:
        if uid not in visited:
            continue
        data = query_unit(uid)
        if data is None:
            continue

        # 起始单位是 Zerg → trains 和 morphs_to 的目标也是 Zerg
        is_start_zerg = uid in ("Larva", "Drone", "Overlord", "Corruptor") if zerg_only else False

        # trains（一级生产，不递归）
        # Larva/Corruptor trains 出的单位肯定是 Zerg
        force = is_start_zerg and uid in ("Larva", "Corruptor")
        for t in data.get("trains", []):
            tid = t.get("unit_id")
            if tid and tid not in visited and not should_skip(tid):
                if add_unit(tid, force_zerg=force):
                    print(f"  Found (train from {uid}): {tid} (total: {len(result)})")

        # builds（一级建造，不递归）
        # Drone builds 可能包含其他种族建筑，需要过滤
        for b in data.get("builds", []):
            bid = b.get("unit_id")
            if bid and bid not in visited and not should_skip(bid):
                if add_unit(bid, force_zerg=False):
                    print(f"  Found (build from {uid}): {bid} (total: {len(result)})")

        # morphs_to（递归展开）
        # Overlord→Overseer, Corruptor→BroodLord 肯定是 Zerg
        force = is_start_zerg and uid in ("Overlord", "Corruptor")
        for m in data.get("morphs_to", []):
            tid = m.get("target_unit_id")
            if tid and tid not in visited and not should_skip(tid):
                if add_unit(tid, force_zerg=force):
                    print(f"  Found (morph from {uid}): {tid} (total: {len(result)})")
                    collect_morphs_recursive(tid, force_zerg=force)

    # 第三步：对收集到的所有单位，递归展开 morphs_to
    # 如果父单位已经是 Zerg，其 morphs_to 目标也应该是 Zerg
    zerg_unit_ids = set()
    if zerg_only:
        # 所有已收集的单位都视为 Zerg（因为非 Zerg 已被过滤）
        zerg_unit_ids = set(result)
    for uid in list(result):
        if uid in start_units:
            continue  # 起始单位已经处理过 morphs_to
        force = uid in zerg_unit_ids if zerg_only else False
        collect_morphs_recursive(uid, force_zerg=force)

    return result


def main():
    import argparse
    parser = argparse.ArgumentParser(description="递归收集指挥官单位")
    parser.add_argument("--commander", default="Abathur", help="指挥官名")
    parser.add_argument("--start", nargs="+", default=["Larva", "Drone", "Overlord", "Corruptor"],
                        help="起始单位列表")
    parser.add_argument("--exclude", nargs="*", default=[],
                        help="要排除的单位 ID")
    parser.add_argument("--zerg-only", action="store_true", help="只保留 Zerg 种族单位")
    parser.add_argument("--out", help="输出文件路径")
    args = parser.parse_args()
    
    exclude_set = set(args.exclude)
    
    print(f"=== 递归收集 {args.commander} 单位 ===")
    print(f"起始单位: {args.start}")
    print(f"排除: {args.exclude}")
    print(f"只保留 Zerg: {args.zerg_only}")
    print()
    
    units = collect_units(args.start, exclude_set, zerg_only=args.zerg_only)
    
    print()
    print(f"=== 结果: {len(units)} 个单位 ===")
    for i, u in enumerate(units):
        print(f"  [{i}] {u}")
    
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            for u in units:
                f.write(u + "\n")
        print(f"\n已写入: {args.out}")
    
    return units


if __name__ == "__main__":
    main()
