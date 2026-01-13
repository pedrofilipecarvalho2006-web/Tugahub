--// Axion V1 Rewrite | Hub (Developer Fly)
--// Autor: Pedro (versão PRO)

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local Config = {
    GuiName = "AxionFlyHub",
    DefaultFlySpeed = 60,
    MinSpeed = 10,
    MaxSpeed = 200,

    FlyKey = Enum.KeyCode.F,
    DefaultToggleMenuKey = Enum.KeyCode.End,

    Size = UDim2.new(0, 600, 0, 400),

    Themes = {
        Dark = {
            BgColor = Color3.fromRGB(18, 18, 18),
            ButtonColor = Color3.fromRGB(40, 40, 40),
            ButtonColorActive = Color3.fromRGB(120, 0, 0),
            AccentColor = Color3.fromRGB(120, 0, 255),
            TextColor = Color3.fromRGB(255, 255, 255),
            SecondaryTextColor = Color3.fromRGB(200, 200, 200),
            SliderBarColor = Color3.fromRGB(40, 40, 40),
            SliderFillColor = Color3.fromRGB(120, 0, 255),
            UnloadColor = Color3.fromRGB(120, 0, 0),
        },
        Light = {
            BgColor = Color3.fromRGB(235, 235, 235),
            ButtonColor = Color3.fromRGB(210, 210, 210),
            ButtonColorActive = Color3.fromRGB(0, 120, 255),
            AccentColor = Color3.fromRGB(0, 120, 255),
            TextColor = Color3.fromRGB(20, 20, 20),
            SecondaryTextColor = Color3.fromRGB(70, 70, 70),
            SliderBarColor = Color3.fromRGB(190, 190, 190),
            SliderFillColor = Color3.fromRGB(0, 120, 255),
            UnloadColor = Color3.fromRGB(180, 0, 0),
        }
    },

    DefaultTheme = "Dark",
}

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------
-- STATE / SAVE
---------------------------------------------------------------------
local SaveEnv
local ok, env = pcall(function()
    return getgenv and getgenv() or _G
end)
if ok and typeof(env) == "table" then
    SaveEnv = env
else
    SaveEnv = _G
end

SaveEnv.Axion_Config = SaveEnv.Axion_Config or {
    FlySpeed = Config.DefaultFlySpeed,
    Theme = Config.DefaultTheme,
    ToggleMenuKey = Config.DefaultToggleMenuKey,
}

local State = {
    FlySpeed = SaveEnv.Axion_Config.FlySpeed or Config.DefaultFlySpeed,
    CurrentThemeName = SaveEnv.Axion_Config.Theme or Config.DefaultTheme,
    ToggleMenuKey = SaveEnv.Axion_Config.ToggleMenuKey or Config.DefaultToggleMenuKey,
}

local CurrentTheme = Config.Themes[State.CurrentThemeName] or Config.Themes[Config.DefaultTheme]

local Gui
local MainFrame
local TabsFrame
local ContentFrame
local NotificationFrame
local BlurEffect
local LoaderFrame

local FlyButton
local UnloadButton
local SpeedSliderBar
local SpeedSliderFill
local SpeedSliderDrag
local SpeedValueLabel
local ThemeToggleButton
local MinimizeButton

local MainTabButton
local SettingsTabButton
local MiscTabButton
local AboutTabButton

local MainPage
local SettingsPage
local MiscPage
local AboutPage

local KeyBox
local KeyMenuLabel

local CurrentTab = "Main"
local Flying = false
local MenuVisible = true
local WaitingForKey = false

local Character
local Humanoid
local HRP

local BodyVel
local BodyGyro

local Connections = {}
local DefaultMainPos

local Sliding = false

-- sons UI
local UISounds = {}

---------------------------------------------------------------------
-- UTILS
---------------------------------------------------------------------
local function Connect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(Connections, conn)
    return conn
end

local function Cleanup()
    Flying = false

    if BodyVel then BodyVel:Destroy() end
    if BodyGyro then BodyGyro:Destroy() end

    for _, conn in ipairs(Connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(Connections)

    if BlurEffect then
        BlurEffect.Enabled = false
        BlurEffect:Destroy()
    end

    if Gui then
        Gui:Destroy()
    end
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function SaveSettings()
    SaveEnv.Axion_Config = SaveEnv.Axion_Config or {}
    SaveEnv.Axion_Config.FlySpeed = State.FlySpeed
    SaveEnv.Axion_Config.Theme = State.CurrentThemeName
    SaveEnv.Axion_Config.ToggleMenuKey = State.ToggleMenuKey
end

local function SetNoclip(state)
    if not Character then return end
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not state
            part.CanTouch = not state
            part.CanQuery = not state
        end
    end
end

local function AttachCharacter(char)
    Character = char
    Humanoid = Character:WaitForChild("Humanoid")
    HRP = Character:WaitForChild("HumanoidRootPart")

    if BodyVel then BodyVel:Destroy() end
    if BodyGyro then BodyGyro:Destroy() end

    BodyVel = Instance.new("BodyVelocity")
    BodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)

    SetNoclip(Flying)
end

local function CreateSound(name, soundId, volume)
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = soundId
    s.Volume = volume or 0.5
    s.Parent = Gui
    UISounds[name] = s
end

local function PlaySound(name)
    local s = UISounds[name]
    if s then
        s:Play()
    end
end

