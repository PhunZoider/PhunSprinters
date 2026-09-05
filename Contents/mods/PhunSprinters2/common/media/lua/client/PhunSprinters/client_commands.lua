if isServer() then
    return
end

local Core = PhunSprinters
local Commands = {}

Commands.settings = function(args)
    Core.applyServerSettings(args)
    -- Risk is derived from these, so recompute rather than waiting for the next tick.
    if Core.CalcPlayersSprinterPercentage then
        Core.CalcPlayersSprinterPercentage()
    end
end

Commands.OnDusk = function()
    Core:setIsNight(true)
end

Commands.OnDawn = function()
    Core:setIsNight(false)
end

return Commands
