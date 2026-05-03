return {
  struct = {
    title = "string",
    status = { "pending", "open", "progress", "done", "closed" },
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
      elseif e.status == "closed" then
        prefix = "\27[37m"  -- gray
      elseif e.status == "progress" then
        prefix = "\27[34m"  -- blue
      elseif e.status == "open" then
        prefix = "\27[36m"  -- cyan
      elseif e.status == "pending" then
        prefix = "\27[33m"  -- yellow
      else
        prefix = "\27[0m"
      end
      return prefix .. e.date .. " | " .. e.status .. " | " .. e.title .. "\27[0m"
    end
  },

  filter = {
    status = function(e, status)
      return e.status == status
    end,

    title = function(e, title)
      return e.title == title
    end,

    today = function(e)
      local now = os.date("*t")
      local today_str = string.format("%04d-%02d-%02d", now.year, now.month, now.day)
      return e.date == today_str
    end,

    before = function(e, date)
      return e.date < date
    end,

    after = function(e, date)
      return e.date > date
    end,

    search = function(e, keyword)
      return e.title:lower():find(keyword:lower(), 1, true) ~= nil
    end
  },

  sort = {
    date = function(a, b)
      return a.date > b.date
    end,
  },
}
