-- nvim-treesitter's indentation for every line of a file, for the oracle comparison of GRV_med indent.
--
--   GROVE_PARSER_DIR=DIR NVIM_TS=PATH_OF_nvim-treesitter nvim -u NONE --headless -l tests/oracle/dump_indent.lua MANIFEST OUTDIR
--
-- MANIFEST: lines of `LANG<TAB>INDENTS_QUERY_FILE<TAB>PATH`. OUTDIR gets one `PATH.ind` per file (slashes
-- written as `__`): `@@ LANG PATH`, then `ROW INDENT` per line (0-based rows, -1 for no opinion), with
-- shiftwidth 4. The query file replaces the one nvim-treesitter ships (it may name node types the grammar
-- revision lacks).
local manifest, out_dir = arg[1], arg[2]
local parser_dir = os.getenv("GROVE_PARSER_DIR")
local ts_path = os.getenv("NVIM_TS")
vim.opt.rtp:append(ts_path)
vim.cmd("runtime plugin/nvim-treesitter.lua")
local indent = require("nvim-treesitter.indent")

local function read(path)
  local f = assert(io.open(path, "rb")); local text = f:read("*a"); f:close(); return text
end

for line in io.lines(manifest) do
  local lang, query_file, path = line:match("^([^\t]+)\t([^\t]+)\t(.+)$")
  if lang then
    vim.treesitter.language.add(lang, { path = parser_dir .. "/" .. lang .. ".so" })
    vim.treesitter.query.set(lang, "indents", read(query_file))
    local out = assert(io.open(out_dir .. "/" .. path:gsub("/", "__") .. ".ind", "w"))
    local ok, err = pcall(function()
      local lines = vim.split(read(path), "\n", { plain = true })
      vim.cmd("enew!")
      vim.bo.shiftwidth = 4
      vim.bo.tabstop = 4
      vim.bo.expandtab = true
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.bo.filetype = lang
      out:write("@@ " .. lang .. " " .. path .. "\n")
      for row = 0, #lines - 1 do
        out:write(string.format("%d %d\n", row, indent.get_indent(row + 1)))
      end
    end)
    if not ok then out:write("!! " .. path .. ": " .. tostring(err) .. "\n") end
    out:close()
  end
end
