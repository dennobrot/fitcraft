--[[
  FitCraft - Core
  Data model, saved variables, trigger queue and logging.

  FitCraftDB (account-wide, so every character's data is visible everywhere):
    exercises = { [id] = { name, unit = "reps"|"sec", archived } }
    triggers  = { [KEY] = { enabled, stack, minQuality, items = { { ex, amount, sets } } } }
    settings  = { ... }
    chars     = { ["Name-Realm"] = { name, realm, class, level, totals = { [exId] = { a, s } },
                                     sessions = { done, partial, skipped }, triggers = { [KEY] = n } } }
    history   = { { t, c, k, ex, n, u, a, s, x } }   -- newest last, capped
]]

local ADDON, ns = ...
_G.FitCraft = ns

local floor, format, tinsert, tremove = math.floor, string.format, table.insert, table.remove

ns.PREFIX = "|cff33ff99FitCraft|r"

---------------------------------------------------------------------------
-- Static definitions
---------------------------------------------------------------------------
ns.TRIGGERS = {
  { key = "QUEST",   label = "Quest turned in",      desc = "Fires every time you hand in a quest." },
  { key = "LEVEL",   label = "Level up",             desc = "Fires when you gain a level. Ding!" },
  { key = "DEATH",   label = "Death",                desc = "Fires when you die. Punishment time." },
  { key = "FLIGHT",  label = "Flight path",          desc = "Shows a live timer while you're on a flight path, then asks you to log it when you land. Set a 'seconds' exercise to 0 to log the actual flight time." },
  { key = "BOSS",    label = "Boss defeated",        desc = "Fires when your group defeats a dungeon or raid boss encounter." },
  { key = "RARE",    label = "Rare mob killed",      desc = "Fires when a rare, rare-elite or world boss that you or your group damaged dies." },
  { key = "LOOT",    label = "Great loot",           desc = "Fires when you loot an item of the chosen quality or better." },
  { key = "DUNGEON", label = "Entered dungeon/raid", desc = "Fires when you zone into a dungeon or raid. Warm-up set!" },
  { key = "HEARTH",  label = "Hearthstone used",     desc = "Fires when your Hearthstone cast completes." },
  { key = "SPELL",   label = "New spell learned",    desc = "Fires when you learn a new spell or rank, e.g. at a trainer. Use 'stack' so a trainer visit becomes one reminder." },
}
ns.TRIGGER_INFO = {}
for _, t in ipairs(ns.TRIGGERS) do ns.TRIGGER_INFO[t.key] = t end
ns.TRIGGER_INFO.MANUAL = { key = "MANUAL", label = "Manual log" }

ns.QUALITY = {
  { q = 2, name = ITEM_QUALITY2_DESC or "Uncommon", hex = "1eff00" },
  { q = 3, name = ITEM_QUALITY3_DESC or "Rare",     hex = "0070dd" },
  { q = 4, name = ITEM_QUALITY4_DESC or "Epic",     hex = "a335ee" },
  { q = 5, name = ITEM_QUALITY5_DESC or "Legendary", hex = "ff8000" },
}

local DEFAULT_EXERCISES = {
  { name = "Push-ups",         unit = "reps" }, -- 1
  { name = "Kettlebell Curls", unit = "reps" }, -- 2
  { name = "Squats",           unit = "reps" }, -- 3
  { name = "Kettlebell Halos", unit = "reps" }, -- 4
  { name = "Burpees",          unit = "reps" }, -- 5
  { name = "Mobility Flow",    unit = "sec"  }, -- 6
  { name = "Plank",            unit = "sec"  }, -- 7
  { name = "Lunges",           unit = "reps" }, -- 8
  { name = "Jumping Jacks",    unit = "reps" }, -- 9
  { name = "Sit-ups",          unit = "reps" }, -- 10
}

local DEFAULT_TRIGGERS = {
  QUEST   = { enabled = true,  stack = true,  items = { { ex = 1, amount = 5,  sets = 1 }, { ex = 2, amount = 5, sets = 1 } } },
  LEVEL   = { enabled = true,  stack = true,  items = { { ex = 3, amount = 20, sets = 1 }, { ex = 4, amount = 20, sets = 1 } } },
  DEATH   = { enabled = true,  stack = true,  items = { { ex = 5, amount = 20, sets = 1 } } },
  FLIGHT  = { enabled = true,  stack = false, items = { { ex = 6, amount = 0,  sets = 1 } } },
  BOSS    = { enabled = true,  stack = true,  items = { { ex = 8, amount = 10, sets = 2 } } },
  RARE    = { enabled = false, stack = true,  items = { { ex = 9, amount = 30, sets = 1 } } },
  LOOT    = { enabled = true,  stack = true,  minQuality = 4, items = { { ex = 10, amount = 15, sets = 1 } } },
  DUNGEON = { enabled = false, stack = false, items = { { ex = 7, amount = 60, sets = 1 } } },
  HEARTH  = { enabled = false, stack = true,  items = { { ex = 9, amount = 20, sets = 1 } } },
  SPELL   = { enabled = false, stack = true,  items = { { ex = 1, amount = 3,  sets = 1 } } },
}

local DEFAULT_SETTINGS = {
  sound       = true,
  raidWarning = true,
  deferCombat = true,
  paused      = false,
  flightPanel = true,
  chatEcho    = true,
  historyCap  = 5000,
  minimap     = { angle = 215, hide = false },
}

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end
ns.deepcopy = deepcopy

function ns:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. ": " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
function ns:InitDB()
  FitCraftDB = FitCraftDB or {}
  local db = FitCraftDB
  db.version = 1

  if not db.exercises then
    db.exercises = {}
    for i, e in ipairs(DEFAULT_EXERCISES) do db.exercises[i] = { name = e.name, unit = e.unit } end
  end
  db.nextExId = db.nextExId or 1
  for id in pairs(db.exercises) do
    if type(id) == "number" and id >= db.nextExId then db.nextExId = id + 1 end
  end

  db.triggers = db.triggers or {}
  for k, v in pairs(DEFAULT_TRIGGERS) do
    if not db.triggers[k] then db.triggers[k] = deepcopy(v) end
    db.triggers[k].items = db.triggers[k].items or {}
  end

  db.settings = db.settings or {}
  for k, v in pairs(DEFAULT_SETTINGS) do
    if db.settings[k] == nil then db.settings[k] = deepcopy(v) end
  end

  db.chars   = db.chars or {}
  db.history = db.history or {}
  self.db = db
  self.queue = {}
end

function ns:InitChar()
  local name, realm = UnitName("player"), GetRealmName()
  self.charKey = name .. "-" .. (realm or "?")
  local c = self.db.chars[self.charKey] or {
    totals = {}, triggers = {}, sessions = { done = 0, partial = 0, skipped = 0 }, created = time(),
  }
  c.totals   = c.totals or {}
  c.triggers = c.triggers or {}
  c.sessions = c.sessions or { done = 0, partial = 0, skipped = 0 }
  c.name, c.realm = name, realm
  c.class = select(2, UnitClass("player"))
  c.level = UnitLevel("player")
  c.lastSeen = time()
  self.db.chars[self.charKey] = c
  self.char = c
end

function ns:RestoreDefaults()
  self.db.triggers = deepcopy(DEFAULT_TRIGGERS)
  for i, e in ipairs(DEFAULT_EXERCISES) do
    local cur = self.db.exercises[i]
    if not cur then
      self.db.exercises[i] = { name = e.name, unit = e.unit }
    else
      cur.archived = nil
    end
  end
  self:NotifyChanged()
end

---------------------------------------------------------------------------
-- Exercises
---------------------------------------------------------------------------
function ns:GetExercise(id) return self.db.exercises[id] end

function ns:ExerciseName(id, fallback)
  local e = self.db.exercises[id]
  return (e and e.name) or fallback or ("Exercise #" .. tostring(id))
end

function ns:ExerciseUnit(id, fallback)
  local e = self.db.exercises[id]
  return (e and e.unit) or fallback or "reps"
end

function ns:SortedExerciseIds(includeArchived)
  local ids = {}
  for id, e in pairs(self.db.exercises) do
    if includeArchived or not e.archived then ids[#ids + 1] = id end
  end
  table.sort(ids, function(a, b)
    return (self.db.exercises[a].name or ""):lower() < (self.db.exercises[b].name or ""):lower()
  end)
  return ids
end

function ns:AddExercise(name, unit)
  name = name and name:gsub("^%s+", ""):gsub("%s+$", "")
  if not name or name == "" then return end
  local id = self.db.nextExId
  self.db.nextExId = id + 1
  self.db.exercises[id] = { name = name, unit = (unit == "sec") and "sec" or "reps" }
  self:NotifyChanged()
  return id
end

local function exerciseHasData(db, id)
  for _, c in pairs(db.chars) do
    if c.totals and c.totals[id] then return true end
  end
  for _, h in ipairs(db.history) do
    if h.ex == id then return true end
  end
  return false
end

function ns:DeleteExercise(id)
  local db = self.db
  -- remove from every trigger
  for _, trig in pairs(db.triggers) do
    for i = #trig.items, 1, -1 do
      if trig.items[i].ex == id then tremove(trig.items, i) end
    end
  end
  -- keep lifetime data intact: archive if it was ever used
  if exerciseHasData(db, id) then
    db.exercises[id].archived = true
  else
    db.exercises[id] = nil
  end
  self:NotifyChanged()
end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
function ns.FormatDuration(s)
  s = floor((s or 0) + 0.5)
  local h, m, sec = floor(s / 3600), floor((s % 3600) / 60), s % 60
  if h > 0 then return format("%dh %02dm", h, m) end
  if m > 0 then return format("%dm %02ds", m, sec) end
  return sec .. "s"
end

function ns.FormatNumber(n)
  n = floor(n or 0)
  local s = tostring(n)
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

-- bare = true -> "5" instead of "5 reps" (time is always formatted)
function ns:FormatAmount(amount, unit, bare)
  if unit == "sec" then return ns.FormatDuration(amount) end
  if bare then return ns.FormatNumber(amount) end
  return ns.FormatNumber(amount) .. " reps"
end

-- "5 Push-ups x 3 sets" / "1m 30s Mobility Flow"
function ns:DescribeItem(it, count)
  count = count or 1
  local unit = self:ExerciseUnit(it.ex)
  local sets = (it.sets or 1) * count
  local s = format("%s %s", self:FormatAmount(it.amount, unit, true), self:ExerciseName(it.ex))
  if sets > 1 then s = s .. format(" x %d sets", sets) end
  return s
end

---------------------------------------------------------------------------
-- Trigger queue
---------------------------------------------------------------------------
function ns:ShouldDefer()
  return self.db.settings.deferCombat and (InCombatLockdown() or UnitAffectingCombat("player"))
end

-- opts: { duration = seconds (flights), note = "extra text" }
-- force: test mode - fires even if disabled/paused, nothing gets logged
function ns:FireTrigger(key, opts, force)
  opts = opts or {}
  local db = self.db
  if not db or not self.char then return end
  if db.settings.paused and not force then return end
  local trig = db.triggers[key]
  if not trig or (not trig.enabled and not force) then return end

  local items = {}
  for _, it in ipairs(trig.items) do
    local ex = db.exercises[it.ex]
    if ex and not ex.archived and (it.sets or 0) > 0 then
      local amount = it.amount or 0
      if ex.unit == "sec" and amount == 0 and opts.duration then
        amount = floor(opts.duration + 0.5)
      end
      if amount > 0 then
        items[#items + 1] = { ex = it.ex, amount = amount, sets = it.sets, checked = false }
      end
    end
  end
  if #items == 0 then return end

  if not force then
    self.char.triggers[key] = (self.char.triggers[key] or 0) + 1
  end

  -- stack onto an identical pending reminder
  if trig.stack and not force then
    for _, p in ipairs(self.queue) do
      if p.key == key and not p.test then
        p.count = p.count + 1
        if opts.note then p.note = opts.note end
        if not self:ShouldDefer() then
          self:Announce(p)
          self.snoozed = false
          self:ShowQueue()
        end
        self:NotifyChanged()
        return
      end
    end
  end

  local p = { key = key, count = 1, items = items, note = opts.note, test = force, t = time() }
  tinsert(self.queue, p)

  if self:ShouldDefer() then
    self.deferred = true
    self:Print(format("%s queued - you'll get your set when combat ends.", self.TRIGGER_INFO[key].label))
  else
    self:Announce(p)
    self.snoozed = false
    self:ShowQueue()
  end
  self:NotifyChanged()
end

function ns:Announce(p)
  local info = self.TRIGGER_INFO[p.key]
  local title = (info and info.label or p.key):upper()
  if p.count > 1 then title = title .. " x" .. p.count end
  if p.note then title = title .. " - " .. p.note end
  local parts = {}
  for _, it in ipairs(p.items) do parts[#parts + 1] = self:DescribeItem(it, p.count) end
  self.Alert:Warn(title, "Time to move: " .. table.concat(parts, ", "))
end

function ns:OnCombatEnded()
  if self.deferred and #self.queue > 0 then
    self.deferred = false
    self:Announce(self.queue[1])
    self.snoozed = false
    self:ShowQueue()
  end
end

function ns:ShowQueue()
  if self.snoozed then return end
  if #self.queue > 0 then
    self.Alert:ShowChecklist(self.queue[1], #self.queue)
  else
    self.Alert:HideChecklist()
  end
end

function ns:OpenPending()
  if #self.queue == 0 then
    self:Print("No pending sets. Go play - the game will tell you when it's time!")
    return
  end
  self.snoozed = false
  self.deferred = false
  self:ShowQueue()
end

function ns:Snooze()
  self.snoozed = true
  self.Alert:HideChecklist()
  self:Print(format("%d pending reminder(s) snoozed. Right-click the minimap button or type /fit pending.", #self.queue))
  self:NotifyChanged()
end

local PRAISE = { "Nice work!", "Strong!", "Gains secured.", "Your raid leader would be proud.", "+1 Stamina (real life).", "Beast mode.", "Keep it up!" }

-- mode: "done" (log checked, skip unchecked) | "all" | "skip"
function ns:ResolveCurrent(mode)
  local p = tremove(self.queue, 1)
  if not p then return end

  if p.test then
    self:Print("Test reminder closed (tests are never logged).")
  else
    local done = 0
    local doneParts = {}
    for _, it in ipairs(p.items) do
      local did = (mode == "all") or (mode == "done" and it.checked)
      local sets = (it.sets or 1) * p.count
      self:LogItem(p.key, it.ex, it.amount * sets, sets, not did, true)
      if did then
        done = done + 1
        doneParts[#doneParts + 1] = format("%s %s", self:FormatAmount(it.amount * sets, self:ExerciseUnit(it.ex), true), self:ExerciseName(it.ex))
      end
    end
    local s = self.char.sessions
    if done == #p.items then
      s.done = s.done + p.count
    elseif done > 0 then
      s.partial = s.partial + p.count
    else
      s.skipped = s.skipped + p.count
    end
    if self.db.settings.chatEcho then
      if done > 0 then
        self:Print("Logged " .. table.concat(doneParts, ", ") .. ". " .. PRAISE[math.random(#PRAISE)])
      else
        self:Print("Skipped. The bugs in Azeroth won't judge you... but the history tab will.")
      end
    end
  end

  self:ShowQueue()
  self:NotifyChanged()
end

---------------------------------------------------------------------------
-- Logging & statistics
---------------------------------------------------------------------------
-- amount = TOTAL reps/seconds for this entry, sets = total sets
function ns:LogItem(key, exId, amount, sets, skipped, silent)
  local db = self.db
  local h = db.history
  h[#h + 1] = {
    t = time(), c = self.charKey, k = key, ex = exId,
    n = self:ExerciseName(exId), u = self:ExerciseUnit(exId),
    a = amount, s = sets, x = skipped and 1 or nil,
  }
  local cap = db.settings.historyCap or 5000
  while #h > cap do tremove(h, 1) end

  if not skipped then
    local tot = self.char.totals[exId] or { a = 0, s = 0 }
    tot.a = tot.a + amount
    tot.s = tot.s + sets
    self.char.totals[exId] = tot
  end
  if not silent then self:NotifyChanged() end
end

function ns.StartOfToday()
  local d = date("*t")
  d.hour, d.min, d.sec = 0, 0, 0
  return time(d)
end

-- totals from history since a timestamp: { [exId] = { a, s } }
function ns:GetPeriodTotals(since, charKey)
  local res = {}
  local h = self.db.history
  for i = #h, 1, -1 do
    local e = h[i]
    if e.t < since then break end
    if not e.x and (not charKey or e.c == charKey) then
      local r = res[e.ex] or { a = 0, s = 0 }
      r.a = r.a + (e.a or 0)
      r.s = r.s + (e.s or 0)
      res[e.ex] = r
    end
  end
  return res
end

function ns:GetAccountTotals()
  local res = {}
  for _, c in pairs(self.db.chars) do
    for id, t in pairs(c.totals or {}) do
      local r = res[id] or { a = 0, s = 0 }
      r.a = r.a + t.a
      r.s = r.s + t.s
      res[id] = r
    end
  end
  return res
end

function ns:GetAccountSessions()
  local s = { done = 0, partial = 0, skipped = 0 }
  for _, c in pairs(self.db.chars) do
    if c.sessions then
      s.done = s.done + (c.sessions.done or 0)
      s.partial = s.partial + (c.sessions.partial or 0)
      s.skipped = s.skipped + (c.sessions.skipped or 0)
    end
  end
  return s
end

-- sum a totals map into (reps, seconds)
function ns:SumTotals(totals)
  local reps, secs = 0, 0
  for id, t in pairs(totals) do
    if self:ExerciseUnit(id) == "sec" then secs = secs + t.a else reps = reps + t.a end
  end
  return reps, secs
end

function ns:TodaySummary(charKey)
  local reps, secs = self:SumTotals(self:GetPeriodTotals(ns.StartOfToday(), charKey))
  return format("%s reps, %s of timed work", ns.FormatNumber(reps), ns.FormatDuration(secs))
end

function ns:ClearHistory()
  wipe(self.db.history)
  self:NotifyChanged()
end

function ns:ResetChar(charKey)
  local c = self.db.chars[charKey]
  if not c then return end
  c.totals = {}
  c.triggers = {}
  c.sessions = { done = 0, partial = 0, skipped = 0 }
  local h = self.db.history
  for i = #h, 1, -1 do
    if h[i].c == charKey then tremove(h, i) end
  end
  self:NotifyChanged()
end

function ns:DeleteChar(charKey)
  if charKey == self.charKey then
    self:ResetChar(charKey)
    return
  end
  self:ResetChar(charKey)
  self.db.chars[charKey] = nil
  self:NotifyChanged()
end

function ns:NotifyChanged()
  if self.UI and self.UI.Refresh then self.UI:Refresh() end
  if self.Minimap and self.Minimap.Update then self.Minimap:Update() end
end
