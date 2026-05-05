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
-- menu
-----------------------------------------------------------------------------

-- Nook structure overview
--
-- Global nook table
-- _G.nook = {
--   path      = script self path
--   dir       = base working directory
--   name      = entry type name
--   rule      = load rule definition from rule/name.lua
--   data      = loaded entry list data
--   trigger   = workflow hooks: format / filter / sort / update / exec
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
--    Order: format → filter → sort → output → update
--
-- Config system
-- Default keys: dir, name, format, filter, sort, output, update
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

local function serialize_entry(e)
  local fields = {}
  for k, v in pairs(e) do
    if k ~= "__ignore" then
      local with_quote = true
      if type(v) == "number" or type(v) == "boolean" then
        with_quote = false
      end
      vs = with_quote and string.format("%q", tostring(v)) or tostring(v)
      table.insert(fields, string.format("%s = %s", k, vs))
    end
  end
  return "entry{ " .. table.concat(fields, ", ") .. " }"
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
  for _, item in ipairs(t) do
    if predicate(item) then
      item.__ignore = false
    end
  end
end

local rule_template = [[
return {
  struct = {
    title = "string",
    status = { "pending", "doing", "done", "cancelled", "postpone", "blocked" },
    date = "string",
  },

  format = {
    brief = function(e)
      return string.format("%s | %s | %s", e.date, e.status, e.title)
    end,

    color = function(e)
      local Color = {
        reset   = "\27[0m",
        red     = "\27[31m",
        green   = "\27[32m",
        yellow  = "\27[33m",
        blue    = "\27[34m",
        pink    = "\27[35m",
        cyan    = "\27[36m",
        gray    = "\27[90m",
      }

      local prefix = ""
      if e.status == "pending" then
        prefix = Color.blue
      elseif e.status == "doing" then
        prefix = Color.yellow
      elseif e.status == "done" then
        prefix = Color.green
      elseif e.status == "cancelled" then
        prefix = Color.gray
      elseif e.status == "postpone" then
        prefix = Color.cyan
      elseif e.status == "blocked" then
        prefix = Color.red
      else
        prefix = Color.reset
      end
      return prefix .. string.format("%s | %s | %s", e.date, e.status, e.title) .. Color.reset
    end
  },

  filter = {
    status = function(e, s)
      return e.status == s
    end,

    today = function(e)
      local now = os.date("*t")
      local today_str = string.format("%04d-%02d-%02d", now.year, now.month, now.day)
      return e.date == today_str
    end,

    before = function(e, d)
      return e.date < d
    end,

    after = function(e, d)
      return e.date > d
    end,

    search = function(e, keyword)
      return e.title:lower():find(keyword:lower(), 1, true) ~= nil
    end,
  },

  sort = {
    date = function(a, b)
      return a.date > b.date
    end,
  },

  update = {
    status = function(e, s)
      e.status = s
    end
  },

  exec = {
    count = function(tbl)
      print("count: " .. #tbl)
    end,
  }
}
]]

local data_template = [[
entry{ title = "Finish daily code review", status = "wait", date = "2026-01-01" }
]]

-----------------------------------------------------------------------------
-- load default config
-----------------------------------------------------------------------------

_G.nook = {
  path = arg[0],
  dir = nil,
  name = nil,
  rule = nil,
  data = { raw = nil, process = nil },
  trigger = {},
  action = {},
  formatter = nil,
  passthrough = true,
  echo = print,
}

local default_config = {
  dir = ".",
  name = nil,
  filter = nil,
  sort = nil,
  format = "brief",
  update = nil,
  exec = nil,
}

local allowed_keys = {
  dir = true,
  name = true,
  filter = true,
  sort = true,
  format = true,
  update = true,
  exec = true
}

setmetatable(default_config, {
  __newindex = function(tbl, key, value)
    if not allowed_keys[key] then
      err.fatal("error: config key '" .. tostring(key) .. "' is not allowed")
    end
    rawset(tbl, key, value)
  end
})

local function check_string_array(arr)
  if type(arr) ~= "table" then
    return false
  end

  for k, v in pairs(arr) do
    if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
      return false
    end
    if type(v) ~= "string" then
      return false
    end
  end

  return true
end

local config_file = file_exists(".nookini.lua") and ".nookini.lua" or os.getenv("NOOKINI")
if config_file ~= nil then
  local config = safe_dofile(config_file)
  for k, v in pairs(config) do
    if type(v) == "table" then
      if not check_string_array(v) then
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
parser:add("-u", "--update",  { nargs = "+", desc = "update data file", default = default_config.update })
parser:add("-x", "--exec",    { nargs = "+", desc = "process filter result (no file change)", default = default_config.exec })
parser:parse()

_G.nook.dir  = parser:getopt("dir").first_arg
_G.nook.name = parser:getopt("name").first_arg

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
_G.nook.action.start = function()
  local start_opt = parser:getopt("start")
  if start_opt.used then
    local sh = start_opt.first_arg
    if sh == "bash" then
      print([[
  nook() {
    lua "]] .. _G.nook.path .. [[" "$@"
  }
  ]])
    elseif sh == "powershell" then
      print([[
  function nook {
    lua "]] .. _G.nook.path .. [[" @args
  }
  ]])
    end
    os.exit(0)
  end
end

-- Show help information
_G.nook.action.help = function()
  if parser:getopt("help").used then
    parser:print()
    os.exit(0)
  end
end

-- Look config
_G.nook.action.config = function()
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
  update = nil,
  exec = nil,
}
]],
  _G.nook.dir,
  _G.nook.name
)

