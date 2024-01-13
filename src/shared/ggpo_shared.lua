--!strict
local Queue = require(script.Parent.util.queue)

export type TimeMS = number

-- helpers
local function now() : TimeMS
    return DateTime.now().UnixTimestampMillis
end

local function Log(s, ...)
    return print(s:format(...))
end




-- CONSTANTS
local serverHandle = 99999999999
-- TODO negative frames used for synchronizing start times maybe
local frameInit = 0
local frameStart = 0
local frameNull = -999999999999
local frameMax = 9999999999999
local frameMin = frameNull+1 -- just so we can distinguish between null and min



-- TYPES
export type Frame = number
export type GGPOPlayerHandle = number

export type GameConfig = {
    numPlayers: number,
    inputDelay: number
}

export type GameInput<I> = {
    -- TODO remove this, not needed
    -- the destination frame of this input
    frame: Frame,

    -- set to whatever type best represents your game input. Keep this object small! Maybe use a buffer! https://devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894
    -- nil represents no input? (i.e. AddLocalInput was never called)
    input: I?
}
export type FrameInputMap<I> = {[Frame] : GameInput<I>}

function FrameInputMap_lastFrame<I>(msg : FrameInputMap<I>) : Frame
    if #msg == 0 then
        return frameNull
    end

    local lastFrame = frameMin
    for frame, input in pairs(msg) do
        if frame > lastFrame then
            lastFrame = frame
        end
    end
    return lastFrame
end

function FrameInputMap_firstFrame<I>(msg : FrameInputMap<I>) : Frame
    if #msg == 0 then
        return frameNull
    end

    local firstFrame = frameMax
    for frame, input in pairs(msg) do
        if frame < firstFrame then
            firstFrame = frame
        end
    end
    return firstFrame
end

export type PlayerInputMap<I> = {[GGPOPlayerHandle] : GameInput<I>}

export type PlayerFrameInputMap<I> = {[GGPOPlayerHandle] : FrameInputMap<I>}

function PlayerFrameInputMap_firstFrame<I>(msg : PlayerFrameInputMap<I>) : Frame
    if #msg == 0 then
        return frameNull
    end

    local firstFrame = frameMax
    for player, data in pairs(msg) do
        local f = FrameInputMap_firstFrame(data)
        if f < firstFrame then
            firstFrame = f
        end
    end
    return firstFrame
end

function PlayerFrameInputMap_addInputs<I>(a : PlayerFrameInputMap<I>, b : PlayerFrameInputMap<I>)
    for player, frameData in pairs(b) do
        for frame, input in pairs(frameData) do
            -- TODO assert inputs are equal if present in a
            --if table.contains(a, player) and table.contains(a[player][frame]) and a[player][frame] ~= a[player][frame] then 
            a[player][frame] = input
        end
end







-- GGPOEvent types
export type GGPOEvent_synchronized = {
    player: GGPOPlayerHandle,
}
export type GGPOEvent_Input<I> = PlayerFrameInputMap<I>
export type GGPOEvent_interrupted = nil
export type GGPOEvent_resumed = nil
-- can we also embed this in the input, perhaps as a serverHandle input
export type GGPOEvent_disconnected = {
    player: GGPOPlayerHandle,
}
export type GGPOEvent<I> = GGPOEvent_synchronized | GGPOEvent_Input<I> | GGPOEvent_interrupted | GGPOEvent_resumed | GGPOEvent_disconnected
  

export type UDPEndpoint<I> = {
    send: (UDPMsg<I>) -> (),
    subscribe: ((UDPMsg<I>)->()) -> (),
}

local uselessUDPEndpoint : UDPEndpoint<any> = {
    send = function(msg) end,
    subscribe = function(cb) end
}

export type PlayerProxyInfo<I> = {
    peer: GGPOPlayerHandle,
    -- which players are represented by this proxy
    -- in a fully connected P2P case this will be empty
    -- in when connecting to a routing server, this will be all players 
    proxy: {[number]: GGPOPlayerHandle},
    endpoint: UDPEndpoint<I>,

    -- TODO figure out best time to transmit this data? maybe a reliable explicit game start packet? or just transmit as frame 0 data? it's weird cuz you can't really forward simulate if you're stuck on frame 0 waiting for data, but maybe just wait is OK, or maybe use first 10 frames to sync and adjust rift etc
    -- use this to pass in deterministic per-player capabilities
    --data: G,
}




