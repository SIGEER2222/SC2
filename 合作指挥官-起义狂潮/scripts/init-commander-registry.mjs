// init-commander-registry.mjs
// Initialize Shared/Commanders/ JSON configs using Node.js (avoids PowerShell quote-eating).
// Usage: node scripts/init-commander-registry.mjs

import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '..');
const outDir = join(projectRoot, 'Shared', 'Commanders');

mkdirSync(outDir, { recursive: true });

const commanders = [
  { file: 'Raynor.json', json: { runtime_name: 'Raynor', race: 'Terran', console_skin: 'ConsoleTerran_Default', runtime_init: 'RaynorRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: ['TerranRaynor'], runtime_checkpoints: ['InitializeBase.beforeRaynorRuntime', 'InitializeBase.afterRaynorRuntime'] } },
  { file: 'RaynorX.json', json: { runtime_name: 'RaynorX', race: 'Terran', console_skin: 'ConsoleTerran_Default', runtime_init: 'RaynorXRuntimeInit', runtime_init_lib: 'libE0EAE147', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: ['InitializeBase.beforeRaynorXRuntime', 'InitializeBase.afterRaynorXRuntime'] } },
  { file: 'Kerrigan.json', json: { runtime_name: 'Kerrigan', race: 'Zerg', console_skin: 'ConsoleZerg_Default', runtime_init: 'KerriganRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'TestZerg.json', json: { runtime_name: 'TestZerg', race: 'Zerg', console_skin: 'ConsoleZerg_Default', runtime_init: 'TestZergRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Abathur.json', json: { runtime_name: 'Abathur', race: 'Zerg', console_skin: 'ConsoleZerg_Abathur', runtime_init: 'AbathurRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: ['AbathurCustom'], runtime_checkpoints: [] } },
  { file: 'AbathurReborn.json', json: { runtime_name: 'AbathurReborn', race: 'Zerg', console_skin: 'ConsoleZerg_Abathur', runtime_init: 'AbathurRebornRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Zagara.json', json: { runtime_name: 'Zagara', race: 'Zerg', console_skin: 'ConsoleZerg_Zagara', runtime_init: 'ZagaraRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Alarak.json', json: { runtime_name: 'Alarak', race: 'Protoss', console_skin: 'ConsoleProtoss_Forged', runtime_init: 'AlarakRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Artanis.json', json: { runtime_name: 'Artanis', race: 'Protoss', console_skin: 'ConsoleProtoss_Default', runtime_init: 'ArtanisRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Fenix.json', json: { runtime_name: 'Fenix', race: 'Protoss', console_skin: 'ConsoleProtoss_Fenix', runtime_init: 'FenixRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Karax.json', json: { runtime_name: 'Karax', race: 'Protoss', console_skin: 'ConsoleProtoss_Default', runtime_init: 'KaraxRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Vorazun.json', json: { runtime_name: 'Vorazun', race: 'Protoss', console_skin: 'ConsoleProtoss_Default', runtime_init: 'VorazunRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Zeratul.json', json: { runtime_name: 'Zeratul', race: 'Protoss', console_skin: 'ConsoleProtoss_Ihanrii', runtime_init: 'ZeratulRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Stukov.json', json: { runtime_name: 'Stukov', race: 'Zerg', console_skin: 'ConsoleZerg_Classic', runtime_init: 'StukovRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Dehaka.json', json: { runtime_name: 'Dehaka', race: 'Zerg', console_skin: 'ConsoleZerg_Dehaka', runtime_init: 'DehakaRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [{ type: 'add_supply', amount: 60, rpg_only: true }], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Tychus.json', json: { runtime_name: 'Tychus', race: 'Terran', console_skin: 'ConsoleTerran_Classic', runtime_init: 'TychusRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [{ type: 'create_caster_unit', unit: 'CoopCasterTychus', gp_init_commander: 'Tychus', squad_init: { hero_count: 4, abil: 'Abil/TychusTrain', tech_type: 'CoopTechTychusSquad', event_structure: 'Event_TychusHeroStructureCreate', event_main: 'Event_TychusHeroMainBuilding' }, rpg_only: true }], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Horner.json', json: { runtime_name: 'Horner', race: 'Terran', console_skin: 'ConsoleTerran_Horner', runtime_init: 'HornerRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: ['Mira', 'HanHorner', 'HanAndHorner'], runtime_checkpoints: [] } },
  { file: 'Nova.json', json: { runtime_name: 'Nova', race: 'Terran', console_skin: 'ConsoleTerran_CovertOps', runtime_init: 'NovaRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Mengsk.json', json: { runtime_name: 'Mengsk', race: 'Terran', console_skin: 'ConsoleTerran_Imperial', runtime_init: 'MengskRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [{ type: 'init_veterancy' }], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Swann.json', json: { runtime_name: 'Swann', race: 'Terran', console_skin: 'ConsoleTerran_Swann', runtime_init: 'SwannRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Stetmann.json', json: { runtime_name: 'Stetmann', race: 'Zerg', console_skin: 'ConsoleZerg_Mecha', runtime_init: 'StetmannRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } },
  { file: 'Izsha.json', json: { runtime_name: 'Izsha', race: 'Zerg', console_skin: '', runtime_init: 'IzshaRuntimeInit', runtime_init_lib: 'libE0EAE146', special_init: [], supply_bonus: 0, aliases: [], runtime_checkpoints: [] } }
];

let count = 0;
for (const entry of commanders) {
  const path = join(outDir, entry.file);
  writeFileSync(path, JSON.stringify(entry.json, null, 2), 'utf8');
  count++;
}

// Also write _registry.json (aggregated index for web-launcher)
const registry = {};
for (const entry of commanders) {
  const c = entry.json;
  registry[c.runtime_name] = { race: c.race, console_skin: c.console_skin, aliases: c.aliases };
  for (const alias of c.aliases) {
    registry[alias] = { race: c.race, console_skin: c.console_skin, aliases: [], _alias_of: c.runtime_name };
  }
}
writeFileSync(join(outDir, '_registry.json'), JSON.stringify(registry, null, 2), 'utf8');

console.log(`Created ${count} commander JSON files + _registry.json in ${outDir}`);
