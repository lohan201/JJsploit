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



export type MockGameState = {
    frame : Frame,
    state : string,
}

function MockGameState_new() : MockGameState
    local r = {
        frame = frameInit,
        state = "",
    }
    return r
end

-- a mock game, input is just a string with letters only! 
export type MockGame = {
    manager : MockUDPEndpointManager<string>,
    players : { [PlayerHandle] : {ggpo : GGPO_Peer<string, string, ()>, state : MockGameState} },
        spectators : { [number] : {ggpo : GGPO_Spectator<string, string, ()>, state : MockGameState} },
}

function MockGame_new(numPlayers : number, isCars : boolean) : MockGame

    local config = defaultGameConfig
    local manager = MockUDPEndpointManager_new()
    local players = {}
    local playersIndices = {}
    for i = 0, numPlayers-1, 1 do
        playersIndices[i] = i
    end
    if isCars then
        playersIndices[carsHandle] = carsHandle
    end

    for i,_ in pairs(playersIndices) do
        local endpoint = MockUDPEndpointManager_AddUDPEndpoint(manager)
        local ggporef = nil
        local stateref = MockGameState_new()
        local callbacks = {
            SaveGameState = function(frame) 
                assert(frame == playerState.frame)
                return playerState.state
            end,
            LoadGameState = function(state, frame) 
                playerState.state = state
                playerState.frame = frame
            end,
            AdvanceFrame = function()
                local pinputs = GGPO_Peer_SynchronizeInput<T,I,J>(ggporef, stateref.frame)
                table.sort(pinputs)
                stateref.state = stateref.state + tostring(stateref.frame) + ":"
                for p, input in pairs(pinputs) do
                    stateref.state = stateref.state + tostring(p) + "&" + input
                end
                stateref.state += stateref.state + "@"
                stateref.frame += 1
            end,
            OnPeerEvent = function(event, player) end,
            OnSpectatorEvent = function(event, spectator) end,
        }  
        ggporef = GGPO_Peer_new(config, callbacks, i)
        players[i] = {
            ggpo = ggporef,
            state = stateref,
        }
    end

    if isCars then
        -- create CARS network
        assert(players[carsHandle] ~= nil)
        for i = 0, numPlayers-1, 1 do
            GGPO_Peer_AddPeer(players[i].ggpo, carsHandle, MockUDPEndpointManager_AddUDPEndpoint(manager)
            GGPO_Peer_AddPeer(players[carsHandle].ggpo, i, MockUDPEndpointManager_AddUDPEndpoint(manager))
        end
    else
        -- create P2P network
        for i = 0, numPlayers-1, 1 do
            for j = 0, numPlayers-1, 1 do
                GGPO_Peer_AddPeer(players[i].ggpo, j, MockUDPEndpointManager_AddUDPEndpoint(manager))
            end
        end
    end

    local r = {
        manager = manager,
        players = players,    
        spectators = {},
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