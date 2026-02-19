--[[
╔══════════════════════════════════════════════════════════════════╗
║           ADMIN GUI v2.0  —  Server-Side / LocalScript          ║
║  Execute via server-side executor (SSS, etc.)                   ║
║  Tabs: [ADMIN] [EXECUTE] [PLAYERS] [LOG]                        ║
║  Features:                                                      ║
║    • Tabbed UI (F3X-style)                                      ║
║    • Press M → CMD Box with autocomplete                        ║
║    • "se [script]" → execute any Lua string server-side        ║
║    • Player name autocomplete dropdown                          ║
║    • Full admin command suite                                   ║
╚══════════════════════════════════════════════════════════════════╝
--]]

-- ──────────────────────────────────────────────────────────────────
--  SERVICES
-- ──────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local RunService       = game:GetService("RunService")

repeat task.wait(0.1) until Players.LocalPlayer
local LP   = Players.LocalPlayer
local PGui = LP:WaitForChild("PlayerGui")
local Mouse = LP:GetMouse()

-- ──────────────────────────────────────────────────────────────────
--  CONFIG
-- ──────────────────────────────────────────────────────────────────
local CONFIG = {
    AdminList = {"YourUsernameHere"},   -- Add your username here
    Prefix    = "/",
    Title     = "ADMIN GUI v2.0",
}

local function isAdmin(player)
    for _, n in ipairs(CONFIG.AdminList) do
        if player.Name:lower() == n:lower() then return true end
    end
    return false
end

-- ──────────────────────────────────────────────────────────────────
--  THEME  (dark green terminal aesthetic)
-- ──────────────────────────────────────────────────────────────────
local C = {
    bg0    = Color3.fromRGB(8,   12,  16),
    bg1    = Color3.fromRGB(14,  20,  26),
    bg2    = Color3.fromRGB(20,  30,  38),
    bg3    = Color3.fromRGB(28,  42,  52),
    accent = Color3.fromRGB(60,  220, 120),
    accent2= Color3.fromRGB(70,  170, 255),
    warn   = Color3.fromRGB(255, 190, 60),
    danger = Color3.fromRGB(230, 70,  70),
    purple = Color3.fromRGB(180, 100, 255),
    text   = Color3.fromRGB(205, 225, 215),
    sub    = Color3.fromRGB(90,  120, 105),
    border = Color3.fromRGB(30,  55,  42),
    cmd    = Color3.fromRGB(255, 210, 80),
}

-- ──────────────────────────────────────────────────────────────────
--  GUI HELPERS
-- ──────────────────────────────────────────────────────────────────
local function mkCorner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 5)
    return c
end
local function mkStroke(p, col, th, tr)
    local s = Instance.new("UIStroke", p)
    s.Color = col or C.border; s.Thickness = th or 1
    s.Transparency = tr or 0.4
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end
local function mkPad(p, px, py)
    local u = Instance.new("UIPadding", p)
    u.PaddingLeft  = UDim.new(0, px); u.PaddingRight  = UDim.new(0, px)
    u.PaddingTop   = UDim.new(0, py or px); u.PaddingBottom = UDim.new(0, py or px)
end
local function mkList(p, dir, pad)
    local l = Instance.new("UIListLayout", p)
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Padding       = UDim.new(0, pad or 3)
    return l
end
local function mkLabel(p, txt, col, sz)
    local l = Instance.new("TextLabel", p)
    l.BackgroundTransparency = 1; l.Text = txt
    l.TextColor3 = col or C.text; l.Font = Enum.Font.Code
    l.TextSize = sz or 11; l.BorderSizePixel = 0
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 0, (sz or 11) + 4)
    l.TextTruncate = Enum.TextTruncate.AtEnd
    return l
end
local function mkBtn(p, txt, w, h, col, txtCol)
    local b = Instance.new("TextButton", p)
    b.Size = UDim2.new(0, w or 80, 0, h or 22)
    b.BackgroundColor3 = col or C.bg2
    b.TextColor3 = txtCol or C.accent
    b.Font = Enum.Font.Code; b.TextSize = 10
    b.Text = txt; b.AutoButtonColor = false; b.BorderSizePixel = 0
    mkCorner(b, 4); mkStroke(b, C.border, 1, 0.3)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = C.bg3}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = col or C.bg2}):Play()
    end)
    return b
end
local function mkInput(p, ph, w, h)
    local b = Instance.new("TextBox", p)
    b.Size = UDim2.new(0, w or 120, 0, h or 22)
    b.BackgroundColor3 = C.bg0; b.Text = ""
    b.PlaceholderText = ph or "..."; b.PlaceholderColor3 = C.sub
    b.TextColor3 = C.accent; b.Font = Enum.Font.Code
    b.TextSize = 10; b.ClearTextOnFocus = false; b.BorderSizePixel = 0
    mkCorner(b, 4); mkStroke(b, C.border, 1, 0.3); mkPad(b, 5)
    return b
end
local function mkScroll(p, h)
    local s = Instance.new("ScrollingFrame", p)
    s.Size = UDim2.new(1, -6, 0, h or 160)
    s.BackgroundColor3 = C.bg0; s.BorderSizePixel = 0
    s.ScrollBarThickness = 3; s.ScrollBarImageColor3 = C.accent
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.LayoutOrder = 999
    mkCorner(s, 4); mkStroke(s, C.border, 1, 0.4); mkPad(s, 3)
    mkList(s, Enum.FillDirection.Vertical, 2)
    return s
end
local function hrow(p, h)
    local f = Instance.new("Frame", p)
    f.Size = UDim2.new(1, -6, 0, h or 26)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.LayoutOrder = #p:GetChildren()
    mkList(f, Enum.FillDirection.Horizontal, 4)
    return f
end
local function secHead(p, txt, col)
    local f = Instance.new("Frame", p)
    f.Size = UDim2.new(1, -6, 0, 18); f.BackgroundColor3 = C.bg1
    f.BorderSizePixel = 0; f.LayoutOrder = #p:GetChildren()
    mkCorner(f, 3)
    local l = mkLabel(f, "  > " .. txt, col or C.accent, 10)
    l.Size = UDim2.new(1, 0, 1, 0)
    return f
end
local function spacer(p, h)
    local f = Instance.new("Frame", p)
    f.Size = UDim2.new(1, -6, 0, h or 6)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.LayoutOrder = #p:GetChildren()
    return f
end
local function clearFrame(f)
    for _, c in ipairs(f:GetChildren()) do
        if not (c:IsA("UIListLayout") or c:IsA("UIPadding") or c:IsA("UIGridLayout")) then
            c:Destroy()
        end
    end
end

-- ──────────────────────────────────────────────────────────────────
--  SHARED STATE
-- ──────────────────────────────────────────────────────────────────
local State = {
    TABS    = {},
    logLines = {},
    logLbl  = nil,
    statusDot = nil,
    statusLbl = nil,
}

local function log(msg, col)
    col = col or "#46d264"
    table.insert(State.logLines, "<font color='" .. col .. "'>" .. tostring(msg) .. "</font>")
    if #State.logLines > 200 then table.remove(State.logLines, 1) end
    if State.logLbl then State.logLbl.Text = table.concat(State.logLines, "\n") end
end
local function logW(m) log("[WARN]  " .. m, "#ffbe3c") end
local function logE(m) log("[ERR]   " .. m, "#e64646") end
local function logI(m) log("[i]     " .. m, "#46aaff") end
local function logS(m) log("[OK]    " .. m, "#46d264") end
local function logC(m) log("[CMD]   " .. m, "#ffd250") end
local function logX(m) log("[EXEC]  " .. m, "#b46eff") end