local function Notify(text, duration)
    duration = duration or 2
    if not NotificationFrame then return end

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, -10, 0, 30)
    notif.BackgroundColor3 = CurrentTheme.ButtonColor
    notif.BorderSizePixel = 0
    notif.BackgroundTransparency = 0
    notif.Parent = NotificationFrame
    notif.ClipsDescendants = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notif

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = CurrentTheme.TextColor
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = notif

    notif.BackgroundTransparency = 1
    notif.Position = UDim2.new(0, 5, 0, 40)

    local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(notif, ti, {
        BackgroundTransparency = 0,
        Position = UDim2.new(0,5,0,0)
    }):Play()

    PlaySound("Notify")

    task.spawn(function()
        task.wait(duration)
        local ti2 = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local tween = TweenService:Create(notif, ti2, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0,5,0,-20)
        })
        tween:Play()
        tween.Completed:Wait()
        notif:Destroy()
    end)
end

local function ApplyTheme()
    if not Gui then return end
    local theme = CurrentTheme

    -- Main frame
    if MainFrame then
        MainFrame.BackgroundColor3 = theme.BgColor
    end

    -- Percorrer todos os descendants e aplicar onde fizer sentido
    for _, obj in ipairs(Gui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            if obj ~= SpeedValueLabel then
                obj.TextColor3 = theme.TextColor
            end
        end
        if obj:IsA("Frame") then
            if obj.Name == "SpeedSliderBar" then
                obj.BackgroundColor3 = theme.SliderBarColor
            elseif obj.Name == "SpeedSliderFill" then
                obj.BackgroundColor3 = theme.SliderFillColor
            end
        end
    end

    if FlyButton then
        FlyButton.BackgroundColor3 = Flying and theme.ButtonColorActive or theme.ButtonColor
    end
    if UnloadButton then
        UnloadButton.BackgroundColor3 = theme.UnloadColor
    end
    if SpeedSliderBar then
        SpeedSliderBar.BackgroundColor3 = theme.SliderBarColor
    end
    if SpeedSliderFill then
        SpeedSliderFill.BackgroundColor3 = theme.SliderFillColor
    end
end

local function SetTheme(name)
    if not Config.Themes[name] then return end
    State.CurrentThemeName = name
    CurrentTheme = Config.Themes[name]
    ApplyTheme()
    SaveSettings()
    Notify("Theme set to: " .. name, 2)
end

---------------------------------------------------------------------
-- PREVENIR MÚLTIPLOS GUIs
---------------------------------------------------------------------
do
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild(Config.GuiName)
    if existing then
        existing:Destroy()
    end
end

AttachCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
Connect(LocalPlayer.CharacterAdded, AttachCharacter)

---------------------------------------------------------------------
-- BLUR
---------------------------------------------------------------------
BlurEffect = Instance.new("BlurEffect")
BlurEffect.Size = 10
BlurEffect.Enabled = false
BlurEffect.Parent = Lighting

---------------------------------------------------------------------
-- GUI BASE
---------------------------------------------------------------------
Gui = Instance.new("ScreenGui")
Gui.Name = Config.GuiName
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Sons UI
CreateSound("Click", "rbxassetid://7149541488", 0.4)
CreateSound("Hover", "rbxassetid://9118823101", 0.2)
CreateSound("Notify", "rbxassetid://153092315", 0.4)

-- Loader
LoaderFrame = Instance.new("Frame")
LoaderFrame.Size = UDim2.new(0, 260, 0, 80)
LoaderFrame.Position = UDim2.new(0.5, -130, 0.5, -40)
LoaderFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
LoaderFrame.BorderSizePixel = 0
LoaderFrame.Parent = Gui

local loaderCorner = Instance.new("UICorner")
loaderCorner.CornerRadius = UDim.new(0, 10)
loaderCorner.Parent = LoaderFrame

local loaderLabel = Instance.new("TextLabel")
loaderLabel.Size = UDim2.new(1, 0, 0, 40)
loaderLabel.Position = UDim2.new(0, 0, 0, 10)
loaderLabel.BackgroundTransparency = 1
loaderLabel.Text = "Axion V1 Hub"
loaderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
loaderLabel.Font = Enum.Font.GothamBold
loaderLabel.TextSize = 22
loaderLabel.Parent = LoaderFrame

local loaderSub = Instance.new("TextLabel")
loaderSub.Size = UDim2.new(1, 0, 0, 20)
loaderSub.Position = UDim2.new(0, 0, 0, 45)
loaderSub.BackgroundTransparency = 1
loaderSub.Text = "Loading..."
loaderSub.TextColor3 = Color3.fromRGB(200, 200, 200)
loaderSub.Font = Enum.Font.Gotham
loaderSub.TextSize = 14
loaderSub.Parent = LoaderFrame

-- Main Frame
MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = Config.Size
MainFrame.Position = UDim2.new(0.5, -Config.Size.X.Offset/2, 0.5, -Config.Size.Y.Offset/2)
MainFrame.BackgroundColor3 = CurrentTheme.BgColor
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = false
MainFrame.Parent = Gui
DefaultMainPos = MainFrame.Position

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = MainFrame

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5028857084"
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24, 24, 276, 276)
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -15)
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.35
shadow.ZIndex = 0
shadow.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 0, 35)
Title.Position = UDim2.new(0, 10, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "Axion V1 Rewrite | Hub"
Title.TextColor3 = CurrentTheme.TextColor
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextSize = 22
Title.ZIndex = 2
Title.Parent = MainFrame

-- Botão de minimizar
MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 24, 0, 24)
MinimizeButton.Position = UDim2.new(1, -34, 0, 12)
MinimizeButton.BackgroundColor3 = CurrentTheme.ButtonColor
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = CurrentTheme.TextColor
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.TextSize = 18
MinimizeButton.BorderSizePixel = 0
MinimizeButton.ZIndex = 3
MinimizeButton.Parent = MainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(1, 0)
minCorner.Parent = MinimizeButton

