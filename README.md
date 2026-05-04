# nook
A simple **rule-based CLI tool** for managing structured data.

---

## Design
- **Rule-driven**: All behavior is defined by Lua scripts.
- **Separation of data and schema**:
  - `rule/NAME.lua` — defines struct, filters, sorters, and formatters.
  - `data/NAME.lua` — stores your actual entries.
- **Lightweight & extensible**: Build your own data types in seconds.

---

## Quick Start

Check the config file `.nookini.lua`

```bash
# Show help
lua nook.lua -h

# List entries
lua nook.lua

# Filter entries
lua nook.lua -f status:done

# Sort entries
lua nook.lua -s date

# Custom output format
lua nook.lua -t color

# List available options
lua nook.lua -n todo -d example -f ?
lua nook.lua -n money -d example -s ?
lua nook.lua -n project -d example -t ?
```

---

For full documentation, see **MANUAL.md**.

## Install

- **bash**
put this to **.bashrc**.
Put this into `~/.bashrc`
```bash
eval "$(lua /path/to/noo.lua --start bash)"
```

- **powershell**
Put this into your PowerShell profile (`$PROFILE`):
```powershell
Invoke-Expression (& { (lua /path/to/nook.lua --start powershell) -join "`n" })
```

If the profile does not exist, run this to create it:
```powershell
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
```

If you cannot run scripts, run this to allow local scripts:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```
