--[[
  FitCraft - Alerts
  Raid-warning style announcement, the "did you do your set?" checklist,
  and the live in-flight mobility panel.
]]

local ADDON, ns = ...
local A = {}
ns.Alert = A

local format = string.format

local DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local MOTIVATION = {
  "Pause the game. Your body is the real main.",
  "Mobs can wait. Gains can't.",
  "Every rep is a point of real-life Stamina.",
  "Even Thrall started with push-ups.",
  "No addon can carry you through this one.",
  "Form over speed. Breathe.",
}

---------------------------------------------------------------------------
-- Raid warning text + sound
---------------------------------------------------------------------------
function A:Warn(title, body)
  local s = ns.db.settings
  if s.raidWarning then
    if RaidNotice_AddMessage and RaidWarningFrame then
      local color = ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.28, b = 0 }
      RaidNotice_AddMessage(RaidWarningFrame, title, color)
      if body then RaidNotice_AddMessage(RaidWarningFrame, body, color) end
    else
      UIErrorsFrame:AddMessage(title, 1, 0.3, 0.1)
    end
  end
  if s.sound then
    PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
  end
  if s.chatEcho then
    ns:Print("|cffff7f3f" .. title .. "|r" .. (body and (" - " .. body) or ""))
  end
end

---------------------------------------------------------------------------
-- Shared movable dialog helper
---------------------------------------------------------------------------
local function MakeMovable(frame, posKey)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.settings[posKey] = { point, relPoint, x, y }
  end)
end

local function RestorePosition(frame, posKey, defPoint, defX, defY)
  frame:ClearAllPoints()
  local p = ns.db and ns.db.settings[posKey]
  if p then
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    frame:SetPoint(defPoint, UIParent, defPoint, defX, defY)
  end
end

function A:ResetPositions()
  ns.db.settings.checklistPos = nil
  ns.db.settings.flightPos = nil
  if self.checklist then RestorePosition(self.checklist, "checklistPos", "TOP", 0, -190) end
  if self.flight then RestorePosition(self.flight, "flightPos", "TOP", 0, -110) end
end

---------------------------------------------------------------------------
-- Checklist
---------------------------------------------------------------------------
local MAX_ROWS = 12
local ROW_H = 26

