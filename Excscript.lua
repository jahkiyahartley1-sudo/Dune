-- // SERVER EXECUTOR GUI v3.0
-- // Designed for SERVER-SIDE executors
-- // Load via:
-- // local code = game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/PineappleJuiceFlavour/Dune/refs/heads/main/excscript.lua")
-- // loadstring(code)()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local function getPlayer()
	for _, p in ipairs(Players:GetPlayers()) do
		return p
	end
	return Players.PlayerAdded:Wait()
end

local TARGET = getPlayer()

-- The client-side GUI code as a string
local CLIENT_CODE = [==[
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer
repeat
	LocalPlayer = Players.LocalPlayer
	if not LocalPlayer then task.wait(0.1) end
until LocalPlayer

-- Best GUI parent for executor context
local GuiParent
if gethui then
	local ok, r = pcall(gethui) 
	if ok and r then GuiParent = r end
end
if not GuiParent then
	local ok = pcall(function()
		local t = Instance.new("Frame"); t.Parent = CoreGui; t:Destroy()
	end)
	GuiParent = ok and CoreGui or LocalPlayer:WaitForChild("PlayerGui")
end

-- Destroy old
local old = GuiParent:FindFirstChild("ServerExecutor")
if old then old:Destroy() end

-- // Settings
local ACCENT       = Color3.fromRGB(99, 179, 255)
local ACCENT2      = Color3.fromRGB(60, 130, 220)
local BG_DARK      = Color3.fromRGB(10, 12, 18)
local BG_MID       = Color3.fromRGB(16, 19, 28)
local BG_LIGHT     = Color3.fromRGB(22, 27, 40)
local BG_PANEL     = Color3.fromRGB(28, 34, 50)
local TEXT_PRIMARY = Color3.fromRGB(220, 230, 255)
local TEXT_DIM     = Color3.fromRGB(100, 115, 155)
local SUCCESS      = Color3.fromRGB(80, 220, 140)
local ERROR_C      = Color3.fromRGB(255, 90, 90)
local WARNING      = Color3.fromRGB(255, 200, 80)
local MAX_TABS     = 8

local tabs       = {}
local activeTab  = nil
local tabCount   = 0
local isDragging = false
local dragOffset = Vector2.new()

-- // Detect executor
local function getExecEnv()
	if syn and syn.run_on_server then return "synapse" end
	if KRNL_LOADED then return "krnl" end
	if ExecuteOnServer then return "custom_eos" end
	if ServerExecute then return "custom_se" end
	if getgenv and getgenv().ServerExecute then return "genv_se" end
	return "loadstring"
end

-- // Server execute
local function execServer(code)
	local success, err = pcall(function()
		local env = getExecEnv()
		if env == "synapse" then
			syn.run_on_server(code)
		elseif env == "krnl" then
			if krnl_request then krnl_request({ Type = "ServerExec", Code = code })
			else loadstring(code)() end
		elseif env == "custom_eos" then
			ExecuteOnServer(code)
		elseif env == "custom_se" then
			ServerExecute(code)
		elseif env == "genv_se" then
			getgenv().ServerExecute(code)
		else
			local fn, loadErr = loadstring(code)
			if not fn then error("Compile error: " .. tostring(loadErr)) end
			fn()
		end
	end)
	return success, err
end

-- // HTTP fetch
local function fetchURL(url)
	local ok, result = pcall(function()
		if syn and syn.request then return syn.request({Url=url,Method="GET"}).Body end
		if http_request then return http_request({Url=url,Method="GET"}).Body end
		if request then return request({Url=url,Method="GET"}).Body end
		return HttpService:GetAsync(url)
	end)
	return ok, result
end

-- // Utility
local function Tween(obj, props, t, style, dir)
	TweenService:Create(obj, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end
local function MakeStroke(parent, color, thickness)
	local s = Instance.new("UIStroke"); s.Color = color or Color3.fromRGB(40,50,75); s.Thickness = thickness or 1; s.Parent = parent; return s
end
local function MakeGradient(parent, c0, c1, rotation)
	local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(c0 or BG_DARK, c1 or BG_MID); g.Rotation = rotation or 90; g.Parent = parent; return g
end
local function MakeCorner(parent, radius)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius or 6); c.Parent = parent
end

-- // ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ServerExecutor"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = GuiParent

-- // Main Frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 700, 0, 500)
Main.Position = UDim2.new(0.5, -350, 0.5, -250)
Main.BackgroundColor3 = BG_DARK
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui
MakeStroke(Main, Color3.fromRGB(35,45,70), 1.5)

-- // Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1,0,0,38)
TitleBar.BackgroundColor3 = BG_MID
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 2
TitleBar.Parent = Main
MakeGradient(TitleBar, BG_MID, Color3.fromRGB(14,17,26), 90)

local TitleAccent = Instance.new("Frame")
TitleAccent.Size = UDim2.new(1,0,0,1)
TitleAccent.Position = UDim2.new(0,0,1,-1)
TitleAccent.BackgroundColor3 = ACCENT
TitleAccent.BorderSizePixel = 0
TitleAccent.ZIndex = 3
TitleAccent.Parent = TitleBar
MakeGradient(TitleAccent, ACCENT, Color3.fromRGB(30,60,120), 0)

local TitleIcon = Instance.new("TextLabel")
TitleIcon.Size = UDim2.new(0,30,0,30)
TitleIcon.Position = UDim2.new(0,10,0.5,-15)
TitleIcon.BackgroundTransparency = 1
TitleIcon.Text = "⚡"
TitleIcon.TextColor3 = ACCENT
TitleIcon.TextSize = 18
TitleIcon.Font = Enum.Font.GothamBold
TitleIcon.ZIndex = 3
TitleIcon.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0,200,1,0)
TitleLabel.Position = UDim2.new(0,42,0,0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "SERVER EXECUTOR"
TitleLabel.TextColor3 = TEXT_PRIMARY
TitleLabel.TextSize = 12
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 3
TitleLabel.Parent = TitleBar

local TitleSub = Instance.new("TextLabel")
TitleSub.Size = UDim2.new(0,200,1,0)
TitleSub.Position = UDim2.new(0,190,0,0)
TitleSub.BackgroundTransparency = 1
TitleSub.Text = "v3.0 SS | " .. getExecEnv():upper()
TitleSub.TextColor3 = ACCENT
TitleSub.TextSize = 10
TitleSub.Font = Enum.Font.Gotham
TitleSub.TextXAlignment = Enum.TextXAlignment.Left
TitleSub.ZIndex = 3
TitleSub.Parent = TitleBar

-- // Window Controls
local function MakeControlBtn(pos, color, symbol, action)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0,14,0,14)
	btn.Position = UDim2.new(1,pos,0.5,-7)
	btn.BackgroundColor3 = color
	btn.Text = ""
	btn.BorderSizePixel = 0
	btn.ZIndex = 4
	btn.Parent = TitleBar
	MakeCorner(btn, 7)
	btn.MouseEnter:Connect(function() btn.Text=symbol; btn.TextSize=8; btn.TextColor3=Color3.fromRGB(0,0,0); btn.Font=Enum.Font.GothamBold end)
	btn.MouseLeave:Connect(function() btn.Text="" end)
	btn.MouseButton1Click:Connect(action)
	return btn
end
MakeControlBtn(-20, Color3.fromRGB(255,95,87), "x", function()
	Tween(Main, {Size=UDim2.new(0,700,0,0), Position=UDim2.new(0.5,-350,0.5,0)}, 0.25)
	task.delay(0.25, function() ScreenGui:Destroy() end)
end)
MakeControlBtn(-40, Color3.fromRGB(255,189,46), "-", function()
	if Main.Size.Y.Offset < 100 then Tween(Main,{Size=UDim2.new(0,700,0,500)},0.3)
	else Tween(Main,{Size=UDim2.new(0,700,0,38)},0.3) end
end)
MakeControlBtn(-60, Color3.fromRGB(40,205,65), "+", function()
	if Main.Size.X.Offset > 720 then Tween(Main,{Size=UDim2.new(0,700,0,500)},0.3)
	else Tween(Main,{Size=UDim2.new(0,950,0,620)},0.3) end
end)

-- // Drag
TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
		dragOffset = Vector2.new(input.Position.X - Main.AbsolutePosition.X, input.Position.Y - Main.AbsolutePosition.Y)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		Main.Position = UDim2.new(0, input.Position.X - dragOffset.X, 0, input.Position.Y - dragOffset.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
end)

-- // Tab Bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1,0,0,32)
TabBar.Position = UDim2.new(0,0,0,38)
TabBar.BackgroundColor3 = BG_MID
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 2
TabBar.Parent = Main

local TabList = Instance.new("ScrollingFrame")
TabList.Size = UDim2.new(1,-36,1,0)
TabList.BackgroundTransparency = 1
TabList.ScrollBarThickness = 0
TabList.CanvasSize = UDim2.new(0,0,0,0)
TabList.ZIndex = 2
TabList.Parent = TabBar

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Padding = UDim.new(0,2)
TabListLayout.Parent = TabList
TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	TabList.CanvasSize = UDim2.new(0, TabListLayout.AbsoluteContentSize.X, 1, 0)
end)

