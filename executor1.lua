-- ============================================================
-- SERVER DEV CONSOLE  |  github-hosted, loadstring-compatible
-- ============================================================
-- SETUP (one-time, in Studio before publishing):
--   1. ServerScriptService  → LoadStringEnabled = true
--   2. HttpService          → HttpEnabled = true
--   3. Publish game
--
-- LOAD IN-GAME (paste into the SERVER console, F9 → Server tab):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/executor.lua"))()
--
-- The script runs SERVER-SIDE. It finds you by UserId and injects
-- the GUI into your PlayerGui, then uses a RemoteEvent so the
-- Execute button calls loadstring() on the server.
-- ============================================================

local OWNER_ID = 846325069  -- ← REPLACE with your Roblox UserId (numbers only)
-- You can find your UserId at: https://www.roblox.com/users/profile
-- Example: local OWNER_ID = 123456789

-- ============================================================
-- Safety checks
-- ============================================================
if not pcall(function() return loadstring("return true")() end) then
	error("[DevConsole] LoadStringEnabled is not set to true in ServerScriptService! Enable it in Studio and republish.")
end

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")

-- ============================================================
-- Find the owner's Player object (wait up to 30 s if loading)
-- ============================================================
local ownerPlayer
do
	local deadline = tick() + 30
	repeat
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == OWNER_ID then
				ownerPlayer = p
				break
			end
		end
		if not ownerPlayer then task.wait(1) end
	until ownerPlayer or tick() > deadline

	if not ownerPlayer then
		-- fallback: try the first player in the server (handy during solo testing)
		ownerPlayer = Players:GetPlayers()[1]
		if not ownerPlayer then
			error("[DevConsole] Owner not found in server. Make sure you're in the game and OWNER_ID is set correctly.")
		end
		warn("[DevConsole] OWNER_ID not matched – falling back to: " .. ownerPlayer.Name ..
			 "  ← Set OWNER_ID = " .. ownerPlayer.UserId .. " to silence this.")
	end
end

print("[DevConsole] Attaching to: " .. ownerPlayer.Name)

-- ============================================================
-- RemoteEvent for GUI → Server communication
-- ============================================================
local remoteFolder = Instance.new("Folder")
remoteFolder.Name  = "_DevConsoleRemotes"
remoteFolder.Parent = game:GetService("ReplicatedStorage")

local execRemote   = Instance.new("RemoteEvent")
execRemote.Name    = "Execute"
execRemote.Parent  = remoteFolder

local resultRemote = Instance.new("RemoteEvent")
resultRemote.Name  = "Result"
resultRemote.Parent = remoteFolder

-- Server listens for Execute calls from the owner only
execRemote.OnServerEvent:Connect(function(player, code)
	if player.UserId ~= ownerPlayer.UserId then return end  -- owner-only guard
	if type(code) ~= "string" or code == "" then
		resultRemote:FireClient(player, false, "Empty script.")
		return
	end
	local fn, compileErr = loadstring(code)
	if not fn then
		resultRemote:FireClient(player, false, "Compile error: " .. tostring(compileErr))
		return
	end
	local ok, runErr = pcall(fn)
	if ok then
		resultRemote:FireClient(player, true, "Executed successfully.")
	else
		resultRemote:FireClient(player, false, "Runtime error: " .. tostring(runErr))
	end
end)

-- ============================================================
-- Inject the GUI into the owner's PlayerGui (via LocalScript)
-- ============================================================
-- We create a LocalScript inside the owner's PlayerGui so that
-- the GUI itself lives on the client (input, tweens, TextBoxes),
-- while all execution happens server-side through the RemoteEvent.
-- ============================================================

local guiScript = Instance.new("LocalScript")
guiScript.Name  = "DevConsoleGUI"

