# Directory Structure
- **rule/**: Stores rule definitions
- **data/**: Stores actual entry data

Example:
```console
rule/
  todo.lua
  project.lua
  money.lua
data/
  todo.lua
  project.lua
  money.lua
```

---

# Builtin
nook provides built-in utilities for writing rules.

- `_G.color`
  - Predefined ANSI color codes (foreground and background) for console output.
  - See source code for full color definitions.

---

# How to Write Rules
A rule is a Lua script that returns a table.
**struct / format / filter / sort / foreach / reduce are all required.**

## struct
Defines the schema (data structure) of entries.

Supported types:
- `"string"`
- `"number"`
- `"boolean"`
- `{ val1, val2, val3 }` — enum list

Example:
```lua
struct = {
  id      = "number",
  title   = "string",
  status  = { "pending", "done", "progress" },
  date    = "string"
}
```

## format
Defines output formatting functions.
Each function receives an entry and returns a string.
**`brief` is required as the default formatter.**

Example:
```lua
format = {
  brief = function(e)
    return e.date .. " | " .. e.status .. " | " .. e.title
  end
}
```

## filter
Defines filtering logic.
- Params: entry, ...cli_args
- Return: boolean (keep entry if true)

Example:
```lua
filter = {
  status = function(e, s) return e.status == s end,
  today  = function(e) return e.date == os.date("%Y-%m-%d") end
}
```

## sort
Defines sorting comparators.
Used directly by `table.sort()`.
- Params: entry_a, entry_b, ...cli_args
- Return: boolean (a before b if true)

Example:
```lua
sort = {
  date = function(a, b) return a.date > b.date end
}
```

## foreach
Defines entry update/process logic.
- Params: entry, ...cli_args
- Behavior: modifies entry fields in-memory
- With `--sync`: writes changes back to data file (map mode)

Example:
```lua
foreach = {
  status = function(e, s) e.status = s end,
  append  = function(e, txt) e.title = e.title .. txt end
}
```

## reduce
Defines aggregation logic for the entire list.
- Params: entries, ...cli_args
- Return: aggregated result (count, sum, avg, etc.)

Example:
```lua
reduce = {
  count = function(ents) return #ents end,
  total = function(ents) local t=0; for _,e in ipairs(ents)do t=t+e.amount end; return t end
}
```

---

# How to Write Data
Data files are Lua scripts that call the global `entry()` function.
Entries **must match the struct defined in the rule**.

Example:
```lua
entry{
  title = "Write manual",
  status = "progress",
  date = "2026-05-03"
}
```

---

# CLI Usage

## Help
```bash
nook -h
```

## Initialize Environment
Create default rule, data, and config files automatically.
- `-I, --init`         initialize rule/data/config (requires `-n`)

```bash
nook -n todo --init
```

## Show Current Config
View loaded configuration and file path.
- `--config`           show active config and values

```bash
nook --config
```

## Target
Specify the entry type and base directory.
- `-n, --name NAME`   entry type (required)
- `-d, --dir DIR`     base directory (default: `.`)

```bash
nook -n todo -d example
```

## Quiet
Suppress default console output.
Useful when you only want to show reduce results or custom output.
- `-q, --quiet`

## Format
Set output format.
- `-t, --format FMT`
- `-t ?` list available formats

```bash
nook -n todo -t color
```

## Filter
Filter entries with AND logic.
**Supports CLI arguments: func:arg1+arg2**
- `-f, --filter FILTER`
- `-f ?` list available filters

Syntax:
```
-f func
-f func:arg1+arg2
-f func1:a func2:b    (AND logic)
```

Flags:
- `-v, --invert`       exclude matched entries (NOT)

## Sort
Sort entries.
- `-s, --sort SORT`
- `-s ?` list available sorters
- `-r, --reverse` reverse order

```bash
nook -n todo -s date -r
```

## Foreach (In-Memory Modify)
Process/modify entries in memory.
**Supports CLI arguments: func:arg1+arg2**
- `-x, --foreach FOREACH`
- `-x ?` list available foreach functions

Syntax:
```
-x func
-x func:arg1+arg2
-x func1:a func2:b
```

## Map (Foreach + Save)
Foreach + **--sync** = persist changes to data file.
This is equivalent to map & save.
- `-S, --sync`         write changes to data file

Example:
```bash
nook -n todo -f status:pending -x status:done -S
```

## Reduce
Aggregate/stat the filtered list.
**Supports CLI arguments: func:arg1+arg2**
- `-X, --reduce REDUCE`
- `-X ?` list available reduce functions

Example:
```bash
nook -n todo -f status:pending -X count -q
```

---

# Important Rule Param Notes
All rule functions support **fixed params + variable CLI args**:
- filter:    `func(entry, ...cli_args)`
- sort:      `func(a, b, ...cli_args)`
- foreach:   `func(entry, ...cli_args)`
- reduce:    `func(entries, ...cli_args)`
- format:    `func(entry, ...cli_args)`

CLI usage format:
```
func_name:arg1+arg2+arg3
```

---

# Config File
Default config file: `.nookini.lua`
You can also use the environment variable: `NOOKINI`

Configurable items:
- `dir`
- `name`
- `format`
- `filter`
- `sort`
- `foreach`
- `reduce`
```
