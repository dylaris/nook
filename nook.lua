--===========================================================================
-- err start
--===========================================================================

local err = {}

function err.println(message)
  io.stderr:write(tostring(message) .. "\n")
end

function err.print(message)
  io.stderr:write(tostring(message))
end

function err.fatal(message)
  io.stderr:write(tostring(message) .. "\n")
  os.exit(1)
end

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
  return not not (s:match("^%-") or s:match("^%-%-"))
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
      err.fatal("error: unknown option: " .. raw.name)
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
    err.fatal(("error: option %s requires %d args, got %d"):format(opt.long, expected, actual))
  end
end

-- Ensure the option receives 0 or 1 argument at most
function argparser:_check_zero_or_one_arg(opt, count)
  if count > 1 then
    err.fatal(("error: option %s allows 0 or 1 args, got %d"):format(opt.long, count))
  end
end

-- Ensure the option receives at least one argument
function argparser:_check_at_least_one_arg(opt, count)
  if count < 1 then
    err.fatal(("error: option %s requires at least 1 arg, got %d"):format(opt.long, count))
  end
end

-- Exit with an error if any required option was not used
function argparser:_ensure_required_options_used()
  local missing = false
  for _, opt in ipairs(self.options) do
    if opt.required and not opt.used then
      err.println("error: required option not used: " .. opt.long)
      missing = true
    end
  end
  if missing then os.exit(1) end
end

--===========================================================================
-- nook start
--===========================================================================

-----------------------------------------------------------------------------
-- builtin
-----------------------------------------------------------------------------

_G.color = {
  reset   = "\27[0m",

  -- foreground
  fg_black   = "\27[30m",
  fg_red     = "\27[31m",
  fg_green   = "\27[32m",
  fg_yellow  = "\27[33m",
  fg_blue    = "\27[34m",
  fg_pink    = "\27[35m",
  fg_cyan    = "\27[36m",
  fg_white   = "\27[37m",

  -- foreground (highlight)
  fg_gray    = "\27[90m",
  fg_lred    = "\27[91m",
  fg_lgreen  = "\27[92m",
  fg_lyellow = "\27[93m",
  fg_lblue   = "\27[94m",
  fg_lpink   = "\27[95m",
  fg_lcyan   = "\27[96m",
  fg_lwhite  = "\27[97m",

  -- background
  bg_black   = "\27[40m",
  bg_red     = "\27[41m",
  bg_green   = "\27[42m",
  bg_yellow  = "\27[43m",
  bg_blue    = "\27[44m",
  bg_pink    = "\27[45m",
  bg_cyan    = "\27[46m",
  bg_white   = "\27[47m",

  -- background (highlight)
  bg_lgray   = "\27[100m",
  bg_lred    = "\27[101m",
  bg_lgreen  = "\27[102m",
  bg_lyellow = "\27[103m",
  bg_lblue   = "\27[104m",
  bg_lpink   = "\27[105m",
  bg_lcyan   = "\27[106m",
}

-----------------------------------------------------------------------------
-- menu
-----------------------------------------------------------------------------

-- Nook structure overview
--
-- nook = {
--   path      = script self path
--   dir       = base working directory
--   name      = entry type name
--   rule      = load rule definition from rule/name.lua
--   data      = loaded entry list data
--   trigger   = workflow hooks: format / filter / sort / foreach / reduce
--   action    = standalone commands: start / help / config / init
--   formatter = selected output format function
-- }
--
-- Two core modules
-- 1. action: high priority commands
--    Run and exit immediately, skip follow workflow
--    List: start, help, config, init
--
-- 2. trigger: workflow lifecycle hooks
--    Run in fixed order, no exit, continue process
--    Order: format → filter → sort → foreach -> reduce
--
-- Config system
-- Default keys: dir, name, format, filter, sort, foreach, reduce
-- Only support pre-difined config
-- Load order: local .nookini.lua → env NOOKINI
-- Config key whitelist, forbid unknown new keys
--
-- Rule file structure
-- rule = {
--   struct  = define entry fields type & enum values
--   format  = output render functions
--   filter  = data filter functions
--   sort    = data sort compare functions
--   foreach = data foreach functions
--   reduce  = data reduce functions
-- }
--
-- Workflow flow
-- 1. load config (local .nookini.lua or env NOOKINI)
-- 2. parse cli arguments
-- 3. run action (exit if matched)
-- 4. load & validate rule file
-- 5. load & validate data entries
-- 6. run trigger pipeline
-- 7. print final result to console

