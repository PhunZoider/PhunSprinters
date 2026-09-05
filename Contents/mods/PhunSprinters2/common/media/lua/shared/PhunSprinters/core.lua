local getSandboxOptions = getSandboxOptions
local climateManager = nil
local gt = nil
local PZ = PhunZones

PhunSprinters = {
    name = "PhunSprinters",
    consts = {},
    data = {},
    env = {},
    commands = {
        OnDusk = "OnDusk",
        OnDawn = "OnDawn"
    },
    events = {
        OnReady = "PhunSprintersOnReady",
        OnSprinterAdded = "PhunSprintersOnSprinterAdded",
        OnDusk = "PhunSprintersOnDusk",
        OnDawn = "PhunSprintersOnDawn"
    },
    settings = {},
    ui = {},
    elements = {},
    queueIds = {},
    queue = {},
    tools = require "PhunSprinters/tools",
    sprint = true,
    daytime = true,
    baseOutfits = {
        christmas = {
            male = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_SantaHatBluePattern",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_SantaHat",
                        probability = 50

                    }, {
                        type = "Base.Hat_SantaHatGreen",
                        probability = 10
                    }}
                }
            },
            female = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_SantaHatBluePattern",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_SantaHat",
                        probability = 50

                    }, {
                        type = "Base.Hat_SantaHatGreen",
                        probability = 10
                    }}
                }

            }
        },
        easter = {
            male = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.BunnyEars",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_BunnyEarsBlack",
                        probability = 50

                    }, {
                        type = "Base.Hat_BunnyEarsWhite",
                        probability = 10
                    }}
                }
            },
            female = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.BunnyEars",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_BunnyEarsBlack",
                        probability = 50

                    }, {
                        type = "Base.Hat_BunnyEarsWhite",
                        probability = 10
                    }}
                }

            }
        },
        halloween = {
            male = {
                FullHelmet = {
                    probability = 100,
                    items = {{
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Angry",
                        mod = "HallweensPumpkinHelmets",
                        probability = 10
                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Pirate",
                        mod = "HallweensPumpkinHelmets",
                        probability = 1

                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Surprised",
                        mod = "HallweensPumpkinHelmets",
                        probability = 5
                    }}
                }
            },
            female = {
                FullHelmet = {
                    probability = 100,
                    items = {{
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Angry",
                        mod = "HallweensPumpkinHelmets",
                        probability = 10
                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Pirate",
                        mod = "HallweensPumpkinHelmets",
                        probability = 1

                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Surprised",
                        mod = "HallweensPumpkinHelmets",
                        probability = 5
                    }}
                }

            }
        },
        party = {
            male = {

                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_ClownConeHead",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_PartyHat_TINT",
                        probability = 80

                    }}
                }
            },
            female = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_ClownConeHead",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_PartyHat_TINT",
                        probability = 80

                    }}
                }
            }

        }

    },
    outfit = nil
}

local Core = PhunSprinters
Core.isLocal = not isClient() and not isServer()
-- A copy, not a reference to the SandboxVars sub-table: toLua() rebuilds SandboxVars
-- wholesale, which would leave us pointing at a stale table.
Core.settings = {}
for k, v in pairs(SandboxVars[Core.name] or {}) do
    Core.settings[k] = v
end

for _, event in pairs(Core.events) do
    if not Events[event] then
        print("PhunSprinters: Adding event " .. event)
        LuaEventManager.AddEvent(event)
    end
end

function Core.debugLn(str)
    if Core.settings.Debug then
        print("[" .. Core.name .. "] " .. str)
    end
end

function Core.debug(...)
    if Core.settings.Debug then
        Core.tools.debug(Core.name, ...)
    end
end

-- Refresh Core.settings from the live sandbox options.
--
-- Reads the SandboxOption objects directly rather than walking SandboxVars or our own
-- cache, because both of those are timing-dependent in ways that have bitten before:
--
--   * Core.settings is seeded when this file loads. On a server the saved values are
--     not necessarily in place that early, so the seed can be nothing but defaults --
--     and anything that iterates the seed can therefore only refresh keys it already
--     had, never discover a missing one or correct a defaulted one.
--   * SandboxVars is rebuilt wholesale by toLua(), so its contents depend on when you
--     look, and a stale reference to a sub-table keeps values that no longer apply.
--
-- Walking getOptionByIndex sidesteps both: the option objects are the values. Falls
-- back to the SandboxVars walk if the enumeration API is not exposed to Lua.
function Core:updateSettings()

    local sandboxOptions = getSandboxOptions()
    local count = sandboxOptions.getNumOptions and sandboxOptions:getNumOptions() or 0
    local found = 0

    for i = 0, count - 1 do
        local option = sandboxOptions:getOptionByIndex(i)
        if option and option.getTableName and option:getTableName() == Core.name then
            -- Enumeration gives us the authoritative key list. Read the value through
            -- getOption, which goes via getOptionByName: getValue() is not on the
            -- SandboxOption interface, only on the concrete config option behind it.
            local key = option:getShortName()
            self.settings[key] = self.getOption(key, self.settings[key])
            found = found + 1
        end
    end

    if found > 0 then
        return found
    end

    for k, v in pairs(SandboxVars[Core.name] or {}) do
        self.settings[k] = self.getOption(k, v)
    end
    return 0

