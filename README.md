# esx_multicharacter

Multicharacter system for **ESX Legacy 1.13.5**, rewritten from **esx_kashacters** and fully compatible with the original **esx_multicharacter** database.

> Drop-in replacement for the official `esx_multicharacter` — same events, same DB structure, no database migration required.

---

## About this project

This script was ported from **esx_kashacters** to **ESX Legacy 1.13.5** and adapted to work as a direct replacement for `esx_multicharacter`.

### What was rewritten?

| Old (esx_kashacters) | New (this script) |
|---|---|
| `kashactersS:*` / `kashactersC:*` events | `esx_multicharacter:*` events |
| `esx:getSharedObject` | `exports["es_extended"]:getSharedObject()` |
| `mysql-async` | `oxmysql` |
| Identifier swapping (`Char1hash`) | Standard `char1:licensehash` |
| `user_lastcharacter` table | `multicharacter_slots` table |
| Custom DB structure | Original esx_multicharacter DB |

### Features

- 4 character slots (configurable)
- Character selection with sky camera overlooking the city
- Camera spawn animation on login
- Separate skin creator and spawn point for new characters
- Character deletion with confirmation dialog
- `/relog` — return to character selection
- Admin commands: `/setslots`, `/remslots`, `/enablechar`, `/disablechar`
- Existing characters from esx_multicharacter load without any DB changes

---

## Dependencies

| Resource | Required | Description |
|---|---|---|
| [es_extended](https://github.com/esx-framework/esx_core) | ✅ | ESX Legacy **1.13.5** |
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ | Database |
| [esx_identity](https://github.com/esx-framework/esx_core) | ✅ | Character registration |
| [esx_skin](https://github.com/esx-framework/esx_core) | ✅ | Skin / appearance |
| [esx_menu_default](https://github.com/esx-framework/esx_core) | ✅ | Menu system |
| [skinchanger](https://github.com/esx-framework/esx_core) | ✅ | Skin data |
| spawnmanager | ✅ | CFX Default — `setAutoSpawn(false)` |

### Server requirements

- **OneSync Infinity** (required for ESX Legacy)
- MySQL / MariaDB
- `mysql_connection_string` in `server.cfg`

---

## Installation

1. Disable or replace the old `esx_multicharacter`
2. Place this folder as `esx_multicharacter` in `resources/[core]/`
3. Add to `server.cfg`:

```cfg
ensure oxmysql
ensure es_extended
ensure esx_multicharacter
```

4. **No DB changes required** if you already use `esx_multicharacter`.

If the tables do not exist yet, import `esx_multicharacter.sql`.

---

## Configuration (`config.lua`)

```lua
Config.Slots = 4                          -- Character slots per player
Config.SkyCam = vector4(...)              -- Sky camera (character selection)
Config.SkinCreator = vector4(x, y, z, h)  -- Position for skin creation
Config.Spawn = vector4(x, y, z, h)        -- Spawn after character creation
Config.CanDelete = true                     -- Allow character deletion
Config.Relog = true                         -- Enable /relog command
```

---

## Commands

| Command | Permission | Description |
|---|---|---|
| `/relog` | Player | Return to character selection |
| `/setslots [identifier] [amount]` | Admin | Set slot count |
| `/remslots [identifier]` | Admin | Remove extra slots |
| `/enablechar [identifier] [slot]` | Admin | Enable a character |
| `/disablechar [identifier] [slot]` | Admin | Disable a character |
| `/forcelog [id]` | Console | Force player logout |

---

## Events (compatibility)

```lua
-- Client
TriggerEvent('esx_multicharacter:SetupCharacters')
RegisterNetEvent('esx_multicharacter:SetupUI')
RegisterNetEvent('esx:onPlayerLogout')

-- Server
RegisterNetEvent('esx_multicharacter:SetupCharacters')
RegisterNetEvent('esx_multicharacter:CharacterChosen')
RegisterNetEvent('esx_multicharacter:DeleteCharacter')
RegisterNetEvent('esx_multicharacter:relog')
```

---

## Database

Identifier format: `char1:licensehash`, `char2:licensehash`, ...

```sql
-- Only required on fresh installation
CREATE TABLE IF NOT EXISTS `multicharacter_slots` (
    `identifier` VARCHAR(60) NOT NULL,
    `slots` INT(11) NOT NULL,
    PRIMARY KEY (`identifier`)
);
```

---

## Credits

- Based on [esx_kashacters](https://github.com/WolfKnight98/esx_kashacters) (Kashacters)
- Compatible with [esx_multicharacter](https://github.com/esx-framework/esx_core) (ESX Framework)
- Rewritten for **ESX Legacy 1.13.5**

## License

See the original licenses of the ESX resources used.
