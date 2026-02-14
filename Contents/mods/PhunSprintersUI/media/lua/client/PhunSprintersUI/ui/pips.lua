if isServer() then
    return
end
local tools = require "PhunSprintersUI/ui/tools"
local Core = PhunSprintersUI
local PS = PhunSprinters
local PL = PhunLib
local profileName = "PhunSprintersUIPips"
PhunSprintersUIPips = ISPanelJoypad:derive(profileName);
local UI = PhunSprintersUIPips

local backgroundColours = {
    on = {
        r = .39,
        g = .78,
        b = .82,
        a = 0.8
    },
    off = {
        r = 0,
        g = 0,
        b = 0,
        a = 0.7
    }
}

function UI:new(x, y, width, height, player, playerIndex)
    local opts = options or {}
    local o = ISPanelJoypad:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;

    o.displayColor = {
        r = .39,
        g = .78,
        b = .82,
        a = 1
    }

    o.ghostColor = {
        r = .4,
        g = .4,
        b = .4,
        a = 0.8
    }
    o.borderColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0
    };
    o.controls = {}
    o.moveWithMouse = false;
    o.anchorRight = true
    o.anchorBottom = true
    o.player = player
    o.playerIndex = playerIndex
    return o;

end

function UI:createChildren()
    ISPanelJoypad.createChildren(self)

    self.tooltip = ISToolTip:new();
    self.tooltip:initialise();
    self.tooltip:setVisible(false);
    self.tooltip:setName("");
    self.tooltip:setAlwaysOnTop(true)
    self.tooltip.description = "";
    self.tooltip:setOwner(self)

end

function UI:onMouseMove(x, y)
    ISPanelJoypad.onMouseMove(self, x, y)
    self.mouseOver = true
end

function UI:onMouseMoveOutside(x, y)
    ISPanelJoypad.onMouseMoveOutside(self, x, y)
    self.mouseOver = false
end

function UI:prerender()
    ISPanelJoypad.prerender(self);

    local modData = self.player:getModData();

    -- self.backgroundColor = {
    --     r = 1,
    --     g = 0,
    --     b = 0,
    --     a = 0.8
    -- }
    local count = 5
    if Core.settings.layout == 2 then
        count = 10
    end

    local h = self.height - 2 -- * tools.FONT_SCALE
    local w = self.width - 2 -- * tools.FONT_SCALE

    local pipWidth = (w / count) - 2 -- * tools.FONT_SCALE

    if Core.settings.layout == 2 then
        pipWidth = math.min(pipWidth, h)
    end
    local x = 2 -- self.width - (count * (pipWidth + 1)) - 1
    local y = (self.height - pipWidth) / 2

    local risk = modData.PhunSprinters and modData.PhunSprinters.risk or 0
    local baseline = 0
    local steps = 100 / count

    for i = 1, count do

        if risk >= baseline + steps then
            self:drawRect(x, y, pipWidth, pipWidth, self.displayColor.a, self.displayColor.r, self.displayColor.g,
                self.displayColor.b);
        elseif risk >= baseline then
            self:drawRect(x, y, pipWidth, pipWidth, self.ghostColor.a, self.ghostColor.r, self.ghostColor.g,
                self.ghostColor.b);
            self:drawRect(x, y, pipWidth * ((risk - baseline) / steps), pipWidth, self.displayColor.a,
                self.displayColor.r, self.displayColor.g, self.displayColor.b);
        else
            self:drawRect(x, y, pipWidth, pipWidth, self.ghostColor.a, self.ghostColor.r, self.ghostColor.g,
                self.ghostColor.b);
            -- self:drawRectBorder(x, y, pipWidth, pipWidth, self.displayColor.a, self.displayColor.r, self.displayColor.g,
            --     self.displayColor.b);
        end
        baseline = baseline + steps
        x = x + pipWidth + tools.FONT_SCALE
    end
    self:updateTooltip()
end

function UI:updateTooltip()
    if self.mouseOver and self.tooltip then
        self.tooltip:setVisible(true)
        self.tooltip:addToUIManager()
        self.tooltip:setX(self:getAbsoluteX() - self.tooltip:getWidth())
        self.tooltip:setName(PS.sprint and getText("IGUI_PhunSprinters_ZedsAreRestless") or
                                 getText("IGUI_PhunSprinters_ZedsAreSettling"))
        local txt = self.desc and self.desc(self.player) or ""
        self.tooltip.description = txt
    else
        self.tooltip:setVisible(false)
        self.tooltip:removeFromUIManager()
    end
end
