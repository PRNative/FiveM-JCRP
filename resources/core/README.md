# Core resources (P0)

Core resources define the platform foundation and shared contracts:

- `core_boot`: config + DB health + migrations runner (startup gate)
- `core_identity`: account resolution + bans + audit (deferrals gate)
- `core_characters`: 3-slot character CRUD + identity storage
- `core_state`: persistent per-character state (position + metadata)
- `core_session`: session map + login flow + character selector UI
- `core_spawn`: spawn selector UI + last/new/default spawn logic

