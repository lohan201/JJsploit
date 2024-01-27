-- jsut testing some stuff here
print("TESTING OUTPUT HERE")




-- reference testing
--[[
export type Test = {
  a: number,
  b: number
}

export type TestHolder = {
  test: Test
}

local function testref(t : TestHolder) : Test
  t.test.a = 5
  t.test.b = 6
  return t.test
end

local t = {a = 1, b = 2}
local th = {test = t}

local t2 = testref(th)

print(t.a)
print(t.b)

t.a = 10
t.b = 11

print(t2.a)
print(t2.b)

print(th.test.a )
print(th.test.b )
]]




--[[


-- table tests
local t : { string } = {}

table.insert(t,"hello")
table.insert(t,"world")
table.insert(t,"meow")
table.insert(t,"woof")
table.insert(t,"moo")

--table.remove(t,2)
t[2] = nil

for i,v in pairs(t) do
  print(i,v)
end

]]


--[[
-- POTATO PRINTER

export type Potato = {
    potato: string
}

local potatoPrinter = {
  __tostring = function(self)
    return self:potato()
  end
}

function printPotato(p : Potato)
  print(p.potato)
end

function makePotato(s : string) : Potato
  local r = {potato = s}


  setmetatable(r,potatoPrinter)

  return r 
end


--local p = makePotato("hello")
--print(tostring(p))

--local p = {potato = "hello", meow = "meow"}
--printPotato(p)

]]