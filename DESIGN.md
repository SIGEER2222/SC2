# Design

## Source of truth
- Status: Draft
- Last refreshed: 2026-06-09
- Primary product surfaces: 7vs1 local Web launcher under `合作指挥官-起义狂潮/web-launcher`.
- Evidence reviewed: `合作指挥官-起义狂潮/scripts/launch-7vs1-coop-test.ps1`, `合作指挥官-起义狂潮/scripts/start-7vs1-launcher.ps1`, `合作指挥官-起义狂潮/Shared/CommanderPower/commander-power-metadata.json`, `合作指挥官-起义狂潮/Mods/kit_mutations.SC2Mod/zhCN.SC2Data/LocalizedData/GameStrings.txt`, `合作指挥官-起义狂潮/Mods/kit_mutations.SC2Mod/Base.SC2Data/GameData/Mutators.xml`.

## Brand
- Personality: Quiet StarCraft operations console: dense, precise, technical, and game-flavored.
- Trust signals: Show loaded counts, exact commander/map/mutator ids, launch process id, and log paths.
- Avoid: Marketing-style hero pages, oversized decorative cards, one-color purple/blue gradients, and placeholder-heavy UI.

## Product goals
- Goals: Select commander, map, commander prestige/mastery values, mutators, then launch through the existing tested PowerShell path.
- Non-goals: Rebuild StarCraft II editor behavior in the browser, replace in-game UI, or fully convert DDS/audio assets in the first version.
- Success signals: The Web UI loads local commander/map/mutator data, validates selections with a one-click dry-run, exports/imports repeatable JSON configs, invokes `launch-7vs1-coop-test.ps1`, and records logs.

## Personas and jobs
- Primary personas: Mod developer testing commanders, maps, mastery presets, and mutator combinations locally.
- User jobs: Quickly start a specific commander/map/factor scenario, inspect what data was loaded, and repeat tests with small changes.
- Key contexts of use: Desktop browser next to StarCraft II, usually on a Windows development machine.

## Information architecture
- Primary navigation: Single-screen tool surface.
- Core routes/screens: Launcher screen, data/status readout, launch result panel.
- Content hierarchy: Command row, current configuration summary strip with validation state and configuration issue line, commander/map selection, prestige/mastery setup, mutator selection, config JSON import/export, launch/log output.

## Design principles
- Principle 1: Operate like a test bench, not a landing page.
- Principle 2: Prefer exact ids and compact controls over decorative copy.
- Tradeoffs: Browser-readable extracted assets are phased behind a reference index so the launcher remains usable before DDS/audio conversion exists.

## Visual language
- Color: Charcoal base, steel panels, warm amber primary action, teal selection accents, restrained red error states.
- Typography: System UI with Chinese-friendly fallbacks; compact labels and tabular numeric controls.
- Spacing/layout rhythm: Dense grid, fixed tool heights where practical, no layout shift when filtering or selecting.
- Shape/radius/elevation: 6px radius or less, thin borders, shallow shadows only for focused overlays.
- Motion: Minimal hover/focus transitions; no background animation.
- Imagery/iconography: Use extracted game icon references when converted assets exist; until then use deterministic text monograms.

## Components
- Existing components to reuse: None; repo had no Web frontend stack.
- New/changed components: Current configuration summary strip with copy action, validation status, and configuration issue line, commander list with race filter, map selector with map-pack filter, prestige toggles, mastery steppers with pair-sum status and cap action, mutator searchable grid with category/tier filters, fixed-count random and copy-id actions, one-click dry-run validation action, validate-then-launch action, scenario/recent/history rows with direct validation actions, config JSON import/export panel, timestamped launch/output log panel with copy, clear, and log-path copy actions.
- Variants and states: Loading, ready, validation error, launching, launched, empty search result.
- Token/component ownership: Plain CSS custom properties in `web-launcher/styles.css`.

## Accessibility
- Target standard: Practical keyboard and contrast support for local tooling.
- Keyboard/focus behavior: Native form controls, visible focus rings, launch button disabled while invalid/loading.
- Contrast/readability: Avoid low-contrast blue-on-black text; status and ids remain readable.
- Screen-reader semantics: Labels attached to controls and status updates through plain text regions.
- Reduced motion and sensory considerations: No auto-playing sound or motion.

