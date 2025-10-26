if isServer() then
    return
end

-- === Module Shortcuts ===
local Core = PhunSprintersUI
local PS = PhunSprinters
local PZ = PhunZones
local PL = PhunLib

Core.elements = {}

function Core:validatePlayerSensor(player)

    if not Core.ui.instances then
        Core.ui.instances = {}
    end

    local items = player:getWornItems()
    local found = Core.settings.Elements or false

    for count = 0, items:size() - 1 do
        local clothingItem = items:getItemByIndex(count)
        local clothingItemType = clothingItem:getType()
        if clothingItemType == "WristWatch_Right_MilitaryX" or clothingItemType == "WristWatch_Left_MilitaryX" then
            found = true
            break
        end
    end

    if not found and self.ui.instances[player:getPlayerNum()] then

        self.ui.instances[player:getPlayerNum()]:setVisible(false)

    else
        if self.ui.instances[player:getPlayerNum()] then
            self.ui.instances[player:getPlayerNum()]:updateLayout()
        else
            self.ui.container.open(player)
        end
    end

end
