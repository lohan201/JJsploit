# ggpo-roblox

***WIP, who knows if I'll ever finish it***




ggpo-roblox is a semi-direct port of [ggpo](https://github.com/pond3r/ggpo) to lua for use in Roblox

the main difference between ggpo-roblox and ggpo is that any connected network topology is support (as oppose to only a fully connected graph), and peers need not also be players

this was basically just to support roblox which has a non-player centralized server that needs to route everything

the main implementation is roblox-agnostic, so you could in principle use it outside af Roblox but I'm not going to bother testing/supporting that


# status

## finished + tested

## finished 
- inputqueue
- sync

## WIP
- udp_proto (needs frame advantage computation adjusted for graph network)



## WIP TODO IGNORE
- allow self to be flagged as authoritative inside sync/inputqueue
  - otherwise, peer can override self inputs
  - if peer does not send self inputs, assume that they were authorized
- figure out how to handle initial player data
  - prob best just to recommend X frames for syncing initial state and rift
  - send player data as server input on frame 0
- figure out server auth input for random and initial state 
  - mainly we don't want to have to send nil server input every frame, assume skipped frames where player == peer are always nil input
- add disconnect tracking
- figure out what to do when player is disconnect
  - refer to orig ggpo implementation
- allow dynamic player entry/exit 
  - probbaly have a server input for such events
    - startgame + player data (frame 0 input)
    - maybe have an all players synced msg (when all players have reasonable rift) (probbaly not needed)
    - player disconnected (input for a player after they disconnected is invalid, should never happen)
    - player reconnected
    - player joined
    - game end (probbaly not needed)