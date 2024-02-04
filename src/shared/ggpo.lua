--!strict
local Queue = require(script.Parent.util.queue)

-- helpers
export type TimeMS = number
local function now() : TimeMS
    return DateTime.now().UnixTimestampMillis
end

local function Log(s, ...)
    return print(s:format(...))
end

local function isempty(t)
    return next(t) == nil
end

local function tablecount(t)
    local count = 0
    for _, _ in pairs(t) do
        count += 1
    end
    return count
end

-- debug helpers that you want to delete 
local function debug_tablekeystostring(t)
    local r = ""
    for k, _ in pairs(t) do
        r = r .. tostring(k) .. ", "
    end
    return "[" .. r .. "]"
end


-- custom logging

type PotatoFakeEnum = {
    ASSERT : number,
    Error : number,
    Warn : number,
    Info : number,
    Debug : number,
    Trace : number,


    Normal : number,
    Verbose : number
}


local Potato : PotatoFakeEnum = {
    ASSERT = -1,
    Error = 0,
    Warn = 1,
    Info = 2,
    Debug = 3,
    Trace = 4,

    Normal = 0,
    Verbose = 1,
}

export type PotatoSeverity = number
export type PotatoVerbosity = number

export type Potato = { potato : (Potato, PotatoVerbosity) -> string, potato_severity : number }

local function extractFirstLineOfTraceback(traceback : string, linecount_ : number?) : {[number]:string}
    local linecount = linecount_ or 1
    local r = {}
    -- first line just says stack
    -- second line is the indirect in __call
    local skip = 2
    local i = 0
    -- Use string.gmatch to iterate over each line in the traceback string
    for line in string.gmatch(traceback, "[^\r\n]+") do
        if skip > 0 then
            skip -= 1
        else
            r[i] = line
            i += 1
            if i >= linecount then
                break
            end
        end
    end
    return r 
end

export type PotatoContext = {
    context : Potato,
    verbosity : number,
    stackLines : number,
}

function ctx(p : Potato, verbosity : PotatoVerbosity?, stackLines : number?) : PotatoContext
    return {
        context = p,
        verbosity = verbosity or 0,
        stackLines = stackLines or 1,
    }
end

local function potatoformat(severity : PotatoSeverity, pc : PotatoContext?, s : string, ...) : string
    local ctxstr = nil
    local stackLines = 1
    if pc ~= nil then
        ctxstr = pc.context.potato(pc.context, pc.verbosity)
        stackLines = pc.stackLines
    end
    local lines = extractFirstLineOfTraceback(debug.traceback(), stackLines)
    local msg = s:format(...)

    local finals = ""
    
    if severity == Potato.Error then
        finals = "ERROR: "
    elseif severity == Potato.Warn then
        finals = "WARN: "
    elseif severity == Potato.Info then
        finals = "INFO: "
    elseif severity == Potato.Debug then
        finals = "DEBUG: "
    elseif severity == Potato.Trace then
        finals = "TRACE: "
    end
    finals = finals .. msg .. "\n"
    if ctxstr ~= nil then
        finals = finals .. "context: " .. ctxstr .. "\n"
    end
    finals = finals .. "stack: "
    if tablecount(lines) > 1 then
        finals = finals .. "\n"
    end
    for i = 0, tablecount(lines)-1, 1 do
        finals = finals .. "    " .. lines[i] .. "\n"
    end
    return finals
end

local potatometatable = {
    __call = function(self, severity : PotatoSeverity, pc : PotatoContext?, s : string, ...)
        if pc and severity > pc.context.potato_severity then
            return
        end
        print(potatoformat(severity, pc, s, ...))
    end
}
setmetatable(Potato, potatometatable)

function Tomato(pc : PotatoContext?, condition : any, s_ : string?, ...)
    if condition == nil or condition == false then
        local s = s_ or "assertion failed"
        error(potatoformat(Potato.ASSERT, pc, s, ...))
    end
end




-- TYPES
export type Frame = number
export type FrameCount = number
export type PlayerHandle = number


-- CONSTANTS
local carsHandle = 99999999999
local spectatorHandle = -1
local nullHandle = -2
local frameInit = 0
local frameNegOne = -1
local frameNull = -999999999999
local frameMax = 9999999999999
local frameMin = frameNull+1 -- just so we can distinguish between null and min







-- GGPOEvent types
export type GGPOEventType = "synchronized" | "input" | "interrupted" | "resumed" | "timesync" | "disconnected"
export type GGPOEvent_synchronized = {
    t: "synchronized",
    player: PlayerHandle,
}

-- TODO Rename field to inputs
export type GGPOEvent_Input<I> = { t : "input", input : PlayerFrameInputMap<I> }

export type GGPOEvent_interrupted = { t: "interrupted" }
export type GGPOEvent_resumed = { t: "resumed"  }
export type GGPOEvent_timesync = { t: "timesync", framesAhead : FrameCount } -- sleep for this number of frame to adjust for frame advantage
-- can we also embed this in the input, perhaps as a serverHandle input
export type GGPOEvent_disconnected = {
    t: "disconnected",
    player: PlayerHandle,
}


export type GGPOEvent<I> = GGPOEvent_synchronized | GGPOEvent_Input<I> | GGPOEvent_interrupted | GGPOEvent_resumed | GGPOEvent_timesync | GGPOEvent_disconnected
  


-- TODO add comments
export type GGPOCallbacks<T,I> = {
    SaveGameState: (frame: Frame) -> T,
    LoadGameState: (T, frame: Frame) -> (),
    AdvanceFrame: () -> (),

    -- TODO these should not be GGPOEvent, they should be some new type, because caller cares about a different set of events
    --OnPeerEvent: (event: GGPOEvent<I>, player: PlayerHandle) -> (),
    --OnSpectatorEvent: (event: GGPOEvent<I>, spectator: number) -> (),
    --DisconnectPlayer: (PlayerHandle) -> ()
}


export type GameInput<I> = {
    -- this is not really needed but conveient to have
    -- the destination frame of this input
    frame: Frame,

    -- TODO disconnect info 

    -- TODO
    -- use this for stuff like per-player startup data, random events, etc
    -- this is distinct from input because it's prediction is always nil
    -- TODO when you add this, don't forget to update the prediction code in InputQueue
    --gameInfo : J?, 

    -- set to whatever type best represents your game input. Keep this object small! Maybe use a buffer! https://devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894
    -- nil represents no input? (i.e. AddLocalInput was never called)
    input: I?,

    potato : (GameInput<I>) -> string,
    potato_severity : number,
}

