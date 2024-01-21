-- jsut testing some stuff here
print("TESTING OUTPUT HERE")






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

