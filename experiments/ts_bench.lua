-- tree-sitter baseline through nvim: cold parse and 20 one-character edits in the middle.
--   cd DIR_WITH_big.json_big.c_big.py_big.rs && nvim -u NONE --headless -l ts_bench.lua
-- Injections are switched off (they dominate otherwise: see docs/SPEC.md 3.2).
vim.opt.runtimepath:append(os.getenv("HOME") .. "/.local/share/nvim/lazy/nvim-treesitter")
local function ms(a) return (vim.uv.hrtime() - a) / 1e6 end
for _, c in ipairs({{"json","big.json"},{"c","big.c"},{"python","big.py"},{"rust","big.rs"}}) do
  local lang, path = c[1], c[2]
  local f = io.open(path, "rb"); local text = f:read("*a"); f:close()
  local lines = vim.split(text, "\n", {plain=true})
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local p = vim.treesitter.get_parser(buf, lang, {injections = {[lang] = ""}})
  local t = vim.uv.hrtime(); p:parse(); local cold = ms(t)
  -- one char edits in the middle, 20 times
  local mid = math.floor(#lines / 2)
  local tot, worst = 0, 0
  for i = 1, 20 do
    local row = mid + i * 3
    vim.api.nvim_buf_set_text(buf, row, 0, row, 0, {" "})
    local t2 = vim.uv.hrtime(); p:parse(); local d = ms(t2)
    tot = tot + d; if d > worst then worst = d end
  end
  local n = 0
  local function cnt(nd) n = n + 1; for ch in nd:iter_children() do cnt(ch) end end
  cnt(p:trees()[1]:root())
  io.write(string.format("%-7s %7d bytes %7d lines  cold parse %8.1f ms  nodes %8d  1-char edit mid-file avg %6.2f ms worst %6.2f ms\n", lang, #text, #lines, cold, n, tot/20, worst))
end
