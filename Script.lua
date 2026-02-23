-- // SERVER EXECUTOR MAINMODULE
-- // require(ASSET_ID_HERE) from any game you have server access to

local OWNER_ID = 846325069 -- !! REPLACE WITH YOUR USER ID !!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Security
local function isOwner(player)
	return player.UserId == OWNER_ID
end

-- // Setup Remotes
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local ExecuteRemote = Remotes:FindFirstChild("ExecuteServer")
if not ExecuteRemote then
	ExecuteRemote = Instance.new("RemoteFunction")
	ExecuteRemote.Name = "ExecuteServer"
	ExecuteRemote.Parent = Remotes
end

-- // Server-side execution handler
ExecuteRemote.OnServerInvoke = function(player, code)
	if not isOwner(player) then
		return false, "Unauthorized"
	end
	if type(code) ~= "string" or code == "" then
		return false, "Invalid code"
	end
	local fn, loadErr = loadstring(code)
	if not fn then
		return false, "Compile error: " .. tostring(loadErr)
	end
	local ok, runErr = pcall(fn)
	return ok, runErr
end

-- // GUI LocalScript code (injected into owner's client)
local GUICode = [[
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ExecuteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ExecuteServer")

local ACCENT = Color3.fromRGB(99, 179, 255)
local ACCENT2 = Color3.fromRGB(60, 130, 220)
local BG_DARK = Color3.fromRGB(10, 12, 18)
local BG_MID = Color3.fromRGB(16, 19, 28)
local BG_LIGHT = Color3.fromRGB(22, 27, 40)
local BG_PANEL = Color3.fromRGB(28, 34, 50)
local TEXT_PRIMARY = Color3.fromRGB(220, 230, 255)
local TEXT_DIM = Color3.fromRGB(100, 115, 155)
local SUCCESS = Color3.fromRGB(80, 220, 140)
local ERROR_C = Color3.fromRGB(255, 90, 90)
local WARNING = Color3.fromRGB(255, 200, 80)
local MAX_TABS = 8
local tabs = {}
local activeTab = nil
local tabCount = 0
local isDragging = false
local dragOffset = Vector2.new()

local function execServer(code)
    local ok, err = ExecuteRemote:InvokeServer(code)
    return ok, err
end

if PlayerGui:FindFirstChild("ServerExecutor") then
    PlayerGui.ServerExecutor:Destroy()
end

local function Tween(obj, props, t, style, dir)
    TweenService:Create(obj, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end
local function MakeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(40,50,75)
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end
local function MakeGradient(parent, c0, c1, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c0 or BG_DARK, c1 or BG_MID)
    g.Rotation = rotation or 90
    g.Parent = parent
    return g
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ServerExecutor"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0,680,0,480)
Main.Position = UDim2.new(0.5,-340,0.5,-240)
Main.BackgroundColor3 = BG_DARK
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui
MakeStroke(Main, Color3.fromRGB(35,45,70), 1.5)

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
TitleSub.Size = UDim2.new(0,150,1,0)
TitleSub.Position = UDim2.new(0,180,0,0)
TitleSub.BackgroundTransparency = 1
TitleSub.Text = "v3.0 SS"
TitleSub.TextColor3 = ACCENT
TitleSub.TextSize = 10
TitleSub.Font = Enum.Font.Gotham
TitleSub.TextXAlignment = Enum.TextXAlignment.Left
TitleSub.ZIndex = 3
TitleSub.Parent = TitleBar

local function MakeControlBtn(pos, color, symbol, action)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,14,0,14)
    btn.Position = UDim2.new(1,pos,0.5,-7)
    btn.BackgroundColor3 = color
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.ZIndex = 4
    btn.Parent = TitleBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    btn.MouseEnter:Connect(function() btn.Text=symbol btn.TextSize=8 btn.TextColor3=Color3.fromRGB(0,0,0) btn.Font=Enum.Font.GothamBold end)
    btn.MouseLeave:Connect(function() btn.Text="" end)
    btn.MouseButton1Click:Connect(action)
    return btn
end

MakeControlBtn(-20, Color3.fromRGB(255,95,87), "x", function()
    Tween(Main, {Size=UDim2.new(0,680,0,0), Position=UDim2.new(0.5,-340,0.5,0)}, 0.25)
    task.delay(0.25, function() ScreenGui:Destroy() end)
end)
MakeControlBtn(-40, Color3.fromRGB(255,189,46), "-", function()
    Tween(Main, {Size=UDim2.new(0,680,0, Main.Size.Y.Offset < 100 and 480 or 38)}, 0.3)
end)
MakeControlBtn(-60, Color3.fromRGB(40,205,65), "+", function()
    Tween(Main, {Size=UDim2.new(0, Main.Size.X.Offset > 700 and 680 or 900, 0, Main.Size.X.Offset > 700 and 480 or 580)}, 0.3)
end)

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = true
        dragOffset = Vector2.new(input.Position.X - Main.AbsolutePosition.X, input.Position.Y - Main.AbsolutePosition.Y)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        Main.Position = UDim2.new(0, input.Position.X-dragOffset.X, 0, input.Position.Y-dragOffset.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
end)

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

local EditorBG = Instance.new("Frame")
EditorBG.Size = UDim2.new(1,0,1,-142)
EditorBG.Position = UDim2.new(0,0,0,70)
EditorBG.BackgroundColor3 = BG_DARK
EditorBG.BorderSizePixel = 0
EditorBG.ZIndex = 1
EditorBG.Parent = Main

local Gutter = Instance.new("Frame")
Gutter.Size = UDim2.new(0,38,1,0)
Gutter.BackgroundColor3 = BG_MID
Gutter.BorderSizePixel = 0
Gutter.ZIndex = 2
Gutter.Parent = EditorBG

local GutterLabel = Instance.new("TextLabel")
GutterLabel.Size = UDim2.new(1,-4,1,0)
GutterLabel.BackgroundTransparency = 1
GutterLabel.Text = "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20"
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
Editor.Size = UDim2.new(1,-44,1,-8)
Editor.Position = UDim2.new(0,42,0,4)
Editor.BackgroundTransparency = 1
Editor.TextColor3 = TEXT_PRIMARY
Editor.TextSize = 12
Editor.Font = Enum.Font.Code
Editor.MultiLine = true
Editor.ClearTextOnFocus = false
Editor.TextXAlignment = Enum.TextXAlignment.Left
Editor.TextYAlignment = Enum.TextYAlignment.Top
Editor.PlaceholderText = "-- Type server-side Lua here...\n-- Ctrl+Enter to execute"
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

local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1,0,0,70)
BottomBar.Position = UDim2.new(0,0,1,-70)
BottomBar.BackgroundColor3 = BG_MID
BottomBar.BorderSizePixel = 0
BottomBar.ZIndex = 2
BottomBar.Parent = Main

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
    StatusText.Text = "● "..msg
    StatusText.TextColor3 = color or SUCCESS
end

local function MakeButton(text, pos, width, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,width,0,32)
    btn.Position = pos
    btn.BackgroundColor3 = color or BG_PANEL
    btn.Text = text
    btn.TextColor3 = TEXT_PRIMARY
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.ZIndex = 4
    btn.Parent = BottomBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    MakeStroke(btn, Color3.fromRGB(40,50,75))
    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3=Color3.fromRGB(
            math.min((color and color.R*255 or 28)+20,255),
            math.min((color and color.G*255 or 34)+20,255),
            math.min((color and color.B*255 or 50)+20,255)
        )}, 0.15)
    end)
    btn.MouseLeave:Connect(function() Tween(btn,{BackgroundColor3=color or BG_PANEL},0.15) end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

MakeButton("⚡ EXECUTE", UDim2.new(0,10,0,28), 120, Color3.fromRGB(30,80,200), function()
    if activeTab then tabs[activeTab].content = Editor.Text end
    local code = Editor.Text
    if code == "" then SetStatus("No script to execute!", WARNING) return end
    SetStatus("Executing...", WARNING)
    local ok, err = execServer(code)
    SetStatus(ok and "Executed successfully!" or "Error: "..tostring(err), ok and SUCCESS or ERROR_C)
end)
MakeButton("🗑 CLEAR", UDim2.new(0,140,0,28), 90, Color3.fromRGB(50,30,30), function()
    Editor.Text = ""
    if activeTab then tabs[activeTab].content = "" end
    SetStatus("Editor cleared", TEXT_DIM)
end)
MakeButton("📋 COPY", UDim2.new(0,240,0,28), 90, BG_PANEL, function()
    setclipboard(Editor.Text)
    SetStatus("Copied!", SUCCESS)
end)
MakeButton("💾 SAVE", UDim2.new(0,340,0,28), 90, BG_PANEL, function()
    if activeTab then
        tabs[activeTab].content = Editor.Text
        SetStatus("Saved to tab: "..tabs[activeTab].name, SUCCESS)
    end
end)
MakeButton("📂 LOAD", UDim2.new(0,440,0,28), 90, BG_PANEL, function()
    pcall(function()
        local content = readfile and readfile("executor_script.lua") or nil
        if content then Editor.Text = content SetStatus("Loaded!", SUCCESS)
        else SetStatus("readfile not supported", WARNING) end
    end)
end)

local function SwitchTab(id)
    if activeTab and tabs[activeTab] then
        tabs[activeTab].content = Editor.Text
        if tabs[activeTab].button then
            Tween(tabs[activeTab].button, {BackgroundColor3=BG_LIGHT}, 0.15)
            tabs[activeTab].button.TextColor3 = TEXT_DIM
        end
    end
    activeTab = id
    if tabs[id] then
        Editor.Text = tabs[id].content
        if tabs[id].button then
            Tween(tabs[id].button, {BackgroundColor3=ACCENT2}, 0.15)
            tabs[id].button.TextColor3 = Color3.fromRGB(255,255,255)
        end
        SetStatus("Switched to "..tabs[id].name, ACCENT)
    end
end

local function CreateTab(name)
    if tabCount >= MAX_TABS then SetStatus("Max tabs reached!", WARNING) return end
    tabCount += 1
    local id = tabCount
    local tabName = name or ("Tab "..id)

    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(0,90,0,32)
    TabBtn.BackgroundColor3 = BG_LIGHT
    TabBtn.Text = ""
    TabBtn.BorderSizePixel = 0
    TabBtn.ZIndex = 3
    TabBtn.LayoutOrder = id
    TabBtn.Parent = TabList

    local TabBtnLabel = Instance.new("TextLabel")
    TabBtnLabel.Size = UDim2.new(1,-22,1,0)
    TabBtnLabel.BackgroundTransparency = 1
    TabBtnLabel.Text = tabName
    TabBtnLabel.TextColor3 = TEXT_DIM
    TabBtnLabel.TextSize = 11
    TabBtnLabel.Font = Enum.Font.Gotham
    TabBtnLabel.TextXAlignment = Enum.TextXAlignment.Left
    TabBtnLabel.Position = UDim2.new(0,8,0,0)
    TabBtnLabel.ZIndex = 4
    TabBtnLabel.Parent = TabBtn

    local CloseTabBtn = Instance.new("TextButton")
    CloseTabBtn.Size = UDim2.new(0,16,0,16)
    CloseTabBtn.Position = UDim2.new(1,-18,0.5,-8)
    CloseTabBtn.BackgroundTransparency = 1
    CloseTabBtn.Text = "×"
    CloseTabBtn.TextColor3 = TEXT_DIM
    CloseTabBtn.TextSize = 14
    CloseTabBtn.Font = Enum.Font.GothamBold
    CloseTabBtn.ZIndex = 5
    CloseTabBtn.Parent = TabBtn

    CloseTabBtn.MouseEnter:Connect(function() CloseTabBtn.TextColor3=ERROR_C end)
    CloseTabBtn.MouseLeave:Connect(function() CloseTabBtn.TextColor3=TEXT_DIM end)
    CloseTabBtn.MouseButton1Click:Connect(function()
        TabBtn:Destroy()
        tabs[id] = nil
        if activeTab == id then
            activeTab = nil
            for tid in pairs(tabs) do SwitchTab(tid) break end
            if not activeTab then Editor.Text="" SetStatus("All tabs closed",TEXT_DIM) end
        end
    end)

    local clickTime = 0
    TabBtn.MouseButton1Click:Connect(function()
        local now = tick()
        if now - clickTime < 0.3 then
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1,-22,1,0)
            box.BackgroundTransparency = 1
            box.TextColor3 = TEXT_PRIMARY
            box.TextSize = 11
            box.Font = Enum.Font.Gotham
            box.Text = tabName
            box.BorderSizePixel = 0
            box.ZIndex = 6
            box.Position = UDim2.new(0,8,0,0)
            box.Parent = TabBtn
            box:CaptureFocus()
            box.FocusLost:Connect(function()
                local newName = box.Text ~= "" and box.Text or tabName
                tabs[id].name = newName
                TabBtnLabel.Text = newName
                box:Destroy()
            end)
        else
            SwitchTab(id)
        end
        clickTime = now
    end)

    tabs[id] = {name=tabName, content="", button=TabBtn, label=TabBtnLabel}
    SwitchTab(id)
    return id
