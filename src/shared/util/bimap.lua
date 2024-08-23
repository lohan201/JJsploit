--!strict
-- bimap implementation in Lua
-- this version allocates functions for each instance :(

type Bimap_<K,V> = {
    
    insert: (self: Bimap<K,V>,  k : K, v : V) -> (),
    delete: (self: Bimap<K,V>, key : K) -> (),
    lookup: (self: Bimap<K,V>, key : K) -> V,
    lookupR: (self: Bimap<K,V>, value : V) -> K,
    insertMany: (self: Bimap<K,V>,  {[K] : V}) -> (),

    forwardMap : {[K] : V},
    backwardMap : { [V] : K},
}

type BimapMT<K,V> = {
    __newindex: (self: Bimap<K,V>, key : K, value : V) -> (),
    __index: (self: Bimap<K,V>, key : K) -> V,
}

export type Bimap<K,V> = typeof(setmetatable({} :: Bimap_<K,V>, {} :: BimapMT<K,V>))


--[[
local bimapMTAny = {
    __newindex = function(self : Bimap<any, any>, key : any, value : any)
        self:insert(key, value)
    end,
    __index = function(self : Bimap<any, any>, key : any) : any
        return self:lookup(key)
    end
}]]

-- we use the factory pattern due to the generic types
-- we could probably also do this with the prototype pattern by using the generic `any` type
local function makeBimap<K,V>() : Bimap<K,V>

    -- ctor stuff
    local bimap = {}
    bimap.forwardMap = {}
    bimap.backwardMap = {}

    bimap.delete = function(self, k)
      local v = self.forwardMap[k]
      assert(v ~= nil, "Bimap does not contain key " .. tostring(k))
      assert(self.backwardMap[v] ~= nil, "Bimap does not contain value " .. tostring(v))
      self.forwardMap[k] = nil
      self.backwardMap[v] = nil
    end

    bimap.insert = function(self, k, v)
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
    end


    bimap.lookup = function(self, k)
      return self.forwardMap[k]
    end

    bimap.lookupR = function(self, v)
      return self.backwardMap[v]
    end

    bimap.insertMany = function(self, t)
      for k, v in pairs(t) do
        self:insert(k, v)
      end
    end

    local bimapMT : BimapMT<K,V> = {
        __newindex = function(self : Bimap<K,V>, key : K, value : V)
            self:insert(key, value)
        end,
        __index = function(self : Bimap<K,V>, key : K) : V
            return self:lookup(key)
        end
    }
    setmetatable(bimap, bimapMT)

    return bimap
end

local fakector = {}
fakector.new = function()
    return makeBimap()
end
return fakector

