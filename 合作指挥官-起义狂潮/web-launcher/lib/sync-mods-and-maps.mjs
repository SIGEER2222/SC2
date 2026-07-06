import { cpSync, existsSync, mkdirSync } from 'fs';
import { join, resolve, basename } from 'path';

const DEFAULT_PRESERVE = ['DocumentHeader', 'DocumentInfo'];

function copyWithExclude(src, dst, preserveFiles) {
  mkdirSync(dst, { recursive: true });
  cpSync(src, dst, {
    recursive: true,
    force: true,
    filter: (source) => {
      const parts = source.split(/[\\/]/);
      const name = parts[parts.length - 1];
      return !preserveFiles.includes(name);
    },
  });
}

/**
 * 同步 mod 到 SC2 安装目录
 */
export function syncMods(opts) {
  const { modNames, workspaceRoot, sc2Root, modSources = {}, preserveFiles = DEFAULT_PRESERVE } = opts;
  const targetModsRoot = join(sc2Root, 'Mods');
  let copied = 0;
  const details = [];

  for (const name of modNames) {
    const modDirName = name.endsWith('.SC2Mod') ? name : `${name}.SC2Mod`;
    let src = join(workspaceRoot, 'Mods', modDirName);
    if (!existsSync(src) && modSources[name]) {
      src = modSources[name];
    }
    if (!existsSync(src)) {
      details.push({ path: modDirName, action: 'skipped', reason: 'source not found' });
      continue;
    }
    const dst = join(targetModsRoot, modDirName);
    copyWithExclude(src, dst, preserveFiles);
    copied++;
    details.push({ path: modDirName, action: 'copied' });
  }

  return { copied, details };
}

/**
 * 同步地图到 SC2 安装目录
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
    cpSync(src, dst, { recursive: true, force: true });
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