export type GGPONetworkStats = {
    max_send_queue_len : number,
    ping : number,
    kbps_sent : number,
    local_frames_behind : number,
    remote_frames_behind : number,
}

export type GGPOCallbacks<T,I> = {
    SaveGameState: (frame: number) -> T,
    LoadGameState: (T, frame: number) -> (),
    AdvanceFrame: () -> (),
    OnEvent: (event: GGPOEvent<I>) -> (),
    DisconnectPlayer: (GGPOPlayerHandle) -> ()
}


-- DONE UNTESTED
export type InputQueue<I> = {
    player : GGPOPlayerHandle,
    first_frame : boolean,

    last_user_added_frame : number,
    last_added_frame : number,
    first_incorrect_frame : number,
    last_frame_requested : number,

    frame_delay : number,

    inputs : FrameInputMap<I>,
}

function InputQueue_new<I>(player: GGPOPlayerHandle, frame_delay : number) : InputQueue<I>
    local r = {
        player = player,
        first_frame = true,

        last_user_added_frame = frameNull,
        last_added_frame = frameNull,
        first_incorrect_frame = frameNull,
        last_frame_requested = frameNull,

        frame_delay = frame_delay,

        inputs = {},
    }
    return r
end

function InputQueue_SetFrameDelay<I>(inputQueue : InputQueue<I>, delay : number)
    inputQueue.frame_delay = delay
end

function InputQueue_GetLastConfirmedFrame<I>(inputQueue : InputQueue<I>) : Frame
    return inputQueue.last_added_frame
end

function InputQueue_GetFirstIncorrectFrame<I>(inputQueue : InputQueue<I>) : Frame
    return inputQueue.first_incorrect_frame
end

-- cleanup confirmed frames, we will never roll back to these
function InputQueue_DiscardConfirmedFrames<I>(inputQueue : InputQueue<I>, frame : Frame)
    assert(frame >= 0)

    -- don't discard frames further back then we've last requested them :O
    if inputQueue.last_frame_requested ~= frameNull then
        frame = math.min(frame, inputQueue.last_frame_requested)
    end

    Log("discarding confirmed frames up to %d (last_added:%d).\n", frame, inputQueue.last_added_frame)

    local start = FrameInputMap_firstFrame(inputQueue.inputs)
    if start ~= frameNull and start <= frame then
        for i = start, frame, 1 do
            table.remove(inputQueue.inputs, i)
        end
    end
    
end


function InputQueue_GetConfirmedInput<I>(inputQueue : InputQueue<I>, frame : Frame) : GameInput<I>
    assert(inputQueue.first_incorrect_frame == frameNull or frame < inputQueue.first_incorrect_frame)
    local fd = inputQueue.inputs[frame]
    assert(fd, "expected frame %d to exist, this probably means the frame has not been confirmed for this player!", frame)
    return fd
end



function InputQueue_GetInput<I>(inputQueue : InputQueue<I>, frame : Frame) : GameInput<I>
    Log("requesting input frame %d.\n", frame);

    --[[
    No one should ever try to grab any input when we have a prediction
    error.  Doing so means that we're just going further down the wrong
    path.  ASSERT this to verify that it's true.
    ]]
    assert(inputQueue.first_incorrect_frame == GameInput::NullFrame);

    -- TODO prob don't need this
    inputQueue.last_frame_requested = frame;

    local fd = inputQueue.inputs[frame]
    if fd then
        return fd
    else
        local lastFrame = FrameInputMap_lastFrame(inputQueue.inputs)
        -- eventually we may drop this requirement and use a more complex prediction algorithm, in particular, we may have inputs from the future 
        assert(lastFrame < frame, "expected frame used for prediction to be less than requested frame")
        if lastFrame ~= frameNull then
            Log("basing new prediction frame from previously added frame (player:%d, frame:%d).", player, lastFrame)
            return inputQueue.inputs[lastFrame]
        else
            Log("basing new prediction frame from nothing, since we have no frames yet.");
            return { frame = frame, input = nil}
        end
        Log("requested frame %d not found in queue.\n", frame);
    end
