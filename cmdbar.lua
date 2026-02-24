-- // CmdBar LocalScript

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

-- Fix: script is nil when loadstring'd, so find the GUI manually
local ScreenGui    = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("CmdBarGui")
local RemoteName   = ScreenGui:WaitForChild("RemoteName")
local rf           = game:GetService("ReplicatedStorage"):WaitForChild(RemoteName.Value, 10)
if not rf then warn("CmdBar: RemoteFunction not found.") return end

rf:InvokeServer("Initialize")

-- // Palette
local BG_MID       = Color3.fromRGB(18,  20,  28)
local ACCENT       = Color3.fromRGB(94,  156, 255)
local ACCENT_DIM   = Color3.fromRGB(50,  90,  160)
local TEXT_PRIMARY = Color3.fromRGB(220, 225, 240)
local TEXT_DIM     = Color3.fromRGB(90,  98,  120)
local SUCCESS      = Color3.fromRGB(80,  210, 140)
local WARNING      = Color3.fromRGB(255, 185, 60)
local ERROR_C      = Color3.fromRGB(255, 80,  80)

-- // Helpers
local function Tween(obj, props, t, style, dir)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end

local function MakeCorner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
end

local function MakeStroke(p, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p
end

-- // Status Bar
local StatusBar = Instance.new("Frame")
StatusBar.Size             = UDim2.new(0, 520, 0, 28)
StatusBar.Position         = UDim2.new(0.5, -260, 1, 10)
StatusBar.BackgroundColor3 = BG_MID
StatusBar.BorderSizePixel  = 0
StatusBar.ZIndex           = 199
StatusBar.Parent           = ScreenGui
MakeCorner(StatusBar, 6)
MakeStroke(StatusBar, ACCENT_DIM, 1)
do
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0,12); p.PaddingRight = UDim.new(0,12); p.Parent = StatusBar
end

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size                   = UDim2.new(1, 0, 1, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3             = TEXT_DIM
StatusLabel.TextSize               = 12
StatusLabel.Font                   = Enum.Font.Code
StatusLabel.TextXAlignment         = Enum.TextXAlignment.Left
StatusLabel.TextTruncate           = Enum.TextTruncate.AtEnd
StatusLabel.ZIndex                 = 200
StatusLabel.Parent                 = StatusBar

local function SetStatus(msg, color, duration)
	StatusLabel.Text       = msg
	StatusLabel.TextColor3 = color or TEXT_DIM
	StatusBar.Position     = UDim2.new(0.5, -260, 1, 10)
	Tween(StatusBar, {Position = UDim2.new(0.5, -260, 1, -38)}, 0.25, Enum.EasingStyle.Back)
	task.delay(duration or 3.5, function()
		Tween(StatusBar, {Position = UDim2.new(0.5, -260, 1, 10)}, 0.2)
	end)
end

-- // Command Bar
local CmdBarBG = Instance.new("Frame")
CmdBarBG.Size             = UDim2.new(0, 520, 0, 48)
CmdBarBG.Position         = UDim2.new(0.5, -260, 0, -70)
CmdBarBG.BackgroundColor3 = BG_MID
CmdBarBG.BorderSizePixel  = 0
CmdBarBG.ZIndex           = 200
CmdBarBG.Visible          = false
CmdBarBG.Parent           = ScreenGui
MakeCorner(CmdBarBG, 10)
MakeStroke(CmdBarBG, ACCENT, 1.5)

local GlowStrip = Instance.new("Frame")
GlowStrip.Size                   = UDim2.new(1, -24, 0, 1)
GlowStrip.Position               = UDim2.new(0, 12, 0, 1)
GlowStrip.BackgroundColor3       = ACCENT
GlowStrip.BackgroundTransparency = 0.55
GlowStrip.BorderSizePixel        = 0
GlowStrip.ZIndex                 = 201
GlowStrip.Parent                 = CmdBarBG
MakeCorner(GlowStrip, 2)

local CmdPrefix = Instance.new("TextLabel")
CmdPrefix.Size                   = UDim2.new(0, 24, 1, 0)
CmdPrefix.Position               = UDim2.new(0, 12, 0, 0)
CmdPrefix.BackgroundTransparency = 1
CmdPrefix.Text                   = "›"
CmdPrefix.TextColor3             = ACCENT
CmdPrefix.TextSize               = 20
CmdPrefix.Font                   = Enum.Font.GothamBold
CmdPrefix.ZIndex                 = 201
CmdPrefix.Parent                 = CmdBarBG

local Cursor = Instance.new("Frame")
Cursor.Size             = UDim2.new(0, 2, 0, 18)
Cursor.AnchorPoint      = Vector2.new(0, 0.5)
Cursor.Position         = UDim2.new(0, 40, 0.5, 0)
Cursor.BackgroundColor3 = ACCENT
Cursor.BorderSizePixel  = 0
Cursor.ZIndex           = 202
Cursor.Parent           = CmdBarBG
MakeCorner(Cursor, 2)

local CmdInput = Instance.new("TextBox")
CmdInput.Size                   = UDim2.new(1, -58, 1, -10)
CmdInput.Position               = UDim2.new(0, 44, 0, 5)
CmdInput.BackgroundTransparency = 1
CmdInput.TextColor3             = TEXT_PRIMARY
CmdInput.TextSize               = 14
CmdInput.Font                   = Enum.Font.Code
CmdInput.PlaceholderText        = "Enter Lua code..."
CmdInput.PlaceholderColor3      = TEXT_DIM
CmdInput.ClearTextOnFocus       = false
CmdInput.BorderSizePixel        = 0
CmdInput.ZIndex                 = 201
CmdInput.Text                   = ""
CmdInput.Parent                 = CmdBarBG

-- Cursor blink
task.spawn(function()
	local v = true
	while true do
		task.wait(0.55)
		v = not v
		Cursor.BackgroundTransparency = v and 0 or 1
	end
end)

-- // All execution goes through the RF
local function Run(code)
	local result = rf:InvokeServer("Run", code)
	if result == "Success" then
		return true
	else
		return false, tostring(result)
	end
end

-- // Toggle
local cmdBarVisible = false

local function ToggleCmdBar()
	cmdBarVisible = not cmdBarVisible
	CmdBarBG.Visible = true
	if cmdBarVisible then
		CmdBarBG.Position = UDim2.new(0.5, -260, 0, -70)
		Tween(CmdBarBG, {Position = UDim2.new(0.5, -260, 0, 28)}, 0.28, Enum.EasingStyle.Back)
		task.delay(0.18, function()
			CmdInput.Text = ""
			CmdInput:CaptureFocus()
		end)
	else
		CmdInput:ReleaseFocus()
		Tween(CmdBarBG, {Position = UDim2.new(0.5, -260, 0, -70)}, 0.22)
		task.delay(0.22, function()
			CmdBarBG.Visible = false
			CmdInput.Text = ""
		end)
	end
end

-- // History
local cmdHistory = {}
local historyIdx = 0

-- // Submit
CmdInput.FocusLost:Connect(function(submitted)
	if not submitted then return end

	local raw = CmdInput.Text:match("^%s*(.-)%s*$")
	if raw == "" then ToggleCmdBar() return end

	table.insert(cmdHistory, raw)
	historyIdx = #cmdHistory + 1

	local ok, err = Run(raw)
	SetStatus(ok and "✓ " .. raw:sub(1, 60) or "✗ " .. tostring(err), ok and SUCCESS or ERROR_C, ok and 3 or 6)

	CmdInput.Text = ""
	ToggleCmdBar()
end)

-- // Keybinds
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then
		ToggleCmdBar()
	elseif input.KeyCode == Enum.KeyCode.Escape and cmdBarVisible then
		ToggleCmdBar()
	elseif cmdBarVisible and input.KeyCode == Enum.KeyCode.Up then
		if #cmdHistory == 0 then return end
		historyIdx = math.max(1, historyIdx - 1)
		CmdInput.Text = cmdHistory[historyIdx] or ""
		task.defer(function() CmdInput.CursorPosition = #CmdInput.Text + 1 end)
	elseif cmdBarVisible and input.KeyCode == Enum.KeyCode.Down then
		historyIdx = math.min(#cmdHistory + 1, historyIdx + 1)
		CmdInput.Text = cmdHistory[historyIdx] or ""
		task.defer(function() CmdInput.CursorPosition = #CmdInput.Text + 1 end)
	end
end)

SetStatus("CmdBar ready  •  [M] to open", ACCENT, 4)
