require(script.Parent.ggpo)

-- TESTING STUFF

export type MockUDPEndpointStuff<I> = {
    --configuration
    delayMin : number,
    delayMax : number,
    dropRate : number,

    -- actual data
    -- key is when to send in epochMs
    msgQueue : { [number] : UDPMsg<I> },
    subscribers : { [number] : (UDPMsg<I>) -> () },
}

function MockUDPEndointStuff_new<I>() : MockUDPEndpointStuff<I>
    local r = {
        delayMin = 100,
        delayMax = 200,
        dropRate = 0,
        msgQueue = {},
        subscribers = {},
    }
    return r
end


export type MockUDPEndpointManager<I> = {
    endpoints : {[UDPEndpoint<I>] : MockUDPEndpointStuff<I> },
    time : number?,
}

function MockUDPEndpointManager_new<I>() : MockUDPEndpointManager<I>
    local r = {
        endpoints = {},
        time = nil,
    }
    return r
end

function MockUDPEndpointManager_SetTime<I>(manager : MockUDPEndpointManager<I>, time : number?)
  if time == nil then
    time = now()
  end

  if manager.time and manager.time > time then
    error("mock time must be monotonic")
  end
  manager.time = time
end

function MockUDPEndpointManager_Update<I>(manager : MockUDPEndpointManager<I>)

    for endpoint, stuff in pairs(manager.endpoints) do
        for t, msg in stuff.msgQueue do
            if t <= time then
                endpoint.send(msg)
                stuff.msgQueue[t] = nil
            end
        end
    end
end

function MockUDPEndpointManager_AddUDPEndpoint<I>(manager : MockUDPEndpointManager<I>) : UDPEndpoint<I>
    local endpointStuff = MockUDPEndointStuff_new()
    local r = {
        send = function(msg)
            local delay = endpointStuff.delayMin + math.random() * (endpointStuff.delayMax - endpointStuff.delayMin)
            local epochMs = now() + math.floor(delay)
            endpointStuff.msgQueue[epochMs] = msg
            table.sort(endpointStuff)
        end,
        subscribe = function(f)
            local id = #endpointStuff.subscribers + 1
            endpointStuff.subscribers[id] = f
        end,
    }
    return r
end




return function()
    describe("setup", function()
        it("p2p basic", function()
            local manager = MockUDPEndpointManager_new()
            -- p1's endpoint to talk to p2
            local endpointp1_p2 = MockUDPEndpointManager_AddUDPEndpoint(manager)
            local endpointp2_p1 = MockUDPEndpointManager_AddUDPEndpoint(manager)

            local config = defaultGameConfig

            local callbacks = {
                SaveGameState = function(frame) end,
                LoadGameState = function(state, frame) end,
                AdvanceFrame = function() end,
                OnPeerEvent = function(event, player) end,
                OnSpectatorEvent = function(event, spectator) end,
            }

            local p1 = GGPO_Peer_new(gameConfig, callbacks, 1)
            GGPO_Peer_AddPeer(p1, 2, endpointp1_p2)
            local p2 = GGPO_Peer_new(gameConfig, callbacks, 2)
            GGPO_Peer_AddPeer(p2, 1, endpointp1_p1)

            -- TODO
        end)
    end)
end