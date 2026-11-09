-- Dump the captures nvim's tree-sitter gives for a query, for the oracle comparison of grove's queries.
--
--   GROVE_PARSER_DIR=DIR nvim -u NONE --headless -l tests/oracle/dump_captures.lua MANIFEST OUTDIR
--
-- MANIFEST: lines of `LANG<TAB>QUERYFILE<TAB>PATH`. OUTDIR gets one `PATH.cap` per file (slashes in
-- PATH written as `__`): `@@ LANG PATH`, then one `NAME SROW SCOL EROW ECOL` per capture (0-based rows
-- and byte columns, END exclusive), predicates and `#offset!` applied by nvim, names starting with `_`
-- left out. The lines are in the order nvim yields them; compare.py sorts both sides.

local manifest, out_dir = arg[1], arg[2]
local parser_dir = os.getenv("GROVE_PARSER_DIR")

local function read(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

-- the two custom handlers nvim-treesitter(-textobjects) add and the queries use
local function first_node(match, id)
  local node = match[id]
  if type(node) == "table" then node = node[#node] end
  return node
end
vim.treesitter.query.add_predicate("kind-eq?", function(match, _, _, pred)
  local node = first_node(match, pred[2])
  if not node then return true end
  for i = 3, #pred do if pred[i] == node:type() then return true end end
  return false
end, { force = true, all = true })
vim.treesitter.query.add_directive("make-range!", function(match, _, _, pred, metadata)
  local nodes_start, nodes_end = match[pred[3]], match[pred[4]]
  if type(nodes_start) == "table" then nodes_start = nodes_start[1] end
  if type(nodes_end) == "table" then nodes_end = nodes_end[#nodes_end] end
  if not (nodes_start and nodes_end) then return end
  local sr, sc = nodes_start:start()
  local er, ec = nodes_end:end_()
  metadata.made = metadata.made or {}
  metadata.made[#metadata.made + 1] = { pred[2], sr, sc, er, ec }
end, { force = true })

for line in io.lines(manifest) do
  local lang, query_file, path = line:match("^([^\t]+)\t([^\t]+)\t(.+)$")
  if lang then
    if parser_dir then vim.treesitter.language.add(lang, { path = parser_dir .. "/" .. lang .. ".so" }) end
    local out = assert(io.open(out_dir .. "/" .. path:gsub("/", "__") .. ".cap", "w"))
    local ok, err = pcall(function()
      local text = read(path)
      local query = vim.treesitter.query.parse(lang, read(query_file))
      local parser = vim.treesitter.get_string_parser(text, lang)
      local root = parser:parse(true)[1]:root()
      out:write("@@ " .. lang .. " " .. path .. "\n")
      for id, node, meta in query:iter_captures(root, text) do
        local name = query.captures[id]
        if name:sub(1, 1) ~= "_" then
          local srow, scol, erow, ecol = node:range()
          local range = (meta and meta.range) or (meta and meta[id] and meta[id].range)
          if range then srow, scol, erow, ecol = range[1], range[2], range[3], range[4] end
          out:write(string.format("%s %d %d %d %d\n", name, srow, scol, erow, ecol))
        end
      end
      for _, match, metadata in query:iter_matches(root, text, 0, -1, { all = true }) do
        for _, m in ipairs((metadata and metadata.made) or {}) do
          out:write(string.format("%s %d %d %d %d\n", m[1], m[2], m[3], m[4], m[5]))
        end
      end
    end)
    if not ok then out:write("!! " .. path .. ": " .. tostring(err) .. "\n") end
    out:close()
  end
end