local Line = Instance.new("Frame")
Line.Size = UDim2.new(1, -20, 0, 2)
Line.Position = UDim2.new(0, 10, 0, 50)
Line.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
Line.BorderSizePixel = 0
Line.ZIndex = 2
Line.Parent = MainFrame

-- Notifications
NotificationFrame = Instance.new("Frame")
NotificationFrame.Size = UDim2.new(0, 260, 0, 120)
NotificationFrame.Position = UDim2.new(1, -270, 0, 10)
NotificationFrame.BackgroundTransparency = 1
NotificationFrame.BorderSizePixel = 0
NotificationFrame.Parent = Gui

local notifLayout = Instance.new("UIListLayout")
notifLayout.FillDirection = Enum.FillDirection.Vertical
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 5)
notifLayout.Parent = NotificationFrame

---------------------------------------------------------------------
-- TABS
---------------------------------------------------------------------
TabsFrame = Instance.new("Frame")
TabsFrame.Name = "Tabs"
TabsFrame.Size = UDim2.new(0, 160, 1, -70)
TabsFrame.Position = UDim2.new(0, 10, 0, 60)
TabsFrame.BackgroundTransparency = 1
TabsFrame.ZIndex = 2
TabsFrame.Parent = MainFrame

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Vertical
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Padding = UDim.new(0, 5)
tabsLayout.Parent = TabsFrame

ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -190, 1, -70)
ContentFrame.Position = UDim2.new(0, 180, 0, 60)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ZIndex = 2
ContentFrame.Parent = MainFrame

local function CreateTabButton(name, iconId)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.BackgroundColor3 = CurrentTheme.ButtonColor
    btn.TextColor3 = CurrentTheme.TextColor
    btn.Text = "   " .. name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 16
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    btn.Parent = TabsFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 18, 0, 18)
    icon.Position = UDim2.new(0, 8, 0.5, -9)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ZIndex = 3
    icon.Parent = btn

    Connect(btn.MouseEnter, function()
        if CurrentTab .. "Tab" ~= btn.Name then
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = CurrentTheme.ButtonColor:Lerp(Color3.fromRGB(70, 70, 70), 0.4)
            }):Play()
            PlaySound("Hover")
        end
    end)

    Connect(btn.MouseLeave, function()
        if CurrentTab .. "Tab" ~= btn.Name then
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = CurrentTheme.ButtonColor
            }):Play()
        end
    end)

    return btn
end

local function SetTabVisual(tabName)
    for _, child in ipairs(TabsFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == tabName .. "Tab" then
                TweenService:Create(child, TweenInfo.new(0.15), {
                    BackgroundColor3 = CurrentTheme.AccentColor
                }):Play()
            else
                TweenService:Create(child, TweenInfo.new(0.15), {
                    BackgroundColor3 = CurrentTheme.ButtonColor
                }):Play()
            end
        end
    end
end

MainTabButton = CreateTabButton("Main", "rbxassetid://7072718362")       -- icon player
SettingsTabButton = CreateTabButton("Settings", "rbxassetid://7072721390") -- icon gear
MiscTabButton   = CreateTabButton("Misc", "rbxassetid://7072719938")      -- icon misc
AboutTabButton  = CreateTabButton("About", "rbxassetid://7072721430")     -- icon info
SetTabVisual("Main")

---------------------------------------------------------------------
-- MAIN TAB CONTENT
---------------------------------------------------------------------
MainPage = Instance.new("Frame")
MainPage.Name = "MainPage"
MainPage.Size = UDim2.new(1, 0, 1, 0)
MainPage.BackgroundTransparency = 1
MainPage.ZIndex = 2
MainPage.Parent = ContentFrame

local MainLabel = Instance.new("TextLabel")
MainLabel.Size = UDim2.new(1, 0, 0, 25)
MainLabel.Position = UDim2.new(0, 0, 0, 0)
MainLabel.BackgroundTransparency = 1
MainLabel.Text = "Player Movement"
MainLabel.TextColor3 = CurrentTheme.SecondaryTextColor
MainLabel.Font = Enum.Font.GothamSemibold
MainLabel.TextSize = 20
MainLabel.TextXAlignment = Enum.TextXAlignment.Left
MainLabel.ZIndex = 2
MainLabel.Parent = MainPage

FlyButton = Instance.new("TextButton")
FlyButton.Size = UDim2.new(0, 160, 0, 40)
FlyButton.Position = UDim2.new(0, 0, 0, 40)
FlyButton.BackgroundColor3 = CurrentTheme.ButtonColor
FlyButton.TextColor3 = CurrentTheme.TextColor
FlyButton.Text = "Fly (" .. Config.FlyKey.Name .. ")"
FlyButton.Font = Enum.Font.Gotham
FlyButton.TextSize = 18
FlyButton.BorderSizePixel = 0
FlyButton.ZIndex = 2
FlyButton.Parent = MainPage

local flyCorner = Instance.new("UICorner")
flyCorner.CornerRadius = UDim.new(0, 6)
flyCorner.Parent = FlyButton

Connect(FlyButton.MouseEnter, function()
    if not Flying then
        TweenService:Create(FlyButton, TweenInfo.new(0.15), {
            BackgroundColor3 = CurrentTheme.ButtonColor:Lerp(Color3.fromRGB(70, 70, 70), 0.4)
        }):Play()
        PlaySound("Hover")
    end
end)

Connect(FlyButton.MouseLeave, function()
    if not Flying then
        TweenService:Create(FlyButton, TweenInfo.new(0.15), {
            BackgroundColor3 = CurrentTheme.ButtonColor
        }):Play()
    end
end)

---------------------------------------------------------------------
-- SETTINGS TAB CONTENT
---------------------------------------------------------------------
SettingsPage = Instance.new("Frame")
SettingsPage.Name = "SettingsPage"
SettingsPage.Size = UDim2.new(1, 0, 1, 0)
SettingsPage.BackgroundTransparency = 1
SettingsPage.ZIndex = 2
SettingsPage.Visible = false
SettingsPage.Parent = ContentFrame

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, 0, 0, 25)
SpeedLabel.Position = UDim2.new(0, 0, 0, 0)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Fly Speed"
SpeedLabel.TextColor3 = CurrentTheme.SecondaryTextColor
SpeedLabel.Font = Enum.Font.GothamSemibold
SpeedLabel.TextSize = 20
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.ZIndex = 2
SpeedLabel.Parent = SettingsPage