function GameInput_new<I>(frame : Frame, input : I?) : GameInput<I>
    assert(frame ~= nil, "expected frame to not be nil")
    local r = {
        frame = frame,
        input = input,
        potato = function(self : GameInput<I>)
            return string.format("GameInput: frame: %d, input: %s", self.frame, tostring(self.input))
        end,
        potato_severity = Potato.Info,
    }
    return r
end

export type GameConfig<I,J> = {
    inputDelay: FrameCount,
    maxPredictionFrames: FrameCount,

    -- if nil, then default serialization is used which may be inefficient
    inputToString : ((I) -> string)?,
    infoToString : ((J) -> string)?,

    inputEquals : ((I?,I?) -> boolean),

    -- TODO
    --prediction : (frame : Frame, pastInputs : FrameInputMap<I>) -> I?,

    -- TODO eventually for performance
    --serializeInput : (I,J) -> string,
    --serializeInfo : (J) -> string,
}

function prediction_use_last_input<I>(frame : Frame, pastInputs : FrameInputMap<I>) : I?
    local lastFrame = FrameInputMap_lastFrame(pastInputs)
    if lastFrame == frameNull then
        return nil
    end
    assert(lastFrame < frame, "expected last frame to be less than prediction frame")
    return pastInputs[lastFrame].input
end

local defaultGameConfig = {
    inputDelay = 0,
    maxPredictionFrames = 8,
    inputToString = nil,
    infoToString = nil,
    inputEquals = function(a : any, b : any) return a == b end,
    --prediction = prediction_use_last_input,
}



export type FrameInputMap<I> = {[Frame] : GameInput<I>}


function FrameInputMap_potato<I>(msg : FrameInputMap<I>) : string
    local r = ""
    for frame, input in pairs(msg) do
        r = r .. string.format("(%d,%s)", frame, tostring(input.input))
    end
    return r
end

function FrameInputMap_lastFrame<I>(msg : FrameInputMap<I>) : Frame
    if isempty(msg) then
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
    if isempty(msg) then
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

export type PlayerInputMap<I> = {[PlayerHandle] : GameInput<I>}

export type PlayerFrameInputMap<I> = {[PlayerHandle] : FrameInputMap<I>}

function PlayerFrameInputMap_firstFrame<I>(msg : PlayerFrameInputMap<I>) : Frame
    if isempty(msg) then
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
end





export type UDPEndpoint<I> = {
    send: (UDPMsg<I>) -> (),
    -- PlayerHandle is the player that sent the message
    -- TODO remove this argument, it's just for debugging
    subscribe: ((UDPMsg<I>, PlayerHandle)->()) -> (),
}

local uselessUDPEndpoint : UDPEndpoint<any> = {
    send = function(msg) end,
    subscribe = function(cb) end
}



export type UDPNetworkStats = {
    max_send_queue_len : number,
    ping : number,
    kbps_sent : number,
    local_frames_behind : FrameCount,
    remote_frames_behind : FrameCount,
}

-- DONE UNTESTED
export type InputQueue<I,J> = {

    gameConfig : GameConfig<I,J>,

    owner : PlayerHandle, -- the player that owns this InputQueue, for debug purposes only
    player : PlayerHandle, -- the player this InputQueue represents
    first_frame : boolean,

    last_user_added_frame : Frame, -- does not include frame_delay
    last_added_frame : Frame, -- accounts for frame_delay, will equal last_user_added_frame + frame_delay if there were no frame delay shenanigans
    first_incorrect_frame : Frame,
    last_frame_requested : Frame,

    frame_delay : FrameCount,

    inputs : FrameInputMap<I>,

    potato : (InputQueue<I,J>) -> string,
    potato_severity : number,
}

function InputQueue_new<I,J>(gameConfig : GameConfig<I,J>, owner : PlayerHandle, player: PlayerHandle, frame_delay : number) : InputQueue<I,J>
    local r = {
        gameConfig = gameConfig,

        owner = owner, 
        player = player,
        first_frame = true,

        last_user_added_frame = frameNull,
        last_added_frame = frameNull,
        first_incorrect_frame = frameNull,
        last_frame_requested = frameNull,

        frame_delay = frame_delay,

        inputs = {},

        potato = function(self : InputQueue<I,J>)
            return string.format("InputQueue: owner %d, player: %d, last_user_added_frame: %d, last_added_frame: %d, first_incorrect_frame: %d, last_frame_requested: %d, frame_delay: %d", 
                self.owner, self.player, self.last_user_added_frame, self.last_added_frame, self.first_incorrect_frame, self.last_frame_requested, self.frame_delay)
        end,
        potato_severity = Potato.Warn,
    }
    return r
end

function InputQueue_SetFrameDelay<I,J>(inputQueue : InputQueue<I,J>, delay : number)
    inputQueue.frame_delay = delay
end

function InputQueue_GetLastConfirmedFrame<I,J>(inputQueue : InputQueue<I,J>) : Frame
    return inputQueue.last_added_frame
end

function InputQueue_GetFirstIncorrectFrame<I,J>(inputQueue : InputQueue<I,J>) : Frame
    return inputQueue.first_incorrect_frame
end

-- cleanup confirmed frames, we will never roll back to these
function InputQueue_DiscardConfirmedFrames<I,J>(inputQueue : InputQueue<I,J>, frame : Frame)
    assert(frame >= 0)

    -- don't discard frames further back then we've last requested them :O
    if inputQueue.last_frame_requested ~= frameNull then
        frame = math.min(frame, inputQueue.last_frame_requested)
    end

    Potato(Potato.Info, ctx(inputQueue), "InputQueue_DiscardConfirmedFrames: frame: %d", frame)

    local start = FrameInputMap_firstFrame(inputQueue.inputs)
    if start ~= frameNull and start <= frame then
        for i = start, frame, 1 do
            inputQueue.inputs[i] = nil
        end
    end
    
end


function InputQueue_GetConfirmedInput<I,J>(inputQueue : InputQueue<I,J>, frame : Frame) : GameInput<I>
    Tomato(ctx(inputQueue), inputQueue.first_incorrect_frame == frameNull or frame < inputQueue.first_incorrect_frame)
    local fd = inputQueue.inputs[frame]
    Tomato(ctx(inputQueue), fd, "expected frame %d to exist, this probably means the frame has not been confirmed for this player!", frame)
    return fd
end



