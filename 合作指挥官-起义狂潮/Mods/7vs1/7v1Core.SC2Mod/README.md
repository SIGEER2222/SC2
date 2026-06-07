# 7v1 Core

Shared 7v1 runtime shim used to decouple pilot maps from `XMFinal.SC2Mod`.

Current scope:

- Provides a lightweight `LibE0EAE146` compatibility layer.
- Pulls in shared `XMCore` and a safe fallback commander mod.
- Keeps map-specific mission logic inside each map.