-- ──────────────────────────────────────────────────────────────────
--  PLAYER UTILITIES + AUTOCOMPLETE ENGINE
-- ──────────────────────────────────────────────────────────────────
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(names, p.Name)
    end
    return names
end

local function findPlayer(query)
    query = query:lower()
    -- Exact match first
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == query then return p end
    end
    -- Partial match
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(query, 1, true) then return p end
    end
    return nil
end

-- Returns a list of player name completions for a partial query
local function getCompletions(partial)
    if partial == "" then return {} end
    partial = partial:lower()
    local results = {}
    for _, name in ipairs(getPlayerNames()) do
        if name:lower():find(partial, 1, true) then
            table.insert(results, name)
        end
    end
    return results
end

-- ──────────────────────────────────────────────────────────────────
--  COMMAND REGISTRY
-- ──────────────────────────────────────────────────────────────────
local Commands = {}

local function reg(name, fn, hint, takesPlayer)
    Commands[name] = { fn = fn, hint = hint, takesPlayer = takesPlayer ~= false }
end

reg("kick", function(args)
    local t = findPlayer(args[1])
    if not t then return "Player not found", "err" end
    local reason = table.concat(args, " ", 2)
    if reason == "" then reason = "No reason given" end
    t:Kick("Kicked by admin: " .. reason)
    return "Kicked " .. t.Name, "ok"
end, "kick [player] [reason]")

reg("kill", function(args)
    local t = findPlayer(args[1])
    if not t or not t.Character then return "Player/character not found", "err" end
    local hum = t.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0; return "Killed " .. t.Name, "ok" end
    return "No humanoid", "err"
end, "kill [player]")

reg("respawn", function(args)
    local t = findPlayer(args[1])
    if not t then return "Player not found", "err" end
    t:LoadCharacter()
    return "Respawned " .. t.Name, "ok"
end, "respawn [player]")

reg("speed", function(args)
    local t = findPlayer(args[1])
    local v = tonumber(args[2]) or 16
    if not t or not t.Character then return "Player not found", "err" end
    local hum = t.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v; return "Speed → " .. v .. " for " .. t.Name, "ok" end
    return "No humanoid", "err"
end, "speed [player] [value]")

reg("jump", function(args)
    local t = findPlayer(args[1])
    local v = tonumber(args[2]) or 50
    if not t or not t.Character then return "Player not found", "err" end
    local hum = t.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = v; return "Jump → " .. v .. " for " .. t.Name, "ok" end
    return "No humanoid", "err"
end, "jump [player] [value]")

reg("god", function(args)
    local t = findPlayer(args[1])
    if not t or not t.Character then return "Player not found", "err" end
    local hum = t.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.MaxHealth = math.huge; hum.Health = math.huge; return "Godded " .. t.Name, "ok" end
    return "No humanoid", "err"
end, "god [player]")

reg("ungod", function(args)
    local t = findPlayer(args[1])
    if not t or not t.Character then return "Player not found", "err" end
    local hum = t.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.MaxHealth = 100; hum.Health = 100; return "Ungodded " .. t.Name, "ok" end
    return "No humanoid", "err"
end, "ungod [player]")

reg("freeze", function(args)
    local t = findPlayer(args[1])
    if not t or not t.Character then return "Player not found", "err" end
    local hrp = t.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = not hrp.Anchored
        return (hrp.Anchored and "Froze " or "Unfroze ") .. t.Name, "ok"
    end
    return "No HumanoidRootPart", "err"
end, "freeze [player]")

reg("tp", function(args)
    local from = findPlayer(args[1])
    local to   = findPlayer(args[2])
    if not from or not to then return "Player(s) not found", "err" end
    if not from.Character or not to.Character then return "Character not loaded", "err" end
    from.Character:PivotTo(to.Character:GetPivot() * CFrame.new(3, 0, 0))
    return "Teleported " .. from.Name .. " → " .. to.Name, "ok"
end, "tp [from] [to]", false)

reg("bring", function(args)
    local t = findPlayer(args[1])
    local me = LP
    if not t or not t.Character or not me.Character then return "Player not found", "err" end
    t.Character:PivotTo(me.Character:GetPivot() * CFrame.new(4, 0, 0))
    return "Brought " .. t.Name, "ok"
end, "bring [player]")

reg("announce", function(args)
    local msg = table.concat(args, " ", 1)
    if msg == "" then return "No message given", "err" end
    for _, p in ipairs(Players:GetPlayers()) do
        local hint = Instance.new("Hint")
        hint.Text = "[ADMIN] " .. msg
        hint.Parent = p.PlayerGui
        game:GetService("Debris"):AddItem(hint, 5)
    end
    return "Announced: " .. msg, "ok"
end, "announce [message]", false)

reg("day", function(_)
    Lighting.TimeOfDay = "14:00:00"
    return "Set time to day", "ok"
end, "day", false)

reg("night", function(_)
    Lighting.TimeOfDay = "02:00:00"
    return "Set time to night", "ok"
end, "night", false)

