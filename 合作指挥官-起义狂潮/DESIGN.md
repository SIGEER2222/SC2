# Design

## Source of truth
- Status: Active
- Last refreshed: 2026-06-10
- Primary product surfaces:
  - `web-launcher/index.html`
  - `web-launcher/app.js`
  - `web-launcher/styles.css`
  - `scripts/start-7vs1-web-launcher.ps1`
- Evidence reviewed:
  - `README.md`
  - `docs/Web启动器长期目标-2026-06-09.md`
  - `docs/当前进度与文件说明-2026-06-07.md`
  - `Shared/CommanderPower/commander-power-metadata.json`
  - `Mods/kit_mutations.SC2Mod/Base.SC2Data/GameData/Mutators.xml`
  - existing launcher HTML/CSS/JS

## Brand
- Personality:
  - StarCraft II control room, local dev tool, not marketing page.
- Trust signals:
  - real game text
  - real commander / mutator art
  - visible runtime ids and launch state
- Avoid:
  - placeholder initials as the primary visual
  - bright toy-like palette
  - oversized hero blocks and decorative cards

## Product goals
- Goals:
  - let the user choose commander, map, masteries, fusion prestige, and mutators quickly
  - keep the launch flow readable and debuggable
  - make the launcher feel like a usable in-universe tool instead of a temporary form
- Non-goals:
  - public-facing website
  - replacing the existing launch script authority
  - perfect 1:1 SC2 menu recreation in this iteration
- Success signals:
  - commander selection happens by clicking portrait cards
  - mutator selection shows game art instead of initials
  - launch/validation controls stay obvious and fast

## Personas and jobs
- Primary personas:
  - mod author validating commander runtime behavior
  - tester combining mutators and fusion setups for smoke runs
- User jobs:
  - pick one commander fast
  - inspect whether a commander is already validated or still partly inline
  - compose mutator sets without remembering ids from docs
  - launch or dry-run without leaving the page
- Key contexts of use:
  - desktop, local machine, repeated short test loops

## Information architecture
- Primary navigation:
  - single-screen tool
- Core routes/screens:
  - config panel
  - mastery / prestige panel
  - mutator panel
  - output / payload / history panel
- Content hierarchy:
  - current selection and launch controls first
  - commander portrait gallery next
  - map and preset helpers after that
  - detailed mutator tooling below fold

## Design principles
- Principle 1:
  - real game content beats abstract placeholders.
- Principle 2:
  - dense but scannable controls are better than decorative layout.
- Tradeoffs:
  - preserve the existing script protocol even if some UI states still map back to mask-based fields.

## Visual language
- Color:
  - dark steel base with restrained amber / teal accents
- Typography:
  - compact, utilitarian, Chinese-first UI text
- Spacing/layout rhythm:
  - tight 6-14px gaps, stable card sizes, no oversized dead space
- Shape/radius/elevation:
  - 6px framed panels and cards, light inner borders, restrained shadow
- Motion:
  - no decorative animation; selection states only
- Imagery/iconography:
  - use extracted SC2 art for commanders and mutators
  - let art occupy the card surface, with text in bottom overlays

## Components
- Existing components to reuse:
  - top action groups
  - summary strip
  - badge system
  - mutator preset / scenario list patterns
- New/changed components:
  - commander portrait gallery cards
  - mutator image cards
  - commander status badges on portrait cards
- Variants and states:
  - default / hover / selected / filtered-empty
  - verified / partial-inline status badge tones
- Token/component ownership:
  - keep styles inside `web-launcher/styles.css`

## Accessibility
- Target standard:
  - practical keyboard-usable local tool
- Keyboard/focus behavior:
  - all commander and mutator cards remain buttons
- Contrast/readability:
  - overlay text must stay legible on top of artwork
- Screen-reader semantics:
  - keep native buttons/selects/inputs
- Reduced motion and sensory considerations:
  - no required motion

## Responsive behavior
- Supported breakpoints/devices:
  - desktop first, usable on narrower laptop widths
- Layout adaptations:
  - commander gallery reflows to smaller cards
  - main workspace stacks when width drops
- Touch/hover differences:
  - hover is additive only; selection must be visible without hover

## Interaction states
- Loading:
  - keep bootstrap counts and top status visible
- Empty:
  - explicit empty cards for commander/map/mutator filters
- Error:
  - retain stderr/stdout path visibility and output panel detail
- Success:
  - show selected state, summary strip, and launch status
- Disabled:
  - controls stay visually muted but readable
- Offline/slow network, if applicable:
  - not applicable; local HTTP only

## Content voice
- Tone:
  - operational, concise, factual
- Terminology:
  - use in-game commander / mutator naming first, ids second
- Microcopy rules:
  - labels explain data, not the interface itself

## Implementation constraints
- Framework/styling system:
  - dependency-free HTML/CSS/JS served by `start-7vs1-web-launcher.ps1`
- Design-token constraints:
  - stay inside existing dark palette family, no new design system layer
- Performance constraints:
  - image prep should happen through local cache files, not repeated heavy conversion in the browser
- Compatibility constraints:
  - backend launch payload and current CommanderPower protocol remain unchanged
- Test/screenshot expectations:
  - run launcher self-test after UI/backend changes
  - when visual verification is available, verify the actual page rather than only reading HTML

## Open questions
- [ ] mutator exact official icon coverage is incomplete in current local exports; decide whether to add a fuller offline extraction pipeline for missing icons
- [ ] whether to add map artwork once a stable local source is available
