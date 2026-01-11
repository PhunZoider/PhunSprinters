if isServer() then
    return
end

-- === Shortcuts & Module Setup ===
local Core = PhunSprinters
local PL = PhunLib
local PZ = PhunZones
local sandboxOptions = getSandboxOptions()
local climateMoon = getClimateMoon()
local getGameTime = getGameTime
local getWorld = getWorld
local ZombRand = ZombRand
local ItemVisual = ItemVisual
local getClimateManager = getClimateManager
local getTimestampMs = getTimestampMs
local getSandboxOptions = getSandboxOptions
local moonMappings = {"MoonPhaseMultiplierNew", "MoonPhaseMultiplierCrescent", "MoonPhaseMultiplierQuarter",
                      "MoonPhaseMultiplierGibbous", "MoonPhaseMultiplierFull", "MoonPhaseMultiplierGibbous",
                      "MoonPhaseMultiplierQuarter", "MoonPhaseMultiplierCrescent"}

-- ============================================================
-- Risk & Environment Evaluation
-- ============================================================

local function formatNumber(number, decimals)
    number = number or 0
    -- Round the number to remove the decimal part
    local roundedNumber = math.floor(number + (decimals and 0.005 or 0.5))
    -- Convert to string and format with commas
    local formattedNumber = tostring(roundedNumber):reverse():gsub("(%d%d%d)", "%1,")
    formattedNumber = formattedNumber:reverse():gsub("^,", "")
    return formattedNumber
end

function Core.CalcMoon()
    Core.moonPhase = climateMoon:getCurrentMoonPhase()
    Core.moon = (Core.settings[moonMappings[Core.moonPhase + 1]] or 100) * 0.01
end

-- Calculate per-player sprinter risk based on hours, zone, moon phase, etc.
function Core.CalcPlayersSprinterPercentage()
    local players = PL.onlinePlayers()
    if Core.moonPhase == nil or Core.moon == nil then
        Core.CalcMoon()
    end
    local moonPhase = Core.moonPhase
    local moon = Core.moon

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local modData = player:getModData()

        modData.PhunSprinters = modData.PhunSprinters or {}
        modData.PhunZones = modData.PhunZones or {}

        local lastRisk = formatNumber(modData.PhunSprinters.risk or 0)

        local totalHours = (modData.PhunSprinters.totalHours or 0) + player:getHoursSurvived()
        local discount = getSandboxOptions():getOptionByName("PhunSprinters.HoursDiscount"):getValue() or 0
        local defaultRisk = getSandboxOptions():getOptionByName("PhunSprinters.DefaultRisk"):getValue() or 0
        local hoursAdj = (discount > totalHours) and (totalHours / discount) or 1
        local minRisk = tonumber(modData.PhunZones.minSprinterRisk or defaultRisk or 0)
        local baseRisk = minRisk
        local risk = baseRisk * moon * hoursAdj
        local maxRisk = tonumber(modData.PhunZones.maxSprinterRisk or 0)

        if minRisk == nil then
            print("PhunSprinters: missing Sprinter Risk value in zone " .. tostring(modData.PhunZones.region) .. ":" ..
                      tostring(modData.PhunZones.zone) .. " for player " .. tostring(player:getDisplayName()) ..
                      ". Defaulting to 0 risk")
        end

        if maxRisk > 0 and risk > maxRisk then
            risk = maxRisk
        end

        risk = math.max(0, math.min(risk, 100))

        modData.PhunSprinters.risk = risk
        modData.PhunSprinters.base = baseRisk
        modData.PhunSprinters.moon = moon
        modData.PhunSprinters.moonPhase = moonPhase
        modData.PhunSprinters.hoursAdj = hoursAdj
        modData.PhunSprinters.hours = totalHours

        if risk < 1 then
            modData.PhunSprinters.riskLevel = "None"
        elseif risk < 10 then
            modData.PhunSprinters.riskLevel = "Low"
        elseif risk < 25 then
            modData.PhunSprinters.riskLevel = "Medium"
        elseif risk < 50 then
            modData.PhunSprinters.riskLevel = "High"
        else
            modData.PhunSprinters.riskLevel = "VeryHigh"
        end
        if Core.settings.Debug and lastRisk ~= formatNumber(risk) then
            print("PhunSprinters: risk=" .. tostring(formatNumber(risk)) .. " (was " .. tostring(lastRisk) .. ")")
        end
        -- Core.moodles:update(player, modData.PhunSprinters)
    end
