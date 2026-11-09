-- Dump tree-sitter's parse tree as an S-expression per file, for the oracle.
--
--   nvim -u NONE --headless -l tests/oracle/dump_sexp.lua MANIFEST OUTDIR
--
-- MANIFEST: lines of `TSLANG<TAB>PATH`. OUTDIR gets one `PATH.sexp` per file
-- (slashes in PATH written as `__`). The tree is printed one node per line,
-- indented two spaces per level, named nodes only, with field names:
--
--     (document
--       (object
--         (pair
--           key: (string
--             (string_content))
--           value: (number))))
--
-- ERROR and MISSING nodes are kept: `(ERROR ...)`, `(MISSING ";")`. Each line
-- carries the byte range after a tab: `(pair\t12-30`. Needs nvim >= 0.10 and
-- nvim-treesitter's parser/ on the runtime path (NVIM_TS_RTP, default lazy's
-- checkout). Nothing is installed or written outside OUTDIR.

local manifest, out_dir = arg[1], arg[2]
local rtp = os.getenv("NVIM_TS_RTP") or (os.getenv("HOME") .. "/.local/share/nvim/lazy/nvim-treesitter")
vim.opt.runtimepath:append(rtp)

-- A grammar.json only describes the parser it was generated with, so the oracle
-- parser must come from the same revision: GROVE_PARSER_DIR holds LANG.so for it.
local parser_dir = os.getenv("GROVE_PARSER_DIR")

local function walk(node, out, depth, field)
  local prefix = string.rep("  ", depth) .. (field and (field .. ": ") or "")
  local _, _, sb = node:start()
  local _, _, eb = node:end_()
  local range = string.format("\t%d-%d", sb, eb)
  if node:missing() then
    out[#out + 1] = prefix .. "(MISSING " .. node:type() .. range .. ")"
    return
  end
  local first = #out + 1
  out[first] = prefix .. "(" .. node:type() .. range
  local has_child = false
  for child, name in node:iter_children() do
    if child:named() or child:missing() then
      has_child = true
      walk(child, out, depth + 1, name)
    end
  end
  out[#out] = out[#out] .. ")"
end

for line in io.lines(manifest) do
  local lang, path = line:match("^([^\t]+)\t(.+)$")
  if lang then
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    local out = {}
    local ok, err = pcall(function()
      if parser_dir then vim.treesitter.language.add(lang, { path = parser_dir .. "/" .. lang .. ".so" }) end
      local parser = vim.treesitter.get_string_parser(text, lang)
      local tree = parser:parse(true)[1]
      walk(tree:root(), out, 0, nil)
    end)
    local o = assert(io.open(out_dir .. "/" .. path:gsub("/", "__") .. ".sexp", "w"))
    if ok then
      o:write("@@ " .. lang .. " " .. path .. "\n" .. table.concat(out, "\n") .. "\n")
    else
      o:write("!! " .. path .. ": " .. tostring(err) .. "\n")
    end
    o:close()
  end
end