SpeedSliderBar = Instance.new("Frame")
SpeedSliderBar.Name = "SpeedSliderBar"
SpeedSliderBar.Size = UDim2.new(0, 260, 0, 8)
SpeedSliderBar.Position = UDim2.new(0, 0, 0, 40)
SpeedSliderBar.BackgroundColor3 = CurrentTheme.SliderBarColor
SpeedSliderBar.BorderSizePixel = 0
SpeedSliderBar.ZIndex = 2
SpeedSliderBar.Parent = SettingsPage

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(0, 4)
sliderCorner.Parent = SpeedSliderBar

SpeedSliderFill = Instance.new("Frame")
SpeedSliderFill.Name = "SpeedSliderFill"
SpeedSliderFill.Size = UDim2.new(0, 0, 1, 0)
SpeedSliderFill.Position = UDim2.new(0, 0, 0, 0)
SpeedSliderFill.BackgroundColor3 = CurrentTheme.SliderFillColor
SpeedSliderFill.BorderSizePixel = 0
SpeedSliderFill.ZIndex = 3
SpeedSliderFill.Parent = SpeedSliderBar

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 4)
fillCorner.Parent = SpeedSliderFill

SpeedSliderDrag = Instance.new("Frame")
SpeedSliderDrag.Size = UDim2.new(0, 12, 0, 18)
SpeedSliderDrag.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
SpeedSliderDrag.BorderSizePixel = 0
SpeedSliderDrag.ZIndex = 4
SpeedSliderDrag.Parent = SpeedSliderBar

local dragCorner = Instance.new("UICorner")
dragCorner.CornerRadius = UDim.new(1, 0)
dragCorner.Parent = SpeedSliderDrag

SpeedValueLabel = Instance.new("TextLabel")
SpeedValueLabel.Size = UDim2.new(0, 80, 0, 20)
SpeedValueLabel.Position = UDim2.new(0, 270, 0, 32)
SpeedValueLabel.BackgroundTransparency = 1
SpeedValueLabel.Text = tostring(State.FlySpeed)
SpeedValueLabel.TextColor3 = CurrentTheme.TextColor
SpeedValueLabel.Font = Enum.Font.Gotham
SpeedValueLabel.TextSize = 16
SpeedValueLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedValueLabel.ZIndex = 2
SpeedValueLabel.Parent = SettingsPage

-- Tema
ThemeToggleButton = Instance.new("TextButton")
ThemeToggleButton.Size = UDim2.new(0, 160, 0, 30)
ThemeToggleButton.Position = UDim2.new(0, 0, 0, 80)
ThemeToggleButton.BackgroundColor3 = CurrentTheme.ButtonColor
ThemeToggleButton.TextColor3 = CurrentTheme.TextColor
ThemeToggleButton.Text = "Theme: " .. State.CurrentThemeName
ThemeToggleButton.Font = Enum.Font.Gotham
ThemeToggleButton.TextSize = 16
ThemeToggleButton.BorderSizePixel = 0
ThemeToggleButton.ZIndex = 2
ThemeToggleButton.Parent = SettingsPage

local themeCorner = Instance.new("UICorner")
themeCorner.CornerRadius = UDim.new(0, 6)
themeCorner.Parent = ThemeToggleButton

---------------------------------------------------------------------
-- MISC TAB CONTENT
---------------------------------------------------------------------
MiscPage = Instance.new("Frame")
MiscPage.Name = "MiscPage"
MiscPage.Size = UDim2.new(1, 0, 1, 0)
MiscPage.BackgroundTransparency = 1
MiscPage.ZIndex = 2
MiscPage.Visible = false
MiscPage.Parent = ContentFrame

local MiscLabel = Instance.new("TextLabel")
MiscLabel.Size = UDim2.new(1, 0, 0, 25)
MiscLabel.Position = UDim2.new(0, 0, 0, 0)
MiscLabel.BackgroundTransparency = 1
MiscLabel.Text = "Miscellaneous"
MiscLabel.TextColor3 = CurrentTheme.SecondaryTextColor
MiscLabel.Font = Enum.Font.GothamSemibold
MiscLabel.TextSize = 20
MiscLabel.TextXAlignment = Enum.TextXAlignment.Left
MiscLabel.ZIndex = 2
MiscLabel.Parent = MiscPage