reg("noclip", function(args)
    local t = findPlayer(args[1])
    if not t or not t.Character then return "Player not found", "err" end
    for _, p in ipairs(t.Character:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = not p.CanCollide end
    end
    return "Toggled noclip for " .. t.Name, "ok"
end, "noclip [player]")

reg("btools", function(args)
    local t = findPlayer(args[1]) or LP
    for i = 1, 4 do
        local bin = Instance.new("HopperBin")
        bin.BinType = i; bin.Parent = t.Backpack
    end
    return "Gave BTools to " .. t.Name, "ok"
end, "btools [player]")

reg("invisible", function(args)
    local t = findPlayer(args[1]) or LP
    if not t.Character then return "No character", "err" end
    for _, p in ipairs(t.Character:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Transparency = p.Transparency >= 0.9 and 0 or 1
        end
    end
    return "Toggled visibility for " .. t.Name, "ok"
end, "invisible [player]")

-- se: execute arbitrary Lua code
reg("se", function(args)
    local code = table.concat(args, " ", 1)
    if code == "" then return "No code given", "err" end
    local fn, compErr = loadstring(code)
    if not fn then return "Compile error: " .. tostring(compErr), "err" end
    local ok, runErr = pcall(fn)
    if ok then return "Executed OK", "ok"
    else return "Runtime error: " .. tostring(runErr), "err" end
end, "se [lua code]", false)

-- help
reg("help", function(_)
    local lines = {}
    for name, data in pairs(Commands) do
        table.insert(lines, name .. "  →  " .. data.hint)
    end
    table.sort(lines)
    return table.concat(lines, "\n"), "ok"
end, "help", false)

-- ──────────────────────────────────────────────────────────────────
--  COMMAND RUNNER
-- ──────────────────────────────────────────────────────────────────
local function runCommand(input)
    input = input:gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then return end
    -- strip prefix if present
    if input:sub(1, #CONFIG.Prefix) == CONFIG.Prefix then
        input = input:sub(#CONFIG.Prefix + 1)
    end
    local parts = string.split(input, " ")
    local cmd   = parts[1]:lower()
    table.remove(parts, 1)
    -- rebuild args correctly
    local args = parts

    logC(">>> " .. cmd .. " " .. table.concat(args, " "))

    -- special: se passes everything as a single code string
    if cmd == "se" then
        local code = table.concat(args, " ")
        logX("Executing: " .. code:sub(1, 80) .. (#code > 80 and "..." or ""))
        local fn, compErr = loadstring(code)
        if not fn then
            logE("Compile error: " .. tostring(compErr)); return
        end
        local ok, runErr = pcall(fn)
        if ok then logS("Script executed successfully")
        else logE("Runtime error: " .. tostring(runErr)) end
        return
    end

    local entry = Commands[cmd]
    if not entry then
        logW("Unknown command: " .. cmd .. "  (type /help for list)")
        return
    end
    local msg, status = entry.fn(args)
    if status == "ok" then logS(msg)
    else logE(msg) end
end

-- ──────────────────────────────────────────────────────────────────
--  ROOT GUI
-- ──────────────────────────────────────────────────────────────────
local SG = Instance.new("ScreenGui", PGui)
SG.Name = "AdminGUIv2"; SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; SG.DisplayOrder = 200

-- Toggle button (bottom-left)
local toggle = Instance.new("TextButton", SG)
toggle.Size = UDim2.new(0, 110, 0, 22)
toggle.Position = UDim2.new(0, 8, 1, -30)
toggle.BackgroundColor3 = C.bg1
toggle.TextColor3 = C.accent; toggle.Font = Enum.Font.Code
toggle.TextSize = 11; toggle.Text = "[ ADMIN GUI v2 ]"
toggle.AutoButtonColor = false; toggle.BorderSizePixel = 0
mkCorner(toggle, 4); mkStroke(toggle, C.accent, 1, 0.2)

-- Main window
local win = Instance.new("Frame", SG)
win.Name = "Win"; win.Size = UDim2.new(0, 640, 0, 540)
win.Position = UDim2.new(0, 8, 1, -578)
win.BackgroundColor3 = C.bg0; win.BorderSizePixel = 0
win.Visible = false; mkCorner(win, 7); mkStroke(win, C.accent, 1, 0.5)

-- Title bar
local tbar = Instance.new("Frame", win)
tbar.Size = UDim2.new(1, 0, 0, 28); tbar.BackgroundColor3 = C.bg1
tbar.BorderSizePixel = 0; mkCorner(tbar, 7)
local tbarFill = Instance.new("Frame", tbar) -- square bottom corners
tbarFill.Size = UDim2.new(1, 0, 0.5, 0); tbarFill.Position = UDim2.new(0, 0, 0.5, 0)
tbarFill.BackgroundColor3 = C.bg1; tbarFill.BorderSizePixel = 0

local titleLbl = Instance.new("TextLabel", tbar)
titleLbl.Size = UDim2.new(1, -120, 1, 0); titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = ">  " .. CONFIG.Title .. "   //  Press M for CMD"
titleLbl.TextColor3 = C.accent; titleLbl.Font = Enum.Font.Code
titleLbl.TextSize = 11; titleLbl.TextXAlignment = Enum.TextXAlignment.Left

State.statusDot = Instance.new("Frame", tbar)
State.statusDot.Size = UDim2.new(0, 8, 0, 8)
State.statusDot.Position = UDim2.new(1, -96, 0.5, -4)
State.statusDot.BackgroundColor3 = C.accent; mkCorner(State.statusDot, 4)
State.statusDot.BorderSizePixel = 0

State.statusLbl = Instance.new("TextLabel", tbar)
State.statusLbl.Size = UDim2.new(0, 60, 1, 0)
State.statusLbl.Position = UDim2.new(1, -88, 0, 0)
State.statusLbl.BackgroundTransparency = 1
State.statusLbl.Text = "READY"
State.statusLbl.TextColor3 = C.accent
State.statusLbl.Font = Enum.Font.Code; State.statusLbl.TextSize = 9
State.statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = mkBtn(tbar, "×", 22, 22, C.bg2, C.danger)
closeBtn.Position = UDim2.new(1, -26, 0.5, -11)
closeBtn.TextSize = 14
closeBtn.Activated:Connect(function() win.Visible = false end)

-- Drag
local _drag, _dragStart, _winStart
tbar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        _drag = true; _dragStart = i.Position; _winStart = win.Position
    end
end)
tbar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then _drag = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if _drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - _dragStart
        win.Position = UDim2.new(_winStart.X.Scale, _winStart.X.Offset + d.X, _winStart.Y.Scale, _winStart.Y.Offset + d.Y)
    end
end)

-- Tab row
local tabRow = Instance.new("Frame", win)
tabRow.Size = UDim2.new(1, -4, 0, 24); tabRow.Position = UDim2.new(0, 2, 0, 30)
tabRow.BackgroundTransparency = 1; tabRow.BorderSizePixel = 0
mkList(tabRow, Enum.FillDirection.Horizontal, 3)

-- Tab content holder
local holder = Instance.new("Frame", win)
holder.Size = UDim2.new(1, -4, 1, -58); holder.Position = UDim2.new(0, 2, 0, 56)
holder.BackgroundTransparency = 1; holder.BorderSizePixel = 0; holder.ClipsDescendants = true

-- ──────────────────────────────────────────────────────────────────
--  TAB SYSTEM
-- ──────────────────────────────────────────────────────────────────
local function newTab(label, accentCol)
    local btn = Instance.new("TextButton", tabRow)
    btn.Size = UDim2.new(0, 88, 1, 0); btn.BackgroundColor3 = C.bg1
    btn.TextColor3 = C.sub; btn.Font = Enum.Font.Code
    btn.TextSize = 10; btn.Text = label; btn.AutoButtonColor = false; btn.BorderSizePixel = 0
    mkCorner(btn, 4); mkStroke(btn, C.border, 1, 0.5)

    local panel = Instance.new("ScrollingFrame", holder)
    panel.Size = UDim2.new(1, 0, 1, 0); panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0; panel.ScrollBarThickness = 3
    panel.ScrollBarImageColor3 = accentCol or C.accent
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.AutomaticCanvasSize = Enum.AutomaticSize.Y; panel.Visible = false
    mkList(panel, Enum.FillDirection.Vertical, 4); mkPad(panel, 4)

    local t = { btn = btn, panel = panel, accent = accentCol or C.accent }
    table.insert(State.TABS, t)

    btn.Activated:Connect(function()
        for _, x in ipairs(State.TABS) do
            x.panel.Visible = false
            TweenService:Create(x.btn, TweenInfo.new(0.08), { BackgroundColor3 = C.bg1, TextColor3 = C.sub }):Play()
        end
        panel.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = C.bg2, TextColor3 = accentCol or C.accent }):Play()
    end)
    return t
end

-- ══════════════════════════════════════════════════════════════════
--  TAB 1: ADMIN COMMANDS
-- ══════════════════════════════════════════════════════════════════
local function buildAdminTab()
    local tab = newTab("[ADMIN]", C.accent)
    local p   = tab.panel

    -- Player autocomplete helper widget
    --   targetInput: the TextBox to fill
    --   acDropdown: the Frame to render suggestions into
    local function setupAutocomplete(targetInput, acDropdown)
        local acLayout = mkList(acDropdown, Enum.FillDirection.Vertical, 0)

        local function refreshAC()
            clearFrame(acDropdown)
            local text = targetInput.Text
            -- Find the last word (player name being typed)
            local lastWord = text:match("(%S+)$") or ""
            local completions = getCompletions(lastWord)
            if #completions == 0 or lastWord == "" then
                acDropdown.Visible = false; return
            end
            for _, name in ipairs(completions) do
                local btn2 = Instance.new("TextButton", acDropdown)
                btn2.Size = UDim2.new(1, 0, 0, 20)
                btn2.BackgroundColor3 = C.bg2; btn2.BorderSizePixel = 0
                btn2.TextColor3 = C.accent2; btn2.Font = Enum.Font.Code
                btn2.TextSize = 10; btn2.Text = "  " .. name
                btn2.TextXAlignment = Enum.TextXAlignment.Left
                btn2.AutoButtonColor = false
                mkStroke(btn2, C.border, 1, 0.5)
                local capName = name
                btn2.MouseEnter:Connect(function()
                    TweenService:Create(btn2, TweenInfo.new(0.06), { BackgroundColor3 = C.bg3 }):Play()
                end)
                btn2.MouseLeave:Connect(function()
                    TweenService:Create(btn2, TweenInfo.new(0.06), { BackgroundColor3 = C.bg2 }):Play()
                end)
                btn2.MouseButton1Click:Connect(function()
                    -- Replace last word in the input with the chosen name
                    local before = targetInput.Text:match("^(.*%s)%S*$") or ""
                    targetInput.Text = before .. capName
                    acDropdown.Visible = false
                    targetInput:CaptureFocus()
                end)
            end
            acDropdown.Visible = true
        end

        targetInput:GetPropertyChangedSignal("Text"):Connect(refreshAC)
        targetInput.FocusLost:Connect(function()
            task.wait(0.15)
            acDropdown.Visible = false
        end)
    end

    -- Execute command row with autocomplete
    local function mkCommandRow(cmdName, color, labelText)
        secHead(p, labelText or cmdName:upper(), color or C.accent)
        local rowF = Instance.new("Frame", p)
        rowF.Size = UDim2.new(1, -6, 0, 26)
        rowF.BackgroundTransparency = 1; rowF.BorderSizePixel = 0
        rowF.LayoutOrder = #p:GetChildren()
        mkList(rowF, Enum.FillDirection.Horizontal, 4)

        local inp = mkInput(rowF, "player name", 230, 22)
        local execBtn = mkBtn(rowF, cmdName:upper(), 80, 22, C.bg2, color or C.accent)

        -- Autocomplete dropdown (overlay)
        local acFrame = Instance.new("Frame", SG)
        acFrame.BackgroundColor3 = C.bg1; acFrame.BorderSizePixel = 0
        acFrame.ZIndex = 50; acFrame.Visible = false
        acFrame.Size = UDim2.new(0, 220, 0, 0)
        acFrame.AutomaticSize = Enum.AutomaticSize.Y
        mkCorner(acFrame, 4); mkStroke(acFrame, C.accent2, 1, 0.3)
        setupAutocomplete(inp, acFrame)

        -- Position dropdown below the input field
        inp:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            local ap = inp.AbsolutePosition
            local sz = inp.AbsoluteSize
            acFrame.Position = UDim2.new(0, ap.X, 0, ap.Y + sz.Y + 2)
        end)
        RunService.Heartbeat:Connect(function()
            if acFrame.Visible then
                local ap = inp.AbsolutePosition
                local sz = inp.AbsoluteSize
                acFrame.Position = UDim2.new(0, ap.X, 0, ap.Y + sz.Y + 2)
            end
        end)

        execBtn.Activated:Connect(function()
            runCommand(cmdName .. " " .. inp.Text)
        end)
        inp.FocusLost:Connect(function(enter)
            if enter then runCommand(cmdName .. " " .. inp.Text) end
        end)

        return inp
    end

    -- 2-arg command row
    local function mkCommandRow2(cmdName, color, labelText, ph1, ph2, w1, w2)
        secHead(p, labelText or cmdName:upper(), color or C.accent)
        local rowF = Instance.new("Frame", p)
        rowF.Size = UDim2.new(1, -6, 0, 26)
        rowF.BackgroundTransparency = 1; rowF.BorderSizePixel = 0
        rowF.LayoutOrder = #p:GetChildren()
        mkList(rowF, Enum.FillDirection.Horizontal, 4)

        local inp1 = mkInput(rowF, ph1 or "player", w1 or 150, 22)
        local inp2 = mkInput(rowF, ph2 or "value",  w2 or 80,  22)
        local execBtn = mkBtn(rowF, cmdName:upper(), 80, 22, C.bg2, color or C.accent)

        -- Autocomplete on first input
        local acFrame = Instance.new("Frame", SG)
        acFrame.BackgroundColor3 = C.bg1; acFrame.BorderSizePixel = 0
        acFrame.ZIndex = 50; acFrame.Visible = false
        acFrame.Size = UDim2.new(0, 180, 0, 0)
        acFrame.AutomaticSize = Enum.AutomaticSize.Y
        mkCorner(acFrame, 4); mkStroke(acFrame, C.accent2, 1, 0.3)
        setupAutocomplete(inp1, acFrame)
        RunService.Heartbeat:Connect(function()
            if acFrame.Visible then
                local ap = inp1.AbsolutePosition; local sz = inp1.AbsoluteSize
                acFrame.Position = UDim2.new(0, ap.X, 0, ap.Y + sz.Y + 2)
            end
        end)

        execBtn.Activated:Connect(function()
            runCommand(cmdName .. " " .. inp1.Text .. " " .. inp2.Text)
        end)
        return inp1, inp2
    end

    -- Player management
    secHead(p, "PLAYER MANAGEMENT", C.accent)
    spacer(p, 2)

    mkCommandRow("kick",    C.danger,  "KICK  (name + reason)")
    mkCommandRow("kill",    C.danger,  "KILL")
    mkCommandRow("respawn", C.accent2, "RESPAWN")
    mkCommandRow("bring",   C.accent2, "BRING TO ME")

    -- tp needs 2 inputs
    secHead(p, "TELEPORT  (from → to)", C.accent2)
    local tpRow = Instance.new("Frame", p)
    tpRow.Size = UDim2.new(1, -6, 0, 26)
    tpRow.BackgroundTransparency = 1; tpRow.BorderSizePixel = 0
    tpRow.LayoutOrder = #p:GetChildren()
    mkList(tpRow, Enum.FillDirection.Horizontal, 4)
    local tpFrom = mkInput(tpRow, "from player", 150, 22)
    local tpTo   = mkInput(tpRow, "to player",   150, 22)
    local tpBtn  = mkBtn(tpRow, "TELEPORT", 90, 22, C.bg2, C.accent2)
    tpBtn.Activated:Connect(function()
        runCommand("tp " .. tpFrom.Text .. " " .. tpTo.Text)
    end)
    -- autocomplete on both
    for _, inp in ipairs({tpFrom, tpTo}) do
        local acF = Instance.new("Frame", SG)
        acF.BackgroundColor3 = C.bg1; acF.BorderSizePixel = 0
        acF.ZIndex = 50; acF.Visible = false
        acF.Size = UDim2.new(0, 170, 0, 0)
        acF.AutomaticSize = Enum.AutomaticSize.Y
        mkCorner(acF, 4); mkStroke(acF, C.accent2, 1, 0.3)
        setupAutocomplete(inp, acF)
        local capturedInp = inp
        RunService.Heartbeat:Connect(function()
            if acF.Visible then
                local ap = capturedInp.AbsolutePosition; local sz = capturedInp.AbsoluteSize
                acF.Position = UDim2.new(0, ap.X, 0, ap.Y + sz.Y + 2)
            end
        end)
    end

    spacer(p, 4)

    -- Character modifiers
    secHead(p, "CHARACTER MODIFIERS", C.accent)
    spacer(p, 2)

    mkCommandRow2("speed",  C.accent, "SPEED",      "player",  "value (16)",  155, 65)
    mkCommandRow2("jump",   C.accent, "JUMP POWER", "player",  "value (50)",  155, 65)
    mkCommandRow("god",       C.warn,   "GOD MODE")
    mkCommandRow("ungod",     C.sub,    "UNGOD")
    mkCommandRow("freeze",    C.accent2,"FREEZE / UNFREEZE")
    mkCommandRow("noclip",    C.accent2,"NOCLIP TOGGLE")
    mkCommandRow("invisible", C.purple, "VISIBILITY TOGGLE")
    mkCommandRow("btools",    C.warn,   "GIVE BUILDING TOOLS")

    spacer(p, 4)

    -- World
    secHead(p, "WORLD CONTROLS", C.accent)
    spacer(p, 2)
    local worldRow = hrow(p, 26)
    local dayBtn   = mkBtn(worldRow, "SET DAY",   90, 22, C.bg2, C.accent)
    local nightBtn = mkBtn(worldRow, "SET NIGHT", 95, 22, C.bg2, C.accent2)
    dayBtn.Activated:Connect(function()   runCommand("day") end)
    nightBtn.Activated:Connect(function() runCommand("night") end)

    secHead(p, "SERVER ANNOUNCE", C.warn)
    local annRow = hrow(p, 26)
    local annIn  = mkInput(annRow, "Message to announce to all players", 380, 22)
    local annBtn = mkBtn(annRow, "SEND", 65, 22, C.bg2, C.warn)
    annBtn.Activated:Connect(function() runCommand("announce " .. annIn.Text) end)
    annIn.FocusLost:Connect(function(enter)
        if enter and annIn.Text ~= "" then runCommand("announce " .. annIn.Text) end
    end)
end

-- ══════════════════════════════════════════════════════════════════
--  TAB 2: SCRIPT EXECUTOR  (se)
-- ══════════════════════════════════════════════════════════════════
local function buildExecuteTab()
    local tab = newTab("[EXECUTE]", C.purple)
    local p   = tab.panel

    local execBanner = Instance.new("Frame", p)
    execBanner.Size = UDim2.new(1, -6, 0, 28); execBanner.BackgroundColor3 = Color3.fromRGB(20, 10, 36)
    execBanner.BorderSizePixel = 0; execBanner.LayoutOrder = 1
    mkCorner(execBanner, 4); mkStroke(execBanner, C.purple, 1, 0.4)
    local execBannerLbl = mkLabel(execBanner, "  ⬡  Script Executor  —  runs via loadstring / pcall", C.purple, 10)
    execBannerLbl.Size = UDim2.new(1, 0, 1, 0)

    secHead(p, "EDITOR", C.purple)

    -- Multi-line code editor
    local editorFrame = Instance.new("Frame", p)
    editorFrame.Size = UDim2.new(1, -6, 0, 200)
    editorFrame.BackgroundColor3 = C.bg0; editorFrame.BorderSizePixel = 0
    editorFrame.LayoutOrder = #p:GetChildren()
    mkCorner(editorFrame, 5); mkStroke(editorFrame, C.purple, 1, 0.4)

    local lineNumFrame = Instance.new("Frame", editorFrame)
    lineNumFrame.Size = UDim2.new(0, 28, 1, 0)
    lineNumFrame.BackgroundColor3 = C.bg1; lineNumFrame.BorderSizePixel = 0
    mkCorner(lineNumFrame, 5)

    local lineNumLbl = Instance.new("TextLabel", lineNumFrame)
    lineNumLbl.Size = UDim2.new(1, 0, 1, -8); lineNumLbl.Position = UDim2.new(0, 0, 0, 4)
    lineNumLbl.BackgroundTransparency = 1; lineNumLbl.Text = "1"
    lineNumLbl.TextColor3 = C.sub; lineNumLbl.Font = Enum.Font.Code
    lineNumLbl.TextSize = 10; lineNumLbl.TextYAlignment = Enum.TextYAlignment.Top
    lineNumLbl.TextXAlignment = Enum.TextXAlignment.Center

    local codeBox = Instance.new("TextBox", editorFrame)
    codeBox.Size = UDim2.new(1, -34, 1, -8); codeBox.Position = UDim2.new(0, 30, 0, 4)
    codeBox.BackgroundTransparency = 1
    codeBox.Text = ""; codeBox.PlaceholderText = "-- Write your Lua script here\nprint('Hello from se!')"
    codeBox.PlaceholderColor3 = Color3.fromRGB(60, 40, 90)
    codeBox.TextColor3 = Color3.fromRGB(200, 160, 255)
    codeBox.Font = Enum.Font.Code; codeBox.TextSize = 11
    codeBox.ClearTextOnFocus = false; codeBox.BorderSizePixel = 0
    codeBox.TextXAlignment = Enum.TextXAlignment.Left
    codeBox.TextYAlignment = Enum.TextYAlignment.Top
    codeBox.MultiLine = true; codeBox.TextWrapped = false

    -- Update line numbers
    codeBox:GetPropertyChangedSignal("Text"):Connect(function()
        local lines = 1
        for _ in codeBox.Text:gmatch("\n") do lines = lines + 1 end
        local nums = {}
        for i = 1, lines do nums[i] = tostring(i) end
        lineNumLbl.Text = table.concat(nums, "\n")
    end)

    -- Quick snippet buttons
    secHead(p, "QUICK SNIPPETS", C.purple)
    local snippets = {
        { "Print Players", "for _,p in ipairs(game.Players:GetPlayers()) do print(p.Name) end" },
        { "Kill All",      "for _,p in ipairs(game.Players:GetPlayers()) do local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid') if h then h.Health=0 end end" },
        { "Lighting Day",  "game.Lighting.TimeOfDay='14:00:00'" },
        { "Clear WS",      "for _,v in ipairs(workspace:GetChildren()) do if v:IsA('BasePart') then v:Destroy() end end" },
        { "Hello World",   "print('Hello, World!')" },
        { "Noclip All",    "for _,p in ipairs(game.Players:GetPlayers()) do if p.Character then for _,v in ipairs(p.Character:GetDescendants()) do if v:IsA('BasePart') then v.CanCollide=false end end end end" },
    }
    local snipScroll = Instance.new("ScrollingFrame", p)
    snipScroll.Size = UDim2.new(1, -6, 0, 72)
    snipScroll.BackgroundColor3 = C.bg0; snipScroll.BorderSizePixel = 0
    snipScroll.ScrollBarThickness = 3; snipScroll.ScrollBarImageColor3 = C.purple
    snipScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    snipScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    snipScroll.LayoutOrder = #p:GetChildren()
    mkCorner(snipScroll, 4); mkStroke(snipScroll, C.purple, 1, 0.5)

    local snipGrid = Instance.new("Frame", snipScroll)
    snipGrid.Size = UDim2.new(1, 0, 0, 0); snipGrid.AutomaticSize = Enum.AutomaticSize.Y
    snipGrid.BackgroundTransparency = 1; snipGrid.BorderSizePixel = 0
    local sg = Instance.new("UIGridLayout", snipGrid)
    sg.CellSize = UDim2.new(0, 148, 0, 26); sg.CellPadding = UDim2.new(0, 4, 0, 4)
    sg.FillDirection = Enum.FillDirection.Horizontal

    for _, snip in ipairs(snippets) do
        local sb = mkBtn(snipGrid, snip[1], 148, 22, C.bg2, C.purple)
        sb.TextSize = 9
        local code = snip[2]
        sb.Activated:Connect(function()
            codeBox.Text = code
        end)
    end

    -- Execute / Clear
    local execRow = hrow(p, 26)
    local runBtn  = mkBtn(execRow, "▶  RUN SCRIPT", 120, 24, Color3.fromRGB(22, 12, 38), C.purple)
    local clearBtn = mkBtn(execRow, "CLEAR", 70, 24, C.bg2, C.sub)
    local execResultLbl = mkLabel(execRow, "  Ready", C.sub, 9)
    execResultLbl.Size = UDim2.new(0, 280, 0, 24)

    runBtn.Activated:Connect(function()
        local code = codeBox.Text
        if code == "" then logW("No code to execute") return end
        logX("Running script from editor (" .. #code .. " chars)...")
        execResultLbl.Text = "  Running..."; execResultLbl.TextColor3 = C.warn
        local fn, compErr = loadstring(code)
        if not fn then
            logE("Compile error: " .. tostring(compErr))
            execResultLbl.Text = "  Compile error — see LOG"; execResultLbl.TextColor3 = C.danger
            return
        end
        local ok, runErr = pcall(fn)
        if ok then
            logS("Script executed successfully")
            execResultLbl.Text = "  ✓ Executed OK"; execResultLbl.TextColor3 = C.accent
        else
            logE("Runtime error: " .. tostring(runErr))
            execResultLbl.Text = "  Runtime error — see LOG"; execResultLbl.TextColor3 = C.danger
        end
        task.delay(4, function()
            execResultLbl.Text = "  Ready"; execResultLbl.TextColor3 = C.sub
        end)
    end)
    clearBtn.Activated:Connect(function()
        codeBox.Text = ""; execResultLbl.Text = "  Ready"; execResultLbl.TextColor3 = C.sub
    end)

    -- One-liner se box
    secHead(p, "QUICK ONE-LINER  (se)", C.purple)
    local seRow = hrow(p, 26)
    local seIn  = mkInput(seRow, "se: one-line Lua — e.g. print(workspace.Name)", 420, 22)
    local seBtn = mkBtn(seRow, "RUN", 65, 22, C.bg2, C.purple)
    seBtn.Activated:Connect(function()
        if seIn.Text ~= "" then runCommand("se " .. seIn.Text) end
    end)
    seIn.FocusLost:Connect(function(enter)
        if enter and seIn.Text ~= "" then runCommand("se " .. seIn.Text) end
    end)

    -- Saved scripts
    secHead(p, "SAVED SCRIPTS", C.purple)
    local savedFrame = Instance.new("Frame", p)
    savedFrame.Size = UDim2.new(1, -6, 0, 80)
    savedFrame.BackgroundColor3 = C.bg0; savedFrame.BorderSizePixel = 0
    savedFrame.LayoutOrder = #p:GetChildren()
    mkCorner(savedFrame, 4); mkStroke(savedFrame, C.purple, 1, 0.5)
    mkPad(savedFrame, 4)
    local savedLayout = mkList(savedFrame, Enum.FillDirection.Vertical, 2)

    local savedScripts = {} -- { name, code } stored in memory

    local function refreshSaved()
        clearFrame(savedFrame)
        if #savedScripts == 0 then
            local nl = mkLabel(savedFrame, "  No saved scripts yet", C.sub, 9)
            nl.Size = UDim2.new(1, 0, 0, 18); return
        end
        for i, s in ipairs(savedScripts) do
            local sRow = Instance.new("Frame", savedFrame)
            sRow.Size = UDim2.new(1, 0, 0, 22); sRow.BackgroundTransparency = 1; sRow.BorderSizePixel = 0
            mkList(sRow, Enum.FillDirection.Horizontal, 4)
            local nl2 = mkLabel(sRow, "  " .. s.name, C.text, 9); nl2.Size = UDim2.new(0, 180, 1, 0)
            local lBtn = mkBtn(sRow, "LOAD", 55, 18, C.bg2, C.purple)
            local dBtn = mkBtn(sRow, "DEL",  40, 18, C.bg2, C.danger)
            local cap  = i
            lBtn.Activated:Connect(function() codeBox.Text = savedScripts[cap].code end)
            dBtn.Activated:Connect(function() table.remove(savedScripts, cap); refreshSaved() end)
        end
    end
    refreshSaved()

    local saveRow2  = hrow(p, 26)
    local saveNameIn = mkInput(saveRow2, "Script name", 160, 22)
    local saveBtn2   = mkBtn(saveRow2, "SAVE CURRENT", 110, 22, C.bg2, C.purple)
    saveBtn2.Activated:Connect(function()
        if saveNameIn.Text == "" then logW("Enter a name") return end
        if codeBox.Text == "" then logW("Editor is empty") return end
        table.insert(savedScripts, { name = saveNameIn.Text, code = codeBox.Text })
        refreshSaved()
        logS("Saved script: " .. saveNameIn.Text)
    end)
end

-- ══════════════════════════════════════════════════════════════════
--  TAB 3: PLAYERS
-- ══════════════════════════════════════════════════════════════════
local function buildPlayersTab()
    local tab = newTab("[PLAYERS]", C.accent2)
    local p   = tab.panel

    secHead(p, "PLAYER LIST", C.accent2)

    local plrScroll = mkScroll(p, 220)

    local function refreshPlayers()
        clearFrame(plrScroll)
        local plrs = Players:GetPlayers()
        if #plrs == 0 then
            mkLabel(plrScroll, "  No players", C.sub, 10)
            return
        end
        for _, plr in ipairs(plrs) do
            local isMe = plr == LP
            local rowF = Instance.new("Frame", plrScroll)
            rowF.Size = UDim2.new(1, -4, 0, 38)
            rowF.BackgroundColor3 = isMe and Color3.fromRGB(16, 30, 46) or C.bg1
            rowF.BorderSizePixel = 0; mkCorner(rowF, 4)
            mkStroke(rowF, isMe and C.accent2 or C.border, 1, isMe and 0.2 or 0.5)

            local nameLbl = mkLabel(rowF, "  " .. (isMe and "★ " or "◎ ") .. plr.Name, isMe and C.accent2 or C.text, 11)
            nameLbl.Size = UDim2.new(0.5, 0, 0, 16); nameLbl.Position = UDim2.new(0, 0, 0, 2)

            -- Ping / team / gamepad info
            local infoLbl = mkLabel(rowF, "  UserId: " .. plr.UserId, C.sub, 9)
            infoLbl.Size = UDim2.new(0.5, 0, 0, 14); infoLbl.Position = UDim2.new(0, 0, 0, 18)

            -- Action buttons on the right
            local btnFrame = Instance.new("Frame", rowF)
            btnFrame.Size = UDim2.new(0.5, -4, 1, 0); btnFrame.Position = UDim2.new(0.5, 0, 0, 0)
            btnFrame.BackgroundTransparency = 1; btnFrame.BorderSizePixel = 0
            mkList(btnFrame, Enum.FillDirection.Horizontal, 3)

            local function qBtn(txt, col, cmd)
                local b = mkBtn(btnFrame, txt, 55, 22, C.bg2, col)
                b.TextSize = 9
                b.Activated:Connect(function() runCommand(cmd .. " " .. plr.Name) end)
            end
            if not isMe then
                qBtn("KILL",    C.danger,  "kill")
                qBtn("KICK",    C.warn,    "kick")
                qBtn("BRING",   C.accent2, "bring")
                qBtn("GOD",     C.accent,  "god")
            else
                qBtn("SPEED",   C.accent,  "speed " .. plr.Name .. " 40")
                qBtn("BTOOLS",  C.warn,    "btools")
                qBtn("GOD",     C.accent,  "god")
            end
        end
    end

    refreshPlayers()

    local refRow = hrow(p, 26)
    local refBtn = mkBtn(refRow, "↻ REFRESH LIST", 120, 22, C.bg2, C.accent2)
    refBtn.Activated:Connect(refreshPlayers)

    Players.PlayerAdded:Connect(function()   task.wait(0.5); refreshPlayers() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshPlayers() end)

    spacer(p, 8)
    secHead(p, "QUICK ACTIONS ON ALL PLAYERS", C.warn)
    local allRow1 = hrow(p, 26)
    local killAllBtn   = mkBtn(allRow1, "KILL ALL",   80, 22, C.bg2, C.danger)
    local godAllBtn    = mkBtn(allRow1, "GOD ALL",    75, 22, C.bg2, C.accent)
    local ungodAllBtn  = mkBtn(allRow1, "UNGOD ALL",  82, 22, C.bg2, C.sub)
    local freezeAllBtn = mkBtn(allRow1, "FREEZE ALL", 85, 22, C.bg2, C.accent2)

    killAllBtn.Activated:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then runCommand("kill " .. plr.Name) end
        end
    end)
    godAllBtn.Activated:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do runCommand("god " .. plr.Name) end
    end)
    ungodAllBtn.Activated:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do runCommand("ungod " .. plr.Name) end
    end)
    freezeAllBtn.Activated:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then runCommand("freeze " .. plr.Name) end
        end
    end)

    spacer(p, 6)
    secHead(p, "COMMANDS REFERENCE", C.sub)
    local cmdScroll = mkScroll(p, 120)
    local cmdList   = {}
    for name, data in pairs(Commands) do
        table.insert(cmdList, { name = name, hint = data.hint })
    end
    table.sort(cmdList, function(a, b) return a.name < b.name end)
    for _, entry in ipairs(cmdList) do
        local col = entry.name == "se" and C.purple or C.sub
        local lbl = mkLabel(cmdScroll, "  /" .. entry.hint, col, 9)
        lbl.Size = UDim2.new(1, -4, 0, 14)
    end
