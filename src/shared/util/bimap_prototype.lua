--!strict
-- bimap implementation in Lua
-- same as the other bimap, except with the prototype pattern (so functions only need to be allocated once)
-- doesn't work due to typeof(setmetatable({} :: BimapData<K,V>, {} :: BimapImpl<K,V> & BimapMT<K,V>)) not propogating the types down 

type BimapData<K,V> = {
    forwardMap : {[K] : V},
    backwardMap : { [V] : K},
}


type BimapMT<K,V> = {
    __newindex: (self: Bimap<K,V>, key : K, value : V) -> (),
    __index: (self: Bimap<K,V>, key : K) -> V,
}

type BimapImpl<K,V> = {
    insert: (self: Bimap<K,V>,  k : K, v : V) -> (),
    delete: (self: Bimap<K,V>, key : K) -> (),
    lookup: (self: Bimap<K,V>, key : K) -> V,
    lookupR: (self: Bimap<K,V>, value : V) -> K,
    insertMany: (self: Bimap<K,V>,  {[K] : V}) -> (),
} & BimapMT<K,V>


export type Bimap<K,V> = typeof(setmetatable({} :: BimapData<K,V>, {} :: BimapImpl<K,V>))


--local Bimap: BimapImpl<any,any> = {} :: BimapImpl<any,any>

local bimapImpl = {
  delete = function(self : Bimap<any, any>, k : any)
    local v = self.forwardMap[k]
    assert(v ~= nil, "Bimap does not contain key " .. tostring(k))
    assert(self.backwardMap[v] ~= nil, "Bimap does not contain value " .. tostring(v))
    self.forwardMap[k] = nil
    self.backwardMap[v] = nil
  end,

  insert = function(self: Bimap<any,any>, k : any, v : any)
    if v == nil then
      self:delete(k)
      return
    end
    assert(self.backwardMap[v] == nil, "Bimap already contains value " .. tostring(v))
    local oldv = self.forwardMap[k]
    if oldv ~= nil then
      self.backwardMap[oldv] = nil
    end
    self.forwardMap[k] = v
    self.backwardMap[v] = k
  end,


  lookup = function(self: Bimap<any,any>, k : any)
    return self.forwardMap[k]
  end,

  lookupR = function(self : Bimap<any, any>, v : any)
    return self.backwardMap[v]
  end,

  insertMany = function(self : Bimap<any, any>, t : any)
    for k, v in pairs(t) do
      self:insert(k, v)
    end
  end,


  __newindex = function(self : Bimap<any, any>, key : any, value : any)
      self:insert(key, value)
  end,
  __index = function(self : Bimap<any, any>, key : any) : any
      return self:lookup(key)
  end
}
setmetatable(bimapImpl, bimapImpl)



local fakector = {}
function fakector.new<K,V>() : Bimap<K,V>
    local r : BimapData<K,V> = {
      forwardMap = {} :: {[K] : V},
      backwardMap = {} :: {[V] : K},
    }
    setmetatable(r, bimapImpl)
    return r
end
return fakector

