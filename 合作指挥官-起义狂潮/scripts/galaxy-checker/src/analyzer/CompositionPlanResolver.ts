// src/analyzer/CompositionPlanResolver.ts
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, basename } from 'node:path';

/**
 * 从 CompositionPlan.json 解析 checker 所需的上下文：
 * - symbolRoots: 所有依赖 mod 的 Base.SC2Data 目录（用于全局符号表）
 * - catalogDbPath: 依赖链中第一个含 catalog-ids.json 的路径
 * - compositionId: plan.planId
 *
 * CompositionPlan schema: scripts/sc2-composer/schema/CompositionPlan.schema.json
 * 本 resolver 只消费 dependencies.always + dependencies.commander + bootstrap.galaxyIncludes
 */
export interface ResolvedContext {
  symbolRoots: string[];
  catalogDbPath?: string;
  compositionId?: string;
  contextLoaded: boolean;
}

interface PlanDependency {
  path: string;
  layer: string;
  source: string;
}

interface CompositionPlan {
  planId: string;
  dependencies?: {
    always?: PlanDependency[];
    commander?: Array<{
      slotIndex: number;
      commanderId: string;
      dependencies: PlanDependency[];
    }>;
    pairPatches?: Array<{ commanderId: string; patchPath: string; reason: string }>;
  };
  bootstrap?: {
    galaxyIncludes?: Array<{ path: string; purpose: string }>;
  };
}

/**
 * 从依赖路径提取 mod 目录的 Base.SC2Data。
 * 依赖路径格式：file:Mods/7vs1/CoreRuntime.SC2Mod 或 file:Mods/Reborn/crys_swarm_assets.SC2Mod
 */
function depPathToBaseSc2Data(depPath: string, projRoot: string): string | null {
  // 去掉 file: 前缀
  let rel = depPath.replace(/^file:/, '');
  // 去掉末尾 .SC2Mod 后缀（如果有），再加上
  if (!rel.endsWith('.SC2Mod')) {
    // 可能是 file:Mods/7vs1/CoreRuntime.SC2Mod 格式
    // 如果路径不含 .SC2Mod，跳过
    if (!rel.includes('.SC2Mod')) return null;
  }
  const modAbsPath = join(projRoot, rel);
  if (!existsSync(modAbsPath)) return null;
  const baseSc2Data = join(modAbsPath, 'Base.SC2Data');
  if (!existsSync(baseSc2Data)) return null;
  return baseSc2Data;
}

/**
 * 从 CompositionPlan 解析上下文。
 * @param planPath CompositionPlan.json 路径
 * @param projRoot 项目根目录（用于解析 file: 前缀的相对路径）
 */
export function resolveFromCompositionPlan(
  planPath: string,
  projRoot: string
): ResolvedContext {
  if (!existsSync(planPath)) {
    return { symbolRoots: [], contextLoaded: false };
  }

  let plan: CompositionPlan;
  try {
    plan = JSON.parse(readFileSync(planPath, 'utf-8')) as CompositionPlan;
  } catch {
    return { symbolRoots: [], contextLoaded: false };
  }

  const symbolRoots = new Set<string>();
  const allDeps: PlanDependency[] = [];

  // 收集 always 依赖
  if (plan.dependencies?.always) {
    allDeps.push(...plan.dependencies.always);
  }
  // 收集 commander 依赖
  if (plan.dependencies?.commander) {
    for (const slot of plan.dependencies.commander) {
      allDeps.push(...slot.dependencies);
    }
  }
  // 收集 pairPatches
  if (plan.dependencies?.pairPatches) {
    for (const pp of plan.dependencies.pairPatches) {
      allDeps.push({ path: pp.patchPath, layer: 'L7-PairPatch', source: pp.reason });
    }
  }

  // 解析每个依赖的 Base.SC2Data
  for (const dep of allDeps) {
    const baseSc2Data = depPathToBaseSc2Data(dep.path, projRoot);
    if (baseSc2Data) {
      symbolRoots.add(baseSc2Data);
    }
  }

  // 查找 catalog-ids.json：在所有 symbolRoots 的父级目录中查找
  let catalogDbPath: string | undefined;
  for (const root of symbolRoots) {
    // catalog-ids.json 可能在 mod 根目录或 data/ 目录
    const modDir = join(root, '..'); // Base.SC2Data 的父级 = mod 根目录
    const candidates = [
      join(modDir, 'catalog-ids.json'),
      join(modDir, 'data', 'catalog-ids.json'),
    ];
    for (const c of candidates) {
      if (existsSync(c)) {
        catalogDbPath = c;
        break;
      }
    }
    if (catalogDbPath) break;
  }

  return {
    symbolRoots: [...symbolRoots],
    catalogDbPath,
    compositionId: plan.planId,
    contextLoaded: true,
  };
}