end

-- ══════════════════════════════════════════════════════════════════
--  TAB 4: LOG
-- ══════════════════════════════════════════════════════════════════
local function buildLogTab()
    local tab = newTab("[LOG]", C.sub)
    local p   = tab.panel

    local logFrame = Instance.new("TextLabel", p)
    logFrame.Size = UDim2.new(1, -6, 0, 400)
    logFrame.BackgroundColor3 = C.bg0; logFrame.BorderSizePixel = 0
    logFrame.TextColor3 = C.accent; logFrame.Font = Enum.Font.Code
    logFrame.TextSize = 10; logFrame.TextXAlignment = Enum.TextXAlignment.Left
    logFrame.TextYAlignment = Enum.TextYAlignment.Top
    logFrame.TextWrapped = true; logFrame.RichText = true
    logFrame.Text = ""; logFrame.LayoutOrder = 1
    mkCorner(logFrame, 4); mkStroke(logFrame, C.border, 1, 0.3); mkPad(logFrame, 5)
    State.logLbl = logFrame

    local clearBtn = mkBtn(p, "CLEAR LOG", 90, 20)
    clearBtn.LayoutOrder = 2
    clearBtn.Activated:Connect(function()
        State.logLines = {}
        logFrame.Text = ""
    end)

    local copyHintLbl = mkLabel(p, "  Log shows all command output, execute results, and errors.", C.sub, 9)
    copyHintLbl.Size = UDim2.new(1, -6, 0, 14); copyHintLbl.LayoutOrder = 3
