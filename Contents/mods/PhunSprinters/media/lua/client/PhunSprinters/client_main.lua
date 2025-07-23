if isServer() then
    return
end

local Core = PhunSprinters
local PL = PhunLib
local PZ = PhunZones
local sandboxOptions = getSandboxOptions()
local climateMoon = getClimateMoon()
local getGameTime = getGameTime
local getWorld = getWorld
local ZombRand = ZombRand
local ItemVisual = ItemVisual
local lastAdjustedLightIntensity = nil
local getClimateManager = getClimateManager
local getTimestampMs = getTimestampMs
local lastUpdate = 0
local moonMappings = {"MoonPhaseMultiplierNew", "MoonPhaseMultiplierCrescent", "MoonPhaseMultiplierQuarter",
                      "MoonPhaseMultiplierGibbous", "MoonPhaseMultiplierFull", "MoonPhaseMultiplierGibbous",
                      "MoonPhaseMultiplierQuarter", "MoonPhaseMultiplierCrescent"}

function Core.CalcPlayersSprinterPercentage()

    local maxHours = 0
    local percent = 0
    local moonPhase = climateMoon:getCurrentMoonPhase()
    local players = PL.onlinePlayers()
    local moon = (Core.settings[moonMappings[moonPhase]] or 100) * 0.01

    for i = 0, players:size() - 1 do

        local playerObj = players:get(i)
        local modData = playerObj:getModData()
        if modData.PhunSprinters == nil then
            modData.PhunSprinters = {}
        end
        if modData.PhunZones == nil then
            modData.PhunZones = {}
        end

        modData.PhunSprinters.hours = math.max(maxHours,
            playerObj:getHoursSurvived() + (modData.PhunZones.totalHours or 0))
        percent = math.max(percent, modData.PhunZones.minSprinterRisk or 0)
        modData.PhunSprinters.base = percent

        modData.PhunSprinters.moon = moon
        modData.PhunSprinters.moonPhase = moonPhase
        modData.PhunSprinters.hoursAdj = 1
        local hours = (modData.PhunSprinters.totalHours or 0) + playerObj:getHoursSurvived()
        local discount = Core.settings.HoursDiscount or 0
        if discount > hours then
            modData.PhunSprinters.hoursAdj = hours / discount
        end
        modData.PhunSprinters.risk = percent * moon * modData.PhunSprinters.hoursAdj
        if modData.PhunSprinters.risk < 0 then
            modData.PhunSprinters.risk = 0
        elseif modData.PhunSprinters.risk > 100 then
            modData.PhunSprinters.risk = 100
        end
        if (modData.PhunZones.maxSprinterRisk or 0) > 0 and (modData.PhunZones.maxSprinterRisk or 0) <
            modData.PhunSprinters.risk then
            modData.PhunSprinters.risk = modData.PhunZones.maxSprinterRisk
        end

        if modData.PhunSprinters.risk < 1 then
            modData.PhunSprinters.riskLevel = "None"
        elseif modData.PhunSprinters.risk < 10 then
            modData.PhunSprinters.riskLevel = "Low"
        elseif modData.PhunSprinters.risk < 25 then
            modData.PhunSprinters.riskLevel = "Medium"
        elseif modData.PhunSprinters.risk < 50 then
            modData.PhunSprinters.riskLevel = "High"
        else
            modData.PhunSprinters.riskLevel = "VeryHigh"
        end
        Core.moodles:update(playerObj, modData.PhunSprinters)
    end

end

function Core:getZedData(zed)

    if zed:isDead() then
        return
    end

    local data = zed:getModData()

    if data.brain then
        -- bandit
        return
    end

    local id = self:getId(zed)
    -- local reg = self.data and self.data[id]
    if data[self.settings.VersionKey] == nil or data[self.settings.VersionKey].id ~= id or
        ((data[self.settings.VersionKey].exp or 0) < (self.delta or 0)) then
        -- zed is not registered or it is being reused so reset it to normal

        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end

        data[self.settings.VersionKey] = {
            exp = (self.delta or 0) + (self.settings.Exp or 300), -- dont test again for a good 5 mins or so
            id = id
        }

    end

    return data[self.settings.VersionKey]

end

