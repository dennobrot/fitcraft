--[[
  FitCraft - Minimap button (library-free, LibDBIcon-style layout) and slash commands.
]]

local ADDON, ns = ...
local M = {}
ns.Minimap = M

local RADIUS = 80

local function UpdatePosition(btn)
  local angle = math.rad(ns.db.settings.minimap.angle or 215)
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function OnDragUpdate(self)
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  ns.db.settings.minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
  UpdatePosition(self)
end

function M:Build()
  if self.button then return self.button end
  local b = CreateFrame("Button", "FitCraftMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local overlay = b:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetPoint("TOPLEFT", 7, -6)
  b.icon = icon

  b.badge = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.badge:SetPoint("BOTTOMRIGHT", -2, 3)
  b.badge:SetTextColor(1, 0.25, 0.25)

  b:SetScript("OnClick", function(self, button)
    GameTooltip:Hide()
    if button == "RightButton" then
      if IsShiftKeyDown() then
        M:TogglePause()
      else
        ns:OpenPending()
      end
    else
      ns.UI:Toggle()
    end
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", OnDragUpdate)
    GameTooltip:Hide()
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff33ff99FitCraft|r")
    if ns.db.settings.paused then
      GameTooltip:AddLine("Reminders PAUSED (rest day)", 1, 0.3, 0.3)
    end
    GameTooltip:AddDoubleLine("Today (this char):", ns:TodaySummary(ns.charKey), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Today (all chars):", ns:TodaySummary(), 1, 0.82, 0, 1, 1, 1)
    local reps, secs = ns:SumTotals(ns:GetAccountTotals())
    GameTooltip:AddDoubleLine("Lifetime:", ns.FormatNumber(reps) .. " reps, " .. ns.FormatDuration(secs), 1, 0.82, 0, 1, 1, 1)
    if #ns.queue > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(#ns.queue .. " pending reminder(s)!", 1, 0.4, 0.4)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open window", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click: pending sets", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift+right-click: pause / resume", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)

  self.button = b
  UpdatePosition(b)
  return b
end

function M:TogglePause()
  local s = ns.db.settings
  s.paused = not s.paused
  ns:Print(s.paused and "Reminders |cffff5555paused|r. Enjoy your rest day." or "Reminders |cff55ff55active|r. Let's get it!")
  ns:NotifyChanged()
end

function M:Update()
  local b = self.button
  if not b then return end
  if ns.db.settings.minimap.hide then b:Hide() else b:Show() end
  b.icon:SetDesaturated(ns.db.settings.paused and true or false)
  local n = #ns.queue
  b.badge:SetText(n > 0 and tostring(n) or "")
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_FITCRAFT1 = "/fit"
SLASH_FITCRAFT2 = "/fitcraft"
SlashCmdList.FITCRAFT = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" then
    ns.UI:Toggle()
  elseif cmd == "pending" or cmd == "p" then
    ns:OpenPending()
  elseif cmd == "pause" then
    M:TogglePause()
  elseif cmd == "minimap" then
    ns.db.settings.minimap.hide = not ns.db.settings.minimap.hide
    M:Update()
  elseif cmd == "test" then
    local key = arg:upper()
    if ns.TRIGGER_INFO[key] and key ~= "MANUAL" then
      ns:FireTrigger(key, { duration = 90, note = "Test" }, true)
    else
      local keys = {}
      for _, t in ipairs(ns.TRIGGERS) do keys[#keys + 1] = t.key:lower() end
      ns:Print("Usage: /fit test <" .. table.concat(keys, "|") .. ">")
    end
  elseif ns.UI.pages and ns.UI.pages[cmd] then
    ns.UI:Toggle(cmd)
  else
    ns:Print("Commands: /fit (window), /fit pending, /fit pause, /fit minimap, /fit test <event>")
  end
end