end

-- ══════════════════════════════════════════════════════════════════
--  CMD BOX  (Press M  —  with autocomplete dropdown)
-- ══════════════════════════════════════════════════════════════════
local cmdFrame = Instance.new("Frame", SG)
cmdFrame.Name = "CmdBox"
cmdFrame.Size = UDim2.new(0, 540, 0, 44)
cmdFrame.Position = UDim2.new(0.5, -270, 1, -70)
cmdFrame.BackgroundColor3 = C.bg1; cmdFrame.BorderSizePixel = 0
cmdFrame.Visible = false; cmdFrame.ZIndex = 100
mkCorner(cmdFrame, 12); mkStroke(cmdFrame, C.cmd, 1.5, 0.1)

local cmdPrefixLbl = Instance.new("TextLabel", cmdFrame)
cmdPrefixLbl.Size = UDim2.new(0, 20, 1, 0)
cmdPrefixLbl.BackgroundTransparency = 1
cmdPrefixLbl.Text = "/"
cmdPrefixLbl.TextColor3 = C.cmd; cmdPrefixLbl.Font = Enum.Font.GothamBold
cmdPrefixLbl.TextSize = 18; cmdPrefixLbl.ZIndex = 101

local cmdInput = Instance.new("TextBox", cmdFrame)
cmdInput.Size = UDim2.new(1, -24, 1, 0); cmdInput.Position = UDim2.new(0, 20, 0, 0)
cmdInput.BackgroundTransparency = 1
cmdInput.Text = ""; cmdInput.PlaceholderText = "command [player] [args]  →  e.g. kill SomePlayer   or   se print('hello')"
cmdInput.PlaceholderColor3 = Color3.fromRGB(100, 90, 55)
cmdInput.TextColor3 = C.cmd; cmdInput.Font = Enum.Font.Code
cmdInput.TextSize = 13; cmdInput.ClearTextOnFocus = false; cmdInput.ZIndex = 101