KeyMenuLabel = Instance.new("TextLabel")
KeyMenuLabel.Size = UDim2.new(0, 120, 0, 25)
KeyMenuLabel.Position = UDim2.new(0, 0, 0, 40)
KeyMenuLabel.BackgroundTransparency = 1
KeyMenuLabel.Text = "Key Menu:"
KeyMenuLabel.TextColor3 = CurrentTheme.SecondaryTextColor
KeyMenuLabel.Font = Enum.Font.GothamSemibold
KeyMenuLabel.TextSize = 18
KeyMenuLabel.TextXAlignment = Enum.TextXAlignment.Left
KeyMenuLabel.ZIndex = 2
KeyMenuLabel.Parent = MiscPage

KeyBox = Instance.new("TextButton")
KeyBox.Size = UDim2.new(0, 100, 0, 30)
KeyBox.Position = UDim2.new(0, 95, 0, 37)
KeyBox.BackgroundColor3 = CurrentTheme.ButtonColor
KeyBox.TextColor3 = CurrentTheme.TextColor
KeyBox.Text = "[" .. State.ToggleMenuKey.Name .. "]"
KeyBox.Font = Enum.Font.Gotham
KeyBox.TextSize = 16
KeyBox.BorderSizePixel = 0
KeyBox.ZIndex = 3
KeyBox.Parent = MiscPage

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 6)
keyCorner.Parent = KeyBox

local keyShadow = Instance.new("ImageLabel")
keyShadow.BackgroundTransparency = 1
keyShadow.Image = "rbxassetid://5028857084"
keyShadow.ScaleType = Enum.ScaleType.Slice
keyShadow.SliceCenter = Rect.new(24, 24, 276, 276)
keyShadow.Size = UDim2.new(1, 12, 1, 12)
keyShadow.Position = UDim2.new(0, -6, 0, -6)
keyShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
keyShadow.ImageTransparency = 0.45
keyShadow.ZIndex = 2
keyShadow.Parent = KeyBox

UnloadButton = Instance.new("TextButton")
UnloadButton.Size = UDim2.new(0, 160, 0, 40)
UnloadButton.Position = UDim2.new(0, 0, 0, 80)
UnloadButton.BackgroundColor3 = CurrentTheme.UnloadColor
UnloadButton.TextColor3 = CurrentTheme.TextColor
UnloadButton.Text = "Unload"
UnloadButton.Font = Enum.Font.Gotham
UnloadButton.TextSize = 18
UnloadButton.BorderSizePixel = 0
UnloadButton.ZIndex = 2
UnloadButton.Parent = MiscPage

local unloadCorner = Instance.new("UICorner")
unloadCorner.CornerRadius = UDim.new(0, 6)
unloadCorner.Parent = UnloadButton

Connect(UnloadButton.MouseEnter, function()
    TweenService:Create(UnloadButton, TweenInfo.new(0.15), {
        BackgroundColor3 = CurrentTheme.UnloadColor:Lerp(Color3.fromRGB(180, 0, 0), 0.4)
    }):Play()
    PlaySound("Hover")
end)

Connect(UnloadButton.MouseLeave, function()
    TweenService:Create(UnloadButton, TweenInfo.new(0.15), {
        BackgroundColor3 = CurrentTheme.UnloadColor
    }):Play()
end)

-- INSTA KILL UI (cliente) - envia pedido ao servidor via RemoteEvent
-- Observação: isto É um pedido ao servidor; o servidor deve validar permissões e executar a ação.
do
    local EVENT_NAME = "AxionInstaKillEvent"

    -- Caixa de texto para inserir nome ou UserId do alvo
    local InstaKillBox = Instance.new("TextBox")
    InstaKillBox.Size = UDim2.new(0, 160, 0, 30)
    InstaKillBox.Position = UDim2.new(0, 0, 0, 130)
    InstaKillBox.BackgroundColor3 = CurrentTheme.ButtonColor
    InstaKillBox.TextColor3 = CurrentTheme.TextColor
    InstaKillBox.Text = "Nome do jogador ou UserId"
    InstaKillBox.Font = Enum.Font.Gotham
    InstaKillBox.TextSize = 16
    InstaKillBox.BorderSizePixel = 0
    InstaKillBox.ZIndex = 3
    InstaKillBox.Parent = MiscPage

    local instaCorner = Instance.new("UICorner")
    instaCorner.CornerRadius = UDim.new(0, 6)
    instaCorner.Parent = InstaKillBox

    -- Botão que envia o pedido ao servidor
    local InstaKillButton = Instance.new("TextButton")
    InstaKillButton.Size = UDim2.new(0, 160, 0, 30)
    InstaKillButton.Position = UDim2.new(0, 170, 0, 130)
    InstaKillButton.BackgroundColor3 = CurrentTheme.UnloadColor
    InstaKillButton.TextColor3 = CurrentTheme.TextColor
    InstaKillButton.Text = "Insta Kill (request)"
    InstaKillButton.Font = Enum.Font.Gotham
    InstaKillButton.TextSize = 16
    InstaKillButton.BorderSizePixel = 0
    InstaKillButton.ZIndex = 3
    InstaKillButton.Parent = MiscPage

    local instaBtnCorner = Instance.new("UICorner")
    instaBtnCorner.CornerRadius = UDim.new(0, 6)
    instaBtnCorner.Parent = InstaKillButton

    Connect(InstaKillButton.MouseEnter, function()
        TweenService:Create(InstaKillButton, TweenInfo.new(0.15), {
            BackgroundColor3 = CurrentTheme.UnloadColor:Lerp(Color3.fromRGB(180, 0, 0), 0.2)
        }):Play()
        PlaySound("Hover")
    end)

    Connect(InstaKillButton.MouseLeave, function()
        TweenService:Create(InstaKillButton, TweenInfo.new(0.15), {
            BackgroundColor3 = CurrentTheme.UnloadColor
        }):Play()
    end)

    -- Gestão do RemoteEvent no cliente: tenta encontrar o evento e liga um handler de resposta.
    local InstaEvent = ReplicatedStorage:FindFirstChild(EVENT_NAME)
    if InstaEvent and InstaEvent:IsA("RemoteEvent") then
        InstaEvent.OnClientEvent:Connect(function(ok, msg)
            if ok then
                Notify("Sucesso: " .. tostring(msg), 2)
            else
                Notify("Erro: " .. tostring(msg), 2)
            end
        end)
    end

    -- Se o RemoteEvent for criado depois, liga o handler quando aparecer
    Connect(ReplicatedStorage.ChildAdded, function(child)
        if child and child.Name == EVENT_NAME and child:IsA("RemoteEvent") then
            InstaEvent = child
            InstaEvent.OnClientEvent:Connect(function(ok, msg)
                if ok then
                    Notify("Sucesso: " .. tostring(msg), 2)
                else
                    Notify("Erro: " .. tostring(msg), 2)
                end
            end)
        end
    end)

    Connect(InstaKillButton.MouseButton1Click, function()
        PlaySound("Click")
        local ev = ReplicatedStorage:FindFirstChild(EVENT_NAME)
        if not ev or not ev:IsA("RemoteEvent") then
            Notify("Erro: AxionInstaKillEvent não encontrado no servidor.", 2)
            return
        end

        local inputText = InstaKillBox.Text and InstaKillBox.Text:match("%S+") or ""
        if inputText == "" then
            Notify("Informe um nome ou UserId do jogador.", 2)
            return
        end

        local asNumber = tonumber(inputText)
        local payload = asNumber or inputText

        -- Envia o pedido ao servidor (o servidor deve validar permissões!)
        ev:FireServer(payload)
    end)
