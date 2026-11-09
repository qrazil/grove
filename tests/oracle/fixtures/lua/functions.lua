local function add(a, b)
  return a + b
end
function M.sub(a, b) return a - b end
function M:method(...)
  local args = {...}
  return #args, select('#', ...)
end
local f = function(x) return x * 2 end
print(add(1, 2), (f(3)))