-- Autocomplete popup for CMD box
local cmdAC = Instance.new("Frame", SG)
cmdAC.BackgroundColor3 = C.bg1; cmdAC.BorderSizePixel = 0
cmdAC.ZIndex = 150; cmdAC.Visible = false
cmdAC.Size = UDim2.new(0, 260, 0, 0); cmdAC.AutomaticSize = Enum.AutomaticSize.Y
mkCorner(cmdAC, 6); mkStroke(cmdAC, C.cmd, 1, 0.2)
mkList(cmdAC, Enum.FillDirection.Vertical, 0)

-- Section label inside autocomplete
local cmdACHdr = Instance.new("TextLabel", cmdAC)
cmdACHdr.Size = UDim2.new(1, 0, 0, 18); cmdACHdr.BackgroundColor3 = C.bg0
cmdACHdr.BorderSizePixel = 0; cmdACHdr.TextColor3 = C.cmd
cmdACHdr.Font = Enum.Font.Code; cmdACHdr.TextSize = 9
cmdACHdr.TextXAlignment = Enum.TextXAlignment.Left
cmdACHdr.Text = "  AUTOCOMPLETE"; cmdACHdr.ZIndex = 151

local function positionCmdAC()
    local ap = cmdFrame.AbsolutePosition; local sz = cmdFrame.AbsoluteSize
    cmdAC.Position = UDim2.new(0, ap.X, 0, ap.Y - cmdAC.AbsoluteSize.Y - 6)
