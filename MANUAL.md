# nook Manual

## Directory Structure
- **rule/**: Stores rule definitions (schema, filters, sorters, formatters)
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

# How to Write Rules
A rule is a Lua script that returns a table.
**struct / format / filter / sort are all required.**

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
Functions receive an entry + optional arguments, return a boolean.

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
Receives two entries, returns a boolean.

Example:
```lua
sort = {
  date = function(a, b) return a.date > b.date end
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
lua nook.lua -h
```

## Target
Specify the entry type and base directory.
- `-n, --name NAME`   entry type (required)
- `-d, --dir DIR`     base directory (default: `.`)

```bash
lua nook.lua -n todo -d example
```

## Format
Set output format.
- `-t, --format FMT`
- `-t ?` list available formats

```bash
lua nook.lua -n todo -l -t color
```

## Filter
Filter entries with support for parameters and AND logic.
- `-f, --filter FILTER`
- `-f ?` list available filters

Syntax:
```
-f func
-f func:arg1,arg2
-f func1:a func2:b    (AND logic)
```

Flags:
- `-v, --invert`       exclude matched entries (NOT)

Note:
- Do NOT use spaces inside arguments: `a,b` not `a, b`
- For values with spaces, use quotes: `msg:'hello world'`
- OR logic is **not supported**.

## Sort
Sort entries.
- `-s, --sort SORT`
- `-s ?` list available sorters
- `-r, --reverse` reverse order

```bash
lua nook.lua -n todo -s date -r
```

## Output to File
Write formatted results to a file.
- `-o, --output PATH`

```bash
lua nook.lua -n todo -o output.txt
```
