export type Frame = number
export type GGPOPlayerHandle = number

export type GameConefig = {
    numPlayers: number,
    inputDelay: number
}

export type GGPOEvent_synchronized = {
    player: GGPOPlayerHandle,
}
export type GGPOEvent_interrupted = nil
export type GGPOEvent_resumed = nil

-- can we also embed this in the input, perhaps as a serverHandle input
export type GGPOEvent_disconnected = {
    player: GGPOPlayerHandle,
}
  
export type GGPOEvent = GGPOEvent_synchronized | GGPOEvent_interrupted | GGPOEvent_resumed | GGPOEvent_disconnected
  
  
export type UDPMsg = nil
export type UDPEndpoint = {
    send: (UDPMsg) -> (),
    subscribe: ((UDPMsg)->()) -> (),
}

export type PlayerInfo = {
    number: number,
    -- use this to pass in deterministic per-player capabilities
    -- TODO figure out best time to transmit this data? maybe a reliable explicit game start packet? or just transmit as frame 0 data? it's weird cuz you can't really forward simulate if you're stuck on frame 0 waiting for data, but maybe just wait is OK, or maybe use first 10 frames to sync and adjust rift etc
    data: {},
    endpoint: UDPEndpoint,
}


export type GameInput<T> = {
    -- the destination frame of this input
    frame: number,

    -- set to whatever type best represents your game input. Keep this object small! Maybe use a buffer! https://devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894
    input: T
}

export type GGPONetworkStats = nil

export type GGPOCallbacks<T> = {
    SaveGameState: (frame: number) -> T,
    LoadGameState: (T, frame: number) -> (),
    AdvanceFrame: () -> (),
    OnEvent: (event: GGPOEvent) -> (),
    DisconnectPlayer: (GGPOPlayerHandle) -> ()

}