end

-- Reassess environment light/fog to determine sprint toggle
function Core:testEnvironment()

    local cm = getClimateManager()
    local daylight = math.floor((cm:getDayLightStrength() or 0) * 100 + 0.5)
    local fog = math.floor((cm:getFogIntensity() or 0) * 100 + 0.5)
    local adjustedLight = daylight - (fog / 3)
    adjustedLight = math.max(0, adjustedLight)

    self.env = {
        lightIntensity = daylight,
        fogIntensity = fog,
        adjustedLightIntensity = adjustedLight,
        night = PL.isNight
    }

    if getSandboxOptions():getOptionByName("PhunSprinters.NightOnly"):getValue() then
        if not PL.isNight then
            if self.sprint then
                self:enableSprinting(false)
            end
        else
            if not self.sprint then
                self:enableSprinting(true)
            end
        end
    end

    if getSandboxOptions():getOptionByName("PhunSprinters.SlowInLight"):getValue() then
        local threshold = getSandboxOptions():getOptionByName("PhunSprinters.DarknessLevel"):getValue() or 74
        local shouldSprint =
            (getSandboxOptions():getOptionByName("PhunSprinters.NightOnly"):getValue() and PL.isNight) or
                (adjustedLight < threshold)
        if not getSandboxOptions():getOptionByName("PhunSprinters.NightOnly"):getValue() and shouldSprint ~= self.sprint then
            Core:enableSprinting(shouldSprint)
        end
    end

end

-- ============================================================
-- Zombie Queue Management
-- ============================================================

function Core:enqueueUpdate(zed)
    if not zed or zed:isDead() then
        return
    end

    local id = tostring(self:getId(zed))
    local player = getPlayer()
    if not player or self.queueIds[id] then
        return
    end

    local dx, dy = zed:getX() - player:getX(), zed:getY() - player:getY()
    local distance = dx * dx + dy * dy
    if distance < (self.settings.MinDistance or 400) then
        -- zed is "too close" to test, however...
        if self.settings.SlowInLight then
            --- if they are close, lets check for light?
            if zed:getTarget() and instanceof(zed:getTarget(), "IsoPlayer") then
                local zdata = self:getZedData(zed)
                if zdata and zdata.sprinter then
                    local p = zed:getTarget()
                    self:testPlayers(p, zed, zdata, p:getModData().PhunSprinters or {})
                end
            end
        end
        return
    elseif distance > (self.settings.MaxDistance or 3000) then
        -- too far away
        return
    end

    local data = self:getZedData(zed)
    if data then
        if data.sprinter == false then
            return
        end
        if data.modified then
            if data.dressed == nil then
                self:applyZedVisualState(zed, data)
                data.dressed = true
            end
            return
        end
    end

    self.queueIds[id] = true
    table.insert(self.queue, zed)
end

