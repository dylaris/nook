# nook
A simple **rule-based CLI tool** for managing structured data with chainable operations.

---

## Design
- **Rule-driven**: All behavior is defined by Lua scripts.
- **Separation of data and schema**:
  - `rule/NAME.lua` — defines struct, filters, sorters, and formatters.
  - `data/NAME.lua` — stores your actual entries.
- **Lightweight & extensible**: Build custom data types in seconds.
- **Chainable calls**: Combine filter, sort, foreach, map, reduce in one command.

---

## Quick Start
Check the config file `.nookini.lua`

```bash
# Show help
nook -h

# List all entries
nook

# Filter entries
nook -f status:done

# Sort entries
nook -s date

# Chain: filter + foreach (mark as done)
nook -f status:pending -x status:done

# Chain: filter + update + save to file
nook -f status:pending -x status:done -S

# Chain: filter + reduce + quiet output
nook -f status:pending -X count -q

# Custom output format
nook -t color

# List available rules
nook -n todo -d example -f ?
nook -x ?
nook -X ?
nook -n money -d example -s ?
nook -n project -d example -t ?
```

For full documentation, see **MANUAL.md**.

---

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
