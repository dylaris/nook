return {
  struct = {
    name = "string",
    category = { "work", "study", "life", "tech" },
    priority = { "low", "medium", "high" },
    status = { "planning", "running", "finished", "stopped" },
    date = "string",
  },

  format = {
    brief = function(e)
      return e.date .. " | " .. e.priority .. " | " .. e.status .. " | " .. e.category .. " | " .. e.name
    end,

    color = function(e)
      local c = "\27[0m"
      if e.status == "finished" then c = "\27[32m"
      elseif e.status == "running" then c = "\27[34m"
      elseif e.status == "planning" then c = "\27[36m"
      elseif e.status == "stopped" then c = "\27[37m"
      end
      return c .. e.date .. " | " .. e.priority .. " | " .. e.status .. " | " .. e.category .. " | " .. e.name .. "\27[0m"
    end
  },

  filter = {
    status = function(e, s) return e.status == s end,
    priority = function(e, p) return e.priority == p end,
    category = function(e, c) return e.category == c end,
    today = function(e)
      local d = os.date("*t")
      return e.date == string.format("%04d-%02d-%02d", d.year, d.month, d.day)
    end,
  },

  sort = {
    date = function(a,b) return a.date > b.date end,
  },

  update = {},
  exec = {},
}
