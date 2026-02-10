local M = {}

-- Minimal SQL splitter for migrations (no stored procs; keep migrations simple).
-- Removes line comments and splits on ';' not inside quotes.
local function stripLineComments(sql)
  local out = {}
  for line in sql:gmatch('([^\n]*)\n?') do
    if line == '' and #out > 0 then
      table.insert(out, '')
    else
      local cleaned = line:gsub('%-%-.*$', '')
      table.insert(out, cleaned)
    end
  end
  return table.concat(out, '\n')
end

function M.SplitStatements(sql)
  if type(sql) ~= 'string' or sql == '' then return {} end
  sql = stripLineComments(sql)

  local stmts = {}
  local buf = {}
  local inSingle, inDouble = false, false
  local i = 1
  while i <= #sql do
    local c = sql:sub(i, i)
    local nextc = sql:sub(i + 1, i + 1)

    if c == "'" and not inDouble then
      -- handle escaped quotes '' (MySQL)
      if inSingle and nextc == "'" then
        table.insert(buf, "''")
        i = i + 2
        goto continue
      end
      inSingle = not inSingle
      table.insert(buf, c)
      i = i + 1
      goto continue
    end

    if c == '"' and not inSingle then
      inDouble = not inDouble
      table.insert(buf, c)
      i = i + 1
      goto continue
    end

    if c == ';' and not inSingle and not inDouble then
      local stmt = table.concat(buf):gsub('^%s+', ''):gsub('%s+$', '')
      if stmt ~= '' then table.insert(stmts, stmt) end
      buf = {}
      i = i + 1
      goto continue
    end

    table.insert(buf, c)
    i = i + 1

    ::continue::
  end

  local tail = table.concat(buf):gsub('^%s+', ''):gsub('%s+$', '')
  if tail ~= '' then table.insert(stmts, tail) end
  return stmts
end

return M