## Responsive behavior
- Supported breakpoints/devices: Desktop-first, remains usable on narrow browser windows.
- Layout adaptations: Multi-column desktop grid collapses to one column below 900px.
- Touch/hover differences: Hover is enhancement only; controls must remain usable without hover.

## Interaction states
- Loading: Global status plus disabled launch.
- Empty: Mutator search shows an empty state.
- Error: Inline status banner with exact backend error.
- Success: Launch result shows pid and log files; output text is timestamped and can be copied or cleared; stdout/stderr paths can be copied directly after launch or validation.
- Disabled: Disabled controls use opacity and retain readable labels.
- Offline/slow network, if applicable: Local-only server; failed API calls report the local endpoint failure.

## Content voice
- Tone: Short Chinese operations labels.
- Terminology: Use repo terms: 指挥官, 地图, 精通, 威望, 因子, 启动.
- Microcopy rules: Prefer exact action/status over explanation.
- Interaction rules: Mutator "随机" uses the numeric input and current mutator filters as the random pool; fixed 3/5/10 buttons set that input and randomize exactly that many mutators when the filtered pool is large enough.
- Interaction rules: Mutator "追加随机" uses the same numeric input and current filter pool but only adds currently unselected mutators; it must not clear existing selections or create duplicate selected ids.
- Interaction rules: Mutator random pool size must be visible whenever filters are active, and "清除筛选" resets search/display/category/tier filters without clearing already selected mutators.
- Interaction rules: An empty filtered mutator random pool must be shown as zero and disable random actions; it must not silently fall back to the full mutator list.
- Interaction rules: Mutator cards show local category and pressure-tier labels derived from stable mutator ids; these labels are selection aids and must not alter launch payload ids.
- Interaction rules: The selected-mutator strip supports local search, expand/collapse, and clearing matched selected mutators. Search only changes the strip view; launch/export payload ids change only when the user explicitly removes chips or clears matched selections.
- Interaction rules: Replacement-style config application, including JSON/recent/scenario/history payloads, saved mutator presets, replace-mode mutator import, default reset, and clear-all mutators, must reset the selected-mutator strip search/expanded state so the strip does not hide the newly applied payload.
- Interaction rules: Mastery pair totals are surfaced as status; "组封顶" scales only over-limit pairs back to a total of 30.
- Interaction rules: Top-level actions are grouped by intent: low-risk configuration actions, validation/preview actions, and launch actions. Launch actions stay visually distinct from configuration edits.
- Interaction rules: When "只安装不启动" is enabled, the summary mode, primary launch button, validate-then-launch button, and running state must use installation wording ("安装", "验证后安装", "安装验证中") rather than implying a game launch.
- Interaction rules: After a normal launch request is accepted, preview and launch-affecting actions must remain disabled while launch-status polling is active and may re-enable only when polling ends, times out, or errors.
- Interaction rules: If a launch request fails before launch-status polling starts, launch-affecting actions must re-enable after the error is surfaced; only an active polling timer may keep them disabled.
- Interaction rules: If normal launch-status polling reaches its attempt limit while the process still appears running, the UI and launch history must show "轮询超时", store the last status snapshot, stop polling, and re-enable launch-affecting actions.
- Interaction rules: The launch submission path must also reject new launch/validation submissions while launch-status polling is active, so row-level actions such as recent/scenario/history validation cannot bypass the disabled top-level controls.
- Interaction rules: Row-level launch/validation actions must visibly disable while launch-status polling is active; non-submission actions such as apply, JSON export, log detail, and delete may remain available.
- Interaction rules: Commander/map quick filtering has a dedicated "清除筛选" action that resets search, commander race, and map pack filters without changing the currently selected commander or map.
- Interaction rules: Random commander, random map, and random scenario must respect the current quick filters; if the filtered pool is empty, they may fall back to the full loaded pool and show that state.
- Interaction rules: Random scenario mutator selection must respect the current mutator filters; if the filtered mutator pool is empty, it must leave the scenario with zero mutators and explicitly report that it did not fall back to the full mutator list.
- Interaction rules: The summary strip shows whether the current launch-affecting configuration is unverified, validated, or changed since the last successful validation/launch; toggling dry-run alone does not invalidate validation.
- Interaction rules: Summary strip cells should keep compact visible labels but expose exact commander id, map id, mastery values, mutator preset, mutator ids, and launch mode through native hover/focus metadata for fast reproduction.
- Interaction rules: When the current launch-affecting configuration differs from the last validated configuration, the validation summary detail should list the changed fields at a compact operational level, such as commander, map, prestige, mastery, mutator preset, and mutator count.
- Interaction rules: A successful dry-run validation must record validation detail for the current signature, including time, pid, and stdout/stderr paths; the summary validation cell should expose that detail through native hover/focus metadata without changing launch payloads.
- Interaction rules: Dry-run validation must wait for the delegated process to finish, require exit code 0, require expected stdout markers, and treat any stderr output as a failed validation. "验证后启动" must only launch after that validation succeeds for the same launch-affecting configuration; when the UI is in "只安装不启动" mode, "验证后安装" must perform only the dry-run/install validation and must not send a second real launch request.
- Interaction rules: A normal launch request alone must not mark the summary as validated, because it does not wait for completion or enforce dry-run stdout/stderr validation gates. Only a successful dry-run validation or the dry-run phase of "验证后启动" may update the validated signature.
- Interaction rules: Launch history entries for dry-run validations and normal launches must store and show the final status, including exit code and completion time, not only the initial spawned process metadata.
- Interaction rules: Launch history "日志" detail must restore stdout/stderr paths into the current log-path state so "复制日志路径" works for past records, not only the latest launch.
- Interaction rules: The output panel should show the current stdout/stderr paths in a compact fixed strip whenever they are known, so launch evidence remains visible without digging through the full output text.
- Interaction rules: Recent config, scenario preset, and launch-history rows must provide a direct JSON export action that writes the row payload into the full-config JSON editor without changing the current selected commander/map/mastery/mutators.
- Interaction rules: Recent config, scenario preset, and launch-history main rows should expose a full compact payload summary through native hover/focus metadata, including exact ids and launch mode; launch-history log actions should expose stdout/stderr paths when available.
- Interaction rules: Recent config, scenario preset, and launch-history rows should render as a stable two-zone row: the main payload button with visible compact mode/mutator/mastery/status badges, plus a right-aligned action group. Submission buttons in those action groups follow the same launch-poll disabled state as top-level actions.
- Interaction rules: Applying a launch-history entry may restore the summary validation state only when that history entry is a completed dry-run validation with exit code 0, dry-run stdout markers, and empty stderr; normal launch or failed history entries must not be treated as current validation.
- Interaction rules: Recent configs must be keyed by the full launch-affecting configuration, including prestige toggles/mask/current prestige, mastery level, all six mastery slots, mutator ids, and mutator preset, so distinct test setups do not overwrite each other.
- Interaction rules: Launch, validation, validate-then-launch, and preview must be locally blocked and visibly disabled when launch-affecting configuration is invalid, including mastery category totals above 30. Random scenario generation must create a launchable mastery distribution rather than an immediately blocked one.
- Interaction rules: Initial load and "默认" reset must produce a launchable configuration; default mastery uses 15/15 in each category, while "全 30" remains an explicit stress/invalid shortcut that the issue line blocks before launch.

## Implementation constraints
- Framework/styling system: No dependency first pass; PowerShell `HttpListener` backend and static HTML/CSS/JS.
- Design-token constraints: CSS variables only.
- Performance constraints: Bootstrap data generated locally; mutator filtering must stay client-side and instant for current 69 ids.
- Compatibility constraints: Windows PowerShell 7+, local file paths with Chinese characters, modern desktop browser.
- Test expectations: Validate PowerShell parser, `/api/bootstrap`, static load, browser DOM behavior, launch dry-run logs, exit code, and stderr. Do not use Windows screenshots or browser screenshot capture for launcher verification.

## Open questions
- [ ] Whether DDS/audio extraction should use SC2 editor exports, CASC tooling, or existing extracted mirrors / owner: developer / impact: determines browser asset pipeline.
- [ ] Whether map names should come from localized in-map strings or maintain a curated display-name map / owner: developer / impact: launcher polish.
