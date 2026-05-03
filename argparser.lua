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

return argparser