function Core:processQueue()
    local count = 0
    local maxCount = self.settings.MaxQueue or 10

    while #self.queue > 0 and count < maxCount do
        local zed = table.remove(self.queue, 1)
        self.queueIds[tostring(self:getId(zed))] = nil
        self:updateZed(zed)
        count = count + 1
    end

    if self.settings.Debug and count == maxCount then
        print("PhunSprinters: Queue full — " .. tostring(#self.queue) .. " more zombies waiting.")
    end
end

function Core:updateZed(zed)
    local zData = self:getZedData(zed) or {}

    if zData.sprinter == nil then
        zData.modified = getTimestampMs()
        zData.sprinter = self:shouldSprint(zed, zData, getPlayer():getModData().PhunSprinters or {})

        if not zData.sprinter then
            self:applyZedVisualState(zed, zData)
            zData.dressed = nil
            if self.settings.Debug then
                print("PhunSprinters: " .. tostring(zData.id) .. " is not a sprinter")
            end
            self.makeNormal(zed)
            return
        end
        -- zed:transmitModData()
    elseif not zData.sprinter then
        zData.dressed = nil
        return
    end
    triggerEvent(self.events.onSprinterAdded, zed)
    -- if self.settings.SlowInLight and zData.sprinter ~= false and zed.getTarget and
    --     instanceof(zed:getTarget(), "IsoPlayer") then
    --     if self:testPlayers(zed:getTarget(), zed, zData) == false then
    --         -- out of sight of all players?
    --         return
    --     end
    -- end

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

function Core:enableSprinting(value)

    if self.sprint == value then
        return
    end
    Core.sprint = value
    Core.lastRecalc = getTimestampMs()
    local now = getTimestamp()
    if not self.lastChangeSound then
        self.lastChangeSound = now
    elseif now - (Core.lastChangeSound or 0) > 5 then
        Core.lastChangeSound = now
        local vol = Core.getOption("SprintingChangeNotificationVolume", 15) * .01
        if vol > 0 then
            getSoundManager():PlaySound(value and "PhunSprinters_Start" or "PhunSprinters_End", false, 0):setVolume(vol);
        end
    end
    if self.settings.Debug then
        print("PhunSprinters: Environment changed - " .. (value and "sprinting" or "normal"))
    end

end

-- ============================================================
-- Screaming
-- ============================================================

function Core:scream(zed, zData)
    zData.screamed = true
    local soundName = "PhunSprinters_" .. (ZombRand(5) + 1)

    if not zed:getEmitter():isPlaying(soundName) then
        local vol = Core.getOption("SprintingChangeNotificationVolume", 15) * .01
        if vol <= 0 then
            return
        end
        local soundEmitter = getWorld():getFreeEmitter()
        local hnd = soundEmitter:playSound(soundName, zed:getX(), zed:getY(), zed:getZ())
        soundEmitter:setVolume(hnd, vol)
    end
end

-- ============================================================
-- Decoration & Outfit Logic
-- ============================================================

function Core:applyZedVisualState(zed, zData)
    if not zData.sprinter then
        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end
        return
    end

    if Core.settings.Skeletons and not zed:isSkeleton() then
        zed:setSkeleton(true)
    end

    if not zData.dressed and Core.settings.Decorate then
        self:decorateZed(zed)
        zData.dressed = true
    end

    if zData.sprinting and not zData.screamed and instanceof(zed:getTarget(), "IsoPlayer") then
        self:scream(zed, zData)
    end
end

function Core:decorateZed(zed)
    local visual = zed:getItemVisuals()
    local outfits = self.outfit
    if not outfits then
        return
    end

    local chosen = zed:isFemale() and outfits.female or outfits.male
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

    for bodyLoc, config in pairs(chosen) do
        local garb = nil
        if config.probability and (config.totalItemProbability or 0) > 0 and ZombRand(100) < config.probability then
            local rnd = ZombRand(config.totalItemProbability)
            local total = 0
            for _, option in ipairs(config.items or {}) do
                if option and option.probability > 0 then
                    total = total + option.probability
                    if rnd < total then
                        garb = option
                        break
                    end
                end
            end
        end

        if garb then
            if parts[bodyLoc] then
                parts[bodyLoc]:setItemType(garb.type)
                doUpdate = true
            else
                local iv = ItemVisual:new()
                iv:setItemType(garb.type)
                visual:add(iv)
                doUpdate = true
            end
        end
    end

    if doUpdate then
        zed:resetModel()
    end
end

-- Set themed outfits based on in-game date (Halloween, Xmas, etc.)
function Core:recalcOutfits()
    self.outfit = nil
    local month = getGameTime():getMonth()
    local day = getGameTime():getDay()

    if month == 11 and day < 28 then
        self.outfit = self.baseOutfits.christmas
    elseif month == 11 then
        self.outfit = self.baseOutfits.party
    elseif month == 9 then
        self.outfit = self.baseOutfits.halloween
    elseif month == 4 then
        self.outfit = self.baseOutfits.easter
    end

    if not self.outfit then
        return
    end

    for seasonName, genderData in pairs(self.outfit) do
        for _, config in pairs(genderData) do
            local total = 0
            for _, item in ipairs(config.items or {}) do
                if not item.mod or getActivatedMods():contains(item.mod) then
                    item.probability = item.probability or 10
                    total = total + item.probability
                else
                    item.probability = 0
                end
            end
            config.totalItemProbability = total
        end
    end
end

-- ============================================================
-- Utility Functions
-- ============================================================

function Core:getZedData(zed)
    if zed:isDead() then
        return
    end
    local data = zed:getModData()

    if data.brain then
        return
    end -- Skip special zeds like bandits

    local id = self:getId(zed)
    local verKey = self.settings.VersionKey

    if not data[verKey] or data[verKey].id ~= id or (data[verKey].exp or 0) < (self.delta or 0) then
        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end

        data[verKey] = {
            exp = (self.delta or 0) + (self.settings.Exp or 300),
            id = id
        }
    end

    return data[verKey]
end

-- Determine if zombie should sprint based on player risk
function Core:shouldSprint(zed, zData, pData)
    local risk = pData.risk or 0
    if risk > 0 then
        local chance = ZombRand(100)
        if self.settings.Debug then
            print("[PhunSprinters]: Testing Zed (" .. tostring(zData.id) .. "). Rolled " .. tostring(chance) ..
                      " against risk " .. tostring(risk) .. " and is " ..
                      (chance <= risk and "now a sprinter" or "not going to be a sprinter "))
        end
        return chance <= risk
    end
    return false
end

-- Handle light-based slowdown/speedup for zeds
function Core:adjustForLight(zed, zData, player)
    local threshold = (self.settings.DarknessLevel or 74) * 0.01
    local light = zed:getCurrentSquare():getLightLevel(player:getPlayerNum())

    if zData.sprinting and light > threshold then
        Core.makeNormal(zed)
    elseif not zData.sprinting and light < threshold then
        Core.makeSprint(zed)
    end
end

-- Handle light-based behavior tests for targeted player
function Core:testPlayers(player, zed, zData, pData)

    local zData = zData or self:getZedData(zed)
    if zData == nil then
        return
    end

    local pData = pData or player:getModData().PhunSprinters or {}

    if zData.sprinter == nil then
        zData.sprinter = self:shouldSprint(zed, zData, pData)
    end

    if zData.sprinter and zed:getTarget() == player then
        if not zData.screamed and zData.sprinting then
            self:scream(zed, zData)
        end
        if self.sprint then
            self:adjustForLight(zed, zData, player)
        elseif zData.sprinting then
            Core.makeNormal(zed)
        end
    end
end

-- Force zed back to normal speed
function Core.makeNormal(zed)
    zed:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 2)
    local data = zed:getModData()
    if not data.PhunSprinters then
        data.PhunSprinters = {}
    end
    data.PhunSprinters.sprinting = false
    zed:makeInactive(false)
end

-- Force zed to sprint
function Core.makeSprint(zed)
    zed:makeInactive(true)
    sandboxOptions:set("ZombieLore.Speed", 1)
    local data = zed:getModData()
    if not data.PhunSprinters then
        data.PhunSprinters = {}
    end
    data.PhunSprinters.sprinting = true
    zed:makeInactive(false)
    sandboxOptions:set("ZombieLore.Speed", 2)
end
