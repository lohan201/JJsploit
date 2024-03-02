--!strict
local GGPO = require(script.Parent.ggpo)
local Bimap = require(script.Parent.util.bimap)

export type GGPORobloxConfig<T,I,J> = {
  gameConfig : GGPO.GameConfig<I,J>,
  callbacks : GGPO.GGPOCallbacks<T,I>,
}
export type GGPORobloxState = "Unkown" | "Initializing" | "Synchronizing" | "Running" |  "Disconnected" | "Disconnected"

export type GGPORobloxEvents = {
  reliableRemoteEvent : RemoteEvent,
  unreliableRemoteEvent : UnreliableRemoteEvent,
}

export type GGPORobloxCommon = {
  state : GGPORobloxState,
}

export type GGPORobloxRCC_ = {
  playerMapping : Bimap.Bimap<GGPO.PlayerHandle, Player>,
  
}


export type GGPORobloxRCC = GGPORobloxRCC_ & GGPORobloxEvents & GGPORobloxCommon



local function GGPORobloxRCC_new(isCars : boolean) : GGPORobloxRCC
  local root = Instance.new("Folder", game.Workspace)
  root.Name = "ggpo-roblox"
  local cars = Instance.new("Folder", root)
  cars.Name = "cars"
  local reliableRemoteEvent = Instance.new("RemoteEvent", cars)
  local unreliableRemoteEvent = Instance.new("UnreliableRemoteEvent", root)

  reliableRemoteEvent.OnServerEvent:Connect(function(player : Player, ...)
    print("Received reliableevent from player " .. tostring(player.UserId))

    -- TODO synchronization
  end)
  unreliableRemoteEvent.OnServerEvent:Connect(function(player : Player, ...)
    print("Received unreliable event from player " .. tostring(player.UserId))
  end)

  return {
    reliableRemoteEvent = reliableRemoteEvent,
    unreliableRemoteEvent = unreliableRemoteEvent,
    playerMapping = Bimap.new(),
    state = "Initializing" :: GGPORobloxState,
  }
end


-- initialize the agme 
local function GGPORobloxRCC_initializeGameAndBeginSynchronization(ggporoblox : GGPORobloxRCC, players :  {[GGPO.PlayerHandle] : Player}, timeout : number)
  
  ggporoblox.playerMapping:insertMany(players)

end


local function GGPORobloxRCC_startGame(ggporoblox : GGPORobloxRCC)


  local config = GGPO.defaultGameConfig
  --local ggpo = GGPO.GGPO_Peer_new(config, callbacks, GGPO.carsHandle)

  
end



local function GGPORobloxRCC_addRealtimePlayer(ggporoblox : GGPORobloxRCC, player : Player)
  error("not supported yet")
end

export type GGPORobloxPlayer_ = {
  owner : GGPO.PlayerHandle,
}

export type GGPORobloxPlayer = GGPORobloxPlayer_ & GGPORobloxEvents & GGPORobloxCommon

local function GGPORobloxPlayer_new(owner : GGPO.PlayerHandle) : GGPORobloxPlayer
  local reliableRemoteEvent = game.Workspace:WaitForChild("ggpo-roblox"):WaitForChild("RemoteEvent")
  local unreliableRemoteEvent = game.Workspace:WaitForChild("ggpo-roblox"):WaitForChild("UnreliableRemoteEvent")
  assert(unreliableRemoteEvent, "UnreliableRemoteEvent not found, this probably means you forgot to initialize the ggpo CARS server or you're having serious connection issues")

  reliableRemoteEvent.OnClientEvent:Connect(function(...)
    print("Received reliable event from server")

    -- TODO synchronization
  end)
  unreliableRemoteEvent.OnClientEvent:Connect(function(...)
    print("Received unreliable event from server")
  end)

  return {
    reliableRemoteEvent = reliableRemoteEvent,
    unreliableRemoteEvent = unreliableRemoteEvent,
    owner = owner,
    state = "Initializing"  :: GGPORobloxState,
  }
end




return {
  GGPORobloxRCC_new = GGPORobloxRCC_new,
}