end

-- INSTA KILL TOOL (cliente) - cria uma Tool que, ao tocar outro jogador, envia pedido ao servidor
-- IMPORTANTE: isto NÃO mata o alvo localmente — apenas envia o UserId do alvo ao RemoteEvent.
do
    local EVENT_NAME = "AxionInstaKillEvent"
    local TOOL_NAME = "Classic Slap" -- nome visível da Tool que o jogador recebe
    local TOOL_HANDLE_SIZE = Vector3.new(1,1,1)
    local HIT_DEBOUNCE = 0.5 -- segundos por alvo para evitar spam

    -- cria Tool (apenas cliente) e coloca no Backpack para facilitar testes
    local function createLocalTool()
        local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack")
        if not backpack then return end

        -- Se já existir, replace/retorna
        if backpack:FindFirstChild(TOOL_NAME) then
            return
        end

        local tool = Instance.new("Tool")
        tool.Name = TOOL_NAME
        tool.RequiresHandle = true
        tool.CanBeDropped = true

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = TOOL_HANDLE_SIZE
        handle.Transparency = 1
        handle.CanCollide = false
        handle.Massless = true
        handle.Parent = tool

        tool.Parent = backpack

        -- feedback visual opcional: tooltip no equip
        tool.Equipped:Connect(function()
            Notify("Tool equipada: " .. TOOL_NAME, 1.5)
        end)
    end

    -- Tenta criar a Tool no Backpack (se já existir, ignora)
    createLocalTool()

    -- set up touched listener (vai ligar ao Handle de todas as Tools com este nome no personagem/backpack)
    local hitTimestamps = {} -- [userId] = lastHitTick

    local function onHandleTouched(hit, attackerPlayer)
        if not hit or not attackerPlayer then return end
        local targetChar = hit:FindFirstAncestorOfClass("Model")
        if not targetChar then return end
        local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
        if not targetPlayer then return end
        if targetPlayer == attackerPlayer then return end

        local uid = targetPlayer.UserId
        local now = tick()
        if hitTimestamps[uid] and now - hitTimestamps[uid] < HIT_DEBOUNCE then
            return
        end
        hitTimestamps[uid] = now

        -- procura o RemoteEvent (espera curto tempo se necessário)
        local ev = ReplicatedStorage:FindFirstChild(EVENT_NAME) or ReplicatedStorage:WaitForChild(EVENT_NAME, 5)
        if not ev or not ev:IsA("RemoteEvent") then
            Notify("Erro: AxionInstaKillEvent não encontrado no servidor.", 2)
            return
        end

        -- envia pedido ao servidor: usar UserId é mais confiável
        ev:FireServer(uid)
        -- feedback ao atacante
        Notify("Pedido de insta-kill enviado para: " .. targetPlayer.Name, 2)
    end

    -- Liga a deteção a tools equipadas no character (quando equipado).
    -- Observa quando o jogador equipa a Tool criada por nós (ou outra com mesmo nome).
    local function onCharacterAdded(char)
        -- observa Tools presentes no character
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and child.Name == TOOL_NAME then
                local handle = child:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    -- conexão Touched
                    Connect(handle.Touched, function(hit)
                        onHandleTouched(hit, LocalPlayer)
                    end)
                end
            end
        end

        -- se uma Tool for adicionada futuramente ao character
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == TOOL_NAME then
                local handle = child:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    Connect(handle.Touched, function(hit)
                        onHandleTouched(hit, LocalPlayer)
                    end)
                end
            end
        end)
    end

    -- liga listeners
    if LocalPlayer.Character then
        onCharacterAdded(LocalPlayer.Character)
    end
    Connect(LocalPlayer.CharacterAdded, onCharacterAdded)

    -- Também observa o Backpack para ligar ferramentas que forem manipuladas diretamente do Backpack (opcional)
    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack")
    backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == TOOL_NAME then
            -- nada extra necessário aqui; quando for equipado, o Character logic tratará
        end
    end)
