
export type GameInput<I> = {
    -- the destination frame of this input
    frame: number,

    -- set to whatever type best represents your game input. Keep this object small! Maybe use a buffer! https://devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894
    -- nil represents no input? (i.e. AddLocalInput was never called)
    input: I?
}
export type FrameInputMap<I> = {[number] : GameInput<I>}
export type PlayerFrameInputMap<I> = {[number] : FrameInputMap<I>}


export type UDPPeerMsg_InputAck = { frame : number }
export type UDPPlayerMsg_Input<I> = FrameInputMap<I>

export type UDPMsg_Contents<I> = 
    UDPPeerMsg_InputAck 
    | UDPPlayerMsg_Input<I> 

export type UDPMsg_Type = "PingRequest" | "PingReply" | "InputAck" | "Input" | "QualityReport" 
export type UDPMsg<I> = {
    t : UDPMsg_Type,
    m : UDPMsg_Contents<I>,
    seq : number,
}

export type UDPProto<I> = {
}

function UDPProto_OnMsg<I>(udpproto : UDPProto<I>, msg : UDPMsg<I>) 

    if msg.t == "InputAck" and type(msg.m) == type({} :: { frame : number }) then
        UDPProto_OnInputAck(udpproto, msg.m)
        -- TODO
    elseif msg.t == "Input" and type(msg.m) == type({} :: PlayerFrameInputMap<I>) then
        UDPProto_OnInput(udpproto, msg.m)
        -- TODO
    else
        print("boop")
    end
end


function UDPProto_OnInput<I>(udpproto : UDPProto<I>, msg :  PlayerFrameInputMap<I>) 
end

function UDPProto_OnInputAck<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_InputAck) 
end



export type NumberWrapper = { tag : "NumberWrapper", n : number }
export type StringWrapper = { tag : "StringWrapper", s : string }
export type UnionType = NumberWrapper | StringWrapper

function NumberWrapperOnly(x : NumberWrapper)
    print (x.n)
end
function StringWrapperOnly(x : StringWrapper)
    print (x.s)
end

function definitelyabug(x : UnionType)
    -- note x can never be of type string so this is extra bogus
    if type(x) == "string" then
        -- no type checker error🤷
        NumberWrapperOnly(x)
    end
    -- type checker error as expected
    NumberWrapperOnly(x)
end

function basicTypeRefinement(x : UnionType)
    if x.tag == "NumberWrapper" then
        NumberWrapperOnly(x)
    elseif x.tag == "stringWrapper" then
        StringWrapperOnly(x)    
    end

    
end



local stringOrNumber: string | number = "foo"

if type(stringOrNumber) == "string" then
    local onlyString: string = stringOrNumber -- ok
end

if type(stringOrNumber) ~= "string" then
    local onlyNumber: number = stringOrNumber -- ok
end