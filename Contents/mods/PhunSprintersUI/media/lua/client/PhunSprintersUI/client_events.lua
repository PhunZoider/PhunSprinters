if isServer() then
    return
end

-- === Module Shortcuts ===
local Core = PhunSprintersUI
local PS = PhunSprinters
local PZ = PhunZones
local PL = PhunLib

-- === Initialization ===
local function setup()
    Events.OnTick.Remove(setup)

    local players = PL.onlinePlayers()
    for i = 0, players:size() - 1 do
        Core:validatePlayerSensor(players:get(i))
    end

end

Events.OnTick.Add(setup)

Events.OnClothingUpdated.Add(function(player)
    if player:isLocalPlayer() then
        Core:validatePlayerSensor(player)
    end
end)

Events.OnCreatePlayer.Add(function(playerIndex, playerObj)
    Core:validatePlayerSensor(playerObj)
end)

Events.OnClothingUpdated.Add(function(player)
    if player:isLocalPlayer() then
        Core:validatePlayerSensor(player)
    end
end)
