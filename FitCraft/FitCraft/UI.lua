--[[
  FitCraft - Main window
  Tabs: Setup | Exercises | History | Totals | Characters | Options
  Built from plain Blizzard templates only (no libraries, no UIDropDownMenu taint).
]]

local ADDON, ns = ...
local UI = {}
ns.UI = UI

local format, floor, max, min = string.format, math.floor, math.max, math.min

local MAIN_W, MAIN_H = 700, 500
local PAGE_W, PAGE_H = MAIN_W - 40, MAIN_H - 112

local DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local PANEL_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------
local nameCounter = 0
local function NextName(prefix)
  nameCounter = nameCounter + 1
  return "FitCraft" .. prefix .. nameCounter
end

local function Text(parent, template, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  if text then fs:SetText(text) end
  return fs
end

local function Button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 100, h or 22)
  b:SetText(text)
  return b
end

local function Tooltip(frame, text)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function Check(parent, label, tip)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb.label = Text(cb, "GameFontHighlight", label)
  cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  if tip then Tooltip(cb, tip) end
  return cb
end

-- onCommit(text) is called when the box loses focus (Enter / click away)
local function EditBox(parent, w, numeric, onCommit)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(w, 20)
  e:SetAutoFocus(false)
  if numeric then
    e:SetNumeric(true)
    e:SetMaxLetters(6)
    e:SetJustifyH("CENTER")
  else
    e:SetMaxLetters(40)
  end
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  if onCommit then
    e:SetScript("OnEditFocusLost", function(self) onCommit(self, self:GetText()) end)
  end
  return e
end

local function ScrollArea(parent, w, h)
  local sf = CreateFrame("ScrollFrame", NextName("Scroll"), parent, "UIPanelScrollFrameTemplate")
  sf:SetSize(w, h)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(w, 1)
  sf:SetScrollChild(content)
  sf.content = content
  return sf
end

local function Panel(parent)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  p:SetBackdrop(PANEL_BACKDROP)
  p:SetBackdropColor(0, 0, 0, 0.55)
  p:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
  return p
end

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not c then return "ffffffff" end
  return format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end
UI.ClassColor = ClassColor

---------------------------------------------------------------------------
-- Lightweight popup menu (replacement for UIDropDownMenu)
---------------------------------------------------------------------------
local menu
local MENU_ROW = 18

local function BuildMenu()
  menu = CreateFrame("Frame", "FitCraftMenu", UIParent, "BackdropTemplate")
  menu:SetBackdrop(PANEL_BACKDROP)
  menu:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu:Hide()
  menu.buttons = {}
end

function UI:CloseMenu()
  if menu then menu:Hide() end
end