end


-- advance the queue head to target frame and returns frame with delay applied
function InputQueue_AdvanceQueueHead<I>(inputQueue : InputQueue<I>, frame : Frame) : Frame
    Log("advancing queue head to frame %d.\n", frame)

    local expected_frame = inputQueue.first_frame and 0 or FrameInputMap_lastFrame(inputQueue.inputs) + 1
    frame += inputQueue.frame_delay

    if expected_frame > frame then
        -- this can occur when the frame delay has dropped since the last time we shoved a frame into the system.  In this case, there's no room on the queue.  Toss it.
        Log("Dropping input frame %d (expected next frame to be %d).\n", frame, expected_frame)
        return frameNull
    end

    -- this can occur when the frame delay has been increased since the last time we shoved a frame into the system.  We need to replicate the last frame in the queue several times in order to fill the space left.
    if expected_frame < frame then
        local last_frame = FrameInputMap_lastFrame(inputQueue.inputs)
        while expected_frame < frame do
            Log("Adding padding frame %d to account for change in frame delay.\n", expected_frame)
            inputQueue.inputs[expected_frame] = { frame = expected_frame, input = inputQueue.inputs[last_frame].input }
            expected_frame += 1
        end
    end
    return frame
end

function InputQueue_AddInput<I>(inputQueue : InputQueue<I>, inout_input : GameInput<I>) 
    Log("adding input frame %d to queue.\n", inout_input.frame)

    -- verify that inputs are passed in sequentially by the user, regardless of frame delay.
    assert(inputQueue.last_user_added_frame == frameNull or inout_input.frame == inputQueue.last_user_added_frame + 1)
    inputQueue.last_user_added_frame = inout_input.frame

    local new_frame = InputQueue_AdvanceQueueHead(inputQueue, inout_input.frame)

    -- ug
    inout_input.frame = new_frame

    if new_frame ~= frameNull then
        inputQueue.inputs[new_frame] = inout_input
        inputQueue.last_added_frame = new_frame
    end
end
   

-- DONE UNTESTED
export type Sync<T,I> = {
    callbacks : GGPOCallbacks<T,I>,
    savedstate : { [Frame] : { state : T, checksum : string } },
    rollingback : bool,
    last_confirmed_frame : number,
    framecount : number,
    max_prediction_frames : number,
    -- TODO rename input_queues
    input_queue : {[GGPOPlayerHandle] : InputQueue<I>},
}


function Sync_new<T,I>(max_prediction_frames: number, callbacks: GGPOCallbacks<T,I>) : Sync<T,I>
    local r = {
        callbacks = callbacks,
        savedstate = {},
        max_prediction_frames = max_prediction_frames,
        rollingback = false,
        last_confirmed_frame = frameNull,
        framecount = 0,

        -- TODO preallocate players
        input_queue = {},
    }
    return r
end

function Sync_SetLastConfirmedFrame<T,I>(sync : Sync<T,I>, frame : number)
    sync.last_confirmed_frame = frame
    
    -- we may eventually allow input on frameInit (to transmit per-player data) so use >= here
    if frame >= frameInit then
        for player, data in pairs(sync.input_queue) do
            local fd = data[frame]
            if fd then
                local start = FrameInputMap_firstFrame(fd)
                for i = start, frame, 1 do
                    table.remove(fd, i)
                end
            end
        end
    end
end


function Sync_AddLocalInput<T,I>(sync : Sync<T,I>, player : GGPOPlayerHandle, input : GameInput<I>) : boolean

    -- reject local input if we've gone too far ahead
    local frames_behind = sync.framecount - sync.last_confirmed_frame
    if sync.framecount >= sync.max_prediction_frames and frames_behind >= sync.max_prediction_frames then
        Log("Rejecting input from emulator: reached prediction barrier.\n");
        return false
    end

    if sync.framecount == 0 then
        Sync_SaveCurrentFrame(sync)
    end

    Log("Adding undelayed local frame %d for player %d.\n", sync.framecount, player)
    assert(input.frame == sync.framecount, "expected input frame to match current frame")
    input.frame = sync.framecount
    InputQueue_AddInput(sync.input_queue[player], input)
    return true
end