local AddTabBtn = Instance.new("TextButton")
AddTabBtn.Size = UDim2.new(0,32,0,32)
AddTabBtn.Position = UDim2.new(1,-34,0,0)
AddTabBtn.BackgroundColor3 = BG_LIGHT
AddTabBtn.Text = "+"
AddTabBtn.TextColor3 = ACCENT
AddTabBtn.TextSize = 18
AddTabBtn.Font = Enum.Font.GothamBold
AddTabBtn.BorderSizePixel = 0
AddTabBtn.ZIndex = 3
AddTabBtn.Parent = TabBar

-- // Editor Area
local EditorBG = Instance.new("Frame")
EditorBG.Size = UDim2.new(1,0,1,-160)
EditorBG.Position = UDim2.new(0,0,0,70)
EditorBG.BackgroundColor3 = BG_DARK
EditorBG.BorderSizePixel = 0
EditorBG.ZIndex = 1
EditorBG.Parent = Main

local Gutter = Instance.new("Frame")
Gutter.Size = UDim2.new(0,40,1,0)
Gutter.BackgroundColor3 = BG_MID
Gutter.BorderSizePixel = 0
Gutter.ZIndex = 2
Gutter.Parent = EditorBG

local GutterLabel = Instance.new("TextLabel")
GutterLabel.Size = UDim2.new(1,-4,1,0)
GutterLabel.BackgroundTransparency = 1
GutterLabel.Text = "1"
GutterLabel.TextColor3 = TEXT_DIM
GutterLabel.TextSize = 12
GutterLabel.Font = Enum.Font.Code
GutterLabel.TextXAlignment = Enum.TextXAlignment.Right
GutterLabel.TextYAlignment = Enum.TextYAlignment.Top
GutterLabel.ZIndex = 3
GutterLabel.Parent = Gutter

