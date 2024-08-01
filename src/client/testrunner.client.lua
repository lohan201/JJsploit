local TestEZ = require(game.ReplicatedStorage.Shared.Packages.TestEZ)

print("util tests")
TestEZ.TestBootstrap:run({ game.ReplicatedStorage.Shared.util})
print("client tests")
TestEZ.TestBootstrap:run({ game.ReplicatedStorage.Shared.clienttests})