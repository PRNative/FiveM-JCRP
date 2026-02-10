# Systems resources (P1+)

Gameplay systems (money, inventory, jobs, etc.). Each system:

- owns its DB tables
- exposes an API via exports and/or `ox_lib` callbacks
- never reads/writes another system’s tables directly