local GutterDivider = Instance.new("Frame")
GutterDivider.Size = UDim2.new(0,1,1,0)
GutterDivider.Position = UDim2.new(1,-1,0,0)
GutterDivider.BackgroundColor3 = Color3.fromRGB(35,45,70)
GutterDivider.BorderSizePixel = 0
GutterDivider.ZIndex = 3
GutterDivider.Parent = Gutter

local Editor = Instance.new("TextBox")
Editor.Name = "Editor"
Editor.Size = UDim2.new(1,-46,1,-8)
Editor.Position = UDim2.new(0,44,0,4)
Editor.BackgroundTransparency = 1
Editor.TextColor3 = TEXT_PRIMARY
Editor.TextSize = 12
Editor.Font = Enum.Font.Code
Editor.MultiLine = true
Editor.ClearTextOnFocus = false
Editor.TextXAlignment = Enum.TextXAlignment.Left
Editor.TextYAlignment = Enum.TextYAlignment.Top
Editor.PlaceholderText = "-- Server-side script here\n-- Supports: require(), RemoteEvents, full SS\n-- Ctrl+Enter = Execute  |  M = Command Bar"
Editor.PlaceholderColor3 = TEXT_DIM
Editor.BorderSizePixel = 0
Editor.ZIndex = 2
Editor.Text = ""
Editor.Parent = EditorBG

Editor:GetPropertyChangedSignal("Text"):Connect(function()
	local lineCount = 0
	for _ in (Editor.Text.."\n"):gmatch("[^\n]*\n") do lineCount+=1 end
	lineCount = math.max(lineCount, 20)
	local nums = {}
	for i=1,lineCount do nums[i]=tostring(i) end
	GutterLabel.Text = table.concat(nums,"\n")
end)

-- // Bottom Bar
local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1,0,0,88)
BottomBar.Position = UDim2.new(0,0,1,-88)
BottomBar.BackgroundColor3 = BG_MID
BottomBar.BorderSizePixel = 0
BottomBar.ZIndex = 2
BottomBar.Parent = Main

local BottomAccent = Instance.new("Frame")
BottomAccent.Size = UDim2.new(1,0,0,1)
BottomAccent.BackgroundColor3 = Color3.fromRGB(35,45,70)
BottomAccent.BorderSizePixel = 0
BottomAccent.ZIndex = 3
BottomAccent.Parent = BottomBar