function Sync_AddRemoteInput<T,I>(sync : Sync<T,I>, player : GGPOPlayerHandle, input : GameInput<I>)
    InputQueue_AddInput(sync.input_queue[player], input)
end


function Sync_GetConfirmedInputs<T,I>(sync : Sync<T,I>, frame: Frame) : PlayerInputMap<I>
    local r = {}
    for player, iq in pairs(sync.input_queue) do
        r[player] = InputQueue_GetConfirmedInput(iq, frame)
    end
    return r
end


function Sync_SynchronizeInputs<T,I>(sync : Sync<T,I>) : PlayerInputMap<I>
    local r = {}
    for player, iq in pairs(sync.input_queue) do
        r[player] = InputQueue_GetInput(iq, sync.framecount)
    end
    return r
end

function Sync_CheckSimulation<T,I>(sync : Sync<T,I>)
    local seekto = Sync_CheckSimulationConsistency(sync)
    if seekto ~= frameNull then
        Sync_AdjustSimulation(sync, seekto);
    end
end

function Sync_IncrementFrame<T,I>(sync : Sync<T,I>)
    sync.framecount += 1
    Sync_SaveCurrentFrame(sync)
end


function Sync_AdjustSimulation<T,I>(sync : Sync<T,I>, seek_to : number)
    local framecount = sync.framecount
    local count = sync.framecount - seek_to
    Log("Catching up\n")
    sync.rollingback = true

    Sync_LoadFrame(sync, seek_to)
    assert(sync.framecount == seek_to)

    for i = 0, count, 1 do
        -- NOTE this is reentrant!
        sync.callbacks.AdvanceFrame()
    end
    assert(sync.framecount == framecount)
    sync.rollingback = false
end

function Sync_LoadFrame<T,I>(sync : Sync<T,I>, frame : Frame) 
    if frame == sync.framecount then
        Log("Skipping NOP.")
    end

    local state = sync.savedstate[frame]

    Log("Loading frame info %d checksum: %s", frame, state.checksum)

    sync.callbacks.LoadGameState(state.state, frame)
end

function Sync_SaveCurrentFrame<T,I>(sync : Sync<T,I>)
    local state = sync.callbacks.SaveGameState(sync.framecount)
    local checksum = "TODO"
    sync.savedstate[sync.framecount] = { state = state, checksum = checksum }
    Log("Saved frame info %d (checksum: %08x).\n", sync.framecount, checksum)
end

function Sync_GetSavedFrame<T,I>(sync : Sync<T,I>, frame : Frame) 
    return sync.savedstate[frame]
end


function Sync_CheckSimulationConsistency<T,I>(sync : Sync<T,I>) : Frame
    local first_incorrect = frameNull
    for player, iq in pairs(sync.input_queue) do
        local incorrect = InputQueue_GetFirstIncorrectFrame(iq)
        if incorrect ~= frameNull and (first_incorrect == frameNull or incorrect < first_incorrect) then
            first_incorrect = incorrect
        end
    end

    if first_incorrect == frameNull then
        Log("prediction ok.  proceeding.\n")
    end

    return first_incorrect
end

function Sync_SetFrameDelay<T,I>(sync : Sync<T,I>, player : GGPOPlayerHandle, delay : number)
    sync.input_queue[player].frame_delay = delay
end


-- TODO make these configureable
local MIN_FRAME_ADVANTAGE = 3
local MAX_FRAME_ADVANTAGE = 9

-- DONE untested
export type TimeSync = {
    localRollingFrameAdvantage : number,
    remoteRollingFrameAdvantage : {[GGPOPlayerHandle] : number},
}

function TimeSync_new() : TimeSync
    local r = {
        localRollingFrameAdvantage = 0,
        remoteRollingFrameAdvantage = {},
    }
    return r
end

function TimeSync_advance_frame(timesync : TimeSync, advantage : number, radvantage : {[GGPOPlayerHandle] : number})
    local w = 0.5
    timesync.localRollingFrameAdvantage = timesync.localRollingFrameAdvantage * (1-w) + advantage*w
    for player, adv in pairs(radvantage) do
        if timesync.remoteRollingFrameAdvantage[player] == nil then
            timesync.remoteRollingFrameAdvantage[player] = adv
        else
            timesync.remoteRollingFrameAdvantage[player] = timesync.remoteRollingFrameAdvantage[player] * (1-w) + adv*w
        end
    end
