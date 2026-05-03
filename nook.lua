--===========================================================================
-- argparser start
--===========================================================================

--[[ example
local argparser = require("argparser")

local parser = argparser.new("testing")

parser:add("-h", "--help",    { desc = "print this information" })
parser:add("-d", "--depth",   { nargs = 1, default = 1 })
parser:add("-p", "--path",    { nargs = 1, default = "." })
parser:add("-f", "--files",   { nargs = "+" })
parser:add("-x", "--exclude", { nargs = 3, required = true })

parser:print()

local opts = parser:parse()

for _, opt in ipairs(opts) do
  local arg_string = ""
  for _, arg in ipairs(opt.args) do
    arg_string = arg_string .. tostring(arg) .. ", "
  end
  print(opt.short, opt.long, opt.default, #opt.args, arg_string)
end

print(parser:getopt("h").used)
--]]

local argparser = {}
argparser.__index = argparser

-- Create a new argument parser instance with a description
function argparser.new(description)
  local obj = setmetatable({}, argparser)
  obj.desc = description or "no description"
  obj.options = {}    -- stores all registered options
  obj.map = {}        -- maps short/long option strings to their option table
  obj.ignore = false  -- ignore check for required options
  return obj
end

-- Add a new option to the parser
-- short_name: like "-h"
-- long_name: like "--help"
-- config: includes nargs, default, desc, required, ignore
function argparser:add(short_name, long_name, config)
  local opt = {
    short = short_name,
    long = long_name,
    args = {},
    default = config.default or nil,
    nargs = config.nargs or 0,
    desc = config.desc or "",
    required = config.required or false,
    ignore = config.ignore or false,
    used = false,
  }

  self.map[short_name] = opt
  self.map[long_name] = opt
  table.insert(self.options, opt)
end

-- Check if a string is an option starting with - or --
local function isopt(s)
  return not not (s:match("^%-%w$") or s:match("^%-%-%w+"))
end

-- Split the global arg table into structured options and their arguments
local function split()
  local opts = {}
  local index = 1
  while index <= #arg do
    local name = arg[index]
    if isopt(name) then
      local opt = { name = name, args = {} }
      index = index + 1

      while index <= #arg do
        local a = arg[index]
        if not isopt(a) then
          table.insert(opt.args, a)
          index = index + 1
        else
          break
        end
      end

      -- handle --key=value format
      local key, value = name:match("^(%-%-[^=]+)=(.*)")
      if key then
        opt.name = key
        table.insert(opt.args, value)
      end

      table.insert(opts, opt)
    else
      index = index + 1
    end
  end
  return opts
end

-- Print formatted help information with aligned columns
function argparser:print()
  if self.desc then
    print("<<< " .. self.desc .. " >>>")
  end

  print("! = required")
  print("* = 0 or more args, + = 1 or more args, ? = 0 or 1 arg")
  print("------------------------------------------------------------")

  print(string.format("%-1s %-6s %-12s %-6s %s", "", "short", "long", "nargs", "desc"))
  print("------------------------------------------------------------")

  for _, opt in ipairs(self.options) do
    local mark = opt.required and "!" or " "
    local nargs_str = tostring(opt.nargs)
    if opt.nargs == 0 then nargs_str = "0" end

    print(string.format("%-1s %-6s %-12s %-6s %s",
      mark, opt.short or "", opt.long or "", nargs_str, opt.desc or ""
    ))
  end
end

-- Get an option by name (without '-' or '--')
-- name can be short or long, e.g., "h" or "help"
function argparser:getopt(name)
  local short = "-" .. name
  local long = "--" .. name
  return self.map[short] or self.map[long]
end

-- Main parse function: process, validate, check required options
function argparser:parse()
  local raw_opts = split()
  self:_process_raw_options(raw_opts)
  self:_process_default_options()
  self:_validate_all_option_args()
  if not self.ignore then
    self:_ensure_required_options_used()
  end
  return self.options
end

-- Parse user input options and fill their arguments and defaults
function argparser:_process_raw_options(raw_opts)
  for _, raw in ipairs(raw_opts) do
    local opt = self.map[raw.name]
    if not opt then
      print("error: unknown option: " .. raw.name)
      os.exit(1)
    end

    opt.used = true
    if opt.ignore then self.ignore = true end

    self:_copy_user_args(opt, raw.args)
    self:_apply_default_values(opt)
    self:_set_first_arg(opt)
  end
end

-- Process options that are not used by user and apply their default values
function argparser:_process_default_options()
  for _, opt in ipairs(self.options) do
    if not opt.used and opt.default ~= nil then
      opt.used = true
      self:_apply_default_values(opt)
      self:_set_first_arg(opt)
    end
  end
end

-- Copy user-provided arguments into the option
function argparser:_copy_user_args(opt, args)
  for _, arg in ipairs(args) do
    table.insert(opt.args, arg)
  end
end

-- Apply default values if the user provided no arguments
function argparser:_apply_default_values(opt)
  if #opt.args == 0 and opt.nargs ~= 0 then
    if type(opt.default) == "table" then
      for _, v in ipairs(opt.default) do
        table.insert(opt.args, v)
      end
    elseif opt.default ~= nil then
      table.insert(opt.args, opt.default)
    end
  end
end

-- Set first_arg as a shortcut to args[1] for convenience
function argparser:_set_first_arg(opt)
  if #opt.args > 0 then
    opt.first_arg = opt.args[1]
  end
end

-- Validate argument counts according to nargs rules for all options
function argparser:_validate_all_option_args()
  for _, opt in ipairs(self.options) do
    if not opt.used then goto continue end

    local count = #opt.args
    local rule = opt.nargs

    if type(rule) == "number" then
      self:_check_exact_arg_count(opt, count, rule)
    elseif rule == "?" then
      self:_check_zero_or_one_arg(opt, count)
    elseif rule == "+" then
      self:_check_at_least_one_arg(opt, count)
    elseif rule == "*" then
      -- no validation needed
    end

    ::continue::
  end
end

-- Ensure the option receives exactly the expected number of arguments
function argparser:_check_exact_arg_count(opt, actual, expected)
  if actual ~= expected then
    print(("error: option %s requires %d args, got %d"):format(opt.long, expected, actual))
    os.exit(1)
  end
end

-- Ensure the option receives 0 or 1 argument at most
function argparser:_check_zero_or_one_arg(opt, count)
  if count > 1 then
    print(("error: option %s allows 0 or 1 args, got %d"):format(opt.long, count))
    os.exit(1)
  end
end

-- Ensure the option receives at least one argument
function argparser:_check_at_least_one_arg(opt, count)
  if count < 1 then
    print(("error: option %s requires at least 1 arg, got %d"):format(opt.long, count))
    os.exit(1)
  end
end

-- Exit with an error if any required option was not used
function argparser:_ensure_required_options_used()
  local missing = false
  for _, opt in ipairs(self.options) do
    if opt.required and not opt.used then
      print("error: required option not used: " .. opt.long)
      missing = true
    end
  end
  if missing then os.exit(1) end
end

--===========================================================================
-- argparser end
--===========================================================================

--===========================================================================
-- nook start
--===========================================================================

-- Initialize command line argument parser
local parser = argparser.new("noooooook")
parser:add("-h", "--help",    { nargs = 0,   desc = "show this help message", ignore = true })
parser:add("-I", "--init",    { nargs = 1,   desc = "init shell (bash/powershell)", ignore = true })
parser:add("-d", "--dir",     { nargs = 1,   desc = "set base directory for rule/ and data/", default = "." })
parser:add("-n", "--name",    { nargs = 1,   desc = "set entry type name", required = true })
parser:add("-t", "--format",  { nargs = 1,   desc = "set output format type", default = "brief" })
parser:add("-f", "--filter",  { nargs = "+", desc = "set filter (func or func:a,b or func:a,b func2:c)" })
parser:add("-s", "--sort",    { nargs = 1,   desc = "set sort type" })
parser:add("-v", "--invert",  { nargs = 0,   desc = "invert filter result (exclude matched)" })
parser:add("-r", "--reverse", { nargs = 0,   desc = "reverse sort order" })
parser:add("-o", "--output",  { nargs = 1,   desc = "write output to file" })
parser:parse()

-- Initialize shell
local NOOK_PATH = arg[0]
local init_opt = parser:getopt("init")
if init_opt.used then
  local sh = init_opt.first_arg
  if sh == "bash" then
    print([[
nook() {
  lua "]] .. NOOK_PATH .. [[" "$@"
}
]])
  elseif sh == "powershell" then
    print([[
function nook {
  lua "]] .. NOOK_PATH .. [[" @args
}
]])
  end
  return
end

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

--===========================================================================
-- nook end
--===========================================================================