-- Embed the entire client GUI as a string and loadstring it.
-- (This is the standard pattern for remote-loaded GUIs.)
local CLIENT_GUI_SOURCE = [==[
-- DevConsole client GUI
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local remoteFolder  = ReplicatedStorage:WaitForChild("_DevConsoleRemotes", 10)
local execRemote    = remoteFolder and remoteFolder:WaitForChild("Execute",  10)
local resultRemote  = remoteFolder and remoteFolder:WaitForChild("Result",   10)

if not execRemote or not resultRemote then
	warn("[DevConsole] Remotes not found – GUI will display but Execute won't work.")
end

-- ── Palette ───────────────────────────────────────────────────
local ACCENT       = Color3.fromRGB(99,  179, 255)
local ACCENT2      = Color3.fromRGB(60,  130, 220)
local BG_DARK      = Color3.fromRGB(10,  12,  18)
local BG_MID       = Color3.fromRGB(16,  19,  28)
local BG_LIGHT     = Color3.fromRGB(22,  27,  40)
local BG_PANEL     = Color3.fromRGB(28,  34,  50)
local TEXT_PRIMARY = Color3.fromRGB(220, 230, 255)
local TEXT_DIM     = Color3.fromRGB(100, 115, 155)
local SUCCESS      = Color3.fromRGB(80,  220, 140)
local ERROR_C      = Color3.fromRGB(255, 90,  90)
local WARNING      = Color3.fromRGB(255, 200, 80)
local MAX_TABS     = 8

-- ── State ──────────────────────────────────────────────────────
local tabs       = {}
local activeTab  = nil
local tabCount   = 0
local isDragging = false
local dragOffset = Vector2.new()

-- ── Helpers ────────────────────────────────────────────────────
local function Tween(obj, props, t, style, dir)
	TweenService:Create(obj,
		TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		props):Play()
end

local function MakeCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = parent
end

local function MakeStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color     = color or Color3.fromRGB(40, 50, 75)
	s.Thickness = thickness or 1
	s.Parent    = parent
end

local function MakeGradient(parent, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color    = ColorSequence.new(c0 or BG_DARK, c1 or BG_MID)
	g.Rotation = rot or 90
	g.Parent   = parent
end

-- ── Destroy stale GUI ─────────────────────────────────────────
if PlayerGui:FindFirstChild("DevConsole") then
	PlayerGui.DevConsole:Destroy()
end

-- ── ScreenGui ─────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "DevConsole"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder   = 999
ScreenGui.Parent         = PlayerGui

-- ── Main Frame ────────────────────────────────────────────────
local Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.new(0, 720, 0, 500)
Main.Position         = UDim2.new(0.5, -360, 0.5, -250)
Main.BackgroundColor3 = BG_DARK
Main.BorderSizePixel  = 0
Main.ClipsDescendants = true
Main.Parent           = ScreenGui
MakeStroke(Main, Color3.fromRGB(35, 45, 70), 1.5)
MakeCorner(Main, 8)

-- ── Title Bar ─────────────────────────────────────────────────
local TitleBar = Instance.new("Frame")
TitleBar.Name            = "TitleBar"
TitleBar.Size            = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3= BG_MID
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex          = 2
TitleBar.Parent          = Main
MakeGradient(TitleBar, BG_MID, Color3.fromRGB(14, 17, 26), 90)

local TitleAccent = Instance.new("Frame")
TitleAccent.Size             = UDim2.new(1, 0, 0, 2)
TitleAccent.Position         = UDim2.new(0, 0, 1, -2)
TitleAccent.BackgroundColor3 = ACCENT
TitleAccent.BorderSizePixel  = 0
TitleAccent.ZIndex           = 3
TitleAccent.Parent           = TitleBar
MakeGradient(TitleAccent, ACCENT, Color3.fromRGB(30, 60, 120), 0)

local function TLabel(parent, text, color, size, font, x, y, w, h, zi)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text     = text
	l.TextColor3 = color
	l.TextSize = size
	l.Font     = font
	l.Position = UDim2.new(0, x, 0, y)
	l.Size     = UDim2.new(0, w, 0, h)
	l.ZIndex   = zi or 3
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent   = parent
	return l
end

TLabel(TitleBar, "⚡", ACCENT, 18, Enum.Font.GothamBold, 10, 4, 28, 30)
TLabel(TitleBar, "SERVER DEV CONSOLE", TEXT_PRIMARY, 12, Enum.Font.GothamBold, 44, 0, 220, 38)
TLabel(TitleBar, "v3.0  loadstring edition", ACCENT, 10, Enum.Font.Gotham, 270, 0, 200, 38)

-- ── Window control buttons ─────────────────────────────────────
local function CtrlBtn(xOffset, color, symbol, action)
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(0, 14, 0, 14)
	b.Position         = UDim2.new(1, xOffset, 0.5, -7)
	b.BackgroundColor3 = color
	b.Text             = ""
	b.BorderSizePixel  = 0
	b.ZIndex           = 4
	b.Parent           = TitleBar
	MakeCorner(b, 7)
	b.MouseEnter:Connect(function()
		b.Text = symbol; b.TextSize = 8
		b.TextColor3 = Color3.fromRGB(0,0,0)
		b.Font = Enum.Font.GothamBold
	end)
	b.MouseLeave:Connect(function() b.Text = "" end)
	b.MouseButton1Click:Connect(action)
end

CtrlBtn(-20, Color3.fromRGB(255, 95, 87), "x", function()
	Tween(Main, {Size = UDim2.new(0,720,0,0), Position = UDim2.new(0.5,-360,0.5,0)}, 0.25)
	task.delay(0.25, function() ScreenGui:Destroy() end)
end)
CtrlBtn(-40, Color3.fromRGB(255,189,46), "−", function()
	local mini = Main.Size.Y.Offset < 60
	Tween(Main, {Size = mini and UDim2.new(0,720,0,500) or UDim2.new(0,720,0,38)}, 0.3)
end)
CtrlBtn(-60, Color3.fromRGB(40,205,65), "+", function()
	local big = Main.Size.X.Offset > 740
	Tween(Main, {Size = big and UDim2.new(0,720,0,500) or UDim2.new(0,960,0,620)}, 0.3)
end)

-- ── Dragging ──────────────────────────────────────────────────
TitleBar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
		dragOffset = Vector2.new(
			i.Position.X - Main.AbsolutePosition.X,
			i.Position.Y - Main.AbsolutePosition.Y)
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if isDragging and i.UserInputType == Enum.UserInputType.MouseMovement then
		Main.Position = UDim2.new(0, i.Position.X - dragOffset.X, 0, i.Position.Y - dragOffset.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
end)

-- ── Tab Bar ───────────────────────────────────────────────────
local TabBar = Instance.new("Frame")
TabBar.Name            = "TabBar"
TabBar.Size            = UDim2.new(1, 0, 0, 32)
TabBar.Position        = UDim2.new(0, 0, 0, 38)
TabBar.BackgroundColor3= BG_MID
TabBar.BorderSizePixel = 0
TabBar.ZIndex          = 2
TabBar.Parent          = Main

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Size               = UDim2.new(1, -36, 1, 0)
TabScroll.BackgroundTransparency = 1
TabScroll.ScrollBarThickness = 0
TabScroll.CanvasSize         = UDim2.new(0,0,0,0)
TabScroll.ZIndex             = 2
TabScroll.Parent             = TabBar

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding       = UDim.new(0, 2)
TabLayout.Parent        = TabScroll
TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	TabScroll.CanvasSize = UDim2.new(0, TabLayout.AbsoluteContentSize.X, 1, 0)
end)

local AddTabBtn = Instance.new("TextButton")
AddTabBtn.Size            = UDim2.new(0, 32, 0, 32)
AddTabBtn.Position        = UDim2.new(1, -34, 0, 0)
AddTabBtn.BackgroundColor3= BG_LIGHT
AddTabBtn.Text            = "+"
AddTabBtn.TextColor3      = ACCENT
AddTabBtn.TextSize        = 18
AddTabBtn.Font            = Enum.Font.GothamBold
AddTabBtn.BorderSizePixel = 0
AddTabBtn.ZIndex          = 3
AddTabBtn.Parent          = TabBar

-- ── Editor Area ───────────────────────────────────────────────
local EditorBG = Instance.new("Frame")
EditorBG.Name             = "EditorBG"
EditorBG.Size             = UDim2.new(1, 0, 1, -152)
EditorBG.Position         = UDim2.new(0, 0, 0, 70)
EditorBG.BackgroundColor3 = BG_DARK
EditorBG.BorderSizePixel  = 0
EditorBG.Parent           = Main

local Gutter = Instance.new("Frame")
Gutter.Size            = UDim2.new(0, 40, 1, 0)
Gutter.BackgroundColor3= BG_MID
Gutter.BorderSizePixel = 0
Gutter.ZIndex          = 2
Gutter.Parent          = EditorBG

local GutterLabel = Instance.new("TextLabel")
GutterLabel.Size             = UDim2.new(1, -6, 1, 0)
GutterLabel.BackgroundTransparency = 1
GutterLabel.TextColor3       = TEXT_DIM
GutterLabel.TextSize         = 12
GutterLabel.Font             = Enum.Font.Code
GutterLabel.TextXAlignment   = Enum.TextXAlignment.Right
GutterLabel.TextYAlignment   = Enum.TextYAlignment.Top
GutterLabel.ZIndex           = 3
GutterLabel.Parent           = Gutter

local GutterDiv = Instance.new("Frame")
GutterDiv.Size            = UDim2.new(0, 1, 1, 0)
GutterDiv.Position        = UDim2.new(1, -1, 0, 0)
GutterDiv.BackgroundColor3= Color3.fromRGB(35, 45, 70)
GutterDiv.BorderSizePixel = 0
GutterDiv.ZIndex          = 3
GutterDiv.Parent          = Gutter

local Editor = Instance.new("TextBox")
Editor.Name              = "Editor"
Editor.Size              = UDim2.new(1, -46, 1, -8)
Editor.Position          = UDim2.new(0, 44, 0, 4)
Editor.BackgroundTransparency = 1
Editor.TextColor3        = TEXT_PRIMARY
Editor.TextSize          = 12
Editor.Font              = Enum.Font.Code
Editor.MultiLine         = true
Editor.ClearTextOnFocus  = false
Editor.TextXAlignment    = Enum.TextXAlignment.Left
Editor.TextYAlignment    = Enum.TextYAlignment.Top
Editor.PlaceholderText   = "-- Type or paste server-side Lua here\n-- Ctrl+Enter to execute"
Editor.PlaceholderColor3 = TEXT_DIM
Editor.BorderSizePixel   = 0
Editor.ZIndex            = 2
Editor.Text              = ""
Editor.Parent            = EditorBG

Editor:GetPropertyChangedSignal("Text"):Connect(function()
	local n = 0
	for _ in (Editor.Text .. "\n"):gmatch("[^\n]*\n") do n += 1 end
	n = math.max(n, 20)
	local t = table.create(n)
	for i = 1, n do t[i] = tostring(i) end
	GutterLabel.Text = table.concat(t, "\n")
end)

-- ── Bottom Bar ────────────────────────────────────────────────
local BottomBar = Instance.new("Frame")
BottomBar.Name            = "BottomBar"
BottomBar.Size            = UDim2.new(1, 0, 0, 80)
BottomBar.Position        = UDim2.new(0, 0, 1, -80)
BottomBar.BackgroundColor3= BG_MID
BottomBar.BorderSizePixel = 0
BottomBar.ZIndex          = 2
BottomBar.Parent          = Main

local StatusBar = Instance.new("Frame")
StatusBar.Size            = UDim2.new(1, 0, 0, 22)
StatusBar.BackgroundColor3= BG_LIGHT
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex          = 3
StatusBar.Parent          = BottomBar

local StatusText = Instance.new("TextLabel")
StatusText.Size              = UDim2.new(1, -20, 1, 0)
StatusText.Position          = UDim2.new(0, 10, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.TextColor3        = SUCCESS
StatusText.TextSize          = 10
StatusText.Font              = Enum.Font.Gotham
StatusText.TextXAlignment    = Enum.TextXAlignment.Left
StatusText.ZIndex            = 4
StatusText.Parent            = StatusBar

local function SetStatus(msg, color)
	StatusText.Text      = "● " .. msg
	StatusText.TextColor3 = color or SUCCESS
end

-- ── Result display ────────────────────────────────────────────
-- Listen for server responses and show them in the status bar
if resultRemote then
	resultRemote.OnClientEvent:Connect(function(ok, msg)
		SetStatus(msg, ok and SUCCESS or ERROR_C)
		-- Also print to local output for longer errors
		if not ok then
			warn("[DevConsole Server Error] " .. tostring(msg))
		end
	end)
end

-- ── Button factory ────────────────────────────────────────────
local function MakeButton(label, pos, w, color, cb)
	local b = Instance.new("TextButton")
	b.Size            = UDim2.new(0, w, 0, 32)
	b.Position        = pos
	b.BackgroundColor3= color or BG_PANEL
	b.Text            = label
	b.TextColor3      = TEXT_PRIMARY
	b.TextSize        = 11
	b.Font            = Enum.Font.GothamBold
	b.BorderSizePixel = 0
	b.ZIndex          = 4
	b.Parent          = BottomBar
	MakeCorner(b, 6)
	MakeStroke(b, Color3.fromRGB(40, 50, 75))
	b.MouseEnter:Connect(function()
		Tween(b, {BackgroundColor3 = (color or BG_PANEL):Lerp(Color3.new(1,1,1), 0.12)}, 0.12)
	end)
	b.MouseLeave:Connect(function()
		Tween(b, {BackgroundColor3 = color or BG_PANEL}, 0.12)
	end)
	b.MouseButton1Click:Connect(cb)
	return b
end

-- Execute button fires the RemoteEvent
MakeButton("⚡ EXECUTE", UDim2.new(0, 10, 0, 34), 120, Color3.fromRGB(30, 80, 200), function()
	if activeTab then tabs[activeTab].content = Editor.Text end
	local code = Editor.Text
	if code == "" then SetStatus("Nothing to execute!", WARNING) return end
	if not execRemote then SetStatus("Remote not available.", ERROR_C) return end
	SetStatus("Sending to server…", WARNING)
	execRemote:FireServer(code)
end)

MakeButton("🗑 CLEAR",  UDim2.new(0, 140, 0, 34),  90, Color3.fromRGB(50, 30, 30), function()
	Editor.Text = ""
	if activeTab then tabs[activeTab].content = "" end
	SetStatus("Cleared.", TEXT_DIM)
end)

MakeButton("📋 COPY",  UDim2.new(0, 240, 0, 34),  90, BG_PANEL, function()
	setclipboard(Editor.Text)
	SetStatus("Copied to clipboard.", SUCCESS)
end)

MakeButton("💾 SAVE",  UDim2.new(0, 340, 0, 34),  90, BG_PANEL, function()
	if activeTab then
		tabs[activeTab].content = Editor.Text
		SetStatus("Saved → " .. tabs[activeTab].name, SUCCESS)
	end
end)

MakeButton("📂 LOAD",  UDim2.new(0, 440, 0, 34),  90, BG_PANEL, function()
	pcall(function()
		local c = readfile and readfile("devconsole_script.lua") or nil
		if c then Editor.Text = c; SetStatus("Loaded from file.", SUCCESS)
		else SetStatus("readfile() not available here.", WARNING) end
	end)
end)

-- ── Tab system ────────────────────────────────────────────────
local function SwitchTab(id)
	if activeTab and tabs[activeTab] then
		tabs[activeTab].content = Editor.Text
		Tween(tabs[activeTab].button, {BackgroundColor3 = BG_LIGHT}, 0.12)
		tabs[activeTab].label.TextColor3 = TEXT_DIM
	end
	activeTab = id
	if tabs[id] then
		Editor.Text = tabs[id].content
		Tween(tabs[id].button, {BackgroundColor3 = ACCENT2}, 0.12)
		tabs[id].label.TextColor3 = Color3.new(1,1,1)
		SetStatus("Tab: " .. tabs[id].name, ACCENT)
	end
end

local function CreateTab(name)
	if tabCount >= MAX_TABS then SetStatus("Max tabs reached!", WARNING) return end
	tabCount += 1
	local id  = tabCount
	local tName = name or ("Tab " .. id)

	local Btn = Instance.new("TextButton")
	Btn.Size            = UDim2.new(0, 96, 0, 32)
	Btn.BackgroundColor3= BG_LIGHT
	Btn.Text            = ""
	Btn.BorderSizePixel = 0
	Btn.ZIndex          = 3
	Btn.LayoutOrder     = id
	Btn.Parent          = TabScroll

	local Lbl = Instance.new("TextLabel")
	Lbl.Size             = UDim2.new(1, -22, 1, 0)
	Lbl.BackgroundTransparency = 1
	Lbl.Text             = tName
	Lbl.TextColor3       = TEXT_DIM
	Lbl.TextSize         = 11
	Lbl.Font             = Enum.Font.Gotham
	Lbl.TextXAlignment   = Enum.TextXAlignment.Left
	Lbl.Position         = UDim2.new(0, 8, 0, 0)
	Lbl.ZIndex           = 4
	Lbl.Parent           = Btn

	local XBtn = Instance.new("TextButton")
	XBtn.Size            = UDim2.new(0, 16, 0, 16)
	XBtn.Position        = UDim2.new(1, -18, 0.5, -8)
	XBtn.BackgroundTransparency = 1
	XBtn.Text            = "×"
	XBtn.TextColor3      = TEXT_DIM
	XBtn.TextSize        = 14
	XBtn.Font            = Enum.Font.GothamBold
	XBtn.ZIndex          = 5
	XBtn.Parent          = Btn
	XBtn.MouseEnter:Connect(function()  XBtn.TextColor3 = ERROR_C  end)
	XBtn.MouseLeave:Connect(function()  XBtn.TextColor3 = TEXT_DIM end)
	XBtn.MouseButton1Click:Connect(function()
		Btn:Destroy()
		tabs[id] = nil
		if activeTab == id then
			activeTab = nil
			for tid in pairs(tabs) do SwitchTab(tid) break end
			if not activeTab then Editor.Text = ""; SetStatus("No tabs open.", TEXT_DIM) end
		end
	end)

	local lastClick = 0
	Btn.MouseButton1Click:Connect(function()
		local now = tick()
		if now - lastClick < 0.3 then
			-- double-click = rename
			local box = Instance.new("TextBox")
			box.Size            = UDim2.new(1, -22, 1, 0)
			box.Position        = UDim2.new(0, 8, 0, 0)
			box.BackgroundTransparency = 1
			box.TextColor3      = TEXT_PRIMARY
			box.TextSize        = 11
			box.Font            = Enum.Font.Gotham
			box.Text            = tName
			box.BorderSizePixel = 0
			box.ZIndex          = 6
			box.Parent          = Btn
			box:CaptureFocus()
			box.FocusLost:Connect(function()
				local n = box.Text ~= "" and box.Text or tName
				tabs[id].name = n; Lbl.Text = n; box:Destroy()
			end)
		else
			SwitchTab(id)
		end
		lastClick = now
	end)

	tabs[id] = { name = tName, content = "", button = Btn, label = Lbl }
	SwitchTab(id)
	return id
end

AddTabBtn.MouseButton1Click:Connect(CreateTab)

-- ── Ctrl+Enter shortcut ───────────────────────────────────────
Editor.InputBegan:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.Return and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		if activeTab then tabs[activeTab].content = Editor.Text end
		if Editor.Text ~= "" and execRemote then
			SetStatus("Sending to server…", WARNING)
			execRemote:FireServer(Editor.Text)
		end
	end
end)

-- ── Command Bar ───────────────────────────────────────────────
local CmdBG = Instance.new("Frame")
CmdBG.Name            = "CommandBar"
CmdBG.Size            = UDim2.new(0, 520, 0, 46)
CmdBG.Position        = UDim2.new(0.5, -260, 0, -60)
CmdBG.BackgroundColor3= BG_MID
CmdBG.BorderSizePixel = 0
CmdBG.ZIndex          = 200
CmdBG.Visible         = false
CmdBG.Parent          = ScreenGui
MakeStroke(CmdBG, ACCENT, 1.5)
MakeCorner(CmdBG, 8)

local CmdPrefix = Instance.new("TextLabel")
CmdPrefix.Size            = UDim2.new(0, 30, 1, 0)
CmdPrefix.Position        = UDim2.new(0, 10, 0, 0)
CmdPrefix.BackgroundTransparency = 1
CmdPrefix.Text            = ">"
CmdPrefix.TextColor3      = ACCENT
CmdPrefix.TextSize        = 16
CmdPrefix.Font            = Enum.Font.GothamBold
CmdPrefix.ZIndex          = 201
CmdPrefix.Parent          = CmdBG

local CmdInput = Instance.new("TextBox")
CmdInput.Size            = UDim2.new(1, -50, 1, -10)
CmdInput.Position        = UDim2.new(0, 40, 0, 5)
CmdInput.BackgroundTransparency = 1
CmdInput.TextColor3      = TEXT_PRIMARY
CmdInput.TextSize        = 13
CmdInput.Font            = Enum.Font.Code
CmdInput.PlaceholderText = "Lua code or: clear  newtab [name]  help"
CmdInput.PlaceholderColor3= TEXT_DIM
CmdInput.ClearTextOnFocus= false
CmdInput.BorderSizePixel = 0
CmdInput.ZIndex          = 201
CmdInput.Text            = ""
CmdInput.Parent          = CmdBG

local cmdOpen = false
local function ToggleCmd()
	cmdOpen = not cmdOpen
	CmdBG.Visible = true
	if cmdOpen then
		CmdBG.Position = UDim2.new(0.5,-260,0,-60)
		Tween(CmdBG, {Position = UDim2.new(0.5,-260,0,30)}, 0.25, Enum.EasingStyle.Back)
		task.delay(0.15, function() CmdInput.Text=""; CmdInput:CaptureFocus() end)
	else
		CmdInput:ReleaseFocus()
		Tween(CmdBG, {Position = UDim2.new(0.5,-260,0,-60)}, 0.2)
		task.delay(0.2, function() CmdBG.Visible=false; CmdInput.Text="" end)
	end
end

local builtins = {
	clear  = function()   Editor.Text=""; SetStatus("Cleared.",TEXT_DIM) end,
	newtab = function(a)  CreateTab(a[1]) end,
	help   = function()
		SetStatus("clear | newtab [name] | help | any Lua → sent to server", ACCENT)
	end,
}

CmdInput.FocusLost:Connect(function(submitted)
	if not submitted then return end
	local raw = CmdInput.Text
	if raw == "" then ToggleCmd() return end
	local parts = raw:split(" ")
	local cmd   = parts[1]:lower(); table.remove(parts,1)
	if builtins[cmd] then
		builtins[cmd](parts)
	elseif execRemote then
		SetStatus("Sending: " .. raw:sub(1,50), WARNING)
		execRemote:FireServer(raw)
	end
	CmdInput.Text = ""
	ToggleCmd()
end)

UserInputService.InputBegan:Connect(function(i, processed)
	if processed then return end
	if i.KeyCode == Enum.KeyCode.M then ToggleCmd() end
	if i.KeyCode == Enum.KeyCode.Escape and cmdOpen then ToggleCmd() end
end)

-- ── Animate in ────────────────────────────────────────────────
Main.Size     = UDim2.new(0,0,0,0)
Main.Position = UDim2.new(0.5,0,0.5,0)
Tween(Main, {Size = UDim2.new(0,720,0,500), Position = UDim2.new(0.5,-360,0.5,-250)},
	0.4, Enum.EasingStyle.Back)

CreateTab("Script 1")
CreateTab("Script 2")
CreateTab("Scratch")

SetStatus("Ready  |  [M] = command bar  |  Ctrl+Enter = execute  |  loadstring enabled ✓", SUCCESS)
print("[DevConsole] GUI ready. Happy scripting, " .. LocalPlayer.Name .. "!")
]==]

guiScript.Source = CLIENT_GUI_SOURCE
guiScript.Parent = ownerPlayer:WaitForChild("PlayerGui")

print("[DevConsole] Server setup complete. GUI injected into " .. ownerPlayer.Name .. "'s screen.")
print("[DevConsole] Remotes live at ReplicatedStorage._DevConsoleRemotes")
print("[DevConsole] All code entered in the GUI is executed server-side via loadstring().")

-- Cleanup remotes if the owner leaves
Players.PlayerRemoving:Connect(function(p)
	if p == ownerPlayer then
		remoteFolder:Destroy()
		print("[DevConsole] Owner left – remotes cleaned up.")
	end
end)
