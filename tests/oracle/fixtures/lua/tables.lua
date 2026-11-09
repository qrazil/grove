local t = { 1, 2, 3; x = 1, ["y z"] = 2, [3] = { nested = true }, }
t.a.b.c = t["k"]
local n = #t + t[1] ^ 2 // 3 .. "s"
return { t = t, n = n, nothing = nil, yes = true, no = false }