-- Make zed return to normal speed
function Core.makeNormal(zed)
    zed:makeInactive(true);
    sandboxOptions:set("ZombieLore.Speed", 2)
    zed:getModData().PhunSprinters.sprinting = false
    zed:makeInactive(false);
end

-- Make zed run at sprint speed
function Core.makeSprint(zed)
    zed:makeInactive(true);
    sandboxOptions:set("ZombieLore.Speed", 1)
    zed:getModData().PhunSprinters.sprinting = true
    zed:makeInactive(false);
    sandboxOptions:set("ZombieLore.Speed", 2)
end

function Core:updateZed(zed)

    local zData = self:getZedData(zed) or {}

    if zData.sprinter == false then
        -- not a sprinter, no need to update
        return
    end

    if (zData.modified or 0) > (self.lastRecalc or 0) then
        -- No need to update
        if zData.dressed == nil then
            zData.dressed = true
            self:applyZedVisualState(zed, zData)
        end
        return
    end

    local now = getTimestampMs()

    if (now - lastUpdate) < 1000 then
        -- Throttle updates to once per second
        return
    end

    if (now - (zData.modified or 0)) < 1000 then
        -- No need to update yet
        return
    end

    local player = getPlayer()
    local dx, dy = zed:getX() - player:getX(), zed:getY() - player:getY()
    local distance = dx * dx + dy * dy

    if distance > (self.settings.MaxDistance or 3000) or distance < (self.settings.MinDistance or 400) then
        -- Too far or Too close, no need to update
        return
    end

    zData.modified = getTimestampMs()

    if zData.sprinter == nil then
        -- Evaluate if this is a sprinter or not
        zData.sprinter = self:shouldSprint(zed, zData, player:getModData().PhunSprinters or {})

        if zData.sprinter == false then
            -- not a sprinter, make sure they aren't looking like one
            self:applyZedVisualState(zed, zData)
            if self.settings.Debug then
                print("PhunSprinters: " .. tostring(zData.id) .. " is not a sprinter")
            end
            self.makeNormal(zed)
            return
        end
    elseif zData.sprinter == false then
        return -- not a sprinter, no need to update
    end

    -- This is a sprinter
    if self.sprint and not zData.sprinting then
        self.makeSprint(zed)
        if self.settings.Debug then
            print("PhunSprinters: " .. tostring(zData.id) .. " is now sprinting")
        end
    elseif not self.sprint and zData.sprinting then
        self.makeNormal(zed)
        if self.settings.Debug then
            print("PhunSprinters: " .. tostring(zData.id) .. " is now normal")
        end
    end

end

function Core:applyZedVisualState(zed, zData)
    if not zData.sprinter then
        -- Ensure non-sprinters aren't skeletons
        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end
        return
    end

    -- Handle sprinter visuals
    if Core.settings.Skeletons and not zed:isSkeleton() then
        zed:setSkeleton(true)
    end

    -- Handle decoration
    if not zData.dressed and Core.settings.Decorate then
        self:decorateZed(zed)
        zData.dressed = true
    end

    -- Handle screaming
    if zData.sprinting and not zData.screamed and instanceof(zed:getTarget(), "IsoPlayer") then
        self:scream(zed, zData)
    end
end

function Core:scream(zed, zData)

    zData.screamed = true
    local soundName = "PhunSprinters_" .. ZombRand(5) + 1
    if not zed:getEmitter():isPlaying(soundName) then
        local vol = (self.settings.Volume) or 15 * .01
        local soundEmitter = getWorld():getFreeEmitter()
        local hnd = soundEmitter:playSound(soundName, zed:getX(), zed:getY(), zed:getZ())
        soundEmitter:setVolume(hnd, vol)
    end

end

function Core:testPlayers(player, zed, zData)

    local pData = player:getModData().PhunSprinters or {}

    if zData.sprinter == nil then
        zData.sprinter = self:shouldSprint(zed, zData, pData)
    end

    if zData.sprinter and zed:getTarget() == player then
        if self.sprint then
            self:adjustForLight(zed, zData, player)
        elseif zData.sprinting then
            self:normalSpeed(zed)
        end
    end

end

function Core:shouldSprint(zed, zData, pData)

    if (pData.risk or 0) > 0 then
        local risk = pData.risk
        return risk > 0 and ZombRand(100) <= risk
    end
    return false
