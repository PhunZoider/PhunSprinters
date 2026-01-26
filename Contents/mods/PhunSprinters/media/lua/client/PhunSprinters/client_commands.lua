if isServer() then
    return
end

local Core = PhunSprinters
local Commands = {}

Commands.playerSetup = function()

end

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
            print("[PhunSprinters] Set sprinter ID " .. tostring(id) .. " to " .. tostring(v))
        end
    end

end

return Commands