end

local function refreshCmdAC()
    -- Remove old entries except header
    for _, c in ipairs(cmdAC:GetChildren()) do
        if c ~= cmdACHdr and not c:IsA("UIListLayout") then c:Destroy() end
    end

    local text  = cmdInput.Text
    local words = {}
    for w in text:gmatch("%S+") do table.insert(words, w) end
    local suggestions = {}

    if #words == 0 or (#words == 1 and text:sub(-1) ~= " ") then
        -- Suggest commands
        local partial = (#words == 1) and words[1]:lower() or ""
        for name in pairs(Commands) do
            if partial == "" or name:find(partial, 1, true) then
                table.insert(suggestions, { type = "cmd", value = name, hint = Commands[name].hint })
            end
        end
        table.sort(suggestions, function(a, b) return a.value < b.value end)
    else
        -- Suggest player names for second+ word
        local partial = (#words >= 2 and text:sub(-1) ~= " ") and words[#words]:lower() or ""
        for _, name in ipairs(getPlayerNames()) do
            if partial == "" or name:lower():find(partial, 1, true) then
                table.insert(suggestions, { type = "player", value = name, hint = "Player" })
            end
        end
    end

    if #suggestions == 0 then cmdAC.Visible = false; return end
    local shown = math.min(#suggestions, 8)
    for i = 1, shown do
        local s = suggestions[i]
        local acBtn = Instance.new("TextButton", cmdAC)
        acBtn.Size = UDim2.new(1, 0, 0, 22); acBtn.BackgroundColor3 = C.bg2
        acBtn.BorderSizePixel = 0; acBtn.AutoButtonColor = false; acBtn.ZIndex = 151
        local prefix = s.type == "cmd" and "  /" or "  @"
        local col    = s.type == "cmd" and C.cmd or C.accent2
        acBtn.Text = prefix .. s.value .. "  "; acBtn.TextColor3 = col
        acBtn.Font = Enum.Font.Code; acBtn.TextSize = 10
        acBtn.TextXAlignment = Enum.TextXAlignment.Left

        local hintLbl2 = Instance.new("TextLabel", acBtn)
        hintLbl2.Size = UDim2.new(1, -120, 1, 0); hintLbl2.Position = UDim2.new(0, 120, 0, 0)
        hintLbl2.BackgroundTransparency = 1; hintLbl2.Text = s.hint
        hintLbl2.TextColor3 = C.sub; hintLbl2.Font = Enum.Font.Code
        hintLbl2.TextSize = 8; hintLbl2.ZIndex = 152
        hintLbl2.TextXAlignment = Enum.TextXAlignment.Left
        hintLbl2.TextTruncate = Enum.TextTruncate.AtEnd

        acBtn.MouseEnter:Connect(function()
            TweenService:Create(acBtn, TweenInfo.new(0.06), { BackgroundColor3 = C.bg3 }):Play()
        end)
        acBtn.MouseLeave:Connect(function()
            TweenService:Create(acBtn, TweenInfo.new(0.06), { BackgroundColor3 = C.bg2 }):Play()
        end)

        local capS = s
        acBtn.MouseButton1Click:Connect(function()
            if capS.type == "cmd" then
                cmdInput.Text = capS.value .. " "
            else
                -- Replace last word with player name
                local before = cmdInput.Text:match("^(.-) *%S*$") or ""
                if before ~= "" then before = before .. " " end
                cmdInput.Text = before .. capS.value .. " "
            end
            cmdAC.Visible = false
            cmdInput:CaptureFocus()
        end)
    end
    cmdAC.Visible = true
    positionCmdAC()
end

cmdInput:GetPropertyChangedSignal("Text"):Connect(refreshCmdAC)

RunService.Heartbeat:Connect(function()
    if cmdAC.Visible then positionCmdAC() end
end)

cmdInput.FocusLost:Connect(function(enter)
    if enter and cmdInput.Text ~= "" then
        runCommand(cmdInput.Text)
        cmdInput.Text = ""
    end
    task.wait(0.2)
    cmdAC.Visible = false
    cmdFrame.Visible = false
end)

-- M key toggle
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.M then
        cmdFrame.Visible = not cmdFrame.Visible
        if cmdFrame.Visible then
            cmdInput.Text = ""
            cmdInput:CaptureFocus()
            refreshCmdAC()
        else
            cmdAC.Visible = false
        end
    end
    -- Escape closes CMD box
    if input.KeyCode == Enum.KeyCode.Escape then
        cmdFrame.Visible = false; cmdAC.Visible = false
    end
end)

-- Notification system
local function notify(msg, color)
    color = color or C.accent
    local note = Instance.new("Frame", SG)
    note.Size = UDim2.new(0, 340, 0, 42)
    note.Position = UDim2.new(0.5, -170, 1, 10)
    note.BackgroundColor3 = C.bg1; note.BorderSizePixel = 0; note.ZIndex = 200
    mkCorner(note, 8); mkStroke(note, color, 1.5, 0.1)
    local noteLbl = mkLabel(note, "  " .. msg, color, 12)
    noteLbl.Size = UDim2.new(1, -12, 1, 0); noteLbl.Position = UDim2.new(0, 8, 0, 0)
    noteLbl.ZIndex = 201
    TweenService:Create(note, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -170, 1, -56) }):Play()
    task.delay(2.8, function()
        TweenService:Create(note, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, -170, 1, 10) }):Play()
        task.wait(0.35); note:Destroy()
    end)