_G.nook.action.init = function()
  if parser:getopt("init").used then
    -- write rule.lua
    local rule_file = _G.nook.dir .. "/rule/" .. _G.nook.name .. ".lua"
    if not file_exists(rule_file) then
      write_to_file(rule_file, rule_template)
    end

    -- write data.lua
    local data_file = _G.nook.dir .. "/data/" .. _G.nook.name .. ".lua"
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
  _G.nook.action[v]()
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
local rule_file = _G.nook.dir .. "/rule/" .. _G.nook.name .. ".lua"
_G.nook.rule = safe_dofile(rule_file)

-- Check top-level required rule fields
local required = { "struct", "format", "filter", "sort", "update", "exec" }
for _, key in ipairs(required) do
  if not _G.nook.rule[key] then
    err.fatal("error: rule missing required top-level key: " .. key)
  end
end

-- Check required format functions
local format_required = { "brief" }
for _, key in ipairs(format_required) do
  if not _G.nook.rule.format[key] then
    err.fatal("error: rule.format missing required function: " .. key)
  end
end

-- Inject help option "?" into rule modules
_G.nook.rule.format["?"] = create_help_func("Output formats available:", _G.nook.rule.format)
_G.nook.rule.filter["?"] = create_help_func("Filters available:", _G.nook.rule.filter)
_G.nook.rule.sort["?"]   = create_help_func("Sort methods available:", _G.nook.rule.sort)
_G.nook.rule.update["?"] = create_help_func("Update operations available:", _G.nook.rule.update)
_G.nook.rule.exec["?"]   = create_help_func("Exec operations available:", _G.nook.rule.exec)

-----------------------------------------------------------------------------
-- load data
-----------------------------------------------------------------------------

-- Validate entry data against struct definition
local function validate_entry(t)
  local rule = _G.nook.rule
  for key, value in pairs(t) do
    if not rule.struct[key] then
      err.fatal("error: key '" .. key .. "' is not defined in struct")
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
_G.nook.data.raw = {}
_G.nook.data.process = _G.nook.data.raw
function _G.entry(t)
  validate_entry(t)
  t.__ignore = true
  table.insert(_G.nook.data.raw, t)
end
local data_file = _G.nook.dir .. "/data/" .. _G.nook.name .. ".lua"
safe_dofile(data_file)

-----------------------------------------------------------------------------
-- trigger
-----------------------------------------------------------------------------

local trigger_priority = {
  "format", -- high
  "quiet",
  "filter",
  "sort",
  "update",
  "exec", -- low
}

-- Apply quiet mode
_G.nook.trigger.quiet = function()
  if parser:getopt("quiet").used then
    _G.nook.echo = function() end
  end
end

-- Apply filters with arguments support and AND/NOT logic
_G.nook.trigger.filter = function()
  local filter_opt = parser:getopt("filter")
  local filter_funcs = {}
  if filter_opt.used then
    _G.nook.passthrough = false
    for _, expr in ipairs(filter_opt.args) do
      -- Parse filter expression: "func" or "func:a1,a2,a3"
      local filter_name, args_str = expr:match("^([^:]+):?(.*)$")
      local filter_func = _G.nook.rule.filter[filter_name]

      if not filter_func then
        err.fatal("error: filter '" .. filter_name .. "' is not defined")
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

    -- Apply invert
    if parser:getopt("invert").used then
      filter(_G.nook.data.process, function(item)
        for _, filter_func in ipairs(filter_funcs) do
          if filter_func(item) then return false end
        end
        return true
      end)
    else
      filter(_G.nook.data.process, function(item)
        for _, filter_func in ipairs(filter_funcs) do
          if not filter_func(item) then return false end
        end
        return true
      end)
    end
  end