function A:BuildChecklist()
  if self.checklist then return self.checklist end
  local f = CreateFrame("Frame", "FitCraftChecklist", UIParent, "BackdropTemplate")
  f:SetSize(400, 200)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop(DIALOG_BACKDROP)
  f:Hide()
  MakeMovable(f, "checklistPos")
  RestorePosition(f, "checklistPos", "TOP", 0, -190)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(36, 36)
  f.icon:SetPoint("TOPLEFT", 18, -18)
  f.icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2)
  f.title:SetPoint("RIGHT", -20, 0)
  f.title:SetJustifyH("LEFT")

  f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.sub:SetPoint("RIGHT", -20, 0)
  f.sub:SetJustifyH("LEFT")

  f.motto = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.motto:SetPoint("TOPLEFT", 22, -62)
  f.motto:SetPoint("RIGHT", -20, 0)
  f.motto:SetJustifyH("LEFT")

  f.rows = {}
  for i = 1, MAX_ROWS do
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 22, -80 - (i - 1) * ROW_H)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.label:SetJustifyH("LEFT")
    cb:SetScript("OnClick", function(self)
      if self.item then self.item.checked = self:GetChecked() and true or false end
      A:UpdateChecklistLabels()
    end)
    f.rows[i] = cb
  end

  local function Btn(text, w, onClick, tip)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(w, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tip then
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", GameTooltip_Hide)
    end
    return b
  end

  f.allBtn  = Btn("All done!", 92, function() ns:ResolveCurrent("all") end, "Log every exercise on this list as completed.")
  f.doneBtn = Btn("Log checked", 92, function() ns:ResolveCurrent("done") end, "Log the checked exercises. Unchecked ones are recorded as skipped.")
  f.skipBtn = Btn("Skip", 70, function() ns:ResolveCurrent("skip") end, "Skip this reminder. It's recorded as skipped in your history.")
  f.laterBtn = Btn("Later", 70, function() ns:Snooze() end, "Hide for now. Reopen with right-click on the minimap button or /fit pending.")

  f.allBtn:SetPoint("BOTTOMLEFT", 20, 18)
  f.doneBtn:SetPoint("LEFT", f.allBtn, "RIGHT", 6, 0)
  f.skipBtn:SetPoint("LEFT", f.doneBtn, "RIGHT", 6, 0)
  f.laterBtn:SetPoint("LEFT", f.skipBtn, "RIGHT", 6, 0)

  self.checklist = f
  return f
end

function A:UpdateChecklistLabels()
  local f = self.checklist
  if not f or not f.pending then return end
  local anyChecked = false
  for _, cb in ipairs(f.rows) do
    if cb:IsShown() and cb.item then
      local done = cb.item.checked
      anyChecked = anyChecked or done
      cb.label:SetText((done and "|cff55ff55" or "|cffffffff") .. ns:DescribeItem(cb.item, f.pending.count) .. "|r")
    end
  end
  if anyChecked then f.doneBtn:Enable() else f.doneBtn:Disable() end
end

function A:ShowChecklist(p, queueSize)
  local f = self:BuildChecklist()
  f.pending = p
  local info = ns.TRIGGER_INFO[p.key]
  local title = info and info.label or p.key
  if p.count > 1 then title = title .. "  |cffffffffx" .. p.count .. "|r" end
  if p.test then title = title .. "  |cff999999(test)|r" end
  f.title:SetText(title)

  local sub = p.note and (p.note .. "  ") or ""
  if queueSize > 1 then sub = sub .. format("|cffff8080%d more reminder(s) waiting|r", queueSize - 1) end
  if sub == "" then sub = "Check off each exercise as you finish it." end
  f.sub:SetText(sub)
  f.motto:SetText(MOTIVATION[math.random(#MOTIVATION)])

  local n = math.min(#p.items, MAX_ROWS)
  for i, cb in ipairs(f.rows) do
    local it = p.items[i]
    if i <= n and it then
      cb.item = it
      cb:SetChecked(it.checked)
      cb:Show()
    else
      cb.item = nil
      cb:Hide()
    end
  end
  f:SetHeight(80 + n * ROW_H + 56)
  self:UpdateChecklistLabels()
  f:Show()
end

function A:HideChecklist()
  if self.checklist then self.checklist:Hide() end
end

---------------------------------------------------------------------------
-- Flight panel
---------------------------------------------------------------------------
function A:BuildFlightPanel()
  if self.flight then return self.flight end
  local f = CreateFrame("Frame", "FitCraftFlightPanel", UIParent, "BackdropTemplate")
  f:SetSize(280, 120)
  f:SetFrameStrata("HIGH")
  f:SetBackdrop(DIALOG_BACKDROP)
  f:Hide()
  MakeMovable(f, "flightPos")
  RestorePosition(f, "flightPos", "TOP", 0, -110)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", 0, -18)
  f.title:SetText("IN FLIGHT - KEEP MOVING!")

  f.timer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  f.timer:SetTextColor(1, 1, 1)
  f.timer:SetPoint("TOP", f.title, "BOTTOM", 0, -6)

  f.list = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.list:SetPoint("TOP", f.timer, "BOTTOM", 0, -6)
  f.list:SetWidth(240)
  f.list:SetJustifyH("CENTER")

  f.elapsed = 0
  f:SetScript("OnUpdate", function(self, el)
    self.elapsed = self.elapsed + el
    if self.elapsed < 0.25 then return end
    self.elapsed = 0
    if self.startTime then
      self.timer:SetText(ns.FormatDuration(GetTime() - self.startTime))
    end
  end)
  self.flight = f
  return f
end

function A:ShowFlight(startTime)
  local f = self:BuildFlightPanel()
  f.startTime = startTime
  local trig = ns.db.triggers.FLIGHT
  local lines = {}
  for _, it in ipairs(trig.items) do
    local ex = ns.db.exercises[it.ex]
    if ex and not ex.archived then
      if ex.unit == "sec" and (it.amount or 0) == 0 then
        lines[#lines + 1] = ex.name .. " until you land"
      else
        lines[#lines + 1] = ns:DescribeItem(it, 1)
      end
    end
  end
  f.list:SetText(table.concat(lines, "\n"))
  f:SetHeight(80 + math.max(1, #lines) * 14)
  f.timer:SetText("0s")
  f:Show()
end

function A:HideFlight()
  if self.flight then
    self.flight.startTime = nil
    self.flight:Hide()
  end
end
