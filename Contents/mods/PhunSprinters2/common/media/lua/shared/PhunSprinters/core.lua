local getSandboxOptions = getSandboxOptions
local getNumClassFields = getNumClassFields
local getClassField = getClassField
local getClassFieldVal = getClassFieldVal
local climateManager = nil
local gt = nil
local PZ = PhunZones

PhunSprinters = {
    name = "PhunSprinters",
    consts = {},
    data = {},
    env = {},
    commands = {
        playerSetup = "playerSetup",
        isSprinter = "isSprinter",
        OnDusk = "OnDusk",
        OnDawn = "OnDawn"
    },
    events = {
        OnReady = "PhunSprintersOnReady",
        OnSprinterAdded = "PhunSprintersOnSprinterAdded",
        OnDusk = "PhunSprintersOnDusk",
        OnDawn = "PhunSprintersOnDawn",
        OnEmptyServer = "PhunSprintersOnEmptyServer"
    },
    settings = {},
    sprinterIds = {},
    pendingIds = {},
    toSend = {},
    lastSend = 0,
    ui = {},
    elements = {},
    queueIds = {},
    queue = {},
    tools = require "PhunSprinters/tools",
    pendingCalcs = false,
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
Core.settings = SandboxVars[Core.name] or {}
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

function Core:updateSettings()
    for k, v in pairs(SandboxVars[Core.name] or {}) do
        self.settings[k] = self.getOption(k, v)
    end
end

function Core.addToSend(id, value)
    if value == 0 then
        value = nil
    end
    local update = Core.sprinterIds[id] ~= value
    Core.sprinterIds[id] = value
    if Core.tools.isLocal then
        return
    end
    if update then
        table.insert(Core.toSend, id)
    end
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

if isClient() or isServer() then
    function Core.getId(zedObj)
        if zedObj and instanceof(zedObj, "IsoZombie") and zedObj:isZombie() then
            return tostring(zedObj:getOnlineID())
        end
    end
else
    function Core.getId(zedObj)
        if zedObj and instanceof(zedObj, "IsoZombie") and zedObj:isZombie() then
            return tostring(zedObj:getID())
        end
    end
end

local speedTypeIndex = nil
local speedTypeField = "public int zombie.characters.IsoZombie.speedType"
function Core.getZedSpeedType(zed)
    local speedType = zed.speedType
    local speedType2 = zed.getVariable and zed:getVariable("speedType")
    local speedType3 = zed.getSpeedType and zed:getSpeedType()
    local test = zed.DoZombieSpeeds and zed:DoZombieSpeeds()

    if speedTypeIndex == nil then
        for i = 0, getNumClassFields(zed) - 1 do
            if tostring(getClassField(zed, i)) == speedTypeField then
                speedTypeIndex = i
                break
            end
        end
    end
    if speedTypeIndex == nil then
        -- couldn't find the field, return default
        return
    end
    local field = tostring(getClassField(zed, speedTypeIndex))
    if field == speedTypeField then
        return getClassFieldVal(zed, getClassField(zed, speedTypeIndex))
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
    triggerEvent(value and self.events.OnDusk or self.events.OnDawn)
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
