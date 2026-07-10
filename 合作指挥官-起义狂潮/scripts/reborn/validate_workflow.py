"""验证 sc2-workflow.json 配置完整性。"""
import json, os, sys

def validate_workflow_config(path):
    with open(path, "r", encoding="utf-8") as f:
        config = json.load(f)

    errors = []
    # path 是 Shared/Workflow/sc2-workflow.json，项目根在两级目录之上
    base = os.path.dirname(os.path.dirname(os.path.dirname(path)))

    # 1. Schema version
    if config.get("schemaVersion") != 1:
        errors.append("schemaVersion 必须为 1")

    # 2. Validate profiles
    profiles = config.get("effectiveProfiles", [])
    if not profiles:
        errors.append("effectiveProfiles 不能为空")

    for p in profiles:
        name = p.get("name", "?")
        if not p.get("name"):
            errors.append("profile 缺少 name")
        if not p.get("targetPattern"):
            errors.append(f"profile[{name}] 缺少 targetPattern")
        if "alwaysDependencies" not in p:
            errors.append(f"profile[{name}] 缺少 alwaysDependencies")
        if "commanderDependencies" not in p:
            errors.append(f"profile[{name}] 缺少 commanderDependencies")

        # Check dependency paths exist or are external
        for dep in p.get("alwaysDependencies", []):
            if dep.startswith("file:"):
                dep_path = dep[5:]
                full = os.path.join(base, dep_path)
                if not os.path.exists(full):
                    # Check if it's in externalDependencies or legacyDependencies
                    if dep in config.get("externalDependencies", []):
                        continue  # external dependency, ok
                    if dep in config.get("legacyDependencies", {}):
                        continue  # legacy dependency, ok
                    errors.append(f"profile[{name}] 依赖不存在: {dep}")

        # Check mapProfiles path
        map_profiles = p.get("mapProfiles")
        if map_profiles:
            full = os.path.join(base, map_profiles)
            if not os.path.exists(full):
                errors.append(f"profile[{name}] mapProfiles 路径不存在: {map_profiles}")

    # 3. Validate external dependencies
    ext_deps = config.get("externalDependencies", [])
    for dep in ext_deps:
        if not dep.startswith("file:"):
            errors.append(f"externalDependency 格式错误: {dep}")

    # 4. Validate validation paths
    val = config.get("validation", {})
    for key, rel_path in val.items():
        full = os.path.join(base, rel_path)
        if not os.path.exists(full):
            errors.append(f"validation.{key} 路径不存在: {rel_path}")

    return errors

def main():
    if len(sys.argv) < 2:
        path = "Shared/Workflow/sc2-workflow.json"
    else:
        path = sys.argv[1]

    # Try to find the file
    for root_try in [".", ".."]:
        full = os.path.join(root_try, path)
        if os.path.exists(full):
            path = full
            break

    print(f"验证: {path}")
    errors = validate_workflow_config(path)

    if errors:
        print(f"\n{len(errors)} 个问题:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    else:
        print("验证通过")
        # Print summary
        with open(path, "r", encoding="utf-8") as f:
            config = json.load(f)
        profiles = config.get("effectiveProfiles", [])
        print(f"  schemaVersion: {config['schemaVersion']}")
        print(f"  配置数量: {len(profiles)}")
        for p in profiles:
            deps = len(p.get("alwaysDependencies", []))
            cdeps = len(p.get("commanderDependencies", {}))
            print(f"    {p['name']}: {deps} always-deps, {cdeps} commanders")

if __name__ == "__main__":
    main()