# nook
A minimal, **rule-based CLI tool** for managing structured data.
Single file, no dependencies, fully customizable.

---

## Design
- **Single-file tool**: Only `nook.lua` is needed.
- **Rule-driven**: All behavior is defined by **Lua script rules**.
- **Separation of data and schema**:
  - `rule/NAME.lua` → structure, filter, sort, format.
  - `data/NAME.lua` → actual entries.

---

## Usage
```bash
# Help
lua nook.lua -n NAME -h

# List entries
lua nook.lua -n NAME -d example -l

# Filter
lua nook.lua -n NAME -d example -l -f FILTER

# Sort
lua nook.lua -n NAME -d example -l -s SORT

# Format output
lua nook.lua -n NAME -d example -l -t FORMAT

# Show available options
lua nook.lua -n NAME -d example -f ?
lua nook.lua -n NAME -d example -s ?
lua nook.lua -n NAME -d example -t ?
```

---

## Rule Example (rule/NAME.lua)
```lua
-- lua script
return {
  struct = {
    title = "string",
    status = { "pending", "done" },
    date = "string"
  },

  filter = {
    pending = function(e) return e.status == "pending" end,
    done = function(e) return e.status == "done" end
  },

  sort = {
    date = function(a,b) return a.date < b.date end
  },

  format = {
    brief = function(e) return e.date .. " | " .. e.status .. " | " .. e.title end
  }
}
```

---

## Data Example (data/NAME.lua)
```lua
-- lua script
entry{
  title = "first",
  status = "pending",
  date = "2025-7-1",
}
entry{
  title = "second",
  status = "pending",
  date = "2025-7-2"
}
entry{
  title = "third",
  status = "done",
  date = "2026-7-2"
}
```
