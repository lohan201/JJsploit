require(script.types)

serverHandle = 999999
frameInit = 0
frameStart = 1
frameNull = -1
  

local GGPO_Shared = {}

-- ggpo_get_network_stats
function GGPO_Shared.GetStats() : GGPONetworkStats 
    return nil
end

function GGPO_Shared.GetCurrentFrame() : number
    return 0
end

-- ggpo_synchronize_input
function GGPO_Shared.GetCurrentInput<T>() : {[GGPOPlayerHandle] : GameInput<T>} 
    return {}
end

-- ggpo_advance_frame
function GGPO_Shared.AdvanceFrame()
end


-- ggpo_add_local_input
function GGPO_Shared.AddLocalInput<T>(input: GameInput<T>)
end


return GGPO_Shared