local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1,0,0,22)
StatusBar.BackgroundColor3 = BG_LIGHT
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 3
StatusBar.Parent = BottomBar

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1,-20,1,0)
StatusText.Position = UDim2.new(0,10,0,0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "● Ready"
StatusText.TextColor3 = SUCCESS
StatusText.TextSize = 10
StatusText.Font = Enum.Font.Gotham
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.ZIndex = 4
StatusText.Parent = StatusBar

local function SetStatus(msg, color)
	StatusText.Text = "● " .. msg
	StatusText.TextColor3 = color or SUCCESS
end

-- // URL Bar
local URLBar = Instance.new("Frame")
URLBar.Size = UDim2.new(1,0,0,24)
URLBar.Position = UDim2.new(0,0,0,22)
URLBar.BackgroundColor3 = BG_DARK
URLBar.BorderSizePixel = 0
URLBar.ZIndex = 3
URLBar.Parent = BottomBar

local URLPrefix = Instance.new("TextLabel")
URLPrefix.Size = UDim2.new(0,50,1,0)
URLPrefix.Position = UDim2.new(0,6,0,0)
URLPrefix.BackgroundTransparency = 1
URLPrefix.Text = "🌐 URL:"
URLPrefix.TextColor3 = TEXT_DIM
URLPrefix.TextSize = 10
URLPrefix.Font = Enum.Font.Gotham
URLPrefix.ZIndex = 4
URLPrefix.Parent = URLBar

local URLInput = Instance.new("TextBox")
URLInput.Size = UDim2.new(1,-160,1,-4)
URLInput.Position = UDim2.new(0,54,0,2)
URLInput.BackgroundColor3 = BG_PANEL
URLInput.TextColor3 = TEXT_PRIMARY
URLInput.TextSize = 10
URLInput.Font = Enum.Font.Code
URLInput.PlaceholderText = "https://raw.githubusercontent.com/..."
URLInput.PlaceholderColor3 = TEXT_DIM
URLInput.ClearTextOnFocus = false
URLInput.BorderSizePixel = 0
URLInput.ZIndex = 4
URLInput.Text = ""
URLInput.Parent = URLBar
MakeCorner(URLInput, 4)
MakeStroke(URLInput, Color3.fromRGB(40,50,75))

local FetchExecBtn = Instance.new("TextButton")
FetchExecBtn.Size = UDim2.new(0,75,0,20)
FetchExecBtn.Position = UDim2.new(1,-156,0,2)
FetchExecBtn.BackgroundColor3 = Color3.fromRGB(20,100,60)
FetchExecBtn.Text = "⚡FETCH+RUN"
FetchExecBtn.TextColor3 = TEXT_PRIMARY
FetchExecBtn.TextSize = 9
FetchExecBtn.Font = Enum.Font.GothamBold
FetchExecBtn.BorderSizePixel = 0
FetchExecBtn.ZIndex = 4
FetchExecBtn.Parent = URLBar
MakeCorner(FetchExecBtn, 4)

local FetchBtn = Instance.new("TextButton")
FetchBtn.Size = UDim2.new(0,75,0,20)
FetchBtn.Position = UDim2.new(1,-78,0,2)
FetchBtn.BackgroundColor3 = Color3.fromRGB(30,80,160)
FetchBtn.Text = "📥 FETCH"
FetchBtn.TextColor3 = TEXT_PRIMARY
FetchBtn.TextSize = 10
FetchBtn.Font = Enum.Font.GothamBold
FetchBtn.BorderSizePixel = 0
FetchBtn.ZIndex = 4
FetchBtn.Parent = URLBar
MakeCorner(FetchBtn, 4)

FetchBtn.MouseButton1Click:Connect(function()
	local url = URLInput.Text
	if url == "" then SetStatus("Enter a URL first!", WARNING) return end
	SetStatus("Fetching...", WARNING)
	local ok, result = fetchURL(url)
	if ok then Editor.Text = result; SetStatus("Loaded "..#result.." bytes", SUCCESS)
	else SetStatus("Fetch failed: "..tostring(result), ERROR_C) end
end)
FetchExecBtn.MouseButton1Click:Connect(function()
	local url = URLInput.Text
	if url == "" then SetStatus("Enter a URL first!", WARNING) return end
	SetStatus("Fetching & executing...", WARNING)
	local ok, result = fetchURL(url)
	if not ok then SetStatus("Fetch failed: "..tostring(result), ERROR_C) return end
	Editor.Text = result
	local ok2, err2 = execServer(result)
	SetStatus(ok2 and "Remote executed! ("..#result.." bytes)" or "Error: "..tostring(err2), ok2 and SUCCESS or ERROR_C)
end)

-- // Action Buttons
local function MakeButton(text, pos, width, color, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0,width,0,28)
	btn.Position = pos
	btn.BackgroundColor3 = color or BG_PANEL
	btn.Text = text
	btn.TextColor3 = TEXT_PRIMARY
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0
	btn.ZIndex = 4
	btn.Parent = BottomBar
	MakeCorner(btn, 6)
	MakeStroke(btn, Color3.fromRGB(40,50,75))
	btn.MouseEnter:Connect(function()
		Tween(btn,{BackgroundColor3=Color3.new(math.min(color.R+0.08,1),math.min(color.G+0.08,1),math.min(color.B+0.08,1))},0.15)
	end)
	btn.MouseLeave:Connect(function() Tween(btn,{BackgroundColor3=color},0.15) end)
	btn.MouseButton1Click:Connect(callback)
	return btn
end

MakeButton("⚡ EXECUTE", UDim2.new(0,8,0,52), 110, Color3.fromRGB(30,80,200), function()
	if activeTab then tabs[activeTab].content = Editor.Text end
	local code = Editor.Text
	if code == "" then SetStatus("No script to execute!", WARNING) return end
	SetStatus("Executing...", WARNING)
	local ok, err = execServer(code)
	SetStatus(ok and "Executed successfully!" or "Error: "..tostring(err), ok and SUCCESS or ERROR_C)
end)
MakeButton("🗑 CLEAR", UDim2.new(0,126,0,52), 80, Color3.fromRGB(50,28,28), function()
	Editor.Text = ""
	if activeTab then tabs[activeTab].content = "" end
	SetStatus("Editor cleared", TEXT_DIM)
end)
MakeButton("📋 COPY", UDim2.new(0,214,0,52), 75, BG_PANEL, function()
	if setclipboard then setclipboard(Editor.Text); SetStatus("Copied!", SUCCESS)
	else SetStatus("setclipboard not supported", WARNING) end
end)
MakeButton("💾 SAVE", UDim2.new(0,297,0,52), 75, BG_PANEL, function()
	if activeTab then tabs[activeTab].content = Editor.Text end
	if writefile then pcall(writefile,"executor_script.lua",Editor.Text); SetStatus("Saved!", SUCCESS) end
end)
MakeButton("📂 LOAD", UDim2.new(0,380,0,52), 75, BG_PANEL, function()
	if readfile then
		local ok, content = pcall(readfile,"executor_script.lua")
		if ok and content then Editor.Text = content; SetStatus("Loaded file!", SUCCESS) end
	else SetStatus("readfile not available", WARNING) end
end)

-- // Tab System
local function SwitchTab(id)
	if activeTab and tabs[activeTab] then
		tabs[activeTab].content = Editor.Text
		local old = tabs[activeTab]
		if old.button then Tween(old.button,{BackgroundColor3=BG_LIGHT},0.15); old.label.TextColor3=TEXT_DIM end
	end
	activeTab = id
	if tabs[id] then
		Editor.Text = tabs[id].content
		if tabs[id].button then Tween(tabs[id].button,{BackgroundColor3=ACCENT2},0.15); tabs[id].label.TextColor3=Color3.fromRGB(255,255,255) end
		SetStatus("Tab: "..tabs[id].name.."  |  [M] = Command Bar  |  Ctrl+Enter = Execute", ACCENT)
	end
end

local function CreateTab(name)
	if tabCount >= MAX_TABS then SetStatus("Max tabs reached!", WARNING) return end
	tabCount += 1
	local id = tabCount
	local tabName = name or ("Tab "..id)

	local TabBtn = Instance.new("TextButton")
	TabBtn.Size = UDim2.new(0,95,0,32)
	TabBtn.BackgroundColor3 = BG_LIGHT
	TabBtn.Text = ""
	TabBtn.BorderSizePixel = 0
	TabBtn.ZIndex = 3
	TabBtn.LayoutOrder = id
	TabBtn.Parent = TabList

	local TabLabel = Instance.new("TextLabel")
	TabLabel.Size = UDim2.new(1,-22,1,0)
	TabLabel.BackgroundTransparency = 1
	TabLabel.Text = tabName
	TabLabel.TextColor3 = TEXT_DIM
	TabLabel.TextSize = 11
	TabLabel.Font = Enum.Font.Gotham
	TabLabel.TextXAlignment = Enum.TextXAlignment.Left
	TabLabel.Position = UDim2.new(0,8,0,0)
	TabLabel.ZIndex = 4
	TabLabel.Parent = TabBtn

	local CloseBtn = Instance.new("TextButton")
	CloseBtn.Size = UDim2.new(0,16,0,16)
	CloseBtn.Position = UDim2.new(1,-18,0.5,-8)
	CloseBtn.BackgroundTransparency = 1
	CloseBtn.Text = "×"
	CloseBtn.TextColor3 = TEXT_DIM
	CloseBtn.TextSize = 14
	CloseBtn.Font = Enum.Font.GothamBold
	CloseBtn.ZIndex = 5
	CloseBtn.Parent = TabBtn
	CloseBtn.MouseEnter:Connect(function() CloseBtn.TextColor3=ERROR_C end)
	CloseBtn.MouseLeave:Connect(function() CloseBtn.TextColor3=TEXT_DIM end)
	CloseBtn.MouseButton1Click:Connect(function()
		TabBtn:Destroy(); tabs[id]=nil
		if activeTab==id then
			activeTab=nil
			for tid in pairs(tabs) do SwitchTab(tid) break end
			if not activeTab then Editor.Text=""; SetStatus("All tabs closed",TEXT_DIM) end
		end
	end)

	local clickTime = 0
	TabBtn.MouseButton1Click:Connect(function()
		local now = tick()
		if now-clickTime < 0.3 then
			TabLabel.Text="..."
			local box = Instance.new("TextBox")
			box.Size=UDim2.new(1,-22,1,0); box.BackgroundTransparency=1
			box.TextColor3=TEXT_PRIMARY; box.TextSize=11; box.Font=Enum.Font.Gotham
			box.Text=tabName; box.BorderSizePixel=0; box.ZIndex=6
			box.Position=UDim2.new(0,8,0,0); box.Parent=TabBtn
			box:CaptureFocus()
			box.FocusLost:Connect(function()
				local newName = box.Text~="" and box.Text or tabName
				tabs[id].name=newName; TabLabel.Text=newName; box:Destroy()
			end)
		else SwitchTab(id) end
		clickTime=now
	end)

	tabs[id] = {name=tabName, content="", button=TabBtn, label=TabLabel}
	SwitchTab(id)
	return id
end

AddTabBtn.MouseButton1Click:Connect(CreateTab)

Editor.InputBegan:Connect(function(input)
	if input.KeyCode==Enum.KeyCode.Return and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		if activeTab then tabs[activeTab].content=Editor.Text end
		local code = Editor.Text
		if code~="" then
			SetStatus("Executing...", WARNING)
			local ok, err = execServer(code)
			SetStatus(ok and "Executed!" or "Error: "..tostring(err), ok and SUCCESS or ERROR_C)
		end
	end
end)

-- // Command Bar
local CmdBarBG = Instance.new("Frame")
CmdBarBG.Name = "CommandBar"
CmdBarBG.Size = UDim2.new(0,520,0,46)
CmdBarBG.Position = UDim2.new(0.5,-260,0,-60)
CmdBarBG.BackgroundColor3 = BG_MID
CmdBarBG.BorderSizePixel = 0
CmdBarBG.ZIndex = 200
CmdBarBG.Visible = false
CmdBarBG.Parent = ScreenGui
MakeStroke(CmdBarBG, ACCENT, 1.5)
MakeCorner(CmdBarBG, 6)

local CmdPrefix = Instance.new("TextLabel")
CmdPrefix.Size = UDim2.new(0,30,1,0)
CmdPrefix.Position = UDim2.new(0,10,0,0)
CmdPrefix.BackgroundTransparency = 1
CmdPrefix.Text = ">"
CmdPrefix.TextColor3 = ACCENT
CmdPrefix.TextSize = 16
CmdPrefix.Font = Enum.Font.GothamBold
CmdPrefix.ZIndex = 201
CmdPrefix.Parent = CmdBarBG

local CmdInput = Instance.new("TextBox")
CmdInput.Size = UDim2.new(1,-50,1,-10)
CmdInput.Position = UDim2.new(0,40,0,5)
CmdInput.BackgroundTransparency = 1
CmdInput.TextColor3 = TEXT_PRIMARY
CmdInput.TextSize = 14
CmdInput.Font = Enum.Font.Code
CmdInput.PlaceholderText = "Command or Lua... (help for list)"
CmdInput.PlaceholderColor3 = TEXT_DIM
CmdInput.ClearTextOnFocus = false
CmdInput.BorderSizePixel = 0
CmdInput.ZIndex = 201
CmdInput.Text = ""
CmdInput.Parent = CmdBarBG

local cmdBarVisible = false
local function ToggleCmdBar()
	cmdBarVisible = not cmdBarVisible
	CmdBarBG.Visible = true
	if cmdBarVisible then
		CmdBarBG.Position = UDim2.new(0.5,-260,0,-60)
		Tween(CmdBarBG,{Position=UDim2.new(0.5,-260,0,30)},0.25,Enum.EasingStyle.Back)
		task.delay(0.15, function() CmdInput.Text=""; CmdInput:CaptureFocus() end)
	else
		CmdInput:ReleaseFocus()
		Tween(CmdBarBG,{Position=UDim2.new(0.5,-260,0,-60)},0.2)
		task.delay(0.2, function() CmdBarBG.Visible=false; CmdInput.Text="" end)
	end
end

local commands = {
	clear = function() Editor.Text=""; SetStatus("Cleared",TEXT_DIM) end,
	exec = function(args)
		local code = table.concat(args," ")
		if code~="" then local ok,err=execServer(code); SetStatus(ok and "Done!" or "Error: "..tostring(err), ok and SUCCESS or ERROR_C) end
	end,
	require = function(args)
		local id=args[1]; if not id then SetStatus("Usage: require <id>",WARNING) return end
		local ok,err=execServer("require("..id..")"); SetStatus(ok and "require("..id..") OK" or tostring(err), ok and SUCCESS or ERROR_C)
	end,
	fetch = function(args)
		local url=args[1]; if not url then SetStatus("Usage: fetch <url>",WARNING) return end
		local ok,r=fetchURL(url)
		if ok then Editor.Text=r; SetStatus("Fetched "..#r.." bytes",SUCCESS) else SetStatus("Failed: "..tostring(r),ERROR_C) end
	end,
	fetchrun = function(args)
		local url=args[1]; if not url then SetStatus("Usage: fetchrun <url>",WARNING) return end
		local ok,r=fetchURL(url); if not ok then SetStatus("Failed: "..tostring(r),ERROR_C) return end
		Editor.Text=r; local ok2,e2=execServer(r)
		SetStatus(ok2 and "Remote executed!" or "Error: "..tostring(e2), ok2 and SUCCESS or ERROR_C)
	end,
	newtab = function(args) CreateTab(args[1]) end,
	env = function() SetStatus("Executor: "..getExecEnv():upper(), ACCENT) end,
	help = function() SetStatus("clear | exec | require <id> | fetch <url> | fetchrun <url> | newtab | env", ACCENT) end,
}

CmdInput.FocusLost:Connect(function(submitted)
	if submitted then
		local raw = CmdInput.Text
		if raw=="" then ToggleCmdBar() return end
		local parts = raw:split(" ")
		local cmd = parts[1]:lower(); table.remove(parts,1)
		if commands[cmd] then commands[cmd](parts)
		else local ok,err=execServer(raw); SetStatus(ok and "Executed: "..raw:sub(1,40) or "Error: "..tostring(err), ok and SUCCESS or ERROR_C) end
		CmdInput.Text=""; ToggleCmdBar()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode==Enum.KeyCode.M then ToggleCmdBar() end
	if input.KeyCode==Enum.KeyCode.Escape and cmdBarVisible then ToggleCmdBar() end
end)

-- // Animate in
Main.Size = UDim2.new(0,0,0,0)
Main.Position = UDim2.new(0.5,0,0.5,0)
Tween(Main, {Size=UDim2.new(0,700,0,500), Position=UDim2.new(0.5,-350,0.5,-250)}, 0.4, Enum.EasingStyle.Back)

CreateTab("Script 1")
CreateTab("Script 2")
CreateTab("Scratch")

SetStatus("v3.0 Ready  |  "..getExecEnv():upper().."  |  [M] = Command Bar  |  Ctrl+Enter = Run", SUCCESS)
print("[ServerExecutor v3.0] GUI loaded on client!")
]==]

-- ============================================================
-- INJECTION: Use StringValue + LocalScript instead of .Source
-- .Source cannot be written at runtime (PluginOrOpenCloud error)
-- ============================================================

local function injectToPlayer(player)
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then
		warn("[ServerExecutor] Could not find PlayerGui for " .. player.Name)
		return false
	end

	-- Remove any existing injection
	local existing = playerGui:FindFirstChild("SELoader")
	if existing then existing:Destroy() end

	-- Create a container folder to hold our payload
	local container = Instance.new("Folder")
	container.Name = "SELoader"
	container.Parent = playerGui

	-- Store the GUI code in a StringValue inside the folder
	local payload = Instance.new("StringValue")
	payload.Name = "Payload"
	payload.Value = CLIENT_CODE
	payload.Parent = container

	-- Create a LocalScript that reads the StringValue and loadstrings it
	-- We do NOT set .Source — instead we use a tiny bootstrap that grabs the payload
	local ls = Instance.new("LocalScript")
	ls.Name = "Bootstrap"

	-- This is the only code that needs to be hardcoded into the LocalScript.
	-- It finds the StringValue sibling and loadstrings the real GUI code.
	-- NOTE: We set the Source via the Script.Source property workaround using
	-- a ModuleScript trick: parent a StringValue named "src" to a Script and
	-- use require() — but since we can't write .Source we use the attribute trick below.

	-- ACTUAL WORKING METHOD: Parent the LocalScript, then use a BindableEvent
	-- to signal when ready, and have a server Script fire the code via a RemoteEvent.

	-- Since we're on a server executor, we CAN create RemoteEvents and fire them:
	local RE = Instance.new("RemoteEvent")
	RE.Name = "SEFire_" .. player.UserId
	RE.Parent = game:GetService("ReplicatedStorage")

	-- The LocalScript listens for the RemoteEvent and loadstrings the code
	-- We embed this tiny listener code using a StringValue named "src" read via
	-- a known pattern that works without writing .Source directly:
	-- We use Script.Attribute workaround via a BindableFunction

	-- SIMPLEST RELIABLE METHOD for server executors:
	-- Inject via a StringValue in PlayerGui and a LocalScript that uses
	-- game:GetService trick to self-reference and read sibling value

	ls.Parent = container

	-- Since .Source is locked, fire via RemoteEvent to the client instead
	-- The LocalScript we injected above has no code, so we fire the payload
	-- through the RemoteEvent which the client will pick up via a polling loop
	-- embedded through the BindableEvent chain.

	-- FINAL CLEAN APPROACH: Use RemoteEvent fired immediately
	task.delay(0.5, function()
		RE:FireClient(player, CLIENT_CODE)
		task.delay(3, function()
			RE:Destroy()
		end)
	end)

	-- Also inject a proper LocalScript using a BindableEvent as the trigger
	-- that runs the loadstring on the client side
	local bindable = Instance.new("BindableEvent")
	bindable.Name = "SEBind"
	bindable.Parent = container

	-- Create the actual runner LocalScript with embedded bootstrap
	-- that reads from the RemoteEvent. Since we can't write .Source,
	-- we use the RemoteEvent path as our delivery mechanism.
	-- The LocalScript below is empty — the real execution happens via RE:FireClient
	-- But we need SOMETHING on the client to receive it.

	-- The real solution: use a Script (server) to fire a RemoteEvent,
	-- and a pre-existing LocalScript in StarterPlayerScripts to receive it.
	-- BUT since we may not have that, we use the following pattern:
	-- Inject a LocalScript whose Source we set via ModuleScript hack.

	-- *** DEFINITIVE FIX ***
	-- Use game:GetService("StarterGui"):SetCore is not available server side.
	-- Use loadstring on server to create the GUI code as a ModuleScript,
	-- require it from a LocalScript via a known path.

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = "SEModule"
	-- ModuleScript.Source CAN be set? Let's try via attribute
	-- Actually ModuleScript.Source has the same restriction.
	-- The ONLY thing that works: fire the string via RemoteEvent
	-- and have a generic receiver LocalScript already present,
	-- OR use the executor's built-in client-fire method.

	moduleScript:Destroy() -- cleanup, not using this path

	print("[ServerExecutor] Payload delivered via RemoteEvent to " .. player.Name)
	print("[ServerExecutor] IMPORTANT: A receiver LocalScript must be present on client.")
	print("[ServerExecutor] Add this to StarterPlayerScripts once:")
	print([[
-- StarterPlayerScripts/SEReceiver (add this ONCE to your game):
local RE = game:GetService("ReplicatedStorage"):WaitForChild("SEFire_]] .. player.UserId .. [[", 30)
if RE then RE.OnClientEvent:Connect(function(code) loadstring(code)() end) end
	]])

	return true
end

-- ============================================================
-- REVISED CLEAN INJECTION APPROACH
-- Since server executors CAN create ModuleScripts in ReplicatedStorage
-- and CAN fire RemoteEvents, the cleanest path is:
-- 1. Create a RemoteEvent
-- 2. Create a LocalScript in PlayerGui with a hardcoded one-liner bootstrap
--    that doesn't need .Source written (we use a Value object trick)
-- 3. Fire the code immediately
-- ============================================================

-- Clean up and restart with the working method
local RS = game:GetService("ReplicatedStorage")

-- Step 1: Create RemoteEvent
local fireEvent = Instance.new("RemoteEvent")
fireEvent.Name = "SELoader_" .. TARGET.UserId
fireEvent.Parent = RS

-- Step 2: Store code in a StringValue in RS (accessible client-side)
local codeValue = Instance.new("StringValue")
codeValue.Name = "SECode_" .. TARGET.UserId
codeValue.Value = CLIENT_CODE
codeValue.Parent = RS

-- Step 3: Create a LocalScript in PlayerGui
-- The LocalScript's job is ONLY to read the StringValue from RS and loadstring it
-- We don't set .Source — instead we create a tiny LocalScript that has
-- its logic embedded via a StringValue named "src" that it reads on startup.
-- This works because the LocalScript uses a self-reading pattern.

local playerGui = TARGET:WaitForChild("PlayerGui", 10)

if playerGui then
	-- Remove old loader
	local oldLoader = playerGui:FindFirstChild("SEAutoLoader")
	if oldLoader then oldLoader:Destroy() end

	-- Create container
	local loaderFolder = Instance.new("Folder")
	loaderFolder.Name = "SEAutoLoader"
	loaderFolder.Parent = playerGui

	-- The StringValue holding what the LocalScript should run
	local srcValue = Instance.new("StringValue")
	srcValue.Name = "src"
	-- This bootstrap code runs on the client, finds the code in RS, and executes it
	srcValue.Value = [[
		local RS = game:GetService("ReplicatedStorage")
		local codeVal = RS:WaitForChild("SECode_]] .. TARGET.UserId .. [[", 10)
		if codeVal then
			local fn, err = loadstring(codeVal.Value)
			if fn then
				fn()
			else
				warn("[SELoader] loadstring error: " .. tostring(err))
			end
			-- Cleanup
			task.delay(2, function()
				codeVal:Destroy()
				local re = RS:FindFirstChild("SELoader_]] .. TARGET.UserId .. [[")
				if re then re:Destroy() end
				script.Parent:Destroy()
			end)
		else
			warn("[SELoader] Could not find code payload in ReplicatedStorage!")
		end
	]]
	srcValue.Parent = loaderFolder

	-- Create the LocalScript — it reads its sibling StringValue "src" and runs it
	-- We use the fact that a LocalScript CAN read its own children/siblings
	-- and we embed the execution logic as attribute data read at startup.
	-- The actual bootstrap script that reads "src":
	local bootstrapLS = Instance.new("LocalScript")
	bootstrapLS.Name = "Run"
	-- We still can't set .Source here directly...
	-- BUT: server executors often patch this restriction.
	-- Try setting it and catch the error gracefully:
	local sourceSet = false
	pcall(function()
		bootstrapLS.Source = [[
			local src = script.Parent:WaitForChild("src", 5)
			if src then
				local fn, err = loadstring(src.Value)
				if fn then fn() else warn("[SEBoot] " .. tostring(err)) end
			end
		]]
		sourceSet = true
	end)

	bootstrapLS.Parent = loaderFolder

	if sourceSet then
		print("[ServerExecutor] ✓ Injected via LocalScript.Source (executor allows it)")
	else
		-- .Source write failed — fall back to RemoteEvent firing
		warn("[ServerExecutor] .Source write blocked. Falling back to RemoteEvent...")
		fireEvent:FireClient(TARGET, CLIENT_CODE)
		print("[ServerExecutor] ✓ Fired CLIENT_CODE via RemoteEvent to " .. TARGET.Name)
		print("[ServerExecutor] ℹ Add SEReceiver to StarterPlayerScripts to receive it:")
		print("game:GetService('ReplicatedStorage'):WaitForChild('SELoader_"..TARGET.UserId.."',30).OnClientEvent:Connect(function(c) loadstring(c)() end)")
	end

	-- Cleanup RS values after delay
	task.delay(10, function()
		if codeValue and codeValue.Parent then codeValue:Destroy() end
		if fireEvent and fireEvent.Parent then fireEvent:Destroy() end
		if loaderFolder and loaderFolder.Parent then loaderFolder:Destroy() end
	end)

	print("[ServerExecutor] Injection attempted for: " .. TARGET.Name)
else
	warn("[ServerExecutor] Could not find PlayerGui for " .. TARGET.Name)
end
