if isServer() then
    return
end
local tools = require "PhunSprintersUI/ui/tools"
local Core = PhunSprintersUI
local PS = PhunSprinters
local PL = PhunLib
local profileName = "PhunSprintersUIMoon"
PhunSprintersUIMoon = ISPanelJoypad:derive(profileName);
local UI = PhunSprintersUIMoon
local RNC = RewardingNightCombat or {}
Core.ui = Core.ui or {}
Core.ui.wearables = Core.ui.wearables or {}

local textures = {getTexture("media/ui/moon0.png"), getTexture("media/ui/moon1.png"), getTexture("media/ui/moon2.png"),
                  getTexture("media/ui/moon3.png"), getTexture("media/ui/moon4.png"), getTexture("media/ui/moon5.png"),
                  getTexture("media/ui/moon6.png"), getTexture("media/ui/moon7.png")}

function UI:new(x, y, width, height, player, playerIndex)
    local opts = options or {}
    local o = ISPanelJoypad:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;

    o.ghostColor = {
        r = .15,
        g = .15,
        b = .15,
        a = 0.5
    }
    o.displayColor = {
        r = .39,
        g = .78,
        b = .82,
        a = 1
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

function UI:prerender()
    ISPanelJoypad.prerender(self);

    local t = textures

    local modData = self.player:getModData();

    if modData.PhunSprinters and modData.PhunSprinters.moonPhase then
        self:drawTextureScaled(t[modData.PhunSprinters.moonPhase + 1], 0, 0, self.width, self.height,
            self.displayColor.a, self.displayColor.r, self.displayColor.g, self.displayColor.b);
    end

    self:updateTooltip()
end

function UI:createChildren()
    ISPanelJoypad.createChildren(self)

    local padding = 10 * tools.FONT_SCALE
    local x = 0
    local y = 0
    local w = self.width
    local h = self.height

    self.controls = {}

    local t = textures
    local moon = ISImage:new(x, y, self.height - 2 * tools.FONT_SCALE, self.height - 2 * tools.FONT_SCALE,
        t.sprinting_on);

    moon.scaledWidth = moon.width
    moon.scaledHeight = moon.height

    moon:initialise();
    moon:instantiate();
    self.controls.moon = moon
    self:addChild(self.controls.moon);

    self.tooltip = ISToolTip:new();
    self.tooltip:initialise();
    self.tooltip:setVisible(false);
    self.tooltip:setName("");
    self.tooltip:setAlwaysOnTop(true)
    self.tooltip.description = "";
    self.tooltip:setOwner(moon)

end

function UI:onMouseMove(x, y)
    ISPanelJoypad.onMouseMove(self, x, y)
    self.mouseOver = true
end

function UI:onMouseMoveOutside(x, y)
    ISPanelJoypad.onMouseMoveOutside(self, x, y)
    self.mouseOver = false
end

function UI:updateTooltip()
    if self.mouseOver and self.tooltip then
        self.tooltip:setVisible(true)
        self.tooltip:addToUIManager()
        self.tooltip:setX(self:getAbsoluteX() - self.tooltip:getWidth())
        self.tooltip:setName(getText("IGUI_PhunSprinters_MoonPhase" ..
                                         (self.player:getModData().PhunSprinters.moonPhase or 0)))
        local txt = self.desc and self.desc(self.player) or ""
        self.tooltip.description = txt
    else
        self.tooltip:setVisible(false)
        self.tooltip:removeFromUIManager()
    end
end