end

---------------------------------------------------------------------
-- ABOUT TAB CONTENT
---------------------------------------------------------------------
AboutPage = Instance.new("Frame")
AboutPage.Name = "AboutPage"
AboutPage.Size = UDim2.new(1, 0, 1, 0)
AboutPage.BackgroundTransparency = 1
AboutPage.ZIndex = 2
AboutPage.Visible = false
AboutPage.Parent = ContentFrame

local AboutTitle = Instance.new("TextLabel")
AboutTitle.Size = UDim2.new(1, 0, 0, 25)
AboutTitle.Position = UDim2.new(0, 0, 0, 0)
AboutTitle.BackgroundTransparency = 1
AboutTitle.Text = "About Axion Hub"
AboutTitle.TextColor3 = CurrentTheme.SecondaryTextColor
AboutTitle.Font = Enum.Font.GothamSemibold
AboutTitle.TextSize = 20
AboutTitle.TextXAlignment = Enum.TextXAlignment.Left
AboutTitle.ZIndex = 2
AboutTitle.Parent = AboutPage

local AboutText = Instance.new("TextLabel")
AboutText.Size = UDim2.new(1, -10, 0, 120)
AboutText.Position = UDim2.new(0, 0, 0, 35)
AboutText.BackgroundTransparency = 1
AboutText.Text = "Axion V1 Rewrite | Hub\nDeveloper: Pedro\nVersion: 1.0.0 PRO\n\nFly, UI animada, keybinds, temas e mais."
AboutText.TextColor3 = CurrentTheme.TextColor
AboutText.Font = Enum.Font.Gotham
AboutText.TextSize = 14
AboutText.TextWrapped = true
AboutText.TextXAlignment = Enum.TextXAlignment.Left
AboutText.TextYAlignment = Enum.TextYAlignment.Top
AboutText.ZIndex = 2
AboutText.Parent = AboutPage

---------------------------------------------------------------------
-- TAB SWITCHING
---------------------------------------------------------------------
local function ShowTab(name)
    CurrentTab = name
    SetTabVisual(name)

    MainPage.Visible = (name == "Main")
    SettingsPage.Visible = (name == "Settings")
    MiscPage.Visible = (name == "Misc")
    AboutPage.Visible = (name == "About")
end

Connect(MainTabButton.MouseButton1Click, function()
    ShowTab("Main")
    PlaySound("Click")
end)

Connect(SettingsTabButton.MouseButton1Click, function()
    ShowTab("Settings")
    PlaySound("Click")
end)

Connect(MiscTabButton.MouseButton1Click, function()
    ShowTab("Misc")
    PlaySound("Click")
end)

Connect(AboutTabButton.MouseButton1Click, function()
    ShowTab("About")
    PlaySound("Click")
end)

---------------------------------------------------------------------
-- DRAG MENU
---------------------------------------------------------------------
local Dragging = false
local DragStart
local StartPos

Connect(MainFrame.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = true
        DragStart = input.Position
        StartPos = MainFrame.Position
    end
end)

Connect(MainFrame.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = false
    end
end)

Connect(UserInputService.InputChanged, function(input)
    if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - DragStart
        local targetPos = UDim2.new(
            StartPos.X.Scale,
            StartPos.X.Offset + delta.X,
            StartPos.Y.Scale,
            StartPos.Y.Offset + delta.Y
        )
        MainFrame.Position = targetPos
    end
end)

---------------------------------------------------------------------
-- ANIMAÇÃO DO MENU + MINIMIZAR
---------------------------------------------------------------------
local function SetMenuVisible(state)
    if state == MenuVisible then return end
    MenuVisible = state

    if state then
        MainFrame.Visible = true
        MainFrame.Position = DefaultMainPos + UDim2.new(0, 0, 0, 20)
        MainFrame.BackgroundTransparency = 1
        BlurEffect.Enabled = true

        TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = DefaultMainPos,
            BackgroundTransparency = 0
        }):Play()
    else
        local tween = TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = DefaultMainPos + UDim2.new(0, 0, 0, 20),
            BackgroundTransparency = 0.2
        })
        tween:Play()
        tween.Completed:Connect(function()
            if not MenuVisible then
                MainFrame.Visible = false
                BlurEffect.Enabled = false
            end
            MainFrame.Position = DefaultMainPos
            MainFrame.BackgroundTransparency = 0
        end)
    end
end

Connect(MinimizeButton.MouseButton1Click, function()
    PlaySound("Click")
    SetMenuVisible(not MenuVisible)
end)

---------------------------------------------------------------------
-- FLY LOGIC + NOCLIP
---------------------------------------------------------------------
local function SetFlyVisual(state)
    if state then
        FlyButton.Text = "Stop"
        TweenService:Create(FlyButton, TweenInfo.new(0.15), {
            BackgroundColor3 = CurrentTheme.ButtonColorActive
        }):Play()
    else
        FlyButton.Text = "Fly (" .. Config.FlyKey.Name .. ")"
        TweenService:Create(FlyButton, TweenInfo.new(0.15), {
            BackgroundColor3 = CurrentTheme.ButtonColor
        }):Play()
    end
end