end

-- ──────────────────────────────────────────────────────────────────
--  BUILD TABS
-- ──────────────────────────────────────────────────────────────────
buildAdminTab()
buildExecuteTab()
buildPlayersTab()
buildLogTab()

-- ──────────────────────────────────────────────────────────────────
--  TOGGLE & INIT
-- ──────────────────────────────────────────────────────────────────
toggle.Activated:Connect(function()
    win.Visible = not win.Visible
    if win.Visible and #State.TABS > 0 then
        for _, x in ipairs(State.TABS) do
            x.panel.Visible = false
            TweenService:Create(x.btn, TweenInfo.new(0.08), { BackgroundColor3 = C.bg1, TextColor3 = C.sub }):Play()
        end
        State.TABS[1].panel.Visible = true
        TweenService:Create(State.TABS[1].btn, TweenInfo.new(0.08),
            { BackgroundColor3 = C.bg2, TextColor3 = C.accent }):Play()
    end
end)

-- Boot sequence
task.defer(function()
    if #State.TABS > 0 then
        for _, x in ipairs(State.TABS) do x.panel.Visible = false end
        State.TABS[1].panel.Visible = true
        TweenService:Create(State.TABS[1].btn, TweenInfo.new(0.08),
            { BackgroundColor3 = C.bg2, TextColor3 = C.accent }):Play()
    end

    logS("══════════════════════════════════════")
    logS("  Admin GUI v2.0 loaded")
    logS("  [ADMIN]   — admin commands + autocomplete")
    logX("  [EXECUTE] — script executor + se command")
    logI("  [PLAYERS] — player list + quick actions")
    logS("  Press M to open CMD box")
    logS("══════════════════════════════════════")
    logC("  CMD usage: /kick Player  /se print('hi')")
    logC("  Autocomplete: start typing, pick a suggestion")

    notify("Admin GUI v2.0 ready! Press M for CMD", C.accent)
    print("[Admin GUI v2.0] Loaded — press M for CMD box")
end)
