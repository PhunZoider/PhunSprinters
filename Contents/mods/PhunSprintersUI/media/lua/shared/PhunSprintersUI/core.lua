PhunSprintersUI = {
    name = "PhunSprintersUI",
    settings = {},
    ui = {},
    events = {
        onReady = "PhunSprintersUIOnReady"
    }
}

local Core = PhunSprintersUI
Core.isLocal = not isClient() and not isServer() and not isCoopHost()
Core.settings = SandboxVars[Core.name] or {}
for _, event in pairs(Core.events) do
    if not Events[event] then
        LuaEventManager.AddEvent(event)
    end
end

function Core:ini()
    self.inied = true
    if not isClient() then

    end
    triggerEvent(self.events.OnReady, self)
end