function InputQueue_GetInput<I,J>(inputQueue : InputQueue<I,J>, frame : Frame) : GameInput<I>
    Potato(Potato.Debug, ctx(inputQueue), "requesting input frame %d.", frame);

    --[[
    No one should ever try to grab any input when we have a prediction
    error.  Doing so means that we're just going further down the wrong
    path.  ASSERT this to verify that it's true.
    ]]
    Tomato(ctx(inputQueue), inputQueue.first_incorrect_frame == frameNull);

    inputQueue.last_frame_requested = frame;

    local fd = inputQueue.inputs[frame]
    if fd then
        return fd
    else
        Potato(Potato.Info, ctx(inputQueue), "requested frame %d not found in queue.", frame);
        local lastFrame = FrameInputMap_lastFrame(inputQueue.inputs)
        -- eventually we may drop this requirement and use a more complex prediction algorithm, in particular, we may have inputs from the future 
        Tomato(ctx(inputQueue), lastFrame < frame, "expected frame used for prediction to be less than requested frame")
        if lastFrame ~= frameNull then
            Potato(Potato.Debug, ctx(inputQueue), "basing new prediction frame from previously added frame (frame:%d).", lastFrame)
            return inputQueue.inputs[lastFrame]
        else
            Potato(Potato.Debug, ctx(inputQueue), "basing new prediction frame from nothing, since we have no frames yet.");
            return GameInput_new(frame, nil)
        end
        
    end
end


-- TODO rename this function, we dont have a queue head concept anymore, instead, just call it AdjustFrameDelay or something
-- advance the queue head to target frame and returns frame with delay applied
function InputQueue_AdvanceQueueHead<I,J>(inputQueue : InputQueue<I,J>, frame : Frame) : Frame
    Potato(Potato.Debug, ctx(inputQueue), "advancing queue head to frame %d.", frame)

    local expected_frame = inputQueue.first_frame and 0 or FrameInputMap_lastFrame(inputQueue.inputs) + 1
    frame += inputQueue.frame_delay

    Tomato(ctx(inputQueue), expected_frame >= frameInit, "expected_frame must be >= 0")

    if expected_frame > frame then
        -- this can occur when the frame delay has dropped since the last time we shoved a frame into the system.  In this case, there's no room on the queue.  Toss it.
        Potato(Potato.Warn, ctx(inputQueue), "Dropping input frame %d (expected next frame to be %d).", frame, expected_frame)
        return frameNull
    end

    -- this can occur when the frame delay has been increased since the last time we shoved a frame into the system.  We need to replicate the last frame in the queue several times in order to fill the space left.
    if expected_frame < frame then
        local last_frame = FrameInputMap_lastFrame(inputQueue.inputs)
        while expected_frame < frame do
            Potato(Potato.Warn, ctx(inputQueue), "Adding padding frame %d to account for change in frame delay.", expected_frame)
            local input : I?
            if last_frame == frameNull then 
                input = nil
            else 
                input = inputQueue.inputs[last_frame].input
            end
            inputQueue.inputs[expected_frame] = GameInput_new(expected_frame, input)
            expected_frame += 1
        end
    end
    return frame
end

