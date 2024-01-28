local GGPO = require(script.Parent.ggpo)


-- simple deep copy, does not handle metatables or recursive tables!!
function deep_copy_simple(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do res[deep_copy_simple(k)] = deep_copy_simple(v) end
    return res
end

function deep_copy(obj : any, seen : ({ [any]: {} })?)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
  
    -- New table; mark it as seen and copy recursively.
    local s = seen or ({} :: { [any]: {} })
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[deep_copy(k, s)] = deep_copy(v, s) end
    return setmetatable(res, getmetatable(obj))
end


export type MockUDPEndpointStuff<I> = {
    --configuration
    delayMin : number,
    delayMax : number,
    dropRate : number,

    -- actual data
    -- key is when to send in epochMs
    msgQueue : { [number] : UDPMsg<I> },
    subscriber : ((UDPMsg<I>) -> ())?,

    -- for debuggng, may not always be set
    sender : PlayerHandle,
    receiver : PlayerHandle,
}

function tprint(s : string) 
    print(s)
    --print(debug.traceback())
end

function MockUDPEndointStuff_new<I>() : MockUDPEndpointStuff<I>
    local r = {
        delayMin = 1,
        delayMax = 2,
        dropRate = 0,
        msgQueue = {},
        subscriber = nil,
        sender = GGPO.nullHandle,
        receiver = GGPO.nullHandle,
    }
    return r
end


export type MockUDPEndpointManager<I> = {
    -- TODO maybe don't manage this here because yo ucan't get the player mappings, combine with MockGame
    endpoints : {[number] : UDPEndpoint<I> },
    time : number,
}

function MockUDPEndpointManager_new<I>() : MockUDPEndpointManager<I>
    local r = {
        endpoints = {},
        time = -1,
    }
    return r
end

function MockUDPEndpointManager_SetTime<I>(manager : MockUDPEndpointManager<I>, time : number?)
  if time == nil then
    time = GGPO.now()
  end

  if manager.time > time then
    error("mock time must be monotonic")
  end
  manager.time = time
end

function MockUDPEndpointManager_PollUDP<I>(manager : MockUDPEndpointManager<I>)
    --print("going through endpoints " .. tostring(#manager.endpoints))
    for _, stuff in pairs(manager.endpoints) do
        --print("endpoint " .. tostring(endpoint) .. " stuff " .. tostring(stuff))
        for t, msgs in stuff.msgQueue do
            if t <= manager.time then
                assert(stuff.subscriber ~= nil, "expected subscriber")
                if stuff.subscriber ~= nil then
                    for _, msg in pairs(msgs) do
                        stuff.subscriber(msg, stuff.sender)
                    end
                end
                stuff.msgQueue[t] = nil
            end
        end
    end
end

-- TODO just replace with table.insert
function array_append<T>(t : {[number] : T}, value : T)
    table.insert(t, value)
end



local function makeSendFn<I>(manager : MockUDPEndpointManager<I>, endpointStuff : MockUDPEndpointStuff<I>) : (UDPMsg<I>) -> ()
    return function(msg : UDPMsg<I>)
        local delay = endpointStuff.delayMin + math.random() * (endpointStuff.delayMax - endpointStuff.delayMin)
        local epochMs = manager.time + math.floor(delay)
        if endpointStuff.msgQueue[epochMs] == nil then
            endpointStuff.msgQueue[epochMs] = {}
        end
        array_append(endpointStuff.msgQueue[epochMs], deep_copy_simple(msg))
    end
end

-- creates a pair of endpoints that are connected to each other and adds them to the manager
local function MockUDPEndpointManager_AddPairedUDPEndpoints<I>(manager : MockUDPEndpointManager<I>) : { A: UDPEndpoint<I>, B: UDPEndpoint<I> }

    local endpointStuffA = MockUDPEndointStuff_new()
    local endpointStuffB = MockUDPEndointStuff_new()
    local rA = {
        send = makeSendFn(manager, endpointStuffA),
        subscribe = function(f) 
            -- subscribe to send events in rB
            endpointStuffB.subscriber = f
        end,
        stuff = endpointStuffA,
    }
    
    local rB = {
        send = makeSendFn(manager, endpointStuffB),
        subscribe = function(f) 
            -- subscribe to send events in rA
            endpointStuffA.subscriber = f
        end,
        stuff = endpointStuffB,
    }

    array_append(manager.endpoints, endpointStuffA)
    array_append(manager.endpoints, endpointStuffB)
    return {A = rA, B = rB}
end



export type MockGameState = {
    frame : Frame,
    state : string,
}

function MockGameState_new() : MockGameState
    local r = {
        frame = GGPO.frameInit,
        state = "\n",
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
    for i = 1, numPlayers, 1 do
        playersIndices[i] = i
    end
    if isCars then
        playersIndices[GGPO.carsHandle] = GGPO.carsHandle
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
                -- NOTE that inputs from frame n get added to the state for frame n+1
                --print(string.format("advancing frame %d for player %d", stateref.frame, i))
                stateref.state = stateref.state .. tostring(stateref.frame) .. ":\n"
                local pinputs = GGPO.GGPO_Peer_SynchronizeInput(ggporef, stateref.frame)
                for _,p in ipairs(playersIndices) do
                    assert(pinputs[p] ~= nil or stateref.frame == 0, string.format("expected input for player %d after frame 0", p))
                    if pinputs[p] ~= nil then
                        -- TODO also note pinputs[p].input could be nil, you need to handle that
                        stateref.state = stateref.state .. "  " .. tostring(p) .. ":" .. pinputs[p].input .. "\n"
                    end
                end
                stateref.state = stateref.state .. "\n"
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
        assert(players[GGPO.carsHandle] ~= nil)
        for i = 1, numPlayers, 1 do
            local pairedeps = MockUDPEndpointManager_AddPairedUDPEndpoints(manager)
            pairedeps.A.stuff.sender = GGPO.carsHandle
            pairedeps.A.stuff.receiver = i
            array_append(players[GGPO.carsHandle].endpoints, pairedeps.A)
            GGPO.GGPO_Peer_AddPeer(players[i].ggpo, GGPO.carsHandle, pairedeps.A)
            pairedeps.B.stuff.sender = i
            pairedeps.B.stuff.receiver = GGPO.carsHandle
            array_append(players[i].endpoints, pairedeps.B)
            GGPO.GGPO_Peer_AddPeer(players[GGPO.carsHandle].ggpo, i, pairedeps.B)
        end
    else
        -- create P2P network
        for i = 1, numPlayers, 1 do
            for j = i+1, numPlayers, 1 do
                print("CONNECTING PLAYERS " .. tostring(i) .. " AND " .. tostring(j))
                local pairedeps = MockUDPEndpointManager_AddPairedUDPEndpoints(manager)
                pairedeps.A.stuff.sender = i
                pairedeps.A.stuff.receiver = j
                array_append(players[i].endpoints, pairedeps.A)
                GGPO.GGPO_Peer_AddPeer(players[i].ggpo, j, pairedeps.A)
                pairedeps.B.stuff.sender = j
                pairedeps.B.stuff.receiver = i
                array_append(players[j].endpoints, pairedeps.B)
                GGPO.GGPO_Peer_AddPeer(players[j].ggpo, i, pairedeps.B)
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
function MockGame_Poll(mockGame : MockGame, totalMs : number, min : number, max : number)
    local acc = 0
    while acc < totalMs do
        local delay = min + math.random() * (max - min)
        acc = math.floor(acc + delay)
        if acc > totalMs then
            acc = totalMs
        end 
        -- TODO allow per player random updating...
        MockUDPEndpointManager_SetTime(mockGame.manager, mockGame.manager.time + acc)
        MockUDPEndpointManager_PollUDP(mockGame.manager)
    end

    -- NOTE that the time inside ggpo will not match the mocked time above
    for i, player in pairs(mockGame.players) do
        GGPO.GGPO_Peer_DoPoll(player.ggpo)
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

function MockGame_AdvanceFrame(mockGame : MockGame)
    for i, player in pairs(mockGame.players) do
        player.ggpo.callbacks.AdvanceFrame()
        -- TODO call this inside of the AdvanceFrame function above to be more consistent with GGPO API usage 
        GGPO.GGPO_Peer_AdvanceFrame(player.ggpo)
    end
end

function MockGame_IsStateSynchronized(mockGame : MockGame)
    
    local last_confirmed_frame = GGPO.frameMax
    for i, player in pairs(mockGame.players) do
        last_confirmed_frame = math.min(last_confirmed_frame, player.ggpo.sync.last_confirmed_frame)
    end

    print("MockGame_IsStateSynchronized: last confirmed frame: " .. tostring(last_confirmed_frame))

    playerStates = {}
    for i, player in pairs(mockGame.players) do
        playerStates[i] = player.ggpo.sync.savedstate[last_confirmed_frame]

        print("MockGame_IsStateSynchronized: saved state for player: " .. tostring(i) .. " state: " .. tostring(playerStates[i].state))
    end

    -- TODO this can be better lol
    for player, state in pairs(playerStates) do
        for otherPlayer, otherState in pairs(playerStates) do
            if state ~= otherState then
                return false
            end
        end
    end

    return true
end




return function()
    --[[
    describe("table helpers", function()
        it("isempty", function()
            expect(GGPO.isempty({})).to.equal(true)
            expect(GGPO.isempty({1})).to.equal(false)
            expect(GGPO.isempty({1,2})).to.equal(false)
        end)
        it("tablecount", function()
            expect(GGPO.tablecount({})).to.equal(0)
            expect(GGPO.tablecount({1})).to.equal(1)
            expect(GGPO.tablecount({1,2})).to.equal(2)
        end)
    end)
    describe("FrameInputMap", function()
        it("FrameInputMap_firstFrame/lastFrame", function()
            local msg = {}
            expect(GGPO.FrameInputMap_lastFrame(msg)).to.equal(GGPO.frameNull)
            expect(GGPO.FrameInputMap_firstFrame(msg)).to.equal(GGPO.frameNull)
            msg[1] = GGPO.GameInput_new(1, "a")
            expect(GGPO.FrameInputMap_lastFrame(msg)).to.equal(1)
            expect(GGPO.FrameInputMap_firstFrame(msg)).to.equal(1)
            msg[2] = GGPO.GameInput_new(2, "b")
            expect(GGPO.FrameInputMap_lastFrame(msg)).to.equal(2)
            expect(GGPO.FrameInputMap_firstFrame(msg)).to.equal(1)
            msg[0] = GGPO.GameInput_new(0, "c")
            expect(GGPO.FrameInputMap_lastFrame(msg)).to.equal(2)
            expect(GGPO.FrameInputMap_firstFrame(msg)).to.equal(0)
        end)
    end)

    describe("UDPProto", function()
        it("UDPProto_ClearInputsBefore", function()
            local udpproto = GGPO.UDPProto_new(0, false, GGPO.uselessUDPEndpoint)
            udpproto.playerData[1] = GGPO.UDPProto_Player_new()
            udpproto.playerData[1].pending_output[0] = GGPO.GameInput_new(0, "a")
            udpproto.playerData[1].pending_output[1] = GGPO.GameInput_new(1, "b")
            udpproto.playerData[1].pending_output[2] = GGPO.GameInput_new(2, "c")
            udpproto.playerData[1].pending_output[3] = GGPO.GameInput_new(3, "meow")
            GGPO.UDPProto_ClearInputsBefore(udpproto, 0)
            expect(GGPO.tablecount(udpproto.playerData[1].pending_output)).to.equal(3)
            expect(udpproto.playerData[1].pending_output[0]).to.equal(nil)
            GGPO.UDPProto_ClearInputsBefore(udpproto, 0)
            expect(GGPO.tablecount(udpproto.playerData[1].pending_output)).to.equal(3)
            GGPO.UDPProto_ClearInputsBefore(udpproto, 2)
            expect(GGPO.tablecount(udpproto.playerData[1].pending_output)).to.equal(1)
            GGPO.UDPProto_ClearInputsBefore(udpproto, 3)
            expect(GGPO.isempty(udpproto.playerData[1].pending_output))
        end)
    end)

    describe("basic", function()
        it("p2p basic", function()
            local manager = MockUDPEndpointManager_new()
            -- p1's endpoint to talk to p2
            local endpoints = MockUDPEndpointManager_AddPairedUDPEndpoints(manager)

            local config = GGPO.defaultGameConfig

            local callbacks = {
                SaveGameState = function(frame) end,
                LoadGameState = function(state, frame) end,
                AdvanceFrame = function() end,
                OnPeerEvent = function(event, player) end,
                OnSpectatorEvent = function(event, spectator) end,
            }

            local p1 = GGPO.GGPO_Peer_new(config, callbacks, 1)
            endpoints.A.stuff.sender = 1
            endpoints.A.stuff.receiver = 2
            GGPO.GGPO_Peer_AddPeer(p1, 2, endpoints.A)
            local p2 = GGPO.GGPO_Peer_new(config, callbacks, 2)
            endpoints.B.stuff.sender = 2
            endpoints.B.stuff.receiver = 1
            GGPO.GGPO_Peer_AddPeer(p2, 1, endpoints.B)

            -- TODO
        end)
    end)
    ]]--
    describe("MockGame", function()
        it("2 player p2p", function()
            print("initializing mock p2p game with 2 players)")
            local game = MockGame_new(2, false)
            for i = 0, 3, 1 do
                

                print("SENDING RANDOM INPUTS ON FRAME " .. tostring(i))
                for j = 1, 2, 1 do
                    MockGame_PressRandomButtons(game, j)
                end

                print("ADVANCING FROM FRAME " .. tostring(i))
                MockGame_AdvanceFrame(game)
                
                print("BEGIN FRAME " .. tostring(i+1))

                print("POLLING FOR FRAME " .. tostring(i+1))
                MockGame_Poll(game, 100, 10, 20)
                
                print("CHECKING FOR SYNCHRONIZATION")
                expect(MockGame_IsStateSynchronized(game))
            end

        end)
    end)
end