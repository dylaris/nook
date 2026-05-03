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
```bash
# Show help
lua nook.lua -h

# List entries
lua nook.lua -n todo -d example -l

# Filter entries
lua nook.lua -n todo -d example -l -f status:done

# Sort entries
lua nook.lua -n todo -d example -l -s date

# Custom output format
lua nook.lua -n todo -d example -l -t color

# List available options
lua nook.lua -n todo -d example -f ?
lua nook.lua -n money -d example -s ?
lua nook.lua -n project -d example -t ?
```

---

For full documentation, see **MANUAL.md**.
