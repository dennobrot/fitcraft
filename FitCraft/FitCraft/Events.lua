--[[
  FitCraft - Game event detection
  Every event registration goes through pcall so a client that lacks an
  event (e.g. ENCOUNTER_END) can never break loading.
]]

local ADDON, ns = ...
local bit_band = bit.band

local f = CreateFrame("Frame")
local handlers = {}

local function Register(event, fn)
  local ok = pcall(f.RegisterEvent, f, event)
  if ok then handlers[event] = fn end
  return ok
end

f:SetScript("OnEvent", function(_, event, ...)
  local fn = handlers[event]
  if fn then fn(...) end
end)

---------------------------------------------------------------------------
-- Load / login
---------------------------------------------------------------------------
local wasInInstance = false

Register("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  ns:InitDB()
  f:UnregisterEvent("ADDON_LOADED")
end)

Register("PLAYER_LOGIN", function()
  ns:InitChar()
  ns.UI:Build()
  ns.Minimap:Build()
  ns.Minimap:Update()
  local inInst, iType = IsInInstance()
  wasInInstance = inInst and (iType == "party" or iType == "raid")
  ns:Print(format("loaded. %s  Type |cffffffff/fit|r or click the minimap button.",
    ns.db.settings.paused and "|cffff5555Reminders are paused.|r" or "Time to earn your XP twice."))
end)

---------------------------------------------------------------------------
-- Quests (QUEST_TURNED_IN, with a GetQuestReward hook as fallback)
---------------------------------------------------------------------------
local questEvent = Register("QUEST_TURNED_IN", function()
  ns:FireTrigger("QUEST")
end)
if not questEvent then
  hooksecurefunc("GetQuestReward", function() ns:FireTrigger("QUEST") end)
end

---------------------------------------------------------------------------
-- Level up / death
---------------------------------------------------------------------------
Register("PLAYER_LEVEL_UP", function(level)
  if ns.char then ns.char.level = level end
  ns:FireTrigger("LEVEL", { note = "Level " .. tostring(level) })
end)

Register("PLAYER_DEAD", function()
  ns:FireTrigger("DEATH")
end)

---------------------------------------------------------------------------
-- Combat end -> release deferred reminders
---------------------------------------------------------------------------
Register("PLAYER_REGEN_ENABLED", function()
  -- small delay so the reminder doesn't pop the same frame the last mob dies
  C_Timer.After(0.5, function() ns:OnCombatEnded() end)
end)

---------------------------------------------------------------------------
-- Boss encounters
---------------------------------------------------------------------------
Register("ENCOUNTER_END", function(encounterID, encounterName, difficultyID, groupSize, success)
  if success == 1 or success == true then
    ns:FireTrigger("BOSS", { note = encounterName })
  end
end)

---------------------------------------------------------------------------
-- Rare kills: remember rare GUIDs we see, mark them engaged when we or the
-- group damage them, fire when they die.
---------------------------------------------------------------------------
local rares, engaged, killed = {}, {}, {}
local GROUP_MASK = 0x00000007 -- AFFILIATION_MINE | PARTY | RAID

local function ScanUnit(unit)
  if not UnitExists(unit) or UnitIsPlayer(unit) or UnitIsDead(unit) then return end
  local c = UnitClassification(unit)
  if c == "rare" or c == "rareelite" or c == "worldboss" then
    local guid = UnitGUID(unit)
    if guid and not killed[guid] then rares[guid] = UnitName(unit) end
  end
end

Register("PLAYER_TARGET_CHANGED", function() ScanUnit("target") end)
Register("UPDATE_MOUSEOVER_UNIT", function() ScanUnit("mouseover") end)
Register("NAME_PLATE_UNIT_ADDED", function(unit) ScanUnit(unit) end)

Register("COMBAT_LOG_EVENT_UNFILTERED", function()
  local _, sub, _, srcGUID, _, srcFlags, _, dstGUID = CombatLogGetCurrentEventInfo()
  if not dstGUID or not rares[dstGUID] then return end
  if sub == "UNIT_DIED" or sub == "PARTY_KILL" then
    if engaged[dstGUID] or (sub == "PARTY_KILL" and srcFlags and bit_band(srcFlags, GROUP_MASK) ~= 0) then
      local name = rares[dstGUID]
      rares[dstGUID], engaged[dstGUID] = nil, nil
      if not killed[dstGUID] then
        killed[dstGUID] = true
        ns:FireTrigger("RARE", { note = name })
      end
    end
  elseif srcFlags and sub:find("_DAMAGE", 1, true) and bit_band(srcFlags, GROUP_MASK) ~= 0 then
    engaged[dstGUID] = true
  end
end)