-- returns nil if the input was not added (due to already being in the queue)
-- returns the GameInput with frame adjusted for frame delay
function InputQueue_AddInput<I,J>(inputQueue : InputQueue<I,J>, input : GameInput<I>) : GameInput<I>?
    Potato(Potato.Info, ctx(inputQueue), "adding input %s for frame %d ", tostring(input.input), input.frame)

    -- verify that inputs are passed in sequentially by the user, regardless of frame delay
    Tomato(ctx(inputQueue), inputQueue.last_user_added_frame == frameNull or input.frame <= inputQueue.last_user_added_frame + 1, string.format("expected input frames to be sequential %d == %d+1", input.frame, inputQueue.last_user_added_frame))
    -- TODO use this check once we actually have per player input ack tracking in CARS case (NOTE, you will have to prune the seen input in udpproto before it gets added to the queue, at least that's how OG ggpo does it)
    --Tomato(ctx(inputQueue), inputQueue.last_user_added_frame == frameNull or input.frame == inputQueue.last_user_added_frame + 1, string.format("expected input frames to be sequential %d == %d+1", input.frame, inputQueue.last_user_added_frame))
    -- TODO remove this guard once the assert above is enabled
    if input.frame < inputQueue.last_user_added_frame + 1 then
        -- expected to happen since we don't prune in udpproto before adding to msg queue
        Potato(Potato.Info, ctx(inputQueue), "Input frame %d is older than the most recently added frame %d.  Ignoring.", input.frame, inputQueue.last_user_added_frame)
        return nil
    end

    inputQueue.last_user_added_frame = input.frame

    local new_frame = InputQueue_AdvanceQueueHead(inputQueue, input.frame)

    --Potato(Potato.Warn, ctx(inputQueue), "adding input %s for frame %d ", tostring(input.input), new_frame)

    if new_frame ~= frameNull then
        -- if we attempted to predict this frame 
        --OR another peer sent us a frame in the past (TODO peer can only do this if peer == carsHandle)
        if inputQueue.inputs[new_frame] then
            if not inputQueue.gameConfig.inputEquals(inputQueue.inputs[new_frame].input, input.input) then
                inputQueue.first_incorrect_frame = new_frame
            end
        else
            assert(inputQueue.inputs[new_frame] == nil, "expected frame to not exist in queue")
        end
        

        Tomato(ctx(inputQueue), inputQueue.inputs[new_frame] == nil, "expected frame to not exist in queue")
        inputQueue.inputs[new_frame] = input
        inputQueue.last_added_frame = new_frame
    end

    inputQueue.first_frame = false

    return GameInput_new(new_frame, input.input)
end
   

-- DONE UNTESTED
export type Sync<T,I,J> = {
    player : PlayerHandle,
    gameConfig : GameConfig<I,J>,
    callbacks : GGPOCallbacks<T,I>,
    -- TODO need cleanup routine (with opt-out for testing)
    savedstate : { [Frame] : { state : T, checksum : string } },
    rollingback : boolean,
    last_confirmed_frame : Frame,
    framecount : Frame, -- TODO rename to currentFrame
    max_prediction_frames : FrameCount,
    -- TODO rename input_queues
    input_queue : {[PlayerHandle] : InputQueue<I,J>},

    potato : (Sync<T,I,J>) -> string,
    potato_severity : number,
}


function Sync_new<T,I,J>(gameConfig: GameConfig<I,J>, callbacks: GGPOCallbacks<T,I>, player : PlayerHandle, max_prediction_frames: FrameCount) : Sync<T,I,J>
    local r = {
        player = player,
        gameConfig = gameConfig,
        callbacks = callbacks,
        savedstate = {},
        max_prediction_frames = max_prediction_frames,
        rollingback = false,
        last_confirmed_frame = frameNull,
        framecount = frameInit,

        -- TODO preallocate players
        input_queue = {},

        potato = function(self : Sync<T,I,J>)
            return string.format("Sync: player: %d, max_prediction_frames: %d, rollingback: %s, last_confirmed_frame: %d, framecount: %d", 
                self.player, self.max_prediction_frames, tostring(self.rollingback), self.last_confirmed_frame, self.framecount)
        end,

        potato_severity = Potato.Warn,
    }
    return r
end

function Sync_LazyAddPlayer<T,I,J>(sync : Sync<T,I,J>, player : PlayerHandle)
    if sync.input_queue[player] == nil then
        sync.input_queue[player] = InputQueue_new(sync.gameConfig, sync.player, player, sync.gameConfig.inputDelay)
    end
end

function Sync_SetLastConfirmedFrame<T,I,J>(sync : Sync<T,I,J>, frame : Frame)
    sync.last_confirmed_frame = frame
    
    -- we may eventually allow input on frameInit (to transmit per-player data) so use >= here
    if frame >= frameInit then
        for player, data in pairs(sync.input_queue) do
            local fd = data[frame]
            if fd then
                local start = FrameInputMap_firstFrame(fd)
                for i = start, frame, 1 do
                    fd[i] = nil
                end
            end
        end
    end
end



-- returns nil if the input was rejected (either due to being too far ahead, or already in the queue)
-- returns the GameInput with frame adjusted for frame delay
function Sync_AddLocalInput<T,I,J>(sync : Sync<T,I,J>, player : PlayerHandle, input : GameInput<I>) : GameInput<I>?
    Tomato(ctx(sync), input ~= nil, "expected input to not be nil")

    Sync_LazyAddPlayer(sync, player)

    -- reject local input if we've gone too far ahead
    local frames_behind = sync.framecount - sync.last_confirmed_frame
    if sync.framecount >= sync.max_prediction_frames and frames_behind >= sync.max_prediction_frames then
        Potato(Potato.Warn, ctx(sync), "Rejecting input from emulator: reached prediction barrier.");
        return nil
    end

    if sync.framecount == 0 then
        -- TODO this is a little werid, better to do this in the ctor, but I guess the callback might not be ready then, so I guess this is fine too
        Sync_SaveCurrentFrame(sync)
    end

    Potato(Potato.Info, ctx(sync), "Adding undelayed local frame %d for player %d.", sync.framecount, player)
    Tomato(ctx(sync), input.frame == sync.framecount, string.format("expected input frame %d to match current frame %d", input.frame, sync.framecount))
    return InputQueue_AddInput(sync.input_queue[player], input)
end

function Sync_AddRemoteInput<T,I,J>(sync : Sync<T,I,J>, player : PlayerHandle, input : GameInput<I>)
    Sync_LazyAddPlayer(sync, player)

    if player == sync.player then
        if sync.input_queue[player][input.frame] ~= nil then
            Potato(Potato.Warn, ctx(sync), "Received remote self input for frame %d", input.frame)
        end
    end
    InputQueue_AddInput(sync.input_queue[player], input)
end


function Sync_GetConfirmedInputs<T,I,J>(sync : Sync<T,I,J>, frame: Frame) : PlayerInputMap<I>
    local r = {}
    for player, iq in pairs(sync.input_queue) do
        r[player] = InputQueue_GetConfirmedInput(iq, frame)
    end
    return r
end


function Sync_SynchronizeInputs<T,I,J>(sync : Sync<T,I,J>) : PlayerInputMap<I>
    local r = {}
    for player, iq in pairs(sync.input_queue) do
        r[player] = InputQueue_GetInput(iq, sync.framecount)
    end
    return r
end

-- returns the frame we rolled back to (or current frame if no rollback was needed)
function Sync_CheckSimulation<T,I,J>(sync : Sync<T,I,J>) : Frame
    local seekto = Sync_CheckSimulationConsistency(sync)
    if seekto ~= frameNull then
        Sync_AdjustSimulation(sync, seekto);
    end
    return seekto
end

function Sync_IncrementFrame<T,I,J>(sync : Sync<T,I,J>)
    sync.framecount += 1
    Sync_SaveCurrentFrame(sync)
end


function Sync_AdjustSimulation<T,I,J>(sync : Sync<T,I,J>, seek_to : number)
    local framecount = sync.framecount
    local count = sync.framecount - seek_to
    Potato(Potato.Debug, ctx(sync), "Catching up")
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

function Sync_LoadFrame<T,I,J>(sync : Sync<T,I,J>, frame : Frame) 
    if frame == sync.framecount then
        Potato(Potato.Info, ctx(sync), "Skipping LoadFame %d NOP.", frame)
    end

    local state = sync.savedstate[frame]

    Potato(Potato.Info, ctx(sync), "Loading frame info %d checksum: %s", frame, state.checksum)

    sync.callbacks.LoadGameState(state.state, frame)
end

function Sync_SaveCurrentFrame<T,I,J>(sync : Sync<T,I,J>)
    local state = sync.callbacks.SaveGameState(sync.framecount)
    local checksum = "TODO"
    sync.savedstate[sync.framecount] = { state = state, checksum = checksum }
    Potato(Potato.Info, ctx(sync), "Saved frame info %d (checksum: %s).", sync.framecount, checksum)
end

function Sync_GetSavedFrame<T,I,J>(sync : Sync<T,I,J>, frame : Frame) 
    return sync.savedstate[frame]
end


function Sync_CheckSimulationConsistency<T,I,J>(sync : Sync<T,I,J>) : Frame
    local first_incorrect = frameNull
    for player, iq in pairs(sync.input_queue) do
        local incorrect = InputQueue_GetFirstIncorrectFrame(iq)
        if incorrect ~= frameNull and (first_incorrect == frameNull or incorrect < first_incorrect) then
            first_incorrect = incorrect
        end
    end

    if first_incorrect == frameNull then
        Potato(Potato.Info, ctx(sync), "prediction ok.  proceeding.")
    end

    return first_incorrect
end

function Sync_SetFrameDelay<T,I,J>(sync : Sync<T,I,J>, player : PlayerHandle, delay : FrameCount)
    Sync_LazyAddPlayer(sync, player)
    sync.input_queue[player].frame_delay = delay
end


-- TODO make these configureable
local MIN_FRAME_ADVANTAGE = 3
local MAX_FRAME_ADVANTAGE = 9

-- DONE untested
export type TimeSync = {
    localRollingFrameAdvantage : number,
    remoteRollingFrameAdvantage : {[PlayerHandle] : number},
}

function TimeSync_new() : TimeSync
    local r = {
        localRollingFrameAdvantage = 0,
        remoteRollingFrameAdvantage = {},
    }
    return r
end

function TimeSync_advance_frame(timesync : TimeSync, advantage : number, radvantage : {[PlayerHandle] : number})
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
    if isempty(timesync.remoteRollingFrameAdvantage) then
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

    Log("sleep frames is %d", sleep_frames)

    if sleep_frames < MIN_FRAME_ADVANTAGE then
        return 0
    end

    -- original ggpo does input checking here, but in our implementation we leave it up to the caller to determine whether to follow the rec or not.

    return math.min(sleep_frames, MAX_FRAME_ADVANTAGE)
end







export type UDPProto_Player<I> = {
    -- alternatively, consider storing these values as a { [PlayerHandle] : number } table, but this would require sending per player stats rather than just max
    -- (according to peer) frame peer - frame player
    frame_advantage : number,
    pending_output : {[Frame] : GameInput<I>},
    lastFrame : Frame,

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
        lastFrame = frameNegOne,
        
    }
    return r
end



local UDPPROTO_MAX_SEQ_DISTANCE = 8
local UDPPROTO_NO_QUEUE_NIL_INPUT = false -- TODO enable this 

export type UDPMsg_Type = "Ping" | "Pong" | "InputAck" | "Input" | "QualityReport" 

-- TODO get rid of these underscores
-- UDPMsg types
-- these replace sync packets which are not needed for Roblox
export type UDPPeerMsg_Ping = { t: "Ping", time: TimeMS }
export type UDPPeerMsg_Pong = { t: "Pong", time: TimeMS }
export type UDPPeerMsg_InputAck = { t: "InputAck", frame : Frame }


export type QualityReport = { 
    frame_advantage : FrameCount, 
}

export type UDPMsg_QualityReport = {
    t: "QualityReport", 
    peer : QualityReport,
    player: {[PlayerHandle] : QualityReport},
    time : TimeMS,
}


export type UDPMsg_Input<I> = {
    t : "Input",
    ack_frame : Frame,
    peerFrame : Frame, -- TODO DELETE this should alwasy mattch the frame inside inputs[peer].lastFrame
    inputs : {[PlayerHandle] : { inputs : FrameInputMap<I>, lastFrame : Frame } },
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
    -- TODO
    return 0
end

function UDPMsg_potato<I>(UDPMsg : UDPMsg<I>) : string
    if UDPMsg.m.t == "Ping" then
        return string.format("UDPMsg: Ping: time: %d", UDPMsg.m.time)
    elseif UDPMsg.m.t == "Pong" then
        return string.format("UDPMsg: Pong: time: %d", UDPMsg.m.time)
    elseif UDPMsg.m.t == "InputAck" then
        return string.format("UDPMsg: InputAck: frame: %d", UDPMsg.m.frame)
    elseif UDPMsg.m.t == "QualityReport" then
        return string.format("UDPMsg: QualityReport: frame_advantage: %d", UDPMsg.m.peer.frame_advantage)
    elseif UDPMsg.m.t == "Input" then
        local inputs = ""
        for p, i in pairs(UDPMsg.m.inputs) do
            inputs = inputs .. string.format("player: %d ", p) .. FrameInputMap_potato(i.inputs)
        end
        return string.format("UDPMsg: Input: ack_frame: %d, peerFrame: %d, inputs: \n%s", UDPMsg.m.ack_frame, UDPMsg.m.peerFrame, inputs)
    else
        return "UDPMsg: unknown"
    end
end


-- DONE UNTESTED
-- manages synchronizing with a single peer
-- in particular, manages the following:
-- sending and acking input
-- synchronizing (initialization)






-- tracks ping for frame advantage computation
export type UDPProto<I> = {

    -- id
    owner : PlayerHandle, -- the player that owns this UDPProto
    player : PlayerHandle, -- the player we are connected to
    endpoint : UDPEndpoint<I>,

    -- configuration
    sendLatency : number,
    msPerFrame: number,
    isProxy : boolean,

    -- rift calculation
    lastReceivedFrame : Frame, -- this will always match playerData[player].lastFrame
    round_trip_time : TimeMS,
    -- (according to peer) frame peer - frame self
    remote_frame_advantage : FrameCount,
    -- (according to self) frame self - frame peer
    local_frame_advantage : FrameCount,

    -- right now, this should always match match playerData[owner].lastFrame
    -- however in the future, if we have cars auth input these will not match, playerData[player].lastFrame will be the last input received from cars
    lastAddedLocalFrame : Frame,

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

    playerData : {[PlayerHandle] : UDPProto_Player<I>},

    timesync : TimeSync,

    -- shutdown/keepalive timers
    --shutdown_timeout : number,
    --last_send_time : number,
    --last_recv_time : number,

    potato : (UDPProto<I>, PotatoVerbosity) -> string,
    potato_severity : number,
}

local function UDPProto_lastSynchronizedFrame<I>(udpproto : UDPProto<I>) : Frame
    local lastFrame = frameMax
    for player, data in pairs(udpproto.playerData) do
        if data.lastFrame < lastFrame then
            lastFrame = data.lastFrame
        end
    end
    if lastFrame == frameMax then
        lastFrame = frameNull
    end
    return lastFrame
end

local function UDPProto_new<I>(owner : PlayerHandle, player : PlayerHandle, isProxy : boolean, endpoint : UDPEndpoint<I>) : UDPProto<I>

    if owner == carsHandle then
        assert(isProxy, "cars must be a proxy")
    end

    -- initialize playerData
    local playerData = {}
    playerData[owner] = UDPProto_Player_new()

    -- DELETE
    --for _, proxy in pairs(player.proxy) do
    --    playerData[proxy] = UDPProto_Player_new()
    --end

    local r = {
        owner = owner,
        player = player,
        endpoint = endpoint,

        -- TODO configure
        sendLatency = 0,
        msPerFrame = 50,
        isProxy = isProxy,

        lastReceivedFrame = frameNegOne,
        round_trip_time = 0,
        remote_frame_advantage = 0,
        local_frame_advantage = 0,

        lastAddedLocalFrame = frameNegOne,

        packets_sent = 0,
        bytes_sent = 0,
        kbps_sent = 0,
        stats_start_time = 0,


        last_sent_input = GameInput_new(frameNull, nil),


        next_send_seq = 0,
        next_recv_seq = 0,

        --last_send_time = 0,
        --last_recv_time = 0,

        event_queue = Queue.new(),

        playerData = playerData,

        timesync = TimeSync_new(),

        potato = function(self : UDPProto<I>, verbosity : PotatoVerbosity)
            if verbosity == Potato.Verbose then
                return string.format("UDPProto: owner %d, player: %d, lastReceivedFrame: %d, round_trip_time: %d, remote_frame_advantage: %d, local_frame_advantage: %d, lastAddedLocalFrame: %d, packets_sent: %d, bytes_sent: %d, kbps_sent: %d, stats_start_time: %d, next_send_seq: %d, next_recv_seq: %d", 
                    self.owner, self.player, self.lastReceivedFrame, self.round_trip_time, self.remote_frame_advantage, self.local_frame_advantage, self.lastAddedLocalFrame, self.packets_sent, self.bytes_sent, self.kbps_sent, self.stats_start_time, self.next_send_seq, self.next_recv_seq)
            else
                return string.format("UDPProto: owner %d, player: %d", self.owner, self.player)
            end
        end,
        potato_severity = Potato.Trace,
    }

    endpoint.subscribe(function(msg : UDPMsg<I>, player : PlayerHandle) 
        assert(player == r.player, "expected player to match")
        -- TODO assert that we aren't in rollback
        UDPProto_OnMsg(r, msg) 
    end)

    return r
end

function UDPProto_LazyInitPlayer<I>(udpproto : UDPProto<I>, player : PlayerHandle) : UDPProto_Player<I>
    local r = udpproto.playerData[player]
    if r == nil then
        -- TODO may need to init with different values if player was added mid game
        r = UDPProto_Player_new()
        udpproto.playerData[player] = r
    end
    return r
end


-- TODO rename to SendOwnerInput
-- MUST be called once each frame!!! If there is no input, just call with { frame = frame, input = nil }
function UDPProto_SendOwnerInput<I>(udpproto : UDPProto<I>, input : GameInput<I>)

    -- Check to see if this is a good time to adjust for the rift...
    local remoteFrameAdvantages = {}
    for player, data in pairs(udpproto.playerData) do
        -- convert frame advantages to be relative to us, they were reported relative to peer
        remoteFrameAdvantages[player] = udpproto.remote_frame_advantage - data.frame_advantage
    end
    -- peer never reports its own frame advantage relative to itself since it's always 0
    remoteFrameAdvantages[udpproto.player] = udpproto.remote_frame_advantage
    TimeSync_advance_frame(udpproto.timesync, udpproto.local_frame_advantage, remoteFrameAdvantages)


    -- TODO I guess you actually don't want this check in server case where inputs might be skipped
    assert(input.frame == udpproto.lastAddedLocalFrame + 1, string.format("expected input frame %d to be %d + 1", input.frame, udpproto.lastAddedLocalFrame))


    udpproto.lastAddedLocalFrame = input.frame
    -- TODO, don't do this if you want server to override player input
    -- if not udpproto.localInputAuthority
    udpproto.playerData[udpproto.owner].lastFrame = input.frame

    -- add our own input to our pending output
    if UDPPROTO_NO_QUEUE_NIL_INPUT and input.input == nil then
        Potato(Potato.Info, ctx(udpproto), "UDPProto_SendOwnerInput: input is nil, no need to queue it")
    else
        udpproto.playerData[udpproto.owner].pending_output[input.frame] = input
    end
    UDPProto_SendPendingOutput(udpproto);
end


function UDPProto_SendPendingOutput<I>(udpproto : UDPProto<I>)
    local inputs = {}
    for player, data in pairs(udpproto.playerData) do
        if tablecount(data.pending_output) > 0 then
            inputs[player] = { inputs = data.pending_output, lastFrame = data.lastFrame }
        end
    end
   UDPProto_SendMsg(udpproto, { t = "Input", ack_frame = udpproto.lastReceivedFrame, peerFrame = udpproto.lastAddedLocalFrame, inputs = inputs })
end


function UDPProto_SendInputAck<I>(udpproto : UDPProto<I>)
    -- ack the minimum of all the last received inputs for now
    -- TODO ack the sequence number in the future, and the server needs to keep track of seq -> player -> frames sent
    -- or you could ack the exact players/frames too 
    local minFrame = frameNull
    for player, data in pairs(udpproto.playerData) do
        if data.lastFrame < minFrame then
            minFrame = data.lastFrame
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

    --Log("SendMsg: %s", msg)
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

   Potato(Potato.Info, ctx(udpproto), "Network Stats -- Bandwidth: %.2f KBps   Packets Sent: %5d (%.2f pps)   KB Sent: %.2f    UDP Overhead: %.2f %%.",
       udpproto.kbps_sent,
       udpproto.packets_sent,
       udpproto.packets_sent * 1000 / (now - udpproto.stats_start_time),
       total_bytes_sent / 1024.0,
       udp_overhead)
end

local function UDPProto_QueueEvent<I>(udpproto : UDPProto<I>, evt : GGPOEvent<I>)
    --Log("Queuing event: %s", evt);
    udpproto.event_queue:enqueue(evt)
end

local function UDPProto_ClearInputsBefore<I>(udpproto : UDPProto<I>, frame : Frame)
    -- remember, the peer will ack the min frame of all inputs they receive for now so it's OK to clear frames for ALL players
    for player, data in pairs(udpproto.playerData) do
        local start = FrameInputMap_firstFrame(data.pending_output)
        if start ~= frameNull and start <= frame then
            
            for i = start, frame, 1 do
                data.pending_output[i] = nil
            end

            --local keys = debug_tablekeystostring(data.pending_output)
            --Potato(Potato.Debug, ctx(udpproto), "Cleared pending output for player %d from %d to %d, left with keys: %s)", player, start, frame, keys)
        end
    end
end

local function UDPProto_OnInput<I>(udpproto : UDPProto<I>, msg :  UDPMsg_Input<I>) 

    local ds = ""
    for player, data in pairs(msg.inputs) do
        local fs = ""
        for frame, input in pairs(data.inputs) do
            fs = fs .. tostring(frame) .. ","
        end
        ds = ds .. string.format("(%d: %s),", player, fs)
    end
    Potato(Potato.Info, ctx(udpproto), "Received input packet (player, frame count) %s (peer frame: %d, ack: %d)", ds, msg.peerFrame, msg.ack_frame)
    

    local inputs = msg.inputs
    if isempty(inputs)then
        Potato(Potato.Warn, ctx(udpproto), "UDPProto_OnInput: Received empty msg")
        return
    end

    for player, _ in pairs(inputs) do
        UDPProto_LazyInitPlayer(udpproto, player)
    end

    -- add the input to our pending output
    if udpproto.isProxy then
        for player, data in pairs(inputs) do
            for frame, input in pairs(data.inputs) do
                -- TODO check that there is no conflict between input and what's already in pending output
                if UDPPROTO_NO_QUEUE_NIL_INPUT and input.input == nil then
                    Potato(Potato.Info, ctx(udpproto), "UDPProto_OnInput: remote input for player %d frame %d is nil, no need to queue it", player, frame)
                else
                    udpproto.playerData[player].pending_output[frame] = input
                end
            end
            udpproto.playerData[player].lastFrame = data.lastFrame
        end
    end

    -- now fill in empty inputs from udpproto.playerData[player].lastFrame+1 to msg.inputs[player].lastFrame because they get omitted for performance if they were nil
    --Tomato(ctx(udpproto), inputs[msg.player] ~= nil, "expected to receive inputs for peer") -- (need to add player to subscribe callback to do this)
    for player, data in pairs(inputs) do
        for i = udpproto.playerData[player].lastFrame+1, data.lastFrame, 1 do
            if data.inputs[i] == nil then
                Potato(Potato.Info, ctx(udpproto), "did not receive inputs for player %d frame %d assume their inputs are nil", player, i)
                data.inputs[i] = GameInput_new(i, nil)
            end
        end
    end

    -- update the last frame    
    udpproto.lastReceivedFrame = msg.peerFrame
    for player, data in pairs(inputs) do
        udpproto.playerData[player].lastFrame = data.lastFrame
    end

    -- TODO I tried to just delete data.lastFrame but that wasn't enough to make the luau typechecker happy :(
    local input = {}
    for player, data in pairs(inputs) do
        input[player] = data.inputs
    end

    UDPProto_QueueEvent(udpproto, {t = "input", input = input})

    UDPProto_ClearInputsBefore(udpproto, msg.ack_frame)
end

local function UDPProto_OnInputAck<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_InputAck) 
    UDPProto_ClearInputsBefore(udpproto, msg.frame)
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
        local pd = UDPProto_LazyInitPlayer(udpproto, player)
        pd.frame_advantage = data.frame_advantage
    end

    UDPProto_SendMsg(udpproto, { t = "Pong", time = msg.time })
end


function UDPProto_OnMsg<I>(udpproto : UDPProto<I>, msg : UDPMsg<I>) 

    --filter out out-of-order packets
    local skipped = msg.seq - udpproto.next_recv_seq
    if skipped > UDPPROTO_MAX_SEQ_DISTANCE then
        Potato(Potato.Warn, ctx(udpproto), "Dropping out of order packet (seq: %d, last seq: %d)", msg.seq, udpproto.next_recv_seq)
        return
    end

    udpproto.next_recv_seq = msg.seq;
    --Potato(Potato.Debug, ctx(udpproto), "recv %s", msg)

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
        Potato(Potato.Info, ctx(udpproto), "Unknown message type: %s", msg.m.t)
    end

    -- TODO resume if disconnected
    --_last_recv_time = Platform::GetCurrentTimeMS();
end

function UDPProto_GetNetworkStats(udpproto : UDPProto<I>) : UDPNetworkStats

    local maxQueueLength = 0
    for player, data in pairs(udpproto.playerData) do
        if tablecount(data.pending_output) > maxQueueLength then
            maxQueueLength = tablecount(data.pending_output)
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
   
-- set the current local frame number so that we can update our frame advantage computation
function UDPProto_SetLocalFrameNumber<I>(udpproto : UDPProto<I>, localFrame : number)
    -- TODO I think this computation is incorrect, I think it should actually be
    --local remoteFrame = udpproto.lastReceivedFrame + (udpproto.round_trip_time / 2 + msSinceLastReceivedFrame) / udpproto.msPerFrame 
    local remoteFrame = udpproto.lastReceivedFrame + udpproto.round_trip_time / udpproto.msPerFrame / 2
    udpproto.local_frame_advantage = remoteFrame - localFrame
end
   
function UDPProto_RecommendFrameDelay<I>(udpproto : UDPProto<I>) : number
    -- TODO
   --// XXX: require idle input should be a configuration parameter
   --return _timesync.recommend_frame_wait_duration(false);
   return 0
end







-- GGPO_Peer
export type GGPO_Peer<T,I,J> = {
    
    gameConfig : GameConfig<I,J>,
    callbacks : GGPOCallbacks<T,I>,
    sync : Sync<T,I,J>,
    udps : { [PlayerHandle] : UDPProto<I> },
    spectators : { [number] : UDPProto<I> },
    player : PlayerHandle,
    next_recommended_sleep : FrameCount,
}

function GGPO_Peer_new<T,I,J>(gameConfig : GameConfig<I,J>, callbacks : GGPOCallbacks<T,I>, player : PlayerHandle) : GGPO_Peer<T,I,J>
    local r = {
        gameConfig = gameConfig,
        callbacks = callbacks,
        sync = Sync_new(gameConfig, callbacks, player, gameConfig.maxPredictionFrames),
        udps = {},
        spectators = {},
        player = player,
        next_recommended_sleep = 0,
        
    }
    return r
end



local function GGPO_Peer_AddSpectator<T,I,J>(peer : GGPO_Peer<T,I,J>, endpoint: UDPEndpoint<I>)
    error("not implemented")
    --peer.spectators[tablecount(peer.spectators)] = UDPProto_new({ player = spectatorHandle, proxy = {}, endpoint = endpoint })
end


-- NOTE this is only for setting up our peers, not the game!
-- in particular, is a CARS setting this is called for all peers on the server
-- and called for just the server on each peer
function GGPO_Peer_AddPeer<T,I,J>(peer : GGPO_Peer<T,I,J>, player : PlayerHandle, endpoint : UDPEndpoint<I>)

    if player == spectatorHandle then
        GGPO_Peer_AddSpectator(peer, endpoint)
        return
    end

    assert(peer.udps[player] == nil, "expected peer to not already exist")
    peer.udps[player] = UDPProto_new(peer.player, player, peer.player == carsHandle, endpoint)
end

function GGPO_Peer_GetStats<T,I,J>(peer : GGPO_Peer<T,I,J>) : {[PlayerHandle] : UDPNetworkStats}
    local r = {}
    for player, udp in pairs(peer.udps) do
        r[player] = UDPProto_GetNetworkStats(udp)
    end
    return r
end

function GGPO_Peer_SetFrameDelay<T,I,J>(peer : GGPO_Peer<T,I,J>, delay : FrameCount) 
    Sync_SetFrameDelay(peer.sync, peer.player, delay)
end

function GGPO_Peer_SynchronizeInput<T,I,J>(peer : GGPO_Peer<T,I,J>, frame : Frame) : PlayerInputMap<I>
    assert(frame == peer.sync.framecount, "expected frame to match current frame")
    return Sync_SynchronizeInputs(peer.sync)
end

local function GGPO_Peer_OnUdpProtocolEvent<T,I,J>(peer : GGPO_Peer<T,I,J>, event : GGPOEvent<I>, player : PlayerHandle)
    -- TODO
    --peer.callbacks.OnPeerEvent(evt, player)
end


local function GGPO_Peer_OnUdpProtocolPeerEvent<T,I,J>(peer : GGPO_Peer<T,I,J>, event : GGPOEvent<I>, player : PlayerHandle)
    GGPO_Peer_OnUdpProtocolEvent(peer, event, player)
    if event.t == "input" then
        for player, inputs in pairs(event.input) do
            print(tostring(peer.player) .. " GOT INPUTS FOR PLAYER " .. tostring(player))


            -- TODO maybe make this more efficient...
            -- iterate through the frame in order and add them to sync
            local first = FrameInputMap_firstFrame(inputs)
            local last = FrameInputMap_lastFrame(inputs)

            -- you can allow this, but upstream should not be sending inputs for empty players
            -- TODO replace with a warning, assert for now to catch bugs
            assert(first ~= frameNull, "expected there to be inputs for player " .. tostring(player))

            if first ~= frameNull then
                for frame = first, last , 1 do
                    local input = inputs[frame]
                    assert(input ~= nil, "expected input to not be nil for frame:" .. tostring(frame))
                    Sync_AddRemoteInput(peer.sync, player, input)
                end
            end
        end
    end


end


local function GGPO_Peer_OnUdpProtocolSpectatorEvent<T,I,J>(peer : GGPO_Peer<T,I,J>, event : GGPOEvent<I>, spectator : number)
    -- TODO
    --peer.callbacks.OnSpectatorEvent(evt, i)
end

function GGPO_Peer_PollUdpProtocolEvents<T,I,J>(peer : GGPO_Peer<T,I,J>)
    for player, udp in pairs(peer.udps) do
        local evt = UDPProto_GetEvent(udp)
        while evt ~= nil do
            GGPO_Peer_OnUdpProtocolPeerEvent(peer, evt, player)
            evt = UDPProto_GetEvent(udp)
        end
    end
    for i, udp in pairs(peer.spectators) do
        local evt = UDPProto_GetEvent(udp)
        while evt ~= nil do
            GGPO_Peer_OnUdpProtocolSpectatorEvent(peer, evt, i)
            evt = UDPProto_GetEvent(udp)
        end
    end
end

function GGPO_Peer_DoPoll<T,I,J>(peer : GGPO_Peer<T,I,J>)

    assert(not peer.sync.rollingback, "do not poll during rollback!")

    for player, udp in pairs(peer.udps) do
        UDPProto_OnLoopPoll(udp)
    end

    GGPO_Peer_PollUdpProtocolEvents(peer)

    --if (!_synchronizing) {

    -- do rollback if needed
    local rollback_frame = Sync_CheckSimulation(peer.sync)

    --if peer.udps[carsHandle] then
        -- we should never rollback past the last received frame from cars (which is authoritative)
        -- TODO note that subscribe calls are asynchronous so the below may fail if the script has yielded since the last time we polled for events and updated Sync
        --assert(rollback_frame >= peer.udps[carsHandle].lastReceivedFrame )
    --end

    local current_frame = peer.sync.framecount
    for player, udp in pairs(peer.udps) do
        UDPProto_SetLocalFrameNumber(udp, current_frame)
    end

    local total_min_confirmed = frameMax
    for player, udp in pairs(peer.udps) do
        -- TODO NOTE this is different than original GGPO, in original GGPO, the peer has the  last received frame and connected status for all peers connected to player (N^2 pieces of data)
        -- and takes the min of all those. I don't quite know why it does this at all, doing just one hop here seems sufficient/better. I guess because we might be disconnected to the peer so we rely on relayed information to get the last frame?
        total_min_confirmed = math.min(udp.lastReceivedFrame, total_min_confirmed)
    end
    Sync_SetLastConfirmedFrame(peer.sync, total_min_confirmed)

end

-- ggpo_advance_frame
function GGPO_Peer_AdvanceFrame<T,I,J>(peer : GGPO_Peer<T,I,J>)
    Sync_IncrementFrame(peer.sync)

    -- TODO maybe poll here?
end


-- returns nil if input was dropped for whatever reason
-- returns the added input with frame adjusted for frame delay
-- TODO return an error code instead
function GGPO_Peer_AddLocalInput<T,I,J>(peer : GGPO_Peer<T,I,J>, input: GameInput<I>) : GameInput<I>?
    assert(not peer.sync.rollingback, "do not add inputs during rollback!")
    
    -- TODO assert no inputs send during synchronization

    local outinput = Sync_AddLocalInput(peer.sync, peer.player, input)

    -- input got rejected due to being too far ahead (common) or already in the queue (uncommon).
    if not outinput then
        return nil
    end

    -- input dropped due to frame delay shenanigans
    if input.frame == frameNull then
        return nil
    else
        for _, udp in pairs(peer.udps) do 
            UDPProto_SendOwnerInput(udp, input)
        end
    end

    return outinput
end

-- Called only as the result of a local decision to disconnect
-- if peers is CARS then this decision is authoritatively sent to all peers
-- otherwise, there will probably be a desync 
-- TODO figure out how this was intended to be used in original GGPO in p2p case
function GGPO_Peer_DisconnectPlayer<T,I,J>(peer : GGPO_Peer<T,I,J>, player : PlayerHandle)
    -- TODO
    error("not implemented")
end




return {
    now = now,

    -- constants
    frameInit = frameInit,
    frameNull = frameNull,
    frameMax = frameMax,
    frameNegOne = frameNegOne,
    defaultGameConfig = defaultGameConfig,
    carsHandle = carsHandle,
    spectatorHandle = spectatorHandle,
    nullHandle = nullHandle,

    -- helpers exposed for testing
    isempty = isempty,
    tablecount = tablecount,

    -- exposed for testing
    FrameInputMap_lastFrame = FrameInputMap_lastFrame,
    FrameInputMap_firstFrame = FrameInputMap_firstFrame,

    UDPMsg_potato = UDPMsg_potato,

    -- UDPProto stuff 
    -- exposed for testing
    uselessUDPEndpoint = uselessUDPEndpoint,
    UDPProto_Player_new = UDPProto_Player_new,
    UDPProto_ClearInputsBefore = UDPProto_ClearInputsBefore,
    UDPProto_new = UDPProto_new,



    GameInput_new = GameInput_new,
    GGPO_Peer_new = GGPO_Peer_new,
    GGPO_Peer_AddPeer = GGPO_Peer_AddPeer,
    GGPO_Peer_AddSpectator = GGPO_Peer_AddSpectator,
    GGPO_Peer_GetStats = GGPO_Peer_GetStats,
    GGPO_Peer_SetFrameDelay = GGPO_Peer_SetFrameDelay,
    GGPO_Peer_SynchronizeInput = GGPO_Peer_SynchronizeInput,
    GGPO_Peer_AdvanceFrame = GGPO_Peer_AdvanceFrame,
    GGPO_Peer_AddLocalInput = GGPO_Peer_AddLocalInput,
    GGPO_Peer_DoPoll = GGPO_Peer_DoPoll,
    GGPO_Peer_DisconnectPlayer = GGPO_Peer_DisconnectPlayer,
}