end

AddTabBtn.MouseButton1Click:Connect(function() CreateTab() end)

Editor.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Return and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if activeTab then tabs[activeTab].content = Editor.Text end
        local code = Editor.Text
        if code ~= "" then
            SetStatus("Executing...", WARNING)
            local ok, err = execServer(code)
            SetStatus(ok and "Executed successfully!" or "Error: "..tostring(err), ok and SUCCESS or ERROR_C)
        end
    end
end)

local CmdBarBG = Instance.new("Frame")
CmdBarBG.Size = UDim2.new(0,500,0,46)
CmdBarBG.Position = UDim2.new(0.5,-250,0,-60)
CmdBarBG.BackgroundColor3 = BG_MID
CmdBarBG.BorderSizePixel = 0
CmdBarBG.ZIndex = 200
CmdBarBG.Visible = false
CmdBarBG.Parent = ScreenGui
MakeStroke(CmdBarBG, ACCENT, 1.5)

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
CmdInput.PlaceholderText = "Enter command or Lua code..."
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
        CmdBarBG.Position = UDim2.new(0.5,-250,0,-60)
        TweenService:Create(CmdBarBG, TweenInfo.new(0.25,Enum.EasingStyle.Back), {Position=UDim2.new(0.5,-250,0,30)}):Play()
        task.delay(0.15, function() CmdInput.Text="" CmdInput:CaptureFocus() end)
    else
        CmdInput:ReleaseFocus()
        TweenService:Create(CmdBarBG, TweenInfo.new(0.2), {Position=UDim2.new(0.5,-250,0,-60)}):Play()
        task.delay(0.2, function() CmdBarBG.Visible=false CmdInput.Text="" end)
    end