---------------------------------------------------------------------------
-- Loot quality
---------------------------------------------------------------------------
local function ToPattern(s)
  if not s then return nil end
  s = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  s = s:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  return "^" .. s .. "$"
end
local LOOT_PATTERNS = {
  ToPattern(LOOT_ITEM_SELF_MULTIPLE),
  ToPattern(LOOT_ITEM_SELF),
}
local HEX_QUALITY = {}
for _, q in ipairs(ns.QUALITY) do HEX_QUALITY[q.hex] = q.q end

local function LinkQuality(link)
  local q
  if C_Item and C_Item.GetItemInfo then
    q = select(3, C_Item.GetItemInfo(link))
  elseif GetItemInfo then
    q = select(3, GetItemInfo(link))
  end
  if q then return q end
  local hex = link:match("|cff(%x%x%x%x%x%x)")
  return hex and HEX_QUALITY[hex:lower()] or 0
end

Register("CHAT_MSG_LOOT", function(msg)
  local trig = ns.db and ns.db.triggers.LOOT
  if not trig or not trig.enabled then return end
  for _, pat in ipairs(LOOT_PATTERNS) do
    local link = pat and msg:match(pat)
    if link then
      if LinkQuality(link) >= (trig.minQuality or 4) then
        ns:FireTrigger("LOOT", { note = link })
      end
      return
    end
  end
end)

---------------------------------------------------------------------------
-- Instances, hearthstone, new spells
---------------------------------------------------------------------------
Register("PLAYER_ENTERING_WORLD", function(isInitialLogin, isReloadingUi)
  local inInst, iType = IsInInstance()
  local now = inInst and (iType == "party" or iType == "raid")
  if now and not wasInInstance and not isInitialLogin and not isReloadingUi then
    ns:FireTrigger("DUNGEON", { note = GetInstanceInfo and (GetInstanceInfo()) or nil })
  end
  wasInInstance = now
end)

local HEARTHSTONE = 8690
Register("UNIT_SPELLCAST_SUCCEEDED", function(unit, castGUID, spellID)
  if unit == "player" and spellID == HEARTHSTONE then
    ns:FireTrigger("HEARTH")
  end
end)

local spellReady = false
C_Timer.After(15, function() spellReady = true end) -- ignore login spam
Register("LEARNED_SPELL_IN_TAB", function()
  if spellReady then ns:FireTrigger("SPELL") end
end)

---------------------------------------------------------------------------
-- Flight paths: poll UnitOnTaxi (cheap, reliable across clients)
---------------------------------------------------------------------------
local onTaxi, flightStart = false, nil
local acc = 0

local function FlightStarted()
  flightStart = GetTime()
  local s, trig = ns.db.settings, ns.db.triggers.FLIGHT
  if s.paused or not trig.enabled or #trig.items == 0 then return end
  if s.flightPanel then ns.Alert:ShowFlight(flightStart) end
  local names = {}
  for _, it in ipairs(trig.items) do
    local ex = ns.db.exercises[it.ex]
    if ex and not ex.archived then names[#names + 1] = ex.name end
  end
  ns.Alert:Warn("TAKING FLIGHT!", "Get up and do " .. table.concat(names, " + ") .. " until you land!")
end

local function FlightEnded()
  ns.Alert:HideFlight()
  local dur = flightStart and (GetTime() - flightStart) or 0
  flightStart = nil
  if dur >= 5 then
    ns:FireTrigger("FLIGHT", { duration = dur, note = "Flew " .. ns.FormatDuration(dur) })
  end
end

f:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + elapsed
  if acc < 0.5 then return end
  acc = 0
  if not ns.char then return end
  local now = UnitOnTaxi("player") and true or false
  if now ~= onTaxi then
    onTaxi = now
    if now then FlightStarted() else FlightEnded() end
  end
end)
