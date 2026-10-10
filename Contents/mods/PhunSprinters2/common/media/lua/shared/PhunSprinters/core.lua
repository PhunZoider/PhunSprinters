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
    -- Set once enableSprinting has reconciled at least once, so the startup baseline
    -- stays silent but every real transition after it is heard.
    sprintInitialised = false,
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
-- Uses print rather than debugLn on purpose: one of the things this is for is the case
-- where the Debug setting itself did not load, and debugLn would then swallow its own
-- diagnosis. Call it by hand from the console when a setting looks wrong:
--
--     PhunSprinters.dumpSettings("check")
--
-- Written after a long hunt for DefaultRisk reading 1 while the server's vars file said
-- 59, with every other option correct. It turned out to be that world's saved state --
-- a fresh world with the same code and the same declaration loads it fine -- but the
-- three-way comparison is what ruled out the mod, so it stays.
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

-- speedType is a public int field on IsoZombie, but PZ's Lua binding does not reliably
-- expose public fields, and getSpeedType() is a real accessor. Prefer the accessor.
function Core.speedTypeOf(zed)
    if zed.getSpeedType then
        return zed:getSpeedType()
    end
    return zed.speedType
end

-- The Mutants (PZTheMutants) type for this zed ("Leaper", "Husk", ...), or nil when the
-- zed is not a mutant or the mod is not installed. The Mutants classifies some zeds
-- after they spawn, so this can change from nil to a type during a zed's life.
function Core.mutantType(zed)
    local api = PZTheMutants and PZTheMutants.API
    if api and api.getMutantType then
        return api.getMutantType(zed)
    end
end

-- Mutant types ticked in the sandbox (IgnoreMutantLeaper etc.) are left entirely to
-- The Mutants: never tested, never sped up, never slowed down.
function Core.isIgnoredMutant(zed)
    local mutant = Core.mutantType(zed)
    return mutant ~= nil and Core.settings["IgnoreMutant" .. mutant] == true
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
        if st == 2 or st == 3 or (st == 1 and Core.mutantType(zed)) then
            -- A mutant's own speed is The Mutants' choice (Leapers and Weepers run
            -- natively), so a 1 there is genuine and is what we hand back.
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
-- The re-assert runs every minute, so only say something when the answer changes.
-- Otherwise a server that needs no adjustment repeats the same line forever.
local lastNeuterOutcome = nil

local function neuterLn(message)
    if lastNeuterOutcome ~= message then
        lastNeuterOutcome = message
        Core.debugLn(message)
    end
end

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
        neuterLn("Zombie Speed is " .. tostring(speed) ..
                     ": no vanilla sprinters to replace, sandbox left alone")
        return
    end

    if speed == 4 then
        -- Random already rolls Rand.Next(2) + 2 for everything that is not a sprinter.
        -- Zeroing the sprinter share keeps the admin's exact fast shambler / shambler
        -- mix intact and removes only the sprinters.
        local pct = sandboxOptions:getOptionByName("ZombieLore.SprinterPercentage")
        if pct and pct:getValue() ~= 0 then
            sandboxOptions:set("ZombieLore.SprinterPercentage", 0)
            neuterLn("Vanilla sprinters disabled: SprinterPercentage set to 0. " ..
                         "Zombie Speed stays Random, so the existing fast shambler / " ..
                         "shambler mix is kept and 'Replace vanilla sprinters with' is not used")
        else
            neuterLn("Zombie Speed is Random with SprinterPercentage already 0: " ..
                         "nothing to replace, sandbox left alone")
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
    neuterLn("Vanilla sprinters disabled: ZombieLore.Speed was 1, now " .. tostring(option:getValue()))

end

function Core:ini()
    self.inied = true
    Core.startTime = getTimestampMs()
    print("[PhunSprinters] Initializing Core")

    -- Re-cache settings: they are not guaranteed to be loaded when this file was. Go
    -- through updateSettings so there is exactly one way settings are read -- this used
    -- to iterate Core.settings, i.e. the seed taken at file-load time, which on a server
    -- can be nothing but defaults.
    Core:updateSettings()

    if Core.settings.Debug then
        Core.dumpSettings("after ini")
    end

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

-- Work the day/night phase out from the climate manager ourselves.
function Core:calcNight()

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

-- Day/night sources, in order of preference.
--
-- PhunServer2DayNight is the current one. PhunLib is the deprecated channel that
-- PhunServer2DayNight still bridges to for older mods -- but only when PhunLib is
-- actually installed, so it cannot be relied on as the single read.
--
-- Neither is a dependency. We follow whichever is present and work the phase out
-- ourselves when neither is.
--
-- What was here before: a getActivatedMods() test for "\\phunserver" that never matched,
-- because the ids are phunserver2 / phunserver2test with no backslash. Fixing the ids
-- exposed the code it guarded -- it captured "local PS = PhunServer" at ini time and
-- redefined this function around it, and PhunServer 2's global is PhunServer2DayNight,
-- so PS was nil and every call threw. Hence: nothing is captured at load, and every
-- field is guarded.
local nightSources = {{
    name = "PhunServer2DayNight",
    get = function()
        return PhunServer2DayNight
    end,
    dusk = "OnPhunServer2Dusk",
    dawn = "OnPhunServer2Dawn"
}, {
    name = "PhunLib",
    get = function()
        return PhunLib
    end,
    dusk = "OnPhunLibDusk",
    dawn = "OnPhunLibDawn"
}}

-- Name of the source we are following, or nil while we are still doing it ourselves.
Core.nightSource = nil

-- Subscribe to a source's dusk/dawn events and stop working the phase out.
--
-- Events rather than polling: the owner of the cycle knows the moment it changes, and
-- polling would report it up to a minute late *and* keep looking correct if the
-- integration were broken. Once subscribed there is nothing left to poll.
local function followNightSource(source)

    local function sync()
        local t = source.get()
        if not t then
            return
        end
        Core.dawnTime = t.dawnTime or Core.dawnTime
        Core.duskTime = t.duskTime or Core.duskTime
        if t.isNight ~= nil then
            Core:setIsNight(t.isNight)
        end
    end

    Events[source.dusk].Add(sync)
    Events[source.dawn].Add(sync)

    Core.nightSource = source.name
    print("[PhunSprinters] " .. source.name .. " detected, following its day/night events")

    -- Those events only fire on a transition, so take the current state now.
    sync()

end

function Core:testNight()

    -- Already following someone else's cycle. Nothing to work out, nothing to poll.
    if Core.nightSource then
        return
    end

    for _, source in ipairs(nightSources) do
        local t = source.get()
        -- Needs both the values and its events registered, or there is nothing to
        -- subscribe to and we would be adopting a source that can never tell us anything.
        if t and t.isNight ~= nil and t.dawnTime and t.duskTime and Events[source.dusk] and
            Events[source.dawn] then
            followNightSource(source)
            return
        end
    end

    self:calcNight()

end

function Core.getPlayerZoneData(player)
    return {}
end