end

function TimeSync_recommend_frame_wait_duration(timesync : TimeSync) : number
    if #timesync.remoteRollingFrameAdvantge == 0 then
        return 0
    end

    local advantage = timesync.localRollingFrameAdvantage


    local radvantagemin
    local radvantagemax
    
    for player, adv in pairs(timesync.remoteRollingFrameAdvantage) do
        if radvantagemin == nil then
            radvantagemin = adv
            radvantagemax = adv
        else
            radvantagemin = math.min(adv, radvantagemin)
            radvantagemax = math.max(adv, radvantagemax)
        end
    end

    -- LOL why not IDK
    local radvantage = (radvantagemin + radvantagemax) / 2

    -- See if someone should take action.  The person furthest ahead needs to slow down so the other user can catch up. Only do this if both clients agree on who's ahead!!
    if advantage >= radvantage then
        return 0
    end

    -- Both clients agree that we're the one ahead.  Split the difference between the two to figure out how many frames too  to sleep for.
    local sleep_frames = math.floor(((radvantage - advantage) / 2) + 0.5)

    Log("sleep frames is %d\n", sleep_frames)

    if sleep_frames < MIN_FRAME_ADVANTAGE then
        return 0
    end

    -- original ggpo does input checking here, but in our implementation we leave it up to the caller to determine whether to follow the rec or not.

    return math.min(sleep_frames, MAX_FRAME_ADVANTAGE)
end







export type UDPProto_Player<I> = {
    -- alternatively, consider storing these values as a { [GGPOPlayerHandle] : number } table, but this would require sending per player stats rather than just max
    -- (according to peer) frame peer - frame player
    frame_advantage : number,
    pending_output : {[Frame] : GameInput<I>},
    last_received_input : GameInput<I>,

   --disconnect_event_sent : number,
   --disconnect_timeout : number;
   --disconnect_notify_start : number;
   --disconnect_notify_sent : number;
    --TimeSync                   _timesync;
    --RingBuffer<UdpProtocol::Event, 64>  _event_queue;
}

function UDPProto_Player_new() : UDPProto_Player<any>
    local r = {
        frame_advantage = 0,
        pending_output = {},
        last_received_input = { frame = frameNull, input = nil },
        
    }
    return r
end



local MAX_SEQ_DISTANCE = 8

export type UDPMsg_Type = "Ping" | "Pong" | "InputAck" | "Input" | "QualityReport" 

-- TODO get rid of these underscores
-- UDPMsg types
-- these replace sync packets which are not needed for Roblox
export type UDPPeerMsg_Ping = { t: "Ping", time: TimeMS }
export type UDPPeerMsg_Pong = { t: "Pong", time: TimeMS }
export type UDPPeerMsg_InputAck = { t: "InputAck", frame : Frame }


export type QualityReport = { 
    frame_advantage : number, 
}

export type UDPMsg_QualityReport = {
    t: "QualityReport", 
    peer : QualityReport,
    player: {[GGPOPlayerHandle] : QualityReport},
    time : TimeMS,
}

export type UDPMsg_Input<I> = {
    t : "Input",
    ack_frame : Frame,
    inputs : PlayerFrameInputMap<I>
}


export type UDPMsg_Contents<I> = 
    UDPPeerMsg_Ping
    | UDPPeerMsg_Pong
    | UDPPeerMsg_InputAck 
    | UDPMsg_QualityReport 
    | UDPMsg_Input<I> 
    | UDPMsg_QualityReport

export type UDPMsg<I> = {
    m : UDPMsg_Contents<I>,
    seq : number,
}

function UDPMsg_Size<I>(UDPMsg : UDPMsg<I>) : number
    return 0
end


