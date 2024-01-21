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
- udp_proto


# understanding GGPO


# terminology
- frame: discrete unit of time measurement for the game
  - starts at frame 0
  - note that input on frame X gets included in game state for frame X+1


# changes from GGPO

for folks familiar with the original [ggpo](https://github.com/pond3r/ggpo) implementation, this section documents some of the major changes

## network topology

- centralized authoritative routing server (CARS)
  - this is the model in use if developing your game on roblox
  - all inputs are routed through a central server (RCC in the case of Roblox)
- fully connected graph (p2p)
  - this is the topology used in the original ggpo implementation, all peers are connected to each other
  - spectators are only connected to a single peer
- connected graph
  - this is the most general network topology
  - this should work in theory, but is not supported in practice and has not been tested


## input 

## no synchronization routine
The game "starts" as soon as the library is initialized. It is recommended that you use the first several seconds of the game to allow all clients to synchronize. This can be done somewhat automatically if you're correctly following the `GGPOEvent_timesync` event code.
You can/should also rely on other network communication means to help reasonably synchronize the starting point.

## additional inputs for initial and random state 
The `GameInput` class has a `gameInfo` field that can be used for arbitrary game information. It is intended to be used for the following:

- synchronizing initial game state in the following 2 ways
  - (CARS) the server sends information for constructing initial game state as frame 0 input (input is from the server which is also a player)
  - (general P2P setting) all players send what they believe to be the initial game state as their frame 0 input and only proceed if all these inputs match

The `gameInfo` field is distinct from the `input` field as it is always predicted to be nil and also to distinguish how its used

## rolling player counts

ggpo-roblox allows players to roll in/out. This information is transmitted in the `GameInput` class (TODO). Players that join midgame must synchronize by requesting the latest confirmed game state/frame from a peer.

NOTE that with rollback, there may be new players introduced! This even applies to frame 0!!!
New players will simply show up in the input map and removed players will simply disappear from the map (TODO not true, removed players (by CARS) will have an explicit player left gameInfo input, however disconnected players will simply stop sending input, TODO add disconnect handling and maybe even disconnect consensus subroutine for P2P case LOL)


## optimizations

- optional input serialization methods
- explicit last frame (for each player) in input packets to allow for nil inputs on frames where nothing has changed