local function ToggleFly()
    if not Character or not Humanoid or not HRP then return end

    Flying = not Flying
    SetFlyVisual(Flying)

    if Flying then
        BodyVel.Parent = HRP
        BodyGyro.Parent = HRP
        Humanoid.PlatformStand = true
        SetNoclip(true)
        Notify("Fly enabled", 1.5)
    else
        BodyVel.Parent = nil
        BodyGyro.Parent = nil
        Humanoid.PlatformStand = false
        SetNoclip(false)
        Notify("Fly disabled", 1.5)
    end
    PlaySound("Click")
end

Connect(FlyButton.MouseButton1Click, ToggleFly)

---------------------------------------------------------------------
-- SPEED SLIDER LOGIC
---------------------------------------------------------------------
local function UpdateSpeedSliderFromX(xPos)
    local barAbsPos = SpeedSliderBar.AbsolutePosition.X
    local barWidth = SpeedSliderBar.AbsoluteSize.X

    local t = math.clamp((xPos - barAbsPos) / barWidth, 0, 1)
    local newSpeed = math.floor(Lerp(Config.MinSpeed, Config.MaxSpeed, t))
    State.FlySpeed = newSpeed

    SpeedSliderFill.Size = UDim2.new(t, 0, 1, 0)
    SpeedSliderDrag.Position = UDim2.new(
        t,
        -SpeedSliderDrag.Size.X.Offset/2,
        -0.5,
        SpeedSliderBar.Size.Y.Offset/2
    )
    SpeedValueLabel.Text = tostring(newSpeed)
    SaveSettings()
end

do
    local t = (State.FlySpeed - Config.MinSpeed) / (Config.MaxSpeed - Config.MinSpeed)
    t = math.clamp(t, 0, 1)
    SpeedSliderFill.Size = UDim2.new(t, 0, 1, 0)
    SpeedSliderDrag.Position = UDim2.new(
        t,
        -SpeedSliderDrag.Size.X.Offset/2,
        -0.5,
        SpeedSliderBar.Size.Y.Offset/2
    )
    SpeedValueLabel.Text = tostring(State.FlySpeed)
end

Connect(SpeedSliderBar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Sliding = true
        UpdateSpeedSliderFromX(input.Position.X)
        PlaySound("Click")
    end
end)

Connect(SpeedSliderBar.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Sliding = false
    end
end)

Connect(UserInputService.InputChanged, function(input)
    if Sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
        UpdateSpeedSliderFromX(input.Position.X)
    end
end)

---------------------------------------------------------------------
-- THEME TOGGLE
---------------------------------------------------------------------
Connect(ThemeToggleButton.MouseButton1Click, function()
    if State.CurrentThemeName == "Dark" then
        SetTheme("Light")
    else
        SetTheme("Dark")
    end
    ThemeToggleButton.Text = "Theme: " .. State.CurrentThemeName
    PlaySound("Click")
end)

---------------------------------------------------------------------
-- KEY PICKER + KEYBINDS
---------------------------------------------------------------------
Connect(KeyBox.MouseButton1Click, function()
    if WaitingForKey then return end
    WaitingForKey = true
    KeyBox.Text = "[ Press any key ]"
    TweenService:Create(KeyBox, TweenInfo.new(0.15), {
        BackgroundColor3 = CurrentTheme.ButtonColor:Lerp(Color3.fromRGB(90, 90, 90), 0.5)
    }):Play()
    PlaySound("Click")
end)

Connect(UserInputService.InputBegan, function(input, gp)
    if gp then return end

    if WaitingForKey then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            State.ToggleMenuKey = input.KeyCode
            KeyBox.Text = "[" .. input.KeyCode.Name .. "]"
            Notify("Toggle key set to: " .. input.KeyCode.Name, 1.5)
            SaveSettings()
        else
            KeyBox.Text = "[ Invalid ]"
        end
        TweenService:Create(KeyBox, TweenInfo.new(0.15), {
            BackgroundColor3 = CurrentTheme.ButtonColor
        }):Play()
        WaitingForKey = false
        return
    end

    if input.KeyCode == Config.FlyKey then
        ToggleFly()
    elseif input.KeyCode == State.ToggleMenuKey then
        SetMenuVisible(not MenuVisible)
    end
end)

---------------------------------------------------------------------
-- LOOP DO FLY (MOVIMENTO + NOCLIP FORÇADO)
---------------------------------------------------------------------
Connect(RunService.RenderStepped, function()
    if Flying and Character and Humanoid and HRP then
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.new()

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir += cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir -= cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir -= cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir += cam.CFrame.RightVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir += cam.CFrame.UpVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir -= cam.CFrame.UpVector
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end

        BodyVel.Velocity = moveDir * State.FlySpeed
        BodyGyro.CFrame = cam.CFrame

        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
            end
        end
    end
end)

---------------------------------------------------------------------
-- UNLOAD
---------------------------------------------------------------------
Connect(UnloadButton.MouseButton1Click, function()
    PlaySound("Click")
    Notify("Unloading Axion Hub...", 1.5)
    task.delay(0.3, function()
        Cleanup()
    end)
end)

---------------------------------------------------------------------
-- LOADER TRANSITION
---------------------------------------------------------------------
task.delay(0.7, function()
    local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    TweenService:Create(LoaderFrame, ti, {
        BackgroundTransparency = 1
    }):Play()
    TweenService:Create(loaderLabel, ti, {
        TextTransparency = 1
    }):Play()
    TweenService:Create(loaderSub, ti, {
        TextTransparency = 1
    }):Play()
    task.wait(0.3)
    LoaderFrame:Destroy()
    MainFrame.Visible = true
    BlurEffect.Enabled = true
    Notify("Axion Hub loaded", 1.5)
end)

ApplyTheme()
ShowTab("Main")