-- DONE UNTESTED
-- manages synchronizing with a single peer
-- in particular, manages the following:
-- sending and acking input
-- synchronizing (initialization)
-- tracks ping for frame advantage computation
export type UDPProto<I> = {

    -- id
    player : GGPOPlayerHandle,
    endpoint : UDPEndpoint<I>,

    -- configuration
    sendLatency : number,
    msPerFrame: number,

    -- rift calculation
    lastReceivedFrame : Frame,
    round_trip_time : TimeMS,
    -- (according to peer) frame peer - frame self
    remote_frame_advantage : number,
    -- (according to self) frame self - frame peer
    local_frame_advantage : number,

    -- stats
    packets_sent : number,
    bytes_sent : number,
    kbps_sent: number,
    stats_start_time : TimeMS,
    
    -- logging
    last_sent_input : GameInput<I>,

    -- running state
    --last_quality_report_time : number,
    --last_network_stats_interval : number,
    --last_input_packet_recv_time : number, 

    -- packet counting
    next_send_seq : number,
    next_recv_seq : number,

    event_queue : Queue<GGPOEvent<I>>,

    playerData : {[GGPOPlayerHandle] : UDPProto_Player<I>},

    timesync : TimeSync,

    -- shutdown/keepalive timers
    --shutdown_timeout : number,
    --last_send_time : number,
    --last_recv_time : number,
}

local function UDPProto_lastSynchronizedFrame<I>(udpproto : UDPProto<I>) : Frame
    local lastFrame = frameMax
    for player, data in pairs(udpproto.playerData) do
        if data.last_received_input.frame < lastFrame then
            lastFrame = data.last_received_input.frame
        end
    end
    if lastFrame == frameMax then
        lastFrame = frameNull
    end
    return lastFrame
end

local function UDPProto_new<I>(player : PlayerProxyInfo<I>) : UDPProto<I>

    local playerData = {}
    playerData[player.peer] = UDPProto_Player_new()
    -- TODO if server, maybe add other peers here as well 

    local r = {
        -- TODO set
        player = 0,
        endpoint = uselessUDPEndpoint,

        -- TODO configure
        sendLatency = 0,
        msPerFrame = 50,

        lastReceivedFrame = frameNull,
        round_trip_time = 0,
        remote_frame_advantage = 0,
        local_frame_advantage = 0,

        packets_sent = 0,
        bytes_sent = 0,
        kbps_sent = 0,
        stats_start_time = 0,


        last_sent_input = { frame = frameNull, input = nil },


        next_send_seq = 0,
        next_recv_seq = 0,

        --last_send_time = 0,
        --last_recv_time = 0,

        event_queue = Queue.new(),

        playerData = playerData,

        timesync = TimeSync_new(),

    }
    return r
end

function UDPProto_SendPeerInput<I>(udpproto : UDPProto<I>, input : GameInput<I>)

    local remoteFrameAdvantages = {}
    for player, data in pairs(udpproto.playerData) do
        -- convert frame advantages to be relative to us, they were reported relative to peer
        remoteFrameAdvantages[player] = data.frame_advantage - udpproto.remote_frame_advantage
    end
    remoteFrameAdvantages[udpproto.player] = udpproto.remote_frame_advantage
    TimeSync_advance_frame(udpproto.timesync, udpproto.local_frame_advantage, remoteFrameAdvantages)

    --_pending_output.push(input);
    udpproto.playerData[udpproto.player].pending_output[input.frame] = input
    UDPProto_SendPendingOutput(udpproto);
end


function UDPProto_SendPendingOutput<I>(udpproto : UDPProto<I>)

    local inputs = {} :: PlayerFrameInputMap<I>

    for player, data in pairs(udpproto.playerData) do
        inputs[player] = data.pending_output
    end
   UDPProto_SendMsg(udpproto, { t = "Input", ack_frame = udpproto.lastReceivedFrame, inputs = inputs })
end


function UDPProto_SendInputAck<I>(udpproto : UDPProto<I>)
    -- ack the minimum of all the last received inputs for now
    -- TODO ack the sequence number in the future, and the server needs to keep track of seq -> player -> frames sent
    -- or you could ack the exact players/frames too 
    local minFrame = frameNull
    for player, data in pairs(udpproto.playerData) do
        if data.last_received_input.frame < minFrame then
            minFrame = data.last_received_input.frame
        end
    end
    UDPProto_SendMsg(udpproto, { t = "InputAck", frame = minFrame })
end

function UDPProto_SendQualityReport<I>(udpproto: UDPProto<I>)
    local playerFrameAdvantages = {}
    for player, data in pairs(udpproto.playerData) do
        playerFrameAdvantages[player] = {frame_advantage = data.frame_advantage}
    end
    UDPProto_SendMsg(udpproto, { t = "QualityReport", peer = { frame_advantage = udpproto.local_frame_advantage }, player = playerFrameAdvantages, time = now() })
