return {
  struct = {
    type = { "income", "expense" },
    category = { "food", "shop", "traffic", "salary", "gift", "medical" },
    amount = "number",
    date = "string",
    note = "string",
  },

  format = {
    brief = function(e)
      return e.date .. " | " .. e.type .. " | " .. string.format("%6.2f", e.amount) .. " | " .. e.category .. " | " .. e.note
    end,

    color = function(e)
      if e.type == "income" then
        return "\27[32m" .. e.date .. " | +" .. string.format("%6.2f", e.amount) .. " | " .. e.category .. " | " .. e.note .. "\27[0m"
      else
        return "\27[31m" .. e.date .. " | -" .. string.format("%6.2f", e.amount) .. " | " .. e.category .. " | " .. e.note .. "\27[0m"
      end
    end,
  },

  filter = {
    type = function(e, t) return e.type == t end,
    category = function(e, c) return e.category == c end,
    amount_ge = function(e, v) return e.amount >= tonumber(v) end,
    today = function(e)
      local d = os.date("*t")
      return e.date == string.format("%04d-%02d-%02d", d.year, d.month, d.day)
    end,
    before = function(e, d) return e.date < d end,
    after = function(e, d) return e.date > d end,
    list = function(e) return true end,
  },

  sort = {
    date = function(a,b) return a.date > b.date end,
    amount = function(a,b) return a.amount > b.amount end,
  },

  update = {
  },
}