end

-- Apply sorting and reverse order
_G.nook.trigger.sort = function()
  local sort_opt = parser:getopt("sort")
  if sort_opt.used then
    local sort_name = sort_opt.first_arg
    local sort_func = _G.nook.rule.sort[sort_name]

    if not sort_func then
      err.fatal("error: sort '" .. sort_name .. "' is not defined")
    end
    if sort_name == "?" then sort_func() end

    local sorted_data = {}
    for _, item in ipairs(_G.nook.data.process) do
      if _G.nook.passthrough or not item.__ignore then
        table.insert(sorted_data, item)
      end
    end
    _G.nook.data.process = sorted_data
    table.sort(_G.nook.data.process, sort_func)

    -- Reverse sorted table if reverse option is used
    if parser:getopt("reverse").used then
      local data = _G.nook.data.process
      local len = #data
      for i = 1, math.floor(len / 2) do
        local j = len - i + 1
        data[i], data[j] = data[j], data[i]
      end
    end
  end
end

-- Get output formatter
_G.nook.trigger.format = function()
  local format_name = parser:getopt("format").first_arg
  local format_func = _G.nook.rule.format[format_name]
  if not format_func then
    err.fatal("error: format '" .. format_name .. "' not defined")
  end
  if format_name == "?" then format_func() end
  _G.nook.formatter = format_func
end

-- Update data file
_G.nook.trigger.update = function()
  local update_opt = parser:getopt("update")
  if update_opt.used then
    for _, expr in ipairs(update_opt.args) do
      -- Parse update expression: "func" or "func:a1,a2,a3"
      local update_name, args_str = expr:match("^([^:]+):?(.*)$")
      local update_func = _G.nook.rule.update[update_name]

      if not update_func then
        err.fatal("error: update '" .. update_name .. "' is not defined")
      end
      if update_name == "?" then update_func() end

      -- Split comma-separated arguments
      local args = {}
      if args_str ~= "" then
        for arg in args_str:gmatch("[^,]+") do
          table.insert(args, arg)
        end
      end

      -- Update entries
      local count = 0
      for _, item in ipairs(_G.nook.data.process) do
        if _G.nook.passthrough or not item.__ignore then
          update_func(item, table.unpack(args))
          count = count + 1
        end
      end
      _G.nook.echo("update " .. count .. " entries")
    end

    -- Write back to data file
    local lines = {}
    for _, item in ipairs(_G.nook.data.raw) do
      table.insert(lines, serialize_entry(item))
    end
    write_to_file(data_file, table.concat(lines, "\n"))
  end
end

-- Process filter result
_G.nook.trigger.exec = function()
  local exec_opt = parser:getopt("exec")
  if exec_opt.used then
    local exec_entries = {}
    for _, item in ipairs(_G.nook.data.process) do
      if _G.nook.passthrough or not item.__ignore then
        item.__ignore = nil -- the priority of exec must be the lowest
        table.insert(exec_entries, item)
      end
    end

    for _, expr in ipairs(exec_opt.args) do
      -- Parse exec expression: "func" or "func:a1,a2,a3"
      local exec_name, args_str = expr:match("^([^:]+):?(.*)$")
      local exec_func = _G.nook.rule.exec[exec_name]

      if not exec_func then
        err.fatal("error: exec '" .. exec_name .. "' is not defined")
      end
      if exec_name == "?" then exec_func() end

      -- Split comma-separated arguments
      local args = {}
      if args_str ~= "" then
        for arg in args_str:gmatch("[^,]+") do
          table.insert(args, arg)
        end
      end

      -- exec entries
      exec_func(exec_entries, table.unpack(args))
    end
  end
end

-----------------------------------------------------------------------------
-- run trigger
-----------------------------------------------------------------------------

for _, v in ipairs(trigger_priority) do
  _G.nook.trigger[v]()
end

-- Output to console
for _, item in ipairs(_G.nook.data.process) do
  if _G.nook.passthrough or not item.__ignore then
    _G.nook.echo(_G.nook.formatter(item))
  end
end
