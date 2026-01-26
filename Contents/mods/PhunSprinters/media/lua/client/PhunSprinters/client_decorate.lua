if isServer() then
    return
end
local getGameTime = getGameTime
local getActivatedMods = getActivatedMods
local Core = PhunSprinters

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

function Core:decorateZed(zed)
    local visual = zed:getItemVisuals()
    local outfits = self.outfit
    if not outfits then
        return
    end

    local chosen = zed:isFemale() and outfits.female or outfits.male
    local parts = {}

    for i = 0, visual:size() - 1 do
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

-- ============================================================
-- Decoration & Outfit Logic
-- ============================================================

function Core:applyZedVisualState(zed, zData)
    if not zData.sprinter then
        if zed:isSkeleton() then
            zed:setSkeleton(false)
        end
        zData.dressed = true
        return
    end

    if Core.settings.Skeletons and not zed:isSkeleton() then
        zed:setSkeleton(true)
    end

    if not zData.dressed and Core.settings.Decorate then
        self:decorateZed(zed)
    end

    if zData.sprinting and not zData.screamed and instanceof(zed:getTarget(), "IsoPlayer") then
        self:scream(zed, zData)
    end
    zData.dressed = true
end
