local GGPO = require(script.Parent.ggpo)

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
        frame = GGPO.frameInit,
        state = "",
    }
    return r
end

-- a mock game, input is just a string with letters only! 
export type MockGame = {
    manager : MockUDPEndpointManager<string>,
    players : { [PlayerHandle] : {ggpo : GGPO_Peer<string, string, ()>, state : MockGameState, endpoints : {[number] : MockUDPEndpointManager<string>} } },
    -- TODO
    --spectators : { [number] : {ggpo : GGPO_Spectator<string, string, ()>, state : MockGameState, endpoints : {[number] : MockUDPEndpointManager<string>} } },
}

function MockGame_new(numPlayers : number, isCars : boolean) : MockGame

    local config = GGPO.defaultGameConfig
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
        local ggporef = nil
        local stateref = MockGameState_new()
        local callbacks = {
            SaveGameState = function(frame) 
                assert(frame == stateref.frame, string.format("expected frame %d, got %d", frame, stateref.frame))
                return stateref.state
            end,
            LoadGameState = function(state, frame) 
                stateref.state = state
                stateref.frame = frame
            end,
            AdvanceFrame = function()
                local pinputs = GGPO.GGPO_Peer_SynchronizeInput(ggporef, stateref.frame)
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
        ggporef = GGPO.GGPO_Peer_new(config, callbacks, i)
        players[i] = {
            ggpo = ggporef,
            state = stateref,
            endpoints = {}
        }
    end

    if isCars then
        -- create CARS network
        assert(players[carsHandle] ~= nil)
        for i = 0, numPlayers-1, 1 do
            local epcp = MockUDPEndpointManager_AddUDPEndpoint(manager)
            players[carsHandle].endpoints[#players[carsHandle].endpoints] = epcp
            GGPO.GGPO_Peer_AddPeer(players[i].ggpo, carsHandle, epcp)
            local eppc = MockUDPEndpointManager_AddUDPEndpoint(manager)
            players[i].endpoints[#players[i].endpoints] = eppc
            GGPO.GGPO_Peer_AddPeer(players[carsHandle].ggpo, i, eppc)
        end
    else
        -- create P2P network
        for i = 0, numPlayers-1, 1 do
            for j = 0, numPlayers-1, 1 do
                local eppp = MockUDPEndpointManager_AddUDPEndpoint(manager)
                players[i].endpoints[#players[i].endpoints] = eppp
                GGPO.GGPO_Peer_AddPeer(players[i].ggpo, j, eppp)
            end
        end
    end

    local r = {
        manager = manager,
        players = players,    
        --spectators = {},
    }
    return r
end

-- update the game for totalMs at random intervals between min and max ms
function MockGame_UpdatePlayer(mockGame : MockGame, player : PlayerHandle, totalMs : number, min : number, max : number)
    local acc = 0
    while acc < totalMs do
        local delay = min + math.random() * (max - min)
        acc = math.floor(acc + delay)
        if acc > totalMs then
            acc = totalMs
        end 
        local endpoints = mockGame.players[player].endpoints
        for _, endpoint in pairs(endpoints) do
            MockUDPEndpointManager_SetTime(endpoint, mockGame.manager.time + acc)
            MockUDPEndpointManager_Update(endpoint)
        end
    end
end

function MockGame_UpdateAllPlayers(mockGame : MockGame, totalMs : number, min : number, max : number)
    for i, _ in pairs(mockGame.players) do
        MockGame_UpdatePlayer(mockGame, i, totalMs, min, max)
    end
end

function MockGame_PressRandomButtons(mockGame : MockGame, player : PlayerHandle)
    local randomlowercase = function()
        return string.char(math.random(65, 65 + 25)):lower()
    end
    local inputs = ""
    for i = 1, math.random(0,7), 1 do
        inputs = inputs .. randomlowercase()
    end
    local ggpoinput = GGPO.GameInput_new(mockGame.players[player].state.frame, inputs)
    GGPO.GGPO_Peer_AddLocalInput(mockGame.players[player].ggpo, ggpoinput)
end

function MockGame_IsStateSynchronized(mockGame : MockGame)
    
    local last_confirmed_frame = GGPO.frameMax
    for i, player in pairs(mockGame.players) do
        last_confirmed_frame = math.min(last_confirmed_frame, player.ggpo.sync.last_confirmed_frame)
    end

    playerStates = {}
    for i, player in pairs(mockGame.players) do
        playerStates[i] = player.ggpo.sync.savedstate[last_confirmed_frame]
    end

    -- TODO this can be better lol
    for player, state in pairs(playerStates) do
        for otherPlayer, otherState in pairs(playerStates) do
            if player ~= otherPlayer then
                return false
            end
        end
    end

    return true
end

return function()
    describe("basic", function()
        it("p2p basic", function()
            local manager = MockUDPEndpointManager_new()
            -- p1's endpoint to talk to p2
            local endpointp1_p2 = MockUDPEndpointManager_AddUDPEndpoint(manager)
            local endpointp2_p1 = MockUDPEndpointManager_AddUDPEndpoint(manager)

            local config = GGPO.defaultGameConfig

            local callbacks = {
                SaveGameState = function(frame) end,
                LoadGameState = function(state, frame) end,
                AdvanceFrame = function() end,
                OnPeerEvent = function(event, player) end,
                OnSpectatorEvent = function(event, spectator) end,
            }

            local p1 = GGPO.GGPO_Peer_new(config, callbacks, 1)
            GGPO.GGPO_Peer_AddPeer(p1, 2, endpointp1_p2)
            local p2 = GGPO.GGPO_Peer_new(config, callbacks, 2)
            GGPO.GGPO_Peer_AddPeer(p2, 1, endpointp2_p1)

            -- TODO
        end)
    end)

    describe("MockGame", function()
        it("2 player p2p", function()
            local game = MockGame_new(2, false)
            for i = 1, 1000, 1 do
                for j = 0, 1, 1 do
                    MockGame_PressRandomButtons(game, j)
                end
                MockGame_UpdateAllPlayers(game, 100, 10, 20)

                -- TODO check that all states are compatible
                expect(MockGame_IsStateSynchronized(game))
            end

        end)
    end)
end