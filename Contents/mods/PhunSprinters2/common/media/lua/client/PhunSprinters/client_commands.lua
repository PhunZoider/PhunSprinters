if isServer() then
    return
end

local Core = PhunSprinters
local Commands = {}

Commands.OnDusk = function()
    Core:setIsNight(true)
end

Commands.OnDawn = function()
    Core:setIsNight(false)
end

return Commands