-----------------------------------------------------------------------------
-- misc
-----------------------------------------------------------------------------

local function check_array(arr)
  if type(arr) ~= "table" then
    return false
  end

  for k, v in pairs(arr) do
    if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
      return false
    end
  end

  return true
end

local function serialize_table(t, level)
  level = level or 1
  local indent = string.rep("  ", level)
  local fields = {}

  for k, v in pairs(t) do
    if k ~= "__ignore" then
      local key_str = tostring(k)
      local value_str
      local kv_str

      if type(v) == "table" then
        value_str = serialize_table(v, level + 1)
      elseif type(v) == "string" then
        value_str = string.format("%q", v)
      elseif type(v) == "number" or type(v) == "boolean" then
        value_str = tostring(v)
      else
        value_str = string.format("%q", tostring(v))
      end

      if check_array(t) then
        kv_str = value_str
      else
        kv_str = key_str .. " = " .. value_str
      end
      table.insert(fields, string.format("%s%s", indent, kv_str))
    end
  end

  if level == 1 then
    return "entry{\n" .. table.concat(fields, ",\n") .. "\n}"
  else
    return "{\n" .. table.concat(fields, ",\n") .. "\n" .. string.rep("  ", level - 1) .. "}"
  end
end

local function serialize_entry(e)
  return serialize_table(e, 1)
end

local function write_to_file(path, content)
  local f = io.open(path, "w")
  if not f then
    err.fatal("error: cannot find file -> '" .. path .. "': maybe you need to create directory first")
  end
  f:write(content)
  f:close()
end

local function file_exists(path)
  local f = io.open(path, "r")
  if not f then
    return false
  end
  f:close()
  return true
end

local function safe_dofile(path)
  local f = io.open(path, "r")
  if not f then
    err.fatal("error: cannot find file -> " .. path)
  end
  f:close()

  local ok, ret = pcall(dofile, path)
  if not ok then
    err.fatal("error: failed to load file -> " .. path .. ": " .. tostring(ret))
  end
  return ret
end

function filter(t, predicate)
  local result = {}
  for _, item in ipairs(t) do
    if predicate(item) then
      table.insert(result, item)
    end
  end
  return result
end