end

-- Dump every PhunSprinters option from all three places it can be read, so a
-- disagreement between them is visible:
--
--   SandboxVars  the Lua table the game builds from the loaded options (toLua)
--   option       the live SandboxOption object, what getOption reads
--   cached       our own Core.settings
--
-- All three should agree. SandboxVars disagreeing with option means the option was
-- registered but never given the saved value. option disagreeing with cached means we
-- cached too early, or something overwrote it afterwards.
--
-- Deliberately uses print, not debugLn: this is for diagnosing the case where the Debug
-- setting itself may not have loaded.
function Core.dumpSettings(tag)

    local sandboxOptions = getSandboxOptions()
    local vars = SandboxVars[Core.name] or {}

    local keys = {}
    for k in pairs(vars) do
        table.insert(keys, k)
    end
    for k in pairs(Core.settings) do
        if vars[k] == nil then
            table.insert(keys, k)
        end
    end
    table.sort(keys)

    local where = isServer() and "SERVER" or (Core.tools.isLocal and "SP" or "CLIENT")
    print("[PhunSprinters] ==== settings dump: " .. where .. " / " .. tostring(tag) .. " ====")
    for _, k in ipairs(keys) do
        local opt = sandboxOptions:getOptionByName(Core.name .. "." .. k)
        local live = opt and opt:getValue()
        local flag = (live ~= vars[k] or live ~= Core.settings[k]) and "   <-- MISMATCH" or ""
        print("[PhunSprinters]   " .. k .. ": SandboxVars=" .. tostring(vars[k]) .. " option=" .. tostring(live) ..
                  " cached=" .. tostring(Core.settings[k]) .. flag)
    end

    -- The two we actually write, so their state is on the record too.
    for _, n in ipairs({"ZombieLore.Speed", "ZombieLore.SprinterPercentage"}) do
        local opt = sandboxOptions:getOptionByName(n)
        print("[PhunSprinters]   " .. n .. " = " .. tostring(opt and opt:getValue()))
    end
    print("[PhunSprinters] ==== end dump ====")

end

function Core:ini()
    self.inied = true
    Core.startTime = getTimestampMs()
    print("[PhunSprinters] Initializing Core")
    if getActivatedMods():contains("\\phunserver") or getActivatedMods():contains("\\phunservertest") or
        getActivatedMods():contains("\\phunserver2") or getActivatedMods():contains("\\phunserver2test") then
        print("[PhunSprinters] PhunServer detected, using its night system")
        local PS = PhunServer
        function Core:testNight()
            -- let phunserver handle this if it's present
            self.dawnTime = PS.dawnTime
            self.duskTime = PS.duskTime
            self:setIsNight(PS.isNight)
        end
    end

    -- Re-cache settings: they are not guaranteed to be loaded when this file was. Go
    -- through updateSettings so there is exactly one way settings are read -- this used
    -- to iterate Core.settings, i.e. the seed taken at file-load time, which on a server
    -- can be nothing but defaults.
    Core:updateSettings()

    Core.dumpSettings("after ini")

    Core.neuterVanillaSprinters()

    triggerEvent(self.events.OnReady, self)
end

function Core.getOption(name, default)
    local n = Core.name .. "." .. name
    local val = getSandboxOptions():getOptionByName(n) and getSandboxOptions():getOptionByName(n):getValue()
    if val == nil then
        return default
    end
    return val
end

-- I suppose getOnlineID is no longer a thing in B42.17
local testForOnlineId = getCore():getGameVersion():getMajor() == 42 and getCore():getGameVersion():getMinor() < 17 and
                            (isClient() or isServer() or isCoopHost())

function Core.getId(zed)
    if zed then
        if instanceof(zed, "IsoZombie") then
            if zed:isZombie() then
                if testForOnlineId then
                    return tostring(zed:getOnlineID())
                else
                    return tostring(zed:getID())
                end

            end
        end
    end
end

function Core:setIsNight(value)

    if self.isNight == value then
        return
    end
    self.isNight = value

    if isServer() then
        sendServerCommand(Core.name, value and Core.commands.OnDusk or Core.commands.OnDawn, {})
    end
    local event = value and self.events.OnDusk or self.events.OnDawn
    local function fireEvent()
        Events.OnTick.Remove(fireEvent)
        triggerEvent(event)
    end
    Events.OnTick.Add(fireEvent)
end

function Core:testNight()

    if not climateManager and getClimateManager then
        climateManager = getClimateManager()
    end
    if not gt and getGameTime then
        gt = getGameTime()
    end
    if gt and climateManager and climateManager.getSeason then

        local season = climateManager:getSeason()
        if season and season.getDawn then
            local time = gt:getTimeOfDay()
            self.dawnTime = season:getDawn()
            self.duskTime = season:getDusk()
        end
    end
    if self.duskTime and self.dawnTime then
        local currentTime = gt:getTimeOfDay()
        local night = currentTime > self.duskTime or currentTime < self.dawnTime
        if night ~= self.isNight then
            self:setIsNight(night)
        end
    end
end

function Core.getPlayerZoneData(player)
    return {}
end
