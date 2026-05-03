local argparser = require "argparser"

-- Initialize command line argument parser
local parser = argparser.new("noooooook")
parser:add("-h", "--help",    { nargs = 0,   desc = "show this help message", ignore = true })
parser:add("-d", "--dir",     { nargs = 1,   desc = "set base directory for rule/ and data/", default = "." })
parser:add("-n", "--name",    { nargs = 1,   desc = "set entry type name", required = true })
parser:add("-t", "--format",  { nargs = 1,   desc = "set output format type", default = "brief" })
parser:add("-f", "--filter",  { nargs = "+", desc = "set filter (func or func:a,b or func:a,b func2:c)" })
parser:add("-s", "--sort",    { nargs = 1,   desc = "set sort type" })
parser:add("-v", "--invert",  { nargs = 0,   desc = "invert filter result (exclude matched)" })
parser:add("-r", "--reverse", { nargs = 0,   desc = "reverse sort order" })
parser:add("-o", "--output",  { nargs = 1,   desc = "write output to file" })
parser:parse()

-- Show help information
if parser:getopt("help").used then
  parser:print()
  return
end

-- Get entry name and file paths
local base_dir = parser:getopt("dir").first_arg
local entry_name = parser:getopt("name").first_arg
local rule_file = base_dir .. "/rule/" .. entry_name .. ".lua"
local data_file = base_dir .. "/data/" .. entry_name .. ".lua"

local function safe_dofile(path)
  local f = io.open(path, "r")
  if not f then
    print("error: cannot find file -> " .. path)
    print("       try '-d' option to specify base directory")
    os.exit(1)
  end
  f:close()

  local ok, ret = pcall(dofile, path)
  if not ok then
    print("error: failed to load file -> " .. path)
    print("reason: " .. tostring(ret))
    os.exit(1)
  end
  return ret
end

-- Load rule configuration
local rule = safe_dofile(rule_file)

-- Check top-level required rule fields
local required = { "struct", "format", "filter", "sort" }
for _, key in ipairs(required) do
  if not rule[key] then
    print("error: rule missing required top-level key: " .. key)
    os.exit(1)
  end
end

-- Check required format functions
local format_required = { "brief" }
for _, key in ipairs(format_required) do
  if not rule.format[key] then
    print("error: rule.format missing required function: " .. key)
    os.exit(1)
  end
end

-- Create a helper function to list available options
local function create_help_func(title, item_table)
  return function()
    print(title)
    for name in pairs(item_table) do
      if name ~= "?" then
        print("  - " .. name)
      end
    end
    os.exit(0)
  end
end

-- Inject help option "?" into rule modules
rule.format["?"] = create_help_func("Available output formats:", rule.format)
rule.filter["?"] = create_help_func("Available filters:", rule.filter)
rule.sort["?"]   = create_help_func("Available sort fields:", rule.sort)

-- Validate entry data against struct definition
local function validate_entry(t)
  for key, value in pairs(t) do
    if not rule.struct[key] then
      print("error: key '" .. key .. "' is not defined in struct")
      os.exit(1)
    end

    local def = rule.struct[key]
    local def_type = type(def) == "table" and "table" or def

    if def_type == "table" then
      local valid = false
      for _, enum_val in ipairs(def) do
        if value == enum_val then
          valid = true
          break
        end
      end
      if not valid then
        print("error: invalid value for " .. key .. ": '" .. value .. "'")
        os.exit(1)
      end
    else
      if type(value) ~= def_type then
        print("error: " .. key .. " expects " .. def_type .. ", got " .. type(value))
        os.exit(1)
      end
    end
  end
end

-- Load and validate data entries
local data = {}
function _G.entry(t)
  validate_entry(t)
  table.insert(data, t)
end
safe_dofile(data_file)

-- Table filter utility
function table.filter(t, predicate)
  local result = {}
  for _, item in ipairs(t) do
    if predicate(item) then
      table.insert(result, item)
    end
  end
  return result
end

-- Apply filters with arguments support and AND logic
local filter_opt = parser:getopt("filter")
local filter_funcs = {}
if filter_opt.used then
  for _, expr in ipairs(filter_opt.args) do
    -- Parse filter expression: "func" or "func:a1,a2,a3"
    local filter_name, args_str = expr:match("^([^:]+):?(.*)$")
    local filter_func = rule.filter[filter_name]

    if not filter_func then
      print("error: filter '" .. filter_name .. "' is not defined")
      os.exit(1)
    end
    if filter_name == "?" then filter_func() end

    -- Split comma-separated arguments
    local args = {}
    if args_str ~= "" then
      for arg in args_str:gmatch("[^,]+") do
        table.insert(args, arg)
      end
    end

    -- Add filter with unpacked arguments (multiple filters = AND)
    table.insert(filter_funcs, function(item)
      return filter_func(item, table.unpack(args))
    end)
  end
end

-- Apply invert
if parser:getopt("invert").used then
  data = table.filter(data, function(item)
    for _, filter_func in ipairs(filter_funcs) do
      if filter_func(item) then return false end
    end
    return true
  end)
else
  data = table.filter(data, function(item)
    for _, filter_func in ipairs(filter_funcs) do
      if not filter_func(item) then return false end
    end
    return true
  end)
end

-- Apply sorting and reverse order
local sort_opt = parser:getopt("sort")
if sort_opt.used then
  local sort_name = sort_opt.first_arg
  local sort_func = rule.sort[sort_name]

  if not sort_func then
    print("error: sort '" .. sort_name .. "' is not defined")
    os.exit(1)
  end
  if sort_name == "?" then sort_func() end

  table.sort(data, sort_func)

  -- Reverse sorted table if reverse option is used
  if parser:getopt("reverse").used then
    local reversed = {}
    for i = #data, 1, -1 do
      table.insert(reversed, data[i])
    end
    data = reversed
  end
end

-- Get output formatter
local format_name = parser:getopt("format").first_arg
local formatter = rule.format[format_name]
if not formatter then
  print("error: format '" .. format_name .. "' not defined")
  os.exit(1)
end
if format_name == "?" then formatter() end

-- Generate formatted output lines
local output_lines = {}
for _, entry in ipairs(data) do
  table.insert(output_lines, formatter(entry))
end

-- Write output to file if -o is used
local output_opt = parser:getopt("output")
if output_opt.used then
  local file_path = output_opt.first_arg
  local file = io.open(file_path, "w")
  if not file then
    print("error: cannot write to output file: " .. file_path)
    os.exit(1)
  end
  for _, line in ipairs(output_lines) do
    file:write(line .. "\n")
  end
  file:close()
  print("output saved to: " .. file_path)
end

-- Print list to console
for _, line in ipairs(output_lines) do
  print(line)
end
