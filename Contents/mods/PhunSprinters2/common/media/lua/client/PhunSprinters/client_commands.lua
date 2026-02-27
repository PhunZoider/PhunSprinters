if isServer() then
    return
end

local Core = PhunSprinters
local Commands = {}

Commands.isSprinter = function(args)
    Core.pendingCalcs = false
    for k, v in pairs(args or {}) do
        local id = k
        if id and Core.sprinterIds[id] ~= v then
            if v == 0 then
                v = nil
            end
            Core.sprinterIds[id] = v
            Core.pendingIds[id] = v ~= nil
        end
    end

end

Commands.OnDusk = function()
    Core:setIsNight(true)
end

Commands.OnDawn = function()
    Core:setIsNight(false)
end

return Commands