end

local commands = {
    clear = function() Editor.Text="" SetStatus("Cleared",TEXT_DIM) end,
    exec = function(args)
        local code = table.concat(args," ")
        if code ~= "" then
            local ok,err = execServer(code)
            SetStatus(ok and "Executed!" or "Error: "..tostring(err), ok and SUCCESS or ERROR_C)
        end
    end,
    newtab = function(args) CreateTab(args[1]) end,
    print = function(args)
        local ok,err = execServer("print("..table.concat(args," ")..")")
        SetStatus(ok and "print() called" or tostring(err), ok and SUCCESS or WARNING)
    end,
    help = function() SetStatus("Commands: clear, exec, newtab, print, help", ACCENT) end,
}

CmdInput.FocusLost:Connect(function(submitted)
    if submitted then
        local raw = CmdInput.Text
        if raw == "" then ToggleCmdBar() return end
        local parts = raw:split(" ")
        local cmd = parts[1]:lower()
        table.remove(parts,1)
        if commands[cmd] then commands[cmd](parts)
        else
            local ok,err = execServer(raw)
            SetStatus(ok and "Executed: "..raw:sub(1,40) or "Error: "..tostring(err), ok and SUCCESS or ERROR_C)
        end
        CmdInput.Text = ""
        ToggleCmdBar()
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.M then ToggleCmdBar() end
    if input.KeyCode == Enum.KeyCode.Escape and cmdBarVisible then ToggleCmdBar() end
end)