-- items = { { text = "...", value = any }, ... }
function UI:OpenMenu(anchor, items, onSelect)
  if not menu then BuildMenu() end
  if menu:IsShown() and menu.anchor == anchor then menu:Hide() return end
  menu.anchor = anchor
  local w = max(anchor:GetWidth(), 160)
  for i, item in ipairs(items) do
    local b = menu.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, menu)
      b:SetHeight(MENU_ROW)
      b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      b.text = Text(b, "GameFontHighlightSmall")
      b.text:SetPoint("LEFT", 6, 0)
      b.text:SetPoint("RIGHT", -6, 0)
      menu.buttons[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * MENU_ROW)
    b:SetWidth(w - 12)
    b.text:SetText(item.text)
    b:SetScript("OnClick", function()
      menu:Hide()
      onSelect(item.value)
    end)
    b:Show()
  end
  for i = #items + 1, #menu.buttons do menu.buttons[i]:Hide() end
  menu:SetSize(w, 12 + max(1, #items) * MENU_ROW)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:Show()
end

local function Dropdown(parent, w, getItems, onSelect)
  local b = Button(parent, "", w, 22)
  local fs = b:GetFontString()
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", 8, 0)
  fs:SetPoint("RIGHT", -20, 0)
  fs:SetJustifyH("LEFT")
  local arrow = b:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  arrow:SetSize(16, 16)
  arrow:SetPoint("RIGHT", -3, 0)
  b:SetScript("OnClick", function(self) UI:OpenMenu(self, getItems(), function(v) onSelect(self, v) end) end)
  return b
end

local function ExerciseMenuItems()
  local items = {}
  for _, id in ipairs(ns:SortedExerciseIds()) do
    local e = ns.db.exercises[id]
    items[#items + 1] = { text = format("%s |cff999999(%s)|r", e.name, e.unit == "sec" and "seconds" or "reps"), value = id }
  end
  return items
end

---------------------------------------------------------------------------
-- Simple data table (header + scrolling rows)
-- cols = { { title, w, j } }
---------------------------------------------------------------------------
local ROW_H = 17

local function CreateTable(parent, cols, w, h)
  local t = {}
  t.header = CreateFrame("Frame", nil, parent)
  t.header:SetSize(w, 18)
  local hbg = t.header:CreateTexture(nil, "BACKGROUND")
  hbg:SetAllPoints()
  hbg:SetColorTexture(1, 0.82, 0, 0.12)
  local x = 0
  for _, c in ipairs(cols) do
    local fs = Text(t.header, "GameFontNormalSmall", c[1])
    fs:SetPoint("LEFT", x + 4, 0)
    fs:SetWidth(c[2] - 8)
    fs:SetJustifyH(c[3] or "LEFT")
    x = x + c[2]
  end
  t.scroll = ScrollArea(parent, w - 22, h - 20)
  t.scroll:SetPoint("TOPLEFT", t.header, "BOTTOMLEFT", 0, -2)
  t.rows = {}

  function t:SetPoint(...) self.header:SetPoint(...) end

  function t:SetRows(data)
    local content = self.scroll.content
    for i, d in ipairs(data) do
      local r = self.rows[i]
      if not r then
        r = CreateFrame("Frame", nil, content)
        r:SetSize(w - 22, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        if i % 2 == 0 then
          local bg = r:CreateTexture(nil, "BACKGROUND")
          bg:SetAllPoints()
          bg:SetColorTexture(1, 1, 1, 0.04)
        end
        r.cells = {}
        local cx = 0
        for j, c in ipairs(cols) do
          local fs = Text(r, "GameFontHighlightSmall")
          fs:SetPoint("LEFT", cx + 4, 0)
          fs:SetWidth(c[2] - 8)
          fs:SetJustifyH(c[3] or "LEFT")
          fs:SetWordWrap(false)
          r.cells[j] = fs
          cx = cx + c[2]
        end
        self.rows[i] = r
      end
      for j = 1, #cols do r.cells[j]:SetText(d[j] or "") end
      r:Show()
    end
    for i = #data + 1, #self.rows do self.rows[i]:Hide() end
    content:SetHeight(max(1, #data * ROW_H))
  end
  return t
end

local function Confirm(text, onAccept)
  StaticPopupDialogs["FITCRAFT_CONFIRM"] = StaticPopupDialogs["FITCRAFT_CONFIRM"] or {
    text = "%s", button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(self, data) if data then data() end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show("FITCRAFT_CONFIRM", text, nil, onAccept)
end

---------------------------------------------------------------------------
-- Page: Setup (event -> exercises)
---------------------------------------------------------------------------
local function BuildSetup(page)
  local selected = ns.TRIGGERS[1].key

  local list = Panel(page)
  list:SetPoint("TOPLEFT", 0, 0)
  list:SetSize(200, PAGE_H)

  local trigRows = {}
  for i, t in ipairs(ns.TRIGGERS) do
    local r = CreateFrame("Button", nil, list)
    r:SetSize(190, 28)
    r:SetPoint("TOPLEFT", 5, -6 - (i - 1) * 30)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.sel:SetColorTexture(1, 0.82, 0, 0.2)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    r.cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.cb:SetSize(24, 24)
    r.cb:SetPoint("LEFT", 2, 0)
    r.cb:SetScript("OnClick", function(self)
      ns.db.triggers[t.key].enabled = self:GetChecked() and true or false
      page:Refresh()
    end)
    Tooltip(r.cb, "Enable / disable this trigger")
    r.fs = Text(r, "GameFontHighlight", t.label)
    r.fs:SetPoint("LEFT", r.cb, "RIGHT", 2, 0)
    r.count = Text(r, "GameFontDisableSmall")
    r.count:SetPoint("RIGHT", -6, 0)
    r.key = t.key
    r:SetScript("OnClick", function() selected = t.key; UI:CloseMenu(); page:Refresh() end)
    trigRows[i] = r
  end

  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", list, "TOPRIGHT", 14, 0)
  right:SetPoint("BOTTOMRIGHT", 0, 0)
  local RW = PAGE_W - 214

  local title = Text(right, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 0, -4)
  local desc = Text(right, "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  desc:SetWidth(RW)

  local stack = Check(right, "Stack repeats into one reminder",
    "If this fires again while a reminder is still open, the sets are added to it (e.g. 3 quests = 3 sets) instead of queueing a new popup.")
  stack:SetPoint("TOPLEFT", 0, -52)
  stack:SetScript("OnClick", function(self) ns.db.triggers[selected].stack = self:GetChecked() and true or false end)

  local qualLabel = Text(right, "GameFontNormalSmall", "Min quality:")
  qualLabel:SetPoint("TOPLEFT", 260, -58)
  local qualDD = Dropdown(right, 100, function()
    local items = {}
    for _, q in ipairs(ns.QUALITY) do items[#items + 1] = { text = "|cff" .. q.hex .. q.name .. "|r", value = q.q } end
    return items
  end, function(_, v) ns.db.triggers.LOOT.minQuality = v; page:Refresh() end)
  qualDD:SetPoint("LEFT", qualLabel, "RIGHT", 6, 0)

  local h1 = Text(right, "GameFontNormalSmall", "Exercise")
  h1:SetPoint("TOPLEFT", 4, -86)
  local h2 = Text(right, "GameFontNormalSmall", "Per set")
  h2:SetPoint("TOPLEFT", 196, -86)
  local h3 = Text(right, "GameFontNormalSmall", "Sets")
  h3:SetPoint("TOPLEFT", 296, -86)

  local sf = ScrollArea(right, RW - 24, 200)
  sf:SetPoint("TOPLEFT", 0, -102)

  local itemRows = {}
  local function CurItems() return ns.db.triggers[selected].items end

  local function GetItemRow(i)
    if itemRows[i] then return itemRows[i] end
    local r = CreateFrame("Frame", nil, sf.content)
    r:SetSize(RW - 24, 26)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * 28)

    r.dd = Dropdown(r, 180, ExerciseMenuItems, function(_, id)
      local it = CurItems()[r.index]
      if it then it.ex = id end
      page:Refresh()
    end)
    r.dd:SetPoint("LEFT", 0, 0)

    r.amount = EditBox(r, 50, true, function(_, txt)
      local it = CurItems()[r.index]
      if it then it.amount = tonumber(txt) or 0 end
    end)
    r.amount:SetPoint("LEFT", r.dd, "RIGHT", 14, 0)
    r.unit = Text(r, "GameFontHighlightSmall")
    r.unit:SetPoint("LEFT", r.amount, "RIGHT", 4, 0)
    r.unit:SetWidth(30)

    r.sets = EditBox(r, 32, true, function(self, txt)
      local it = CurItems()[r.index]
      if it then
        it.sets = max(1, tonumber(txt) or 1)
        self:SetText(tostring(it.sets))
      end
    end)
    r.sets:SetPoint("LEFT", r.unit, "RIGHT", 10, 0)

    r.del = Button(r, "Remove", 62, 20)
    r.del:SetPoint("LEFT", r.sets, "RIGHT", 10, 0)
    r.del:SetScript("OnClick", function()
      table.remove(CurItems(), r.index)
      page:Refresh()
    end)
    itemRows[i] = r
    return r
  end

  local addBtn = Button(right, "+ Add exercise", 120, 22)
  addBtn:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -8)
  addBtn:SetScript("OnClick", function()
    local ids = ns:SortedExerciseIds()
    if #ids == 0 then ns:Print("Create an exercise in the Exercises tab first.") return end
    table.insert(CurItems(), { ex = ids[1], amount = 10, sets = 1 })
    page:Refresh()
  end)

  local testBtn = Button(right, "Test reminder", 120, 22)
  testBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
  Tooltip(testBtn, "Preview this reminder. Tests are never logged.")
  testBtn:SetScript("OnClick", function()
    for _, r in ipairs(itemRows) do r.amount:ClearFocus(); r.sets:ClearFocus() end
    ns:FireTrigger(selected, { duration = 90, note = "Test" }, true)
  end)

  local hint = Text(right, "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -10)
  hint:SetWidth(RW)

  function page:Refresh()
    local db = ns.db
    local char = ns.char
    for _, r in ipairs(trigRows) do
      local trig = db.triggers[r.key]
      r.cb:SetChecked(trig.enabled)
      r.sel:SetShown(r.key == selected)
      if trig.enabled then r.fs:SetTextColor(1, 1, 1) else r.fs:SetTextColor(0.55, 0.55, 0.55) end
      local n = char and char.triggers[r.key]
      r.count:SetText(n and n > 0 and tostring(n) or "")
    end

    local info, trig = ns.TRIGGER_INFO[selected], db.triggers[selected]
    title:SetText(info.label .. (trig.enabled and "" or "  |cff999999(disabled)|r"))
    desc:SetText(info.desc)
    stack:SetChecked(trig.stack)

    local isLoot = selected == "LOOT"
    qualLabel:SetShown(isLoot)
    qualDD:SetShown(isLoot)
    if isLoot then
      for _, q in ipairs(ns.QUALITY) do
        if q.q == (trig.minQuality or 4) then qualDD:SetText("|cff" .. q.hex .. q.name .. "|r") end
      end
    end

    for i, it in ipairs(trig.items) do
      local r = GetItemRow(i)
      r.index = i
      local ex = db.exercises[it.ex]
      r.dd:SetText(ex and (ex.name .. (ex.archived and " (deleted)" or "")) or "(choose)")
      r.amount:SetText(tostring(it.amount or 0))
      r.unit:SetText(ex and ex.unit == "sec" and "sec" or "reps")
      r.sets:SetText(tostring(it.sets or 1))
      r:Show()
    end
    for i = #trig.items + 1, #itemRows do itemRows[i]:Hide() end
    sf.content:SetHeight(max(1, #trig.items * 28))

    if selected == "FLIGHT" then
      hint:SetText("Tip: set a 'seconds' exercise to 0 and it logs your actual flight time when you land. A live timer shows while you fly.")
    elseif #trig.items == 0 then
      hint:SetText("No exercises yet - click '+ Add exercise'.")
    else
      hint:SetText("Changes save automatically. Reps/seconds are per set.")
    end
  end
end

---------------------------------------------------------------------------
-- Page: Exercises (library)
---------------------------------------------------------------------------
local function BuildExercises(page)
  local intro = Text(page, "GameFontHighlightSmall",
    "Your exercise library. Add anything that fits your equipment and level. Use 'seconds' for holds, mobility or cardio.")
  intro:SetPoint("TOPLEFT", 0, -2)
  intro:SetWidth(PAGE_W)

  local hName = Text(page, "GameFontNormalSmall", "Name")
  hName:SetPoint("TOPLEFT", 6, -30)
  local hUnit = Text(page, "GameFontNormalSmall", "Unit")
  hUnit:SetPoint("TOPLEFT", 246, -30)
  local hTot = Text(page, "GameFontNormalSmall", "Lifetime (all characters)")
  hTot:SetPoint("TOPLEFT", 340, -30)

  local sf = ScrollArea(page, PAGE_W - 24, PAGE_H - 100)
  sf:SetPoint("TOPLEFT", 0, -46)
  local rows = {}

  local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, sf.content)
    r:SetSize(PAGE_W - 24, 26)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * 27)
    r.name = EditBox(r, 220, false, function(self, txt)
      local e = ns.db.exercises[r.id]
      txt = txt and txt:gsub("^%s+", ""):gsub("%s+$", "")
      if e and txt and txt ~= "" then e.name = txt else self:SetText(e and e.name or "") end
    end)
    r.name:SetPoint("LEFT", 8, 0)
    r.unit = Button(r, "", 80, 20)
    r.unit:SetPoint("LEFT", r.name, "RIGHT", 12, 0)
    r.unit:SetScript("OnClick", function()
      local e = ns.db.exercises[r.id]
      if e then e.unit = (e.unit == "sec") and "reps" or "sec" end
      ns:NotifyChanged()
    end)
    Tooltip(r.unit, "Toggle between counting reps and counting seconds.")
    r.total = Text(r, "GameFontHighlightSmall")
    r.total:SetPoint("LEFT", r.unit, "RIGHT", 14, 0)
    r.total:SetWidth(170)
    r.del = Button(r, "Delete", 62, 20)
    r.del:SetPoint("LEFT", r.total, "RIGHT", 6, 0)
    r.del:SetScript("OnClick", function()
      local e = ns.db.exercises[r.id]
      if not e then return end
      Confirm(format("Delete '%s'?\nIt is removed from all triggers. Lifetime totals and history are kept.", e.name),
        function() ns:DeleteExercise(r.id) end)
    end)
    rows[i] = r
    return r
  end

  local addLabel = Text(page, "GameFontNormal", "New exercise:")
  addLabel:SetPoint("BOTTOMLEFT", 2, 14)
  local newUnit = "reps"
  local newName = EditBox(page, 200, false)
  newName:SetPoint("LEFT", addLabel, "RIGHT", 12, 0)
  local unitBtn = Button(page, "reps", 80, 22)
  unitBtn:SetPoint("LEFT", newName, "RIGHT", 10, 0)
  unitBtn:SetScript("OnClick", function(self)
    newUnit = (newUnit == "reps") and "sec" or "reps"
    self:SetText(newUnit == "sec" and "seconds" or "reps")
  end)
  local addBtn = Button(page, "Add", 70, 22)
  addBtn:SetPoint("LEFT", unitBtn, "RIGHT", 8, 0)
  local function DoAdd()
    local id = ns:AddExercise(newName:GetText(), newUnit)
    if id then
      newName:SetText("")
      newName:ClearFocus()
      ns:Print("Added exercise: " .. ns.db.exercises[id].name)
    end
  end
  addBtn:SetScript("OnClick", DoAdd)
  newName:SetScript("OnEnterPressed", DoAdd)

  function page:Refresh()
    local totals = ns:GetAccountTotals()
    local ids = ns:SortedExerciseIds()
    for i, id in ipairs(ids) do
      local r = GetRow(i)
      r.id = id
      local e = ns.db.exercises[id]
      if not r.name:HasFocus() then r.name:SetText(e.name) end
      r.unit:SetText(e.unit == "sec" and "seconds" or "reps")
      local t = totals[id]
      r.total:SetText(t and format("%s  |cff999999(%d sets)|r", ns:FormatAmount(t.a, e.unit), t.s) or "|cff777777-|r")
      r:Show()
    end
    for i = #ids + 1, #rows do rows[i]:Hide() end
    sf.content:SetHeight(max(1, #ids * 27))
  end
end

---------------------------------------------------------------------------
-- Page: History
---------------------------------------------------------------------------
local HISTORY_SHOWN = 300

local function BuildHistory(page)
  local allChars = false
  local manualEx

  local logLabel = Text(page, "GameFontNormal", "Log a workout:")
  logLabel:SetPoint("TOPLEFT", 0, -6)
  local exDD = Dropdown(page, 170, ExerciseMenuItems, function(self, id)
    manualEx = id
    self:SetText(ns:ExerciseName(id))
    page.unitLbl:SetText(ns:ExerciseUnit(id) == "sec" and "sec" or "reps")
  end)
  exDD:SetPoint("LEFT", logLabel, "RIGHT", 8, 0)
  local amount = EditBox(page, 50, true)
  amount:SetPoint("LEFT", exDD, "RIGHT", 14, 0)
  amount:SetText("10")
  page.unitLbl = Text(page, "GameFontHighlightSmall", "reps")
  page.unitLbl:SetPoint("LEFT", amount, "RIGHT", 4, 0)
  local x = Text(page, "GameFontHighlightSmall", "x")
  x:SetPoint("LEFT", page.unitLbl, "RIGHT", 10, 0)
  local sets = EditBox(page, 32, true)
  sets:SetPoint("LEFT", x, "RIGHT", 10, 0)
  sets:SetText("1")
  local setsLbl = Text(page, "GameFontHighlightSmall", "sets")
  setsLbl:SetPoint("LEFT", sets, "RIGHT", 4, 0)
  local logBtn = Button(page, "Log it", 70, 22)
  logBtn:SetPoint("LEFT", setsLbl, "RIGHT", 10, 0)
  Tooltip(logBtn, "Did some extra work outside the game prompts? Log it here - it counts toward your totals.")
  logBtn:SetScript("OnClick", function()
    amount:ClearFocus(); sets:ClearFocus()
    local a, s = tonumber(amount:GetText()) or 0, max(1, tonumber(sets:GetText()) or 1)
    if not manualEx or not ns.db.exercises[manualEx] then ns:Print("Pick an exercise first.") return end
    if a <= 0 then ns:Print("Enter an amount above 0.") return end
    ns:LogItem("MANUAL", manualEx, a * s, s, false)
    ns:Print(format("Logged %s %s manually. Extra credit!", ns:FormatAmount(a * s, ns:ExerciseUnit(manualEx), true), ns:ExerciseName(manualEx)))
  end)

  local filter = Button(page, "", 190, 22)
  filter:SetPoint("TOPLEFT", 0, -36)
  filter:SetScript("OnClick", function() allChars = not allChars; page:Refresh() end)

  local summary = Text(page, "GameFontHighlightSmall")
  summary:SetPoint("LEFT", filter, "RIGHT", 12, 0)

  local tbl = CreateTable(page, {
    { "When", 90 }, { "Character", 110 }, { "Event", 130 }, { "Exercise", 150 }, { "Amount", 100, "RIGHT" }, { "Status", 70, "CENTER" },
  }, PAGE_W, PAGE_H - 66)
  tbl:SetPoint("TOPLEFT", 0, -66)

  function page:Refresh()
    if not manualEx or not ns.db.exercises[manualEx] or ns.db.exercises[manualEx].archived then
      manualEx = ns:SortedExerciseIds()[1]
    end
    exDD:SetText(manualEx and ns:ExerciseName(manualEx) or "(none)")
    page.unitLbl:SetText(manualEx and ns:ExerciseUnit(manualEx) == "sec" and "sec" or "reps")
    filter:SetText(allChars and "Showing: All characters" or "Showing: This character")

    local rows = {}
    local h = ns.db.history
    local done, skipped = 0, 0
    for i = #h, 1, -1 do
      local e = h[i]
      if allChars or e.c == ns.charKey then
        if e.x then skipped = skipped + 1 else done = done + 1 end
        if #rows < HISTORY_SHOWN then
          local c = ns.db.chars[e.c]
          local cname = (e.c or "?"):match("^[^-]+") or "?"
          local info = ns.TRIGGER_INFO[e.k]
          rows[#rows + 1] = {
            date("%m/%d %H:%M", e.t),
            "|c" .. ClassColor(c and c.class) .. cname .. "|r",
            info and info.label or e.k or "?",
            ns:ExerciseName(e.ex, e.n),
            ns:FormatAmount(e.a or 0, e.u),
            e.x and "|cffff5555Skipped|r" or "|cff55ff55Done|r",
          }
        end
      end
    end
    summary:SetText(format("%d done, %d skipped%s", done, skipped, (done + skipped > HISTORY_SHOWN) and format(" (latest %d shown)", HISTORY_SHOWN) or ""))
    tbl:SetRows(rows)
  end
end

---------------------------------------------------------------------------
-- Page: Totals (account-wide)
---------------------------------------------------------------------------
local function BuildTotals(page)
  local box = Panel(page)
  box:SetPoint("TOPLEFT", 0, 0)
  box:SetSize(PAGE_W, 92)

  local big = Text(box, "GameFontNormalLarge")
  big:SetPoint("TOPLEFT", 12, -12)
  local line1 = Text(box, "GameFontHighlight")
  line1:SetPoint("TOPLEFT", big, "BOTTOMLEFT", 0, -8)
  local line2 = Text(box, "GameFontHighlightSmall")
  line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -6)
  line2:SetWidth(PAGE_W - 24)

  local tbl = CreateTable(page, {
    { "Exercise", 200 }, { "Lifetime", 140, "RIGHT" }, { "Sets", 70, "RIGHT" }, { "Today", 110, "RIGHT" }, { "Last 7 days", 116, "RIGHT" },
  }, PAGE_W, PAGE_H - 102)
  tbl:SetPoint("TOPLEFT", 0, -102)

  function page:Refresh()
    local totals = ns:GetAccountTotals()
    local today = ns:GetPeriodTotals(ns.StartOfToday())
    local week = ns:GetPeriodTotals(time() - 7 * 86400)
    local reps, secs = ns:SumTotals(totals)
    local s = ns:GetAccountSessions()
    local all = s.done + s.partial + s.skipped
    local nChars = 0
    for _ in pairs(ns.db.chars) do nChars = nChars + 1 end

    big:SetText(format("All characters: |cffffffff%s reps|r  +  |cffffffff%s|r timed", ns.FormatNumber(reps), ns.FormatDuration(secs)))
    line1:SetText(format("Reminders: |cff55ff55%d done|r, |cffffd100%d partial|r, |cffff5555%d skipped|r   -   completion rate |cffffffff%d%%|r",
      s.done, s.partial, s.skipped, all > 0 and floor((s.done + s.partial * 0.5) / all * 100 + 0.5) or 0))
    line2:SetText(format("Characters tracked: %d.   Today: %s.", nChars, ns:TodaySummary()))

    local ids = {}
    for id in pairs(totals) do ids[#ids + 1] = id end
    for id in pairs(week) do if not totals[id] then ids[#ids + 1] = id end end
    table.sort(ids, function(a, b) return (totals[a] and totals[a].a or 0) > (totals[b] and totals[b].a or 0) end)

    local rows = {}
    for _, id in ipairs(ids) do
      local u = ns:ExerciseUnit(id)
      local t, td, wk = totals[id], today[id], week[id]
      rows[#rows + 1] = {
        ns:ExerciseName(id) .. (ns.db.exercises[id] and ns.db.exercises[id].archived and " |cff777777(deleted)|r" or ""),
        t and ns:FormatAmount(t.a, u) or "-",
        t and tostring(t.s) or "-",
        td and ns:FormatAmount(td.a, u) or "|cff777777-|r",
        wk and ns:FormatAmount(wk.a, u) or "|cff777777-|r",
      }
    end
    if #rows == 0 then rows[1] = { "|cff999999Nothing logged yet - go turn in a quest!|r" } end
    tbl:SetRows(rows)
  end
end

---------------------------------------------------------------------------
-- Page: Characters
---------------------------------------------------------------------------
local function BuildCharacters(page)
  local selected

  local list = Panel(page)
  list:SetPoint("TOPLEFT", 0, 0)
  list:SetSize(200, PAGE_H)
  local lsf = ScrollArea(list, 170, PAGE_H - 12)
  lsf:SetPoint("TOPLEFT", 6, -6)
  local charBtns = {}

  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", list, "TOPRIGHT", 14, 0)
  right:SetPoint("BOTTOMRIGHT")
  local RW = PAGE_W - 214

  local name = Text(right, "GameFontNormalLarge")
  name:SetPoint("TOPLEFT", 0, -4)
  local info = Text(right, "GameFontHighlightSmall")
  info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
  info:SetWidth(RW)
  local trig = Text(right, "GameFontDisableSmall")
  trig:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -6)
  trig:SetWidth(RW)

  local tbl = CreateTable(right, {
    { "Exercise", 190 }, { "Lifetime", 140, "RIGHT" }, { "Sets", 60, "RIGHT" }, { "Today", 56, "RIGHT" },
  }, RW, PAGE_H - 132)
  tbl:SetPoint("TOPLEFT", 0, -100)

  local resetBtn = Button(right, "Reset character", 130, 22)
  resetBtn:SetPoint("BOTTOMRIGHT", 0, 0)
  resetBtn:SetScript("OnClick", function()
    if not selected then return end
    local isMe = selected == ns.charKey
    Confirm(format("%s all FitCraft data for %s?\nThis cannot be undone.", isMe and "Reset" or "Delete", selected), function()
      ns:DeleteChar(selected)
      if not isMe then selected = ns.charKey end
    end)
  end)

  function page:Refresh()
    local keys = {}
    for k in pairs(ns.db.chars) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if a == ns.charKey then return true elseif b == ns.charKey then return false end
      return (ns.db.chars[a].lastSeen or 0) > (ns.db.chars[b].lastSeen or 0)
    end)
    if not selected or not ns.db.chars[selected] then selected = ns.charKey end

    for i, k in ipairs(keys) do
      local b = charBtns[i]
      if not b then
        b = CreateFrame("Button", nil, lsf.content)
        b:SetSize(168, 34)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 36)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b.sel = b:CreateTexture(nil, "BACKGROUND")
        b.sel:SetAllPoints()
        b.sel:SetColorTexture(1, 0.82, 0, 0.2)
        b.n = Text(b, "GameFontNormal")
        b.n:SetPoint("TOPLEFT", 6, -3)
        b.d = Text(b, "GameFontDisableSmall")
        b.d:SetPoint("TOPLEFT", b.n, "BOTTOMLEFT", 0, -2)
        b:SetScript("OnClick", function(self) selected = self.key; page:Refresh() end)
        charBtns[i] = b
      end
      local c = ns.db.chars[k]
      b.key = k
      b.n:SetText("|c" .. ClassColor(c.class) .. (c.name or k) .. "|r")
      local reps = ns:SumTotals(c.totals or {})
      b.d:SetText(format("Lvl %d  %s  -  %s reps", c.level or 0, c.realm or "", ns.FormatNumber(reps)))
      b.sel:SetShown(k == selected)
      b:Show()
    end
    for i = #keys + 1, #charBtns do charBtns[i]:Hide() end
    lsf.content:SetHeight(max(1, #keys * 36))

    local c = ns.db.chars[selected]
    if not c then return end
    local reps, secs = ns:SumTotals(c.totals or {})
    local s = c.sessions or { done = 0, partial = 0, skipped = 0 }
    name:SetText(format("|c%s%s|r  |cffaaaaaa- level %d %s|r", ClassColor(c.class), c.name or selected, c.level or 0, c.realm or ""))
    info:SetText(format("Lifetime: |cffffffff%s reps|r + |cffffffff%s|r timed.   Reminders: %d done, %d partial, %d skipped.   Today: %s",
      ns.FormatNumber(reps), ns.FormatDuration(secs), s.done, s.partial, s.skipped, ns:TodaySummary(selected)))

    local parts = {}
    for _, t in ipairs(ns.TRIGGERS) do
      local n = c.triggers and c.triggers[t.key]
      if n and n > 0 then parts[#parts + 1] = format("%s: %d", t.label, n) end
    end
    trig:SetText(#parts > 0 and ("Events triggered - " .. table.concat(parts, ",  ")) or "No events triggered yet.")

    local today = ns:GetPeriodTotals(ns.StartOfToday(), selected)
    local ids = {}
    for id in pairs(c.totals or {}) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return c.totals[a].a > c.totals[b].a end)
    local rows = {}
    for _, id in ipairs(ids) do
      local u, t = ns:ExerciseUnit(id), c.totals[id]
      rows[#rows + 1] = {
        ns:ExerciseName(id),
        ns:FormatAmount(t.a, u),
        tostring(t.s),
        today[id] and ns:FormatAmount(today[id].a, u, true) or "|cff777777-|r",
      }
    end
    if #rows == 0 then rows[1] = { "|cff999999No exercises logged yet.|r" } end
    tbl:SetRows(rows)
    resetBtn:SetText(selected == ns.charKey and "Reset character" or "Delete character")
  end
end

---------------------------------------------------------------------------
-- Page: Options
---------------------------------------------------------------------------
local function BuildOptions(page)
  local opts = {
    { key = "paused",      label = "Pause all reminders (rest day)", tip = "Nothing fires while paused. Shift+right-click the minimap button to toggle." },
    { key = "raidWarning", label = "Show big raid-warning text", tip = "Announce each trigger in the middle of the screen like a raid warning." },
    { key = "sound",       label = "Play raid warning sound" },
    { key = "deferCombat", label = "Wait until combat ends before reminding me", tip = "Triggers that happen in combat are queued until you're safe." },
    { key = "flightPanel", label = "Show live timer panel while on a flight path" },
    { key = "chatEcho",    label = "Echo reminders and logs in chat" },
  }
  local cbs = {}
  for i, o in ipairs(opts) do
    local cb = Check(page, o.label, o.tip)
    cb:SetPoint("TOPLEFT", 0, -4 - (i - 1) * 28)
    cb:SetScript("OnClick", function(self)
      ns.db.settings[o.key] = self:GetChecked() and true or false
      ns:NotifyChanged()
    end)
    cb.key = o.key
    cbs[#cbs + 1] = cb
  end
  local mm = Check(page, "Show minimap button")
  mm:SetPoint("TOPLEFT", 0, -4 - #opts * 28)
  mm:SetScript("OnClick", function(self)
    ns.db.settings.minimap.hide = not self:GetChecked()
    ns.Minimap:Update()
  end)

  local y = -4 - (#opts + 1) * 28 - 20
  local hdr = Text(page, "GameFontNormal", "Maintenance")
  hdr:SetPoint("TOPLEFT", 0, y)

  local b1 = Button(page, "Reset popup positions", 170, 22)
  b1:SetPoint("TOPLEFT", 0, y - 22)
  b1:SetScript("OnClick", function() ns.Alert:ResetPositions() end)

  local b2 = Button(page, "Restore default triggers", 170, 22)
  b2:SetPoint("LEFT", b1, "RIGHT", 10, 0)
  b2:SetScript("OnClick", function()
    Confirm("Restore the default trigger setup?\nYour custom exercises and all totals are kept.", function() ns:RestoreDefaults() end)
  end)

  local b3 = Button(page, "Clear history log", 170, 22)
  b3:SetPoint("LEFT", b2, "RIGHT", 10, 0)
  b3:SetScript("OnClick", function()
    Confirm("Clear the history log for ALL characters?\nLifetime totals are kept.", function() ns:ClearHistory() end)
  end)

  local help = Text(page, "GameFontHighlightSmall",
    "Slash commands:  /fit  (toggle window)   /fit pending   /fit pause   /fit test <event>   /fit minimap\n\n" ..
    "Minimap button:  Left-click = this window.  Right-click = open pending sets.  Shift+right-click = pause.  Drag to move.\n\n" ..
    "Train within your limits. Scale reps, sets and exercises to your own level and equipment - FitCraft is a reminder, not a coach.")
  help:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -24)
  help:SetWidth(PAGE_W)
  help:SetSpacing(2)

  function page:Refresh()
    for _, cb in ipairs(cbs) do cb:SetChecked(ns.db.settings[cb.key]) end
    mm:SetChecked(not ns.db.settings.minimap.hide)
  end
end

---------------------------------------------------------------------------
-- Main frame
---------------------------------------------------------------------------
local TABS = {
  { key = "setup",  label = "Setup",      build = BuildSetup },
  { key = "ex",     label = "Exercises",  build = BuildExercises },
  { key = "hist",   label = "History",    build = BuildHistory },
  { key = "tot",    label = "Totals",     build = BuildTotals },
  { key = "chars",  label = "Characters", build = BuildCharacters },
  { key = "opts",   label = "Options",    build = BuildOptions },
}

function UI:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "FitCraftMainFrame", UIParent, "BackdropTemplate")
  f:SetSize(MAIN_W, MAIN_H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetBackdrop(DIALOG_BACKDROP)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetScript("OnHide", function() UI:CloseMenu() end)
  f:SetScript("OnShow", function() UI:Refresh() end)
  f:Hide()
  tinsert(UISpecialFrames, "FitCraftMainFrame")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(28, 28)
  icon:SetPoint("TOPLEFT", 20, -18)
  icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")

  local title = Text(f, "GameFontNormalLarge", "FitCraft")
  title:SetPoint("LEFT", icon, "RIGHT", 8, 6)
  local sub = Text(f, "GameFontDisableSmall", "Stay fit while you grind")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)

  self.status = Text(f, "GameFontHighlightSmall")
  self.status:SetPoint("TOPRIGHT", -40, -24)
  self.status:SetJustifyH("RIGHT")

  self.tabs, self.pages = {}, {}
  local x = 20
  for i, t in ipairs(TABS) do
    local b = Button(f, t.label, 100, 24)
    b:SetPoint("TOPLEFT", x, -56)
    x = x + 104
    b:SetScript("OnClick", function() UI:SelectTab(t.key) end)
    self.tabs[t.key] = b

    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 20, -92)
    page:SetSize(PAGE_W, PAGE_H)
    page:Hide()
    t.build(page)
    self.pages[t.key] = page
  end

  self.frame = f
  self.current = self.current or "setup"
  self:SelectTab(self.current)
  return f
end

function UI:SelectTab(key)
  self.current = key
  self:CloseMenu()
  for k, b in pairs(self.tabs) do
    if k == key then b:LockHighlight() else b:UnlockHighlight() end
    self.pages[k]:SetShown(k == key)
  end
  self:Refresh()
end

function UI:Refresh()
  if not self.frame or not self.frame:IsShown() then return end
  local s = ns.db.settings
  local status
  if s.paused then
    status = "|cffff5555PAUSED|r"
  else
    status = "Today: " .. ns:TodaySummary(ns.charKey)
  end
  if #ns.queue > 0 then status = format("|cffff8080%d pending|r   ", #ns.queue) .. status end
  self.status:SetText(status)
  local page = self.pages[self.current]
  if page and page.Refresh then page:Refresh() end
end

function UI:Toggle(tab)
  local f = self:Build()
  if f:IsShown() and (not tab or tab == self.current) then
    f:Hide()
  else
    f:Show()
    if tab then self:SelectTab(tab) end
  end
end
