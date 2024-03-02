--!strict
-- Queue implementation in Lua
-- more efficient than table.insert/delete which reindexes the table

type BimapImpl<K,V> = {
    
    insert: (self: Bimap<K,V>,  k : K, v : V) -> (),
    delete: (self: Bimap<K,V>, key : K) -> (),
    lookup: (self: Bimap<K,V>, key : K) -> V,
    lookupR: (self: Bimap<K,V>, value : V) -> K,
    insertMany: (self: Bimap<K,V>,  {[K] : V}) -> (),

    __newindex: (self: Bimap<K,V>, key : K, value : V) -> (),
    __index: (self: Bimap<K,V>, key : K) -> V,
    

    forwardMap : {[K] : V},
    backwardMap : { [V] : K},
}

export type Bimap<K,V> = typeof(setmetatable({} :: { forwardMap : {[K] : V}, backwardMap : { [V] : K}, }, {} :: BimapImpl<K,V>))

-- we use the factory pattern in order to pass in the generic type
-- the prototype pattern won't allow us to do this
local function makeBimap<K,V>() : Bimap<K,V>

    -- TODO I think the whole way your doing classes here might be more complicated than it needs to be...
    -- setup the metatable
    -- note, this will create a new "prototype" for each call, which is NBD 
    local Bimap: BimapImpl<K,V> = {} :: BimapImpl<K,V>
    

    -- ctor stuff
    local bimap = {}
    bimap.forwardMap = {}
    bimap.backwardMap = {}
    setmetatable(bimap, Bimap)

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

    -- is this right?
    Bimap.__index = bimap.lookup 
    Bimap.__newindex = bimap.insert

    return bimap
end

local fakector = {}
fakector.new = function()
    return makeBimap()
end
return fakector