Main.Size = UDim2.new(0,0,0,0)
Main.Position = UDim2.new(0.5,0,0.5,0)
TweenService:Create(Main, TweenInfo.new(0.4,Enum.EasingStyle.Back), {
    Size=UDim2.new(0,680,0,480),
    Position=UDim2.new(0.5,-340,0.5,-240)
}):Play()

CreateTab("Script 1")
CreateTab("Script 2")
CreateTab("Scratch")
SetStatus("Ready  |  Owner Verified  |  [M] = Command Bar  |  Ctrl+Enter = Execute", SUCCESS)
]]

-- // Inject GUI into owner's client
local function InjectGUI(player)
	if not isOwner(player) then return end
	local existing = player.PlayerGui:FindFirstChild("_SELoader")
	if existing then existing:Destroy() end
	local ls = Instance.new("LocalScript")
	ls.Name = "_SELoader"
	ls.Source = GUICode
	ls.Parent = player.PlayerGui
end

Players.PlayerAdded:Connect(function(player)
	if not isOwner(player) then return end
	player.CharacterAdded:Connect(function()
		task.wait(1.5)
		InjectGUI(player)
	end)
	if player.Character then
		task.wait(1.5)
		InjectGUI(player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	if isOwner(player) then
		task.delay(1.5, function() InjectGUI(player) end)
	end
end

local Module = {}
function Module.Execute(code) -- call this directly from server if needed
	local fn, err = loadstring(code)
	if not fn then return false, err end
	return pcall(fn)
end
return Module
]]

return Module
