--!strict
-- Queue implementation in Lua
-- more efficient than table.insert/remove which reindexes the table
-- this version allocates functions for each instance :(

type QueueImpl<T> = {
    enqueue: (self: Queue<T>, x: T) -> (),
    dequeue: (self: Queue<T>) -> T?,

    queue : {[number] : T},
    startIndex: number,
    endIndex: number,
}

export type Queue<T> = typeof(setmetatable({} :: { startIndex: number, endIndex: number, queue : {[number]: T} }, {} :: QueueImpl<T>))

-- Only these two annotations are necessary
--local Queue: QueueImpl<any> = {} :: QueueImpl<any>
--Queue.__index = Queue


-- we use the factory pattern in order to pass in the generic type
-- the prototype pattern won't allow us to do this
local function makeQueue<T>() : Queue<T>

    -- TODO delete, this is unecessary if you do the factory pattern
    -- setup the metatable
    -- note, this will create a new "prototype" for each call, which is NBD 
    local Queue: QueueImpl<T> = {} :: QueueImpl<T>
    --Queue.__index = Queue

    -- ctor stuff
    local queue = {}
    queue.startIndex = 0
    queue.endIndex = 0
    queue.queue = {}
    setmetatable(queue, Queue)

    queue.enqueue = function(self : Queue<T>, x : T)
        self.queue[self.endIndex] = x
        self.endIndex += 1
    end

    queue.dequeue = function(self : Queue<T>) : T?
        if self.startIndex == self.endIndex then
            return nil
        end
        local out = self.queue[self.startIndex]
        table.remove(self.queue, self.startIndex)
        self.startIndex += 1
        return out
    end

    return queue
end

local fakector = {}
fakector.new = function()
    return makeQueue()
end
return fakector