end

function UDPProto_GetEvent<I>(udpproto : UDPProto<I>) : GGPOEvent<I>?
    return udpproto.event_queue:dequeue()
end


function UDPProto_OnLoopPoll<I>(udpproto : UDPProto<I>)
   
    local now = now()
    local next_interval = 0

    -- TODO add some timer stuff here and finish

    -- sync requests (not needed)

    -- send pending output
    --UDPProto_SendPendingOutput(udpproto)

    -- send qulaity report
    --UDPProto_SendQualityReport(udpproto)
    
    -- update nteworkstats
    --UDPProto_UpdateNetworkStats(udpproto)

    -- send keep alive (not needed)

    -- send disconnect notification (omit)
    -- determine self disconnect (omit)
end



function UDPProto_SendMsg<I>(udpproto : UDPProto<I>, msgc : UDPMsg_Contents<I>)
    local msg = {
        m = msgc,
        seq = udpproto.next_send_seq,
    }
    udpproto.next_send_seq += 1
    udpproto.packets_sent += 1
    udpproto.bytes_sent += UDPMsg_Size(msg)

    Log("SendMsg: %s", msg)
    --_last_send_time = Platform::GetCurrentTimeMS();
    udpproto.endpoint.send(msg)
end



local UDP_HEADER_SIZE = 0
local function UDPProto_UpdateNetworkStats<I>(udpproto : UDPProto<I>) 
   local now = now()
   
   if udpproto.stats_start_time == 0 then
      udpproto.stats_start_time = now
   end

   local total_bytes_sent = udpproto.bytes_sent + (UDP_HEADER_SIZE * udpproto.packets_sent)
   local seconds = (now - udpproto.stats_start_time) / 1000
   local bps = total_bytes_sent / seconds;
   local udp_overhead = (100.0 * (UDP_HEADER_SIZE * udpproto.packets_sent) / udpproto.bytes_sent)

   udpproto.kbps_sent = bps / 1024;

   Log("Network Stats -- Bandwidth: %.2f KBps   Packets Sent: %5d (%.2f pps)   KB Sent: %.2f    UDP Overhead: %.2f %%.\n",
       udpproto.kbps_sent,
       udpproto.packets_sent,
       udpproto.packets_sent * 1000 / (now - udpproto.stats_start_time),
       total_bytes_sent / 1024.0,
       udp_overhead)
end

local function UDPProto_QueueEvent<I>(udpproto : UDPProto<I>, evt : GGPOEvent<I>)
    Log("Queuing event: %s", evt);
    udpproto.event_queue:enqueue(evt)
end

local function UDPProto_OnInput<I>(udpproto : UDPProto<I>, msg :  UDPMsg_Input<I>) 

    udpproto.lastReceivedFrame = msg.frame

    local inputs = msg.inputs
    if #inputs == 0 then
        Log("UDPProto_OnInput: Received empty msg")
        return
    end

    local lastFrame
    for player, data in pairs(inputs) do
        
        -- for now, assume frames are contiguous
        lastFrame = FrameInputMap_lastFrame(data)

        
        if lastFrame ~= frameNull then
            udpproto.playerData[player].last_received_input = data[lastFrame]
        end
    end

    UDPProto_QueueEvent(udpproto, inputs)
end

local function UDPProto_OnInputAck<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_InputAck) 
    -- remember, we ack the min frame of all inputs we received for now
    for player, data in pairs(udpproto.playerData) do
        local start = FrameInputMap_firstFrame(data.pending_output)
        if start ~= frameNull and start <= msg.frame then
            for i = start, msg.frame, 1 do
                table.remove(data.pending_output, i)
            end
        end
    end
end


local function UDPProto_OnPing<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_Ping) 
    UDPProto_SendMsg(udpproto, { t = "Pong", time = msg.time })
end

local function UDPProto_OnPong<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_Pong) 
    -- TODO maybe rolling average this?
    udpproto.round_trip_time = now() - msg.time
end