local rule_template = [[
return {
  -- Data structure definition for entries
  struct = {
    a = "string",               -- String type
    b = { "apple", "grape" },   -- Enum type (allowed values)
    c = "table",                -- Table / object type
    d = "number",               -- Number type
    e = "boolean",              -- Boolean type
  },

  -- Format output rules
  format = {
    -- Required brief display string
    -- Params: entry, ...cli_args
    -- Return: string
    brief = function(e) return "" end,
  },

  -- Filter rules (keep entry if true)
  -- Params: entry, ...cli_args
  -- Return: boolean
  filter = {
    status = function(e, s) return e.status == s end,
  },

  -- Sort rules (a before b if true)
  -- Params: entry_a, entry_b, ...cli_args
  -- Return: boolean
  sort = {
    date = function(a, b) return a.date > b.date end,
  },

  -- Foreach update rules
  -- Params: entry, ...cli_args
  -- Note: Use --sync to persist changes to file
  foreach = {
    status = function(e, s) e.state = s end,
  },

  -- Reduce / aggregate rules
  -- Params: entries, ...cli_args
  -- Return: aggregated result
  reduce = {
    count = function(es) print(#es) end
  },
}
]]

local data_template = [[
-- Data entry structure example:
-- entry{ title = "Finish daily code review", status = "wait", date = "2026-01-01" }
]]

-----------------------------------------------------------------------------
-- load default config
-----------------------------------------------------------------------------

local nook = {
  path = arg[0],
  dir = nil,
  name = nil,
  rule = nil,
  data = { all = nil, list = nil },
  trigger = {},
  action = {},
  formatter = nil,
  echo = print,
}

local default_config = {
  dir = ".",
  name = nil,
  filter = nil,
  sort = nil,
  format = "brief",
  foreach = nil,
  reduce = nil,
}

local allowed_keys = {
  dir = true,
  name = true,
  filter = true,
  sort = true,
  format = true,
  foreach = true,
  reduce = true
}

setmetatable(default_config, {
  __newindex = function(tbl, key, value)
    if not allowed_keys[key] then
      err.fatal("error: config key '" .. tostring(key) .. "' is not allowed")
    end
    rawset(tbl, key, value)
  end
})

local config_file = file_exists(".nookini.lua") and ".nookini.lua" or os.getenv("NOOKINI")
if config_file ~= nil then
  local config = safe_dofile(config_file)
  for k, v in pairs(config) do
    if type(v) == "table" then
      if not check_array(v) then
        err.fatal("error: value of config key: '" .. tostring(k) .. "' should be string array")
      end
    end
    default_config[k] = v
  end
end

-----------------------------------------------------------------------------
-- parser
-----------------------------------------------------------------------------

local parser = argparser.new("noooooook")
parser:add("",   "--start",   { nargs = 1,   desc = "init shell (bash/powershell)", ignore = true })
parser:add("",   "--config",  { nargs = 0,   desc = "look nook default config", ignore = true })
parser:add("-h", "--help",    { nargs = 0,   desc = "show this help message", ignore = true })
parser:add("-I", "--init",    { nargs = 0,   desc = "auto create rule/data (-n is required)" })
parser:add("-d", "--dir",     { nargs = 1,   desc = "set base directory for rule/ and data/", default = default_config.dir })
parser:add("-n", "--name",    { nargs = 1,   desc = "set entry type name", default = default_config.name, required = true })
parser:add("-t", "--format",  { nargs = 1,   desc = "set output format type", default = default_config.format })
parser:add("-f", "--filter",  { nargs = "+", desc = "set filter (func or func:a,b or func:a,b func2:c)", default = default_config.filter })
parser:add("-s", "--sort",    { nargs = 1,   desc = "set sort type", default = default_config.sort })
parser:add("-v", "--invert",  { nargs = 0,   desc = "invert filter result (exclude matched)" })
parser:add("-r", "--reverse", { nargs = 0,   desc = "reverse sort order" })
parser:add("-q", "--quiet",   { nargs = 0,   desc = "no echo" })
parser:add("-x", "--foreach", { nargs = "+", desc = "apply foreach action on filtered entries", default = default_config.foreach })
parser:add("-X", "--reduce",  { nargs = 1,   desc = "aggregate filtered entries", default = default_config.reduce })
parser:add("-S", "--sync",    { nargs = 0,   desc = "save changes back to data file" })
parser:parse()

nook.dir  = parser:getopt("dir").first_arg
nook.name = parser:getopt("name").first_arg

-----------------------------------------------------------------------------
-- define action
-----------------------------------------------------------------------------

local action_priority = {
  "start", -- high
  "help",
  "config",
  "init", -- low
}

-- Initialize shell
nook.action.start = function()
  local start_opt = parser:getopt("start")
  if start_opt.used then
    local sh = start_opt.first_arg
    if sh == "bash" then
      print([[
  nook() {
    lua "]] .. nook.path .. [[" "$@"
  }
  ]])
    elseif sh == "powershell" then
      print([[
  function nook {
    lua "]] .. nook.path .. [[" @args
  }
  ]])
    end
    os.exit(0)
  end
end

-- Show help information
nook.action.help = function()
  if parser:getopt("help").used then
    parser:print()
    os.exit(0)
  end
end

-- Look config
nook.action.config = function()
  if parser:getopt("config").used then
    if config_file then
      print("===nook default config===")
      print("config file: " .. config_file)
      print("=========================")
      for k, v in pairs(default_config) do
        local arg = type(v) == "string" and v or table.concat(v, " ")
        print(tostring(k) .. " = " .. arg)
      end
      print("=========================")
    else
      print("===no config file===")
    end
    os.exit(0)
  end
end

-- Initialize directory
local cfg_template = string.format([[
return {
  dir = %q,
  name = %q,
  format = "brief",
  filter = nil,
  sort = nil,
  foreach = nil,
  reduce = nil,
}
]],
  nook.dir,
  nook.name
)

nook.action.init = function()
  if parser:getopt("init").used then
    -- write rule.lua
    local rule_file = nook.dir .. "/rule/" .. nook.name .. ".lua"
    if not file_exists(rule_file) then
      write_to_file(rule_file, rule_template)
    end

    -- write data.lua
    local data_file = nook.dir .. "/data/" .. nook.name .. ".lua"
    if not file_exists(data_file) then
      write_to_file(data_file, data_template)
    end

    -- write cfg.lua
    local cfg_file = ".nookini.lua"
    if not file_exists(cfg_file) then
      write_to_file(cfg_file, cfg_template)
    end
    os.exit(0)
  end
end

-----------------------------------------------------------------------------
-- run action
-----------------------------------------------------------------------------

for _, v in ipairs(action_priority) do
  nook.action[v]()
end

-----------------------------------------------------------------------------
-- load rule
-----------------------------------------------------------------------------

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

-- Load rule configuration
local rule_file = nook.dir .. "/rule/" .. nook.name .. ".lua"
nook.rule = safe_dofile(rule_file)

-- Check top-level required rule fields
local required = { "struct", "format", "filter", "sort", "foreach", "reduce" }
for _, key in ipairs(required) do
  if not nook.rule[key] then
    err.fatal("error: rule missing required top-level key: " .. key)
  end
end

-- Check required format functions
local format_required = { "brief" }
for _, key in ipairs(format_required) do
  if not nook.rule.format[key] then
    err.fatal("error: rule.format missing required function: " .. key)
  end
end

-- Inject help option "?" into rule modules
nook.rule.format["?"]  = create_help_func("Output formats available:", nook.rule.format)
nook.rule.filter["?"]  = create_help_func("Filters available:", nook.rule.filter)
nook.rule.sort["?"]    = create_help_func("Sort methods available:", nook.rule.sort)
nook.rule.foreach["?"] = create_help_func("Foreach operations available:", nook.rule.foreach)
nook.rule.reduce["?"]  = create_help_func("Reduce operations available:", nook.rule.reduce)

-----------------------------------------------------------------------------
-- load data
-----------------------------------------------------------------------------

-- Validate entry data against struct definition
local function validate_entry(t)
  local rule = nook.rule
  for key, value in pairs(t) do
    if not rule.struct[key] then
      err.fatal("error: key '" .. key .. "' is not defined in struct")
    end

    local def = rule.struct[key]
    local def_type = type(def) == "table" and "enum" or def

    if def_type == "enum" then
      local valid = false
      for _, enum_val in ipairs(def) do
        if value == enum_val then
          valid = true
          break
        end
      end
      if not valid then
        err.fatal("error: invalid value for " .. key .. ": '" .. value .. "'")
      end
    else
      if type(value) ~= def_type then
        err.fatal("error: " .. key .. " expects " .. def_type .. ", got " .. type(value))
      end
    end
  end
end

-- Load and validate data entries
nook.data.all = {}
nook.data.list = {}
function _G.entry(t)
  validate_entry(t)
  table.insert(nook.data.all, t)
  table.insert(nook.data.list, t)
end
local data_file = nook.dir .. "/data/" .. nook.name .. ".lua"
safe_dofile(data_file)

-----------------------------------------------------------------------------
-- trigger
-----------------------------------------------------------------------------

local trigger_priority = {
  "quiet",  -- high
  "format",
  "filter",
  "sort",
  "foreach",
  "reduce",
  "display", -- low
}

-- Apply quiet mode
nook.trigger.quiet = function()
  if parser:getopt("quiet").used then
    nook.echo = function() end
  end
end

-- input: func_name:arg1+arg2...
-- output: (name, args)
local function parse_expr(expr)
  local name, args_str = expr:match("^([^:]+):?(.*)$")
  local args = {}
  if args_str ~= "" then
    for arg in args_str:gmatch("[^+]+") do
      table.insert(args, arg)
    end
  end
  return name, args
end

-- Apply filters with arguments support and AND/NOT logic
nook.trigger.filter = function()
  local opt = parser:getopt("filter")
  local funcs = {}
  if opt.used then
    for _, expr in ipairs(opt.args) do
      local func_name, func_args = parse_expr(expr)
      local func = nook.rule.filter[func_name]
      if not func then
        err.fatal("error: filter '" .. func_name .. "' is not defined")
      end
      if func_name == "?" then func() end

      -- Add filter with unpacked arguments (multiple filters = AND)
      table.insert(funcs, function(item)
        return func(item, table.unpack(func_args))
      end)
    end

    -- Apply invert
    local predicate
    if parser:getopt("invert").used then
      predicate = function(item)
        for _, func in ipairs(funcs) do
          if func(item) then return false end
        end
        return true
      end
    else
      predicate = function(item)
        for _, func in ipairs(funcs) do
          if not func(item) then return false end
        end
        return true
      end
    end
    nook.data.list = filter(nook.data.list, predicate)
  end
end

-- Apply sorting and reverse order
nook.trigger.sort = function()
  local opt = parser:getopt("sort")
  if opt.used then
    local func_name, func_args = parse_expr(opt.first_arg)
    local func = nook.rule.sort[func_name]
    if not func then
      err.fatal("error: sort '" .. func_name .. "' is not defined")
    end
    if func_name == "?" then func() end

    -- Sort
    table.sort(nook.data.list, function(a, b)
      return func(a, b, table.unpack(func_args))
    end)

    -- Reverse sorted table if reverse option is used
    if parser:getopt("reverse").used then
      local data = nook.data.list
      local len = #data
      for i = 1, math.floor(len / 2) do
        local j = len - i + 1
        data[i], data[j] = data[j], data[i]
      end
    end
  end
end

-- Get output formatter
nook.trigger.format = function()
  local func_name = parser:getopt("format").first_arg
  local func = nook.rule.format[func_name]
  if not func then
    err.fatal("error: format '" .. func_name .. "' not defined")
  end
  if func_name == "?" then func() end
  nook.formatter = func
end

-- Process filter result for each entry
nook.trigger.foreach = function()
  local opt = parser:getopt("foreach")
  local funcs = {}
  if opt.used then
    for _, expr in ipairs(opt.args) do
      local func_name, func_args = parse_expr(expr)
      local func = nook.rule.foreach[func_name]
      if not func then
        err.fatal("error: foreach '" .. func_name .. "' is not defined")
      end
      if func_name == "?" then func() end

      -- Add foreach with unpacked arguments (multiple foreach = pipeline)
      table.insert(funcs, function(item)
        func(item, table.unpack(func_args))
      end)
    end

    -- Foreach
    for _, item in ipairs(nook.data.list) do
      for _, func in ipairs(funcs) do func(item) end
    end

    -- Apply sync (write back to data file)
    if parser:getopt("sync").used then
      local lines = {}
      for _, item in ipairs(nook.data.all) do
        table.insert(lines, serialize_entry(item))
      end
      write_to_file(data_file, table.concat(lines, "\n"))
    end
  end
end

-- Process filter result for the table itself
nook.trigger.reduce = function()
  local opt = parser:getopt("reduce")
  if opt.used then
    local func_name, func_args = parse_expr(opt.first_arg)
    local func = nook.rule.reduce[func_name]
    if not func then
      err.fatal("error: reduce '" .. func_name .. "' is not defined")
    end
    if func_name == "?" then func() end

    -- Reduce
    func(nook.data.list, table.unpack(func_args))
  end
end

-- Display list to console
nook.trigger.display = function()
  nook.echo("<<<<<< -q : quiet mode")
  for _, item in ipairs(nook.data.list) do
    nook.echo(nook.formatter(item))
  end
  nook.echo(">>>>>>")
end

-----------------------------------------------------------------------------
-- run trigger
-----------------------------------------------------------------------------

for _, v in ipairs(trigger_priority) do
  nook.trigger[v]()
end

