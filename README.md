# Sky Mythic History

**Sky Mythic History** is a World of Warcraft addon that automatically tracks your Mythic+ key history and the history of every player you've run with. Built for the **Midnight** expansion (retail, Interface 120001+).

## Features

- **Automatic run tracking** — every completed or abandoned Mythic+ key is recorded automatically, no manual input needed
- **Full run details** — dungeon name, key level, result (timed / overtime / abandoned), time, deaths, death penalty, and Mythic+ score delta
- **Per-player stats** — damage, DPS, healing, HPS, interrupts, deaths, loot, spec and role for each player in the run
- **Player index** — browse every player you've ever grouped with, see their aggregate stats across all runs, dungeons, roles and specs
- **Player notes** — write personal notes on any player
- **Social alerts** — get a chat message when you group with someone you've run keys with before, showing how many runs you've done together
- **Completion popup** — a summary popup appears right after a run finishes (configurable trigger, delay and scale)
- **Stats tab** — overview of your overall performance: best key, success rate, favourite dungeons, most common teammates
- **Filters & search** — filter runs by dungeon, season, date, result, or owned characters; search by player name or dungeon
- **Multi-character support** — mark multiple characters as yours to view runs across all of them
- **Minimap button** — quick access toggle
- **Configurable** — max stored runs (50–5000), chat alerts, minimap button, completion popup behaviour

## Slash Commands

| Command | Action |
|---|---|
| `/smh` | Open / close the main window |
| `/smh help` | List all commands in chat |
| `/smh player Name-Realm` | Jump directly to a player's history |
| `/smh test` | Show a test completion popup |
| `/smh debug` | Show debug logging status |
| `/smh debug on\|off` | Enable / disable debug logging |
| `/smh debug last` | Print the latest saved debug report |
| `/smh debug clear` | Clear all saved debug reports |

## Installation

### Manual
1. Download the latest release zip
2. Extract the `SkyMythicHistory` folder into your WoW addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/SkyMythicHistory/
   ```
3. Reload the game or log in

### Migrating from MythicTools
If you renamed the addon from `MythicTools` to `SkyMythicHistory`, the SavedVariables file in your WTF folder must be named `SkyMythicHistory.lua`. If that file still contains `MythicToolsDB = {...}`, Sky Mythic History will migrate it automatically into `SkyMythicHistoryDB` the next time the addon loads.

### CurseForge / Wago Addons
Install through the CurseForge App or Wago App — the addon will be kept up to date automatically.

## Compatibility

| Field | Value |
|---|---|
| Game version | Midnight retail (120001, 120005) |
| SavedVariables | `SkyMythicHistoryDB` (`MythicToolsDB` is read once for migration) |
| Libraries | Ace3 (embedded), ScrollingTable (embedded) |

## Contributing

Bug reports and feature requests are welcome via [GitHub Issues](../../issues).

## License

All rights reserved. See [LICENSE](LICENSE) if present.
