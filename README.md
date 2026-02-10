# FiveM-JCRP (DB-first, modular FiveM framework)

This repo contains a **database-first**, **API-first** FiveM codebase scaffold and implementation.

## Quick start (local dev)

- Install FXServer artifacts
- Install/ensure `oxmysql` + `ox_lib`
- Create a database and set `mysql_connection_string`
- Copy `server.cfg.example` to `server.cfg` and adjust values
- Drop this repo’s `resources/` folder into your server’s resources directory (or symlink it)
- Add/ensure the resources in `server.cfg` (order matters: `core_boot` first)

## Repo layout

See `resources/README.md`.
