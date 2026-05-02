return {
  struct = {
    title = "string",
    status = { "pending", "done" },
    date = "string",
  },

  format = {
    brief = function(e)
      return e.date .. " | " .. e.status .. " | " .. e.title
    end,

    color = function(e)
      local prefix = ""
      if e.status == "done" then
        prefix = "\27[32m"  -- green
      elseif e.status == "pending" then
        prefix = "\27[33m"  -- yellow
      else
        prefix = "\27[0m"   -- default
      end
      return prefix .. e.date .. " | " .. e.status .. " | " .. e.title .. "\27[0m"
    end
  },

  filter = {
    pending = function(e)
      return e.status == "pending"
    end,

    done = function(e)
      return e.status == "done"
    end
  },

  sort = {
    date = function(a, b)
      return a.date > b.date
    end,
  },
}
