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
        playerSetup = "playerSetup",
        settings = "settings",
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

-- Set once the server has told us its values. See Core.applyServerSettings.
Core.settingsFromServer = false
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
    -- On a multiplayer client the server's values are authoritative and are pushed to
    -- us. Re-reading the local sandbox here would overwrite them with this client's
    -- defaults, which is the whole bug applyServerSettings exists to fix.
    if self.settingsFromServer then
        return
    end
    for k, v in pairs(SandboxVars[Core.name] or {}) do
        self.settings[k] = self.getOption(k, v)
    end
end

-- Take the server's settings as authoritative.
--
-- A joining client *does* receive the server's sandbox correctly. But
-- ConnectToServerState then calls Core.ResetLua to load the server's mod list, and that
-- runs SandboxOptions.Reset() + CustomSandboxOptions.init() + initInstance(), which
-- re-registers every mod option at its declared default. Nothing re-applies the
-- server's values afterwards, so from then on the client reads its own defaults for
-- every PhunSprinters.* option -- silently, with nothing logged, because the value was
-- accepted and then discarded rather than rejected.
--
-- Verified against projectzomboid.jar: Core.ResetLua has exactly one caller, and it is
-- ConnectToServerState. An admin editing settings in-game happens to paper over it for
-- that session, because that re-push lands after the reset. This makes it deterministic.
function Core.applyServerSettings(settings)

    if not settings then
        return
    end

    local changed = 0
    for k, v in pairs(settings) do
        if Core.settings[k] ~= v then
            print("[PhunSprinters] server setting " .. tostring(k) .. ": " ..
                      tostring(Core.settings[k]) .. " -> " .. tostring(v))
            Core.settings[k] = v
            changed = changed + 1
        end
    end

    Core.settingsFromServer = true
    print("[PhunSprinters] applied server settings (" .. tostring(changed) .. " differed from local)")

    return changed

end

-- speedType is a public int field on IsoZombie, but PZ's Lua binding does not reliably
-- expose public fields, and getSpeedType() is a real accessor. Prefer the accessor.
function Core.speedTypeOf(zed)
    if zed.getSpeedType then
        return zed:getSpeedType()
    end
    return zed.speedType
end

-- What vanilla would roll for a zed now that sprinters are off. Used when a zed has no
-- readable speed of its own -- see captureBaseSpeed.
function Core.neuteredSpeedType()
    local choice = Core.settings.VanillaSprinters or 1
    if choice == 2 then
        return 3
    elseif choice == 3 then
        return ZombRand(2) + 2
    end
    return 2
end

-- Record what this zed goes back to when it is not running. Normally that is simply
-- what vanilla rolled it as.
--
-- The awkward case is a zed that was already in the world when we neutered the
-- sandbox: neutering changes what vanilla rolls *next*, so an existing zed keeps
-- speedType 1 until its next activation cycle. On a Sprinter server that is every zed
-- we meet at first. There is no honest "own speed" to recover for those, so give them
-- what the neutered sandbox would have produced. Always records something, so a zed
-- that has sprinted never has a nil base.
function Core.captureBaseSpeed(zed, zData)
    if not zData.baseSpeedType then
        local st = Core.speedTypeOf(zed)
        if st == 2 or st == 3 then
            zData.baseSpeedType = st
        else
            -- 1 (rolled before the neuter, or another client's doing) or -1 (mid
            -- activation cycle) or nil (binding failure).
            zData.baseSpeedType = Core.neuteredSpeedType()
        end
    end
    return zData.baseSpeedType
end

-- Take vanilla's ability to roll sprinters away, so this mod is the only thing in the
-- world that makes anything sprint. Shared: the server's ZombiePopulationManager rolls
-- speed for zeds it spawns and NetworkZombieSimulator broadcasts it, so a client-only
-- call would leave server-simulated sprinters uncorrected.
--
-- This is NOT the per-transition sandbox toggling this mod used to do. That ran dozens
-- of times a second inside a makeInactive bracket; this runs at init and on a slow
-- timer, and never touches a zed.
--
-- Verified against projectzomboid.jar (B42), not recalled:
--   * SandboxOptions.set() is a HashMap lookup plus ConfigOption.setValueFromObject().
--     No disk write, no packet, nothing else.
--   * saveGameFile / saveCurrentGameBinFile have no callers outside SandboxOptions,
--     and the only internal one is the legacy handleOldZombiesFile2() migration, so
--     nothing here writes itself into a single-player save.
--   * determineZombieSpeed() reads the live singleton, so it takes effect at once.
--   * BUT SandboxOptions.load(ByteBuffer) IS called from GameClient and
--     ConnectToServerState receiveSandboxOptions -- an admin editing sandbox options
--     in-game re-pushes them and wipes this. Hence the re-run on a timer; the function
--     is written to be safe to call repeatedly.
function Core.neuterVanillaSprinters()

    local sandboxOptions = getSandboxOptions()
    local option = sandboxOptions:getOptionByName("ZombieLore.Speed")
    if not option then
        return
    end

    local speed = option:getValue()

    if speed == 2 or speed == 3 then
        -- Fast shamblers or shamblers. Vanilla was never going to roll a sprinter, so
        -- leave the admin's setting completely alone. Also the no-op path for a re-run
        -- after we have already changed it.
        return
    end

    if speed == 4 then
        -- Random already rolls Rand.Next(2) + 2 for everything that is not a sprinter.
        -- Zeroing the sprinter share keeps the admin's exact fast shambler / shambler
        -- mix intact and removes only the sprinters.
        local pct = sandboxOptions:getOptionByName("ZombieLore.SprinterPercentage")
        if pct and pct:getValue() ~= 0 then
            sandboxOptions:set("ZombieLore.SprinterPercentage", 0)
            Core.debugLn("Vanilla sprinters disabled: SprinterPercentage set to 0")
        end
        return
    end

    -- speed == 1: every zed would be a sprinter, so there is no distribution worth
    -- preserving and the admin picks what they are instead.
    local choice = Core.settings.VanillaSprinters or 1
    if choice == 3 then
        -- Random: hand it back to vanilla's own 2-or-3 roll.
        sandboxOptions:set("ZombieLore.Speed", 4)
        sandboxOptions:set("ZombieLore.SprinterPercentage", 0)
    else
        sandboxOptions:set("ZombieLore.Speed", choice == 2 and 3 or 2)
    end
    Core.debugLn("Vanilla sprinters disabled: ZombieLore.Speed was 1, now " ..
                     tostring(option:getValue()))

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

    -- re-cache settings as they are not guaranteed to be loaded prior
    for k, v in pairs(Core.settings) do
        Core.settings[k] = Core.getOption(k, v)
    end

    print("[PhunSprinters] " .. (isServer() and "server" or (Core.tools.isLocal and "singleplayer" or "client")) ..
              " settings after ini: DefaultRisk=" .. tostring(Core.settings.DefaultRisk) .. " Mode=" ..
              tostring(Core.settings.Mode) .. " Debug=" .. tostring(Core.settings.Debug))

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
