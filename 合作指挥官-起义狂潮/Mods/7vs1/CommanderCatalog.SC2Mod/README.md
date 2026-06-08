# CommanderCatalog.SC2Mod

Small 7vs1 catalog patch for commander unit variants that must remain independent from map initialization and CommanderPower bank options.

Current test condition covered:
- Raynor starter base must create `CommandCenterRaynor`, train `SCVRaynor`, expose `UpgradeToOrbitalRaynor`, and give `SCVRaynor` the `TerranBuildRaynor` command card.

Keep prestige bonus selection and mastery point selection in `CommanderPower` bank/runtime code. This mod should only carry catalog data needed for those runtime choices to be valid in maps.