local function UDPProto_OnQualityReport<I>(udpproto : UDPProto<I>, msg : UDPMsg_QualityReport) 
    udpproto.remote_frame_advantage = msg.peer.frame_advantage
    for player, data in pairs(msg.player) do
        udpproto.playerData[player].frame_advantage = data.frame_advantage
    end

    UDPProto_SendMsg(udpproto, { t = "Pong", time = msg.time })
end


function UDPProto_OnMsg<I>(udpproto : UDPProto<I>, msg : UDPMsg<I>) 

    --filter out out-of-order packets
    local skipped = msg.seq - udpproto.next_recv_seq
    if skipped > MAX_SEQ_DISTANCE then
        Log("Dropping out of order packet (seq: %d, last seq: %d)", msg.seq, udpproto.next_recv_seq)
        return
    end

    udpproto.next_recv_seq = msg.seq;
    Log("recv %s", msg)

    if msg.m.t == "Ping" then
        UDPProto_OnPing(udpproto, msg.m)
    elseif msg.m.t == "Pong" then
        UDPProto_OnPong(udpproto, msg.m)
    elseif msg.m.t == "InputAck" then
        UDPProto_OnInputAck(udpproto, msg.m)
    elseif msg.m.t == "Input" then
        UDPProto_OnInput(udpproto, msg.m)
    elseif msg.m.t == "QualityReport" then
        UDPProto_OnQualityReport(udpproto, msg.m)
    else
        Log("Unknown message type: %s", msg.m.t)
    end

    -- TODO resume if disconnected
    --_last_recv_time = Platform::GetCurrentTimeMS();
end

function UDPProto_GetNetworkStats(udpproto : UDPProto<I>) : GGPONetworkStats

    local maxQueueLength = 0
    for player, data in pairs(udpproto.playerData) do
        if #data.pending_output > maxQueueLength then
            maxQueueLength = #data.pending_output
        end
    end
    
    local s = {
        max_send_queue_len = maxQueueLength,
        ping = udpproto.round_trip_time,
        kbps_sent = udpproto.kbps_sent,
        local_frames_behind = udpproto.local_frame_advantage,
        remote_frames_behind = udpproto.remote_frame_advantage,
    }

    return s
end
    
function UDPProto_SetLocalFrameNumber(udpproto : UDPProto<I>, localFrame : number)
    -- TODO I think this computation is incorrect, I think it should actually be
    --local remoteFrame = udpproto.lastReceivedFrame + (udpproto.round_trip_time / 2 + msSinceLastReceivedFrame) / udpproto.msPerFrame 
    local remoteFrame = udpproto.lastReceivedFrame + udpproto.round_trip_time / udpproto.msPerFrame / 2
    udpproto.local_frame_advantage = remoteFrame - localFrame
end
   
function UDPProto_RecommendFrameDelay(udpproto : UDPProto<I>) : number
    -- TODO
   --// XXX: require idle input should be a configuration parameter
   --return _timesync.recommend_frame_wait_duration(false);
   return 0
end







--[[
-- GGPO_Peer
local GGPO_Peer = {}

-- ggpo_get_network_stats
function GGPO_Peer.GetStats() : GGPONetworkStats 
    return nil
end

function GGPO_Peer.GetCurrentFrame() : number
    return 0
end

-- ggpo_synchronize_input
function GGPO_Peer.GetCurrentInput<I>() : {[GGPOPlayerHandle] : GameInput<I>} 
    return {}
end

-- ggpo_advance_frame
function GGPO_Peer.AdvanceFrame()
end


-- ggpo_add_local_input
function GGPO_Peer.AddLocalInput<I>(input: GameInput<I>)
end

-- ggpo_start_session  (you still need to call addPlayer)
function GGPO_Peer.StartSession<T>(config: GameConfig, callbacks: GGPOCallbacks<T>)
end

function GGPO_Peer.AddSpectator(endpoint: UDPEndpoint)
end

function GGPO_Peer.AddPlayerProxy(player: PlayerProxyInfo)
end







--return GGPO_Peer


-- GGPO_SERVER
--local GGPO_Server = {}
-- inhert GGPO_Peer
--GGPO_Server.mt = {}
--GGPO_Server.mt.__index = function (table, key)
--    return GGPO_Peer[key]
--end



-- GGPO_CLIENT
--local GGPO_Client = {}



]]