end

function Core:testEnvironment()

    -- get daylight intensity
    local lightIntensity = math.max(0, math.floor((getClimateManager():getDayLightStrength() * 100) + 0.5))
    -- get fog intensity
    local fogIntensity = math.floor((getClimateManager():getFogIntensity() * 100) + 0.5)
    -- adjust daylight intensity by fog intensity
    local adjustedLightIntensity = lightIntensity;

    if fogIntensity > 0 then
        -- adjust for fog
        adjustedLightIntensity = math.max(0, lightIntensity - (lightIntensity * getClimateManager():getFogIntensity()))
    end

    self.env = {
        lightIntensity = lightIntensity,
        adjustedLightIntensity = adjustedLightIntensity,
        fogIntensity = fogIntensity
    }

    local run = (Core.settings.NightOnly and PL.isNight) or adjustedLightIntensity <
                    ((self.settings.DarknessLevel or 74) * .01)

    if run ~= self.sprint then
        self.sprint = run
        self.lastRecalc = getTimestampMs()
        if self.settings.Debug then
            print("PhunSprinters: Environment changed - " .. (run and "sprinting" or "normal"))
        end
    end

end

function Core:adjustForLight(zed, zData, player)

    local slowInLightLevel = (self.settings.DarknessLevel or 74) * .01

    local zsquare = zed:getCurrentSquare()

    local light = zsquare:getLightLevel(player:getPlayerNum())

    if zData.sprinting and light > slowInLightLevel then
        self:normalSpeed(zed)
    elseif not zData.sprinting and light < slowInLightLevel then
        self:sprintSpeed(zed)
    end
end

function Core:decorateZed(zed)

    local visual = zed:getItemVisuals()
    local outfits = self.outfit

    if outfits == nil then
        return
    end

    local item = zed:isFemale() and outfits.female or outfits.male

    local parts = {}
    for i = 1, visual:size() - 1 do
        local item = visual:get(i)
        if not item then
            break
        end
        local bodyLocation = item:getScriptItem():getBodyLocation()

        parts[bodyLocation] = item
    end

    local doUpdate = false

    for k, v in pairs(item) do

        local garb = nil
        local garbs = nil
        if v.probability and (v.totalItemProbability or 0) > 0 and ZombRand(100) < v.probability then
            garbs = v.items
        end

        if garbs then
            local rnd = ZombRand(v.totalItemProbability)
            local total = 0
            for _, g in ipairs(garbs) do
                if g and g.probability > 0 then
                    total = total + g.probability
                    if rnd < total then
                        garb = g
                        break
                    end
                end
            end

            if garb then
                if parts[k] then
                    parts[k]:setItemType(garb.type)
                    doUpdate = true
                else
                    local iv = ItemVisual:new()
                    iv:setItemType(garb.type)
                    zed:getItemVisuals():add(iv)
                    doUpdate = true
                end

            end
        end

    end

    if doUpdate then
        zed:resetModel()
    end

end

-- configure any themed outfits
function Core:recalcOutfits()
    local total = 0
    local month = getGameTime():getMonth()
    local day = getGameTime():getDay()

    local items = {}

    self.outfit = nil

    if month == 11 and day < 28 then
        -- christmas
        self.outfit = self.baseOutfits.christmas
    elseif month == 11 and day >= 28 then
        -- nye
        self.outfit = self.baseOutfits.party
    elseif month == 9 then
        -- halloween
        self.outfit = self.baseOutfits.halloween
    elseif month == 4 then
        -- easter
        self.outfit = self.baseOutfits.easter
    end

    if self.outfit ~= nil then

        local genders = {"male", "female"}

        for k, v in pairs(self.outfit) do -- eg, party or christmas
            for _, partVal in pairs(v) do -- eg male or female
                -- for _, partVal in pairs(v[g]) do -- eg, Hat or Top
                local itotals = 0
                for _, vv in ipairs(partVal.items or {}) do
                    if not vv.mod or getActivatedMods():contains(vv.mod) then
                        if not vv.probability then
                            vv.probability = 10
                        end
                        itotals = itotals + vv.probability
                    else
                        vv.probability = 0
                    end
                end
                partVal.totalItemProbability = itotals
                -- end

            end
        end

    end

end
