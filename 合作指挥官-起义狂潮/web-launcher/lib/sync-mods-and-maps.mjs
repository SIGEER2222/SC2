import { execSync } from 'child_process';
import { copyFileSync, existsSync, mkdirSync, statSync } from 'fs';
import { join, resolve, basename, dirname } from 'path';

const DEFAULT_PRESERVE = ['DocumentHeader', 'DocumentInfo'];

// mod 搜索子目录（按优先级）
const MOD_SEARCH_DIRS = ['', '7vs1', 'XM'];

/**
 * 用 robocopy 复制目录（Windows），跳过 preserveFiles 中的文件
 * @param {string} src 源目录
 * @param {string} dst 目标目录
 * @param {string[]} [preserveFiles] 跳过的文件名
 */
function copyDir(src, dst, preserveFiles = []) {
  mkdirSync(dst, { recursive: true });

  const args = [src, dst, '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NP', '/MT:8'];
  for (const name of preserveFiles) {
    args.push('/XF', name);
  }

  // robocopy 退出码 < 8 都算成功
  try {
    execSync(`robocopy ${args.map(a => `"${a}"`).join(' ')}`, {
      windowsHide: true,
      stdio: 'pipe',
    });
  } catch (e) {
    // robocopy 退出码 0-7 都算成功，8+ 才是失败
    if (e.status === undefined || e.status >= 8) {
      throw new Error(`robocopy 失败: ${src} -> ${dst} (exit ${e.status})`);
    }
  }
}

/**
 * 复制单个文件（如果是目录则递归复制）
 * @param {string} src 源路径
 * @param {string} dst 目标路径
 */
function copyPath(src, dst) {
  const stat = statSyncSafe(src);
  if (stat && stat.isDirectory()) {
    copyDir(src, dst);
  } else {
    mkdirSync(dirname(dst), { recursive: true });
    copyFileSync(src, dst);
  }
}

function statSyncSafe(p) {
  try {
    return statSync(p);
  } catch {
    return null;
  }
}

/**
 * 在多个候选目录下搜索 mod
 * @param {string} workspaceRoot
 * @param {string} modName
 * @returns {string|null}
 */
function findModPath(workspaceRoot, modName) {
  const modDirName = modName.endsWith('.SC2Mod') ? modName : `${modName}.SC2Mod`;
  for (const sub of MOD_SEARCH_DIRS) {
    const candidate = sub
      ? join(workspaceRoot, 'Mods', sub, modDirName)
      : join(workspaceRoot, 'Mods', modDirName);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

/**
 * 同步 mod 到 SC2 安装目录
 * @param {Object} opts
 * @param {string[]} opts.modNames - mod 名列表（不含 .SC2Mod 后缀）
 * @param {string} opts.workspaceRoot
 * @param {string} opts.sc2Root
 * @param {Object} [opts.modSources] - 外部 mod 源路径映射
 * @param {string[]} [opts.preserveFiles] - 跳过的文件名
 * @returns {{copied: number, details: Array}}
 */
export function syncMods(opts) {
  const { modNames, workspaceRoot, sc2Root, modSources = {}, preserveFiles = DEFAULT_PRESERVE } = opts;
  const targetModsRoot = join(sc2Root, 'Mods');
  let copied = 0;
  const details = [];

  for (const name of modNames) {
    const modDirName = name.endsWith('.SC2Mod') ? name : `${name}.SC2Mod`;

    // 搜索 mod 源路径
    let src = findModPath(workspaceRoot, name);
    if (!src && modSources[name]) {
      src = modSources[name];
    }
    if (!src) {
      details.push({ path: modDirName, action: 'skipped', reason: 'source not found' });
      continue;
    }

    const dst = join(targetModsRoot, modDirName);
    const srcStat = statSyncSafe(src);
    if (srcStat && srcStat.isDirectory()) {
      copyDir(src, dst, preserveFiles);
    } else if (srcStat && srcStat.isFile()) {
      mkdirSync(targetModsRoot, { recursive: true });
      copyFileSync(src, dst);
    } else {
      details.push({ path: modDirName, action: 'skipped', reason: 'source not a file or directory' });
      continue;
    }
    copied++;
    details.push({ path: modDirName, action: 'copied' });
  }

  return { copied, details };
}

/**
 * 同步地图到 SC2 安装目录
 * @param {Object} opts
 * @param {string[]} opts.mapPaths - 地图相对路径（相对于 workspaceRoot）
 * @param {string} opts.workspaceRoot
 * @param {string} opts.sc2Root
 * @returns {{copied: number, details: Array}}
 */
export function syncMaps(opts) {
  const { mapPaths, workspaceRoot, sc2Root } = opts;
  const targetMapsRoot = join(sc2Root, 'Maps');
  mkdirSync(targetMapsRoot, { recursive: true });
  let copied = 0;
  const details = [];

  for (const relPath of mapPaths) {
    const src = resolve(workspaceRoot, relPath);
    if (!existsSync(src)) {
      details.push({ path: relPath, action: 'skipped', reason: 'source not found' });
      continue;
    }
    const name = basename(src);
    const dst = join(targetMapsRoot, name);
    copyPath(src, dst);
    copied++;
    details.push({ path: relPath, action: 'copied' });
  }

  return { copied, details };
}

/**
 * 同时同步 mods 和 maps
 */
export function syncAll(opts) {
  const modResult = syncMods(opts);
  const mapResult = syncMaps(opts);
  return {
    copied: modResult.copied + mapResult.copied,
    details: [...modResult.details, ...mapResult.details],
  };
}
