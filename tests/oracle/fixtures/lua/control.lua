for i = 1, 10 do
  if i % 2 == 0 then
    print(i)
  elseif i > 7 then
    break
  else
    goto continue
  end
  ::continue::
end
while x do x = nil end
repeat local k = 1 until k
for k, v in pairs(t) do print(k, v) end
