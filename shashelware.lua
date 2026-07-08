local Settings = {
    Enabled = true,
    AimKey = Enum.KeyCode.Q,          
    ToggleUIKey = Enum.KeyCode.K,     
    FOVEnabled = true,               
    FOV = 150,      
    CameraFOV = 70,                           
    Smoothness = 0.15,                        
    WallCheck = true,                        
    TargetSwitching = false, 
    RainbowMode = false,
    RainbowSpeed = 1,
    
    -- Render Modules Config
    ESP = false,
    Chams = false,
    Nametags = false,
    Tracers = false,

    -- Utility Modules Config
    Noclip = false,
    Flight = false,
    FlightSpeed = 50,
    MouseTP = false,
    MouseTPKey = Enum.KeyCode.F,
    Speed = false,
    SpeedMode = "Normal", 
    SpeedValue = 50,
    InfJump = false,
    Spinbot = false,
    SpinbotSpeed = 50,
    Dupe = false,

    -- World Modules Config
    Atmosphere = false,
    AtmosphereColor = "255, 0, 0",
    AtmosphereIntensity = 0.5,
    TimeChanger = false,
    TimeValue = 12,
    Freecam = false,
    FreecamSpeed = 50,
    Xray = false,
    XrayTransparency = 0.5,

    -- TextGUI Deep Customization Configuration Block
    TextGUI = false,
    TextGuiSize = 14,
    TextGuiShadow = true,       
    TextGuiTextShadow = true,   
    TextGuiWatermark = true,    
    TextGuiCustomText = ""      
}
-- =============================================================================

-- Services
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- Unique tag to ensure clean lifecycle tracking during multiple reinjections
local CurrentScriptUUID = "SW_" .. HttpService:GenerateGUID(false)
getgenv().ShashelWareRunningUUID = CurrentScriptUUID

-- Track Connections for absolute cleanup on Destroy
local ScriptConnections = {}

local function trackedConnect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(ScriptConnections, conn)
    return conn
end

-- State Variables (GUI set to unopened by default)
local menuInterfaceVisibilityState = false
local isAiming = false
local currentTarget = nil
local isBinding = false
local isBindingUIKey = false
local isBindingMTPKey = false
local isMainPanelInSettingsMode = false
local rainbowHue = 0
local macroBindsRegistry = {} 
local moduleMacroNames = {}    
local moduleStateCheckers = {} 

-- Freecam internal states
local freecamPart = nil
local freecamActive = false

-- Track tab persistence states independently of visibility toggle
local savedTabStates = {
    ["Combat"] = true, 
    ["Render"] = false,
    ["Utility"] = false,
    ["World"] = false,
    ["Inventory"] = false,
    ["Minigames"] = false,
    ["Other"] = false
}

local VAPE_MAIN_BG = Color3.fromRGB(20, 20, 20)      
local VAPE_SIDEBAR_BG = Color3.fromRGB(24, 24, 24)   
local VAPE_TEXT_COLOR = Color3.fromRGB(160, 160, 160) 
local VAPE_TEXT_ACTIVE = Color3.fromRGB(220, 220, 220)
local VAPE_BRAND_GREEN = Color3.fromRGB(46, 139, 107) 
local VAPE_DROPDOWN_BG = Color3.fromRGB(16, 16, 16)  

local CurrentThemeColor = VAPE_BRAND_GREEN
local themeUpdateObjects = {}
local globalWindowRegistry = {} 

-- Visual structures
local ActiveHighlights = {}
local ActiveTracers = {}
local ActiveBoxes = {}
local ActiveBillboards = {}
local OriginalTransparencyCache = {}

-- Create ScreenGui with 3-Layer Safe Hierarchy Protection
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ShashelWareHybridLayout_" .. math.random(1000, 9999)
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true 

-- Robust Parenting Fallback Engine
local runContextParent = nil
local successHui, resHui = pcall(function() return typeof(gethui) == "function" and gethui() end)
if successHui and resHui then
    runContextParent = resHui
else
    local successCore, resCore = pcall(function() return game:GetService("CoreGui") end)
    if successCore and resCore then
        runContextParent = resCore
    else
        runContextParent = LocalPlayer:WaitForChild("PlayerGui", 5)
    end
end

if not runContextParent then
    error("[ShashelWare Critical Error]: Could not find a safe UI environment to parent the interface.")
end

ScreenGui.Parent = runContextParent

--------------------------------------------------------------------------------
-- NOTIFICATION SYSTEM ENGINE
--------------------------------------------------------------------------------
local NotificationContainer = Instance.new("Frame")
NotificationContainer.Name = "NotificationContainer"
NotificationContainer.Size = UDim2.new(0, 220, 0, 500)
NotificationContainer.Position = UDim2.new(1, -230, 1, -510)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.Parent = ScreenGui

local NotificationLayout = Instance.new("UIListLayout")
NotificationLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotificationLayout.Padding = UDim.new(0, 6)
NotificationLayout.Parent = NotificationContainer

local function showNotification(text, duration)
    duration = duration or 3
    
    local Toast = Instance.new("Frame")
    Toast.Size = UDim2.new(1, 0, 0, 36)
    Toast.BackgroundColor3 = VAPE_MAIN_BG
    Toast.BorderSizePixel = 0
    Toast.BackgroundTransparency = 1 
    Toast.Parent = NotificationContainer

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Toast

    local SideBar = Instance.new("Frame")
    SideBar.Name = "AccentIndicatorBar"
    SideBar.Size = UDim2.new(0, 3, 1, 0)
    SideBar.BackgroundColor3 = CurrentThemeColor
    SideBar.BorderSizePixel = 0
    SideBar.Parent = Toast
    table.insert(themeUpdateObjects, SideBar)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -15, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = VAPE_TEXT_ACTIVE
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextTransparency = 1 
    Label.Parent = Toast

    -- Animate Fade-In
    TweenService:Create(Toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.1}):Play()
    TweenService:Create(Label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

    task.delay(duration, function()
        if Toast and Toast.Parent then
            local fadeOutBg = TweenService:Create(Toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            local fadeOutTxt = TweenService:Create(Label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
            fadeOutBg:Play()
            fadeOutTxt:Play()
            fadeOutBg.Completed:Connect(function()
                Toast:Destroy()
            end)
        end
    end)
end

-- Forward Declarations
local TextGuiWatermarkTitle
local ActiveListLayout
local TextGuiContainerFrame
local CustomTextLabel
local TextGuiHeaderDragHandle

local updateTextGuiDisplay

-- Theme Update Engine
local function updateUITheme(newColor)
    CurrentThemeColor = newColor
    for _, obj in ipairs(themeUpdateObjects) do
        if obj.Parent == nil then continue end
        if obj:IsA("TextLabel") and string.find(obj.Text, "ShashelWare") then
            obj.Text = "ShashelWare <font color='rgb("..math.round(newColor.R*255)..","..math.round(newColor.G*255)..","..math.round(newColor.B*255)..")'>V1</font>"
        elseif obj:IsA("TextButton") and obj.Name == "ActiveCategory" then
            obj.TextColor3 = newColor
        elseif obj:IsA("Frame") and obj.Name == "SliderFill" then
            obj.BackgroundColor3 = newColor
        elseif obj:IsA("UIStroke") then
            obj.Color = newColor
        elseif obj:IsA("TextButton") and (obj.Name == "ModuleToggle" or obj.Name == "DynamicBindBtn" or obj.Name == "ModeSelectBtn" or obj.Name == "ActionBtn") then
            if obj.TextColor3 ~= VAPE_TEXT_COLOR and obj.TextColor3 ~= Color3.fromRGB(120, 120, 120) and obj.TextColor3 ~= Color3.fromRGB(130, 130, 130) then
                obj.TextColor3 = newColor
            end
        elseif obj:IsA("TextButton") and obj.Name == "MatchThemeActionBtn" then
            obj.TextColor3 = newColor
            local stroke = obj:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = newColor end
        elseif obj:IsA("TextLabel") and obj.Name == "ActiveHudPart" then
            obj.TextColor3 = newColor
        elseif obj:IsA("Frame") and obj.Name == "AccentIndicatorBar" then
            obj.BackgroundColor3 = newColor
        end
    end
end

-- Visual structures cleanup logic
local function cleanAllBoxes()
    for ply, frame in pairs(ActiveBoxes) do pcall(function() frame:Destroy() end) end
    ActiveBoxes = {}
end

local function cleanAllHighlights()
    for ply, hl in pairs(ActiveHighlights) do pcall(function() hl:Destroy() end) end
    ActiveHighlights = {}
end

local function cleanAllBillboards()
    for ply, bb in pairs(ActiveBillboards) do pcall(function() bb:Destroy() end) end
    ActiveBillboards = {}
end

local function cleanAllTracers()
    for ply, line in pairs(ActiveTracers) do pcall(function() line:Destroy() end) end
    ActiveTracers = {}
end

-- Absolute cleanup destruction pipeline
local function initiateScriptSelfDestruct()
    getgenv().ShashelWareRunningUUID = nil
    for _, connection in ipairs(ScriptConnections) do
        if connection.Connected then connection:Disconnect() end
    end
    cleanAllBoxes()
    cleanAllHighlights()
    cleanAllBillboards()
    cleanAllTracers()
    
    -- Restore Xray elements
    for part, original in pairs(OriginalTransparencyCache) do
        pcall(function() part.Transparency = original end)
    end
    
    -- Clean Atmosphere effects
    local fx = Lighting:FindFirstChild("ShashelAtmosphereFX")
    if fx then fx:Destroy() end
    
    -- Clean Freecam
    if freecamPart then freecamPart:Destroy() end
    Camera.CameraType = Enum.CameraType.Custom
    
    pcall(function() ScreenGui:Destroy() end)
end

-- Alignment Snapping Assistant for TextGUI
local function handleTextGuiSnapping(frame)
    local screenWidth = Camera.ViewportSize.X
    local frameCenter = frame.AbsolutePosition.X + (frame.AbsoluteSize.X / 2)
    local alignment = Enum.TextXAlignment.Right
    local listAlignment = Enum.HorizontalAlignment.Right

    if frameCenter < (screenWidth / 2) then
        alignment = Enum.TextXAlignment.Left
        listAlignment = Enum.HorizontalAlignment.Left
    end

    if TextGuiWatermarkTitle then TextGuiWatermarkTitle.TextXAlignment = alignment end
    if CustomTextLabel then CustomTextLabel.TextXAlignment = alignment end
    if ActiveListLayout then ActiveListLayout.HorizontalAlignment = listAlignment end
    
    updateTextGuiDisplay()
end

-- Dragging Helper
local function makeDraggable(frame, dragHandle, structuralConstraintCheck)
    local dragging = false
    local dragInput, dragStart, startPos

    trackedConnect(dragHandle.InputBegan, function(input)
        if structuralConstraintCheck and not menuInterfaceVisibilityState then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if structuralConstraintCheck then
                        handleTextGuiSnapping(frame)
                    end
                end
            end)
        end
    end)

    trackedConnect(dragHandle.InputChanged, function(input)
        if structuralConstraintCheck and not menuInterfaceVisibilityState then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    trackedConnect(UserInputService.InputChanged, function(input)
        if input == dragInput and dragging then
            if structuralConstraintCheck and not menuInterfaceVisibilityState then dragging = false return end
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

--------------------------------------------------------------------------------
-- BASE FLOATING WINDOW GENERATOR FACTORY
--------------------------------------------------------------------------------
local function createBaseWindow(titleText, defaultPos)
    local WindowFrame = Instance.new("Frame")
    WindowFrame.Size = UDim2.new(0, 190, 0, 300) 
    WindowFrame.Position = defaultPos
    WindowFrame.BackgroundColor3 = VAPE_MAIN_BG
    WindowFrame.BorderSizePixel = 0
    WindowFrame.Active = true
    WindowFrame.Visible = false -- Boot closed by default
    WindowFrame.Parent = ScreenGui

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 5)
    Corner.Parent = WindowFrame

    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 45)
    Header.BackgroundTransparency = 1
    Header.Parent = WindowFrame

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -20, 1, 0)
    TitleLabel.Position = UDim2.new(0, 15, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = titleText
    TitleLabel.TextColor3 = VAPE_TEXT_ACTIVE
    TitleLabel.TextSize = 14
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Header

    makeDraggable(WindowFrame, Header, false)
    table.insert(globalWindowRegistry, WindowFrame)

    local ContentContainer = Instance.new("ScrollingFrame")
    ContentContainer.Size = UDim2.new(1, 0, 1, -50)
    ContentContainer.Position = UDim2.new(0, 0, 0, 45)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.BorderSizePixel = 0
    ContentContainer.ScrollBarThickness = 2
    ContentContainer.Parent = WindowFrame

    local Layout = Instance.new("UIListLayout")
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = ContentContainer

    trackedConnect(Layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        ContentContainer.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 15)
    end)

    return WindowFrame, ContentContainer
end

--------------------------------------------------------------------------------
-- PRIMARY NAVIGATION SIDEBAR CONTROL PANEL (MAIN TAB)
--------------------------------------------------------------------------------
local LeftPanel = Instance.new("Frame")
LeftPanel.Size = UDim2.new(0, 190, 0, 400)
LeftPanel.Position = UDim2.new(0.05, 0, 0.25, 0)
LeftPanel.BackgroundColor3 = VAPE_MAIN_BG
LeftPanel.BorderSizePixel = 0
LeftPanel.Active = true
LeftPanel.Visible = false -- Boot closed by default
LeftPanel.Parent = ScreenGui
table.insert(globalWindowRegistry, LeftPanel)

local LeftCorner = Instance.new("UICorner", LeftPanel)
LeftCorner.CornerRadius = UDim.new(0, 5)

local LogoHeader = Instance.new("Frame")
LogoHeader.Size = UDim2.new(1, 0, 0, 45)
LogoHeader.BackgroundTransparency = 1
LogoHeader.Parent = LeftPanel

local LogoText = Instance.new("TextLabel")
LogoText.Name = "WatermarkMain"
LogoText.Size = UDim2.new(1, -50, 1, 0)
LogoText.Position = UDim2.new(0, 15, 0, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "ShashelWare <font color='rgb(46,139,107)'>V1</font>"
LogoText.RichText = true
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.TextSize = 16
LogoText.Font = Enum.Font.GothamBold
LogoText.TextXAlignment = Enum.TextXAlignment.Left
LogoText.Parent = LogoHeader
table.insert(themeUpdateObjects, LogoText)

local SettingsButton = Instance.new("TextButton")
SettingsButton.Size = UDim2.new(0, 30, 0, 30)
SettingsButton.Position = UDim2.new(1, -38, 0.5, -15)
SettingsButton.BackgroundTransparency = 1
SettingsButton.Text = "⚙"
SettingsButton.TextColor3 = Color3.fromRGB(100, 100, 100)
SettingsButton.Font = Enum.Font.GothamBold
SettingsButton.TextSize = 16
SettingsButton.Parent = LogoHeader

makeDraggable(LeftPanel, LogoHeader, false)

local CategoryScroll = Instance.new("Frame")
CategoryScroll.Size = UDim2.new(1, 0, 1, -45)
CategoryScroll.Position = UDim2.new(0, 0, 0, 45)
CategoryScroll.BackgroundTransparency = 1
CategoryScroll.Visible = true
CategoryScroll.Parent = LeftPanel

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = CategoryScroll

local SettingsPage = Instance.new("ScrollingFrame")
SettingsPage.Size = UDim2.new(1, 0, 1, -45)
SettingsPage.Position = UDim2.new(0, 0, 0, 45)
SettingsPage.BackgroundTransparency = 1
SettingsPage.BorderSizePixel = 0
SettingsPage.ScrollBarThickness = 2
SettingsPage.Visible = false
SettingsPage.Parent = LeftPanel

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.Parent = SettingsPage

trackedConnect(SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    SettingsPage.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
end)

--------------------------------------------------------------------------------
-- INITIALIZE TRAYS FOR FLOATING WINDOWS
--------------------------------------------------------------------------------
local CombatWindow, CombatPage = createBaseWindow("Combat", UDim2.new(0.05, 205, 0.25, 0))
local RenderWindow, RenderPage = createBaseWindow("Render", UDim2.new(0.05, 410, 0.25, 0))
local UtilityWindow, UtilityPage = createBaseWindow("Utility", UDim2.new(0.05, 615, 0.25, 0))
local WorldWindow, WorldPage = createBaseWindow("World", UDim2.new(0.05, 615, 0.25, 200))
local InventoryWindow, InventoryPage = createBaseWindow("Inventory", UDim2.new(0.05, 205, 0.25, 200))
local MinigamesWindow, MinigamesPage = createBaseWindow("Minigames", UDim2.new(0.05, 410, 0.25, 200))
local OtherWindow, OtherPage = createBaseWindow("Other", UDim2.new(0.05, 615, 0.25, 400))

local windowMapping = {
    ["Combat"] = CombatWindow,
    ["Render"] = RenderWindow,
    ["Utility"] = UtilityWindow,
    ["World"] = WorldWindow,
    ["Inventory"] = InventoryWindow,
    ["Minigames"] = MinigamesWindow,
    ["Other"] = OtherWindow
}

local function fillEmptyNotice(parentTray)
    local EmptyMsg = Instance.new("TextLabel")
    EmptyMsg.Size = UDim2.new(1, 0, 0, 40)
    EmptyMsg.BackgroundTransparency = 1
    EmptyMsg.Text = "No active modules found."
    EmptyMsg.TextColor3 = Color3.fromRGB(60, 60, 60)
    EmptyMsg.Font = Enum.Font.GothamMedium
    EmptyMsg.TextSize = 11
    EmptyMsg.Parent = parentTray
end

fillEmptyNotice(InventoryPage)
fillEmptyNotice(MinigamesPage)

--------------------------------------------------------------------------------
-- TEXTGUI MAIN CONTAINER ARCHITECTURE
--------------------------------------------------------------------------------
TextGuiContainerFrame = Instance.new("Frame")
TextGuiContainerFrame.Size = UDim2.new(0, 240, 0, 500)
TextGuiContainerFrame.Position = UDim2.new(0.8, 0, 0.05, 0)
TextGuiContainerFrame.BackgroundTransparency = 1
TextGuiContainerFrame.Active = true
TextGuiContainerFrame.Visible = Settings.TextGUI
TextGuiContainerFrame.Parent = ScreenGui

-- Combined Header containing Watermark Title & Custom Text right beneath it
TextGuiHeaderDragHandle = Instance.new("Frame")
TextGuiHeaderDragHandle.Size = UDim2.new(1, 0, 0, 50)
TextGuiHeaderDragHandle.BackgroundTransparency = 1
TextGuiHeaderDragHandle.Parent = TextGuiContainerFrame

local HeaderLayout = Instance.new("UIListLayout")
HeaderLayout.SortOrder = Enum.SortOrder.LayoutOrder
HeaderLayout.Padding = UDim.new(0, 1)
HeaderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
HeaderLayout.Parent = TextGuiHeaderDragHandle

TextGuiWatermarkTitle = Instance.new("TextLabel")
TextGuiWatermarkTitle.Name = "WatermarkMain"
TextGuiWatermarkTitle.Size = UDim2.new(1, 0, 0, Settings.TextGuiSize + 4)
TextGuiWatermarkTitle.BackgroundTransparency = 1
TextGuiWatermarkTitle.Text = "ShashelWare <font color='rgb(46,139,107)'>V1</font>"
TextGuiWatermarkTitle.RichText = true
TextGuiWatermarkTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
TextGuiWatermarkTitle.Font = Enum.Font.GothamBold
TextGuiWatermarkTitle.TextSize = Settings.TextGuiSize + 2  
TextGuiWatermarkTitle.TextXAlignment = Enum.TextXAlignment.Right
TextGuiWatermarkTitle.LayoutOrder = 1
TextGuiWatermarkTitle.Visible = Settings.TextGuiWatermark
TextGuiWatermarkTitle.Parent = TextGuiHeaderDragHandle
table.insert(themeUpdateObjects, TextGuiWatermarkTitle)

CustomTextLabel = Instance.new("TextLabel")
CustomTextLabel.Size = UDim2.new(1, 0, 0, Settings.TextGuiSize + 2)
CustomTextLabel.BackgroundTransparency = 1
CustomTextLabel.Text = Settings.TextGuiCustomText
CustomTextLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
CustomTextLabel.Font = Enum.Font.GothamMedium
CustomTextLabel.TextSize = Settings.TextGuiSize - 2
CustomTextLabel.TextXAlignment = Enum.TextXAlignment.Right
CustomTextLabel.LayoutOrder = 2
CustomTextLabel.Visible = false
CustomTextLabel.Parent = TextGuiHeaderDragHandle

local ActiveListScrollArea = Instance.new("Frame")
ActiveListScrollArea.Size = UDim2.new(1, 0, 1, -60)
ActiveListScrollArea.Position = UDim2.new(0, 0, 0, 60)
ActiveListScrollArea.BackgroundTransparency = 1
ActiveListScrollArea.Parent = TextGuiContainerFrame

ActiveListLayout = Instance.new("UIListLayout")
ActiveListLayout.SortOrder = Enum.SortOrder.Name
ActiveListLayout.Padding = UDim.new(0, 3)
ActiveListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ActiveListLayout.Parent = ActiveListScrollArea

local isLeftSnapped = false
makeDraggable(TextGuiContainerFrame, TextGuiHeaderDragHandle, true)

local function adjustHeaderSizeConstraints()
    local totalHeight = 0
    if Settings.TextGuiWatermark then totalHeight = totalHeight + Settings.TextGuiSize + 6 end
    if Settings.TextGuiCustomText and Settings.TextGuiCustomText ~= "" then totalHeight = totalHeight + Settings.TextGuiSize end
    
    TextGuiHeaderDragHandle.Size = UDim2.new(1, 0, 0, totalHeight > 0 and totalHeight or 20)
    ActiveListScrollArea.Position = UDim2.new(0, 0, 0, totalHeight + 6)
    ActiveListScrollArea.Size = UDim2.new(1, 0, 1, -(totalHeight + 6))
end

function updateTextGuiDisplay()
    for _, child in ipairs(ActiveListScrollArea:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    
    if not Settings.TextGUI then return end

    TextGuiWatermarkTitle.Visible = Settings.TextGuiWatermark
    TextGuiWatermarkTitle.TextSize = Settings.TextGuiSize + 2

    if Settings.TextGuiCustomText and Settings.TextGuiCustomText ~= "" then
        CustomTextLabel.Text = Settings.TextGuiCustomText
        CustomTextLabel.TextSize = Settings.TextGuiSize - 1
        CustomTextLabel.Visible = true
    else
        CustomTextLabel.Visible = false
    end

    adjustHeaderSizeConstraints()

    isLeftSnapped = (TextGuiContainerFrame.AbsolutePosition.X + (TextGuiContainerFrame.AbsoluteSize.X / 2) < Camera.ViewportSize.X / 2)
    local alignment = isLeftSnapped and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    local listAlignment = isLeftSnapped and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right

    HeaderLayout.HorizontalAlignment = listAlignment
    ActiveListLayout.HorizontalAlignment = listAlignment

    for moduleName, checkFunc in pairs(moduleStateCheckers) do
        if moduleName ~= "TextGUI" and checkFunc() then
            local textBounds = TextService:GetTextSize(moduleName, Settings.TextGuiSize, Enum.Font.GothamBold, Vector2.new(1000, 1000))
            local rowWidth = textBounds.X + 16 

            if Settings.TextGuiShadow then
                local RowFrame = Instance.new("Frame")
                RowFrame.Size = UDim2.new(0, rowWidth, 0, Settings.TextGuiSize + 6)
                RowFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                RowFrame.BackgroundTransparency = 0.4
                RowFrame.BorderSizePixel = 0
                RowFrame.Parent = ActiveListScrollArea

                local RowCorner = Instance.new("UICorner", RowFrame)
                RowCorner.CornerRadius = UDim.new(0, 3)

                local AccentBar = Instance.new("Frame")
                AccentBar.Name = "AccentIndicatorBar"
                AccentBar.Size = UDim2.new(0, 3, 1, 0)
                AccentBar.BackgroundColor3 = CurrentThemeColor
                AccentBar.BorderSizePixel = 0
                AccentBar.Position = isLeftSnapped and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -3, 0, 0)
                AccentBar.Parent = RowFrame
                table.insert(themeUpdateObjects, AccentBar)

                local ElementRow = Instance.new("TextLabel")
                ElementRow.Name = "ActiveHudPart"
                ElementRow.Size = UDim2.new(1, -10, 1, 0)
                ElementRow.Position = isLeftSnapped and UDim2.new(0, 7, 0, 0) or UDim2.new(0, 3, 0, 0)
                ElementRow.BackgroundTransparency = 1
                ElementRow.Text = moduleName
                ElementRow.TextColor3 = CurrentThemeColor
                ElementRow.Font = Enum.Font.GothamBold
                ElementRow.TextSize = Settings.TextGuiSize
                ElementRow.TextXAlignment = alignment
                ElementRow.TextStrokeTransparency = Settings.TextGuiTextShadow and 0.5 or 1
                ElementRow.Parent = RowFrame
                table.insert(themeUpdateObjects, ElementRow)
            else
                local ElementRow = Instance.new("TextLabel")
                ElementRow.Name = "ActiveHudPart"
                ElementRow.Size = UDim2.new(0, rowWidth, 0, Settings.TextGuiSize + 2)
                ElementRow.BackgroundTransparency = 1
                ElementRow.Text = moduleName
                ElementRow.TextColor3 = CurrentThemeColor
                ElementRow.Font = Enum.Font.GothamBold
                ElementRow.TextSize = Settings.TextGuiSize
                ElementRow.TextXAlignment = alignment
                ElementRow.TextStrokeTransparency = Settings.TextGuiTextShadow and 0.5 or 1
                ElementRow.Parent = ActiveListScrollArea
                table.insert(themeUpdateObjects, ElementRow)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- RUNTIME CONTROLS: FIXED PERCENTAGE BOUNDED DROPDOWN INPUTS
--------------------------------------------------------------------------------
local function createModuleWithSettings(targetContainer, text, default, toggleCallback, buildSettingsCallback)
    local MasterRowContainer = Instance.new("Frame")
    MasterRowContainer.Size = UDim2.new(1, 0, 0, 38) 
    MasterRowContainer.BackgroundTransparency = 1
    MasterRowContainer.ClipsDescendants = true
    MasterRowContainer.Parent = targetContainer

    local MainRow = Instance.new("Frame")
    MainRow.Size = UDim2.new(1, 0, 0, 38)
    MainRow.BackgroundTransparency = 1
    MainRow.Parent = MasterRowContainer

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ModuleToggle"
    ToggleBtn.Size = UDim2.new(1, -50, 1, 0)
    ToggleBtn.Position = UDim2.new(0, 15, 0, 0)
    ToggleBtn.BackgroundTransparency = 1
    ToggleBtn.Text = text
    ToggleBtn.TextColor3 = default and CurrentThemeColor or VAPE_TEXT_COLOR
    ToggleBtn.Font = Enum.Font.GothamMedium
    ToggleBtn.TextSize = 13
    ToggleBtn.TextXAlignment = Enum.TextXAlignment.Left
    ToggleBtn.Parent = MainRow
    table.insert(themeUpdateObjects, ToggleBtn)
    
    moduleMacroNames[ToggleBtn] = text
    local currentAssignedMacroKey = nil

    local SettingsDots = Instance.new("TextButton")
    SettingsDots.Size = UDim2.new(0, 35, 1, 0)
    SettingsDots.Position = UDim2.new(1, -40, 0, 0)
    SettingsDots.BackgroundTransparency = 1
    SettingsDots.Text = "•••"
    SettingsDots.TextColor3 = Color3.fromRGB(70, 70, 70)
    SettingsDots.TextSize = 10
    SettingsDots.Font = Enum.Font.GothamBold
    SettingsDots.Parent = MainRow

    local DropdownTray = Instance.new("Frame")
    DropdownTray.Size = UDim2.new(1, 0, 0, 0) 
    DropdownTray.Position = UDim2.new(0, 0, 0, 38)
    DropdownTray.BackgroundColor3 = VAPE_DROPDOWN_BG
    DropdownTray.BorderSizePixel = 0
    DropdownTray.Visible = false
    DropdownTray.Parent = MasterRowContainer

    local calculatedTrayHeight = 0
    if buildSettingsCallback then calculatedTrayHeight = buildSettingsCallback(DropdownTray) end

    local isToggled = default
    
    local function executeToggleAction(isInitialLoad)
        isToggled = not isToggled
        ToggleBtn.TextColor3 = isToggled and CurrentThemeColor or VAPE_TEXT_COLOR
        toggleCallback(isToggled)
        updateTextGuiDisplay()
        
        if not isInitialLoad then
            showNotification(text .. (isToggled and " enabled" or " disabled"), 2.5)
        end
    end

    trackedConnect(ToggleBtn.MouseButton1Click, function()
        executeToggleAction(false)
    end)

    moduleStateCheckers[text] = function() return isToggled end

    local isRightClickBinding = false
    trackedConnect(ToggleBtn.MouseButton2Click, function()
        if isBinding or isBindingUIKey or isBindingMTPKey or isRightClickBinding then return end
        isRightClickBinding = true
        ToggleBtn.Text = "[Press Key]"
        ToggleBtn.TextColor3 = Color3.fromRGB(130, 130, 130)
    end)

    trackedConnect(UserInputService.InputBegan, function(input, processed)
        if isRightClickBinding then
            if input.KeyCode == Enum.KeyCode.Backspace then
                if currentAssignedMacroKey then
                    macroBindsRegistry[currentAssignedMacroKey] = nil
                    currentAssignedMacroKey = nil
                end
                ToggleBtn.Text = moduleMacroNames[ToggleBtn]
            else
                local targetInput = (input.UserInputType == Enum.UserInputType.Keyboard) and input.KeyCode or input.UserInputType
                if targetInput ~= Enum.KeyCode.Escape and targetInput ~= Settings.ToggleUIKey then
                    if currentAssignedMacroKey then macroBindsRegistry[currentAssignedMacroKey] = nil end
                    
                    currentAssignedMacroKey = targetInput
                    macroBindsRegistry[targetInput] = function() executeToggleAction(false) end
                    
                    local cleanName = (input.UserInputType == Enum.UserInputType.Keyboard) and input.KeyCode.Name or input.UserInputType.Name:gsub("MouseButton", "MB")
                    ToggleBtn.Text = moduleMacroNames[ToggleBtn] .. " [" .. cleanName .. "]"
                else
                    ToggleBtn.Text = currentAssignedMacroKey and (moduleMacroNames[ToggleBtn] .. " [" .. currentAssignedMacroKey.Name:gsub("MouseButton", "MB") .. "]") or moduleMacroNames[ToggleBtn]
                end
            end
            ToggleBtn.TextColor3 = isToggled and CurrentThemeColor or VAPE_TEXT_COLOR
            isRightClickBinding = false
        end
    end)

    local trayExpanded = false
    trackedConnect(SettingsDots.MouseButton1Click, function()
        if calculatedTrayHeight == 0 then return end
        trayExpanded = not trayExpanded
        SettingsDots.TextColor3 = trayExpanded and CurrentThemeColor or Color3.fromRGB(70, 70, 70)
        
        if trayExpanded then
            DropdownTray.Visible = true
            DropdownTray.Size = UDim2.new(1, 0, 0, calculatedTrayHeight)
            MasterRowContainer.Size = UDim2.new(1, 0, 0, 38 + calculatedTrayHeight)
        else
            DropdownTray.Size = UDim2.new(1, 0, 0, 0)
            MasterRowContainer.Size = UDim2.new(1, 0, 0, 38)
            DropdownTray.Visible = false
        end
    end)
end

local function attachInnerSlider(parentFrame, text, min, max, default, topYOffset, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, 0, 0, 44)
    SliderFrame.Position = UDim2.new(0, 0, 0, topYOffset)
    SliderFrame.BackgroundTransparency = 1
    SliderFrame.Parent = parentFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.5, 0, 0, 20)
    Label.Position = UDim2.new(0, 15, 0, 4)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(120, 120, 120)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SliderFrame

    local ValueDisplay = Instance.new("TextLabel")
    ValueDisplay.Size = UDim2.new(0.3, 0, 0, 20)
    ValueDisplay.Position = UDim2.new(1, -45, 0, 4)
    ValueDisplay.BackgroundTransparency = 1
    ValueDisplay.Text = tostring(default)
    ValueDisplay.TextColor3 = CurrentThemeColor
    ValueDisplay.Font = Enum.Font.GothamBold
    ValueDisplay.TextSize = 10
    ValueDisplay.TextXAlignment = Enum.TextXAlignment.Right
    ValueDisplay.Parent = SliderFrame
    table.insert(themeUpdateObjects, ValueDisplay)

    local Track = Instance.new("Frame")
    Track.Size = UDim2.new(1, -30, 0, 2)
    Track.Position = UDim2.new(0, 15, 0, 28)
    Track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Track.BorderSizePixel = 0
    Track.Parent = SliderFrame

    local Fill = Instance.new("Frame")
    Fill.Name = "SliderFill"
    local startPercent = (default - min) / (max - min)
    Fill.Size = UDim2.new(startPercent, 0, 1, 0)
    Fill.BackgroundColor3 = CurrentThemeColor
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    table.insert(themeUpdateObjects, Fill)

    local Knob = Instance.new("TextButton")
    Knob.Size = UDim2.new(0, 8, 0, 8)
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.Position = UDim2.new(startPercent, 0, 0.5, 0)
    Knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    Knob.Text = ""
    Knob.Parent = Track
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    trackedConnect(Knob.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    trackedConnect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    trackedConnect(RunService.RenderStepped, function()
        if dragging then
            local mousePos = UserInputService:GetMouseLocation()
            local relativeX = math.clamp((mousePos.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
            Fill.Size = UDim2.new(relativeX, 0, 1, 0)
            Knob.Position = UDim2.new(relativeX, 0, 0.5, 0)
            local value = min + (relativeX * (max - min))
            local displayStr = (max - min <= 1) and string.format("%.2f", value) or tostring(math.round(value))
            ValueDisplay.Text = displayStr
            callback(tonumber(displayStr))
        end
    end)
end

local function attachInnerCheckbox(parentFrame, text, default, topYOffset, callback)
    local CheckFrame = Instance.new("Frame")
    CheckFrame.Size = UDim2.new(1, 0, 0, 36)
    CheckFrame.Position = UDim2.new(0, 0, 0, topYOffset)
    CheckFrame.BackgroundTransparency = 1
    CheckFrame.Parent = parentFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(120, 120, 120)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = CheckFrame

    local Box = Instance.new("TextButton")
    Box.Size = UDim2.new(0, 16, 0, 16)
    Box.Position = UDim2.new(1, -31, 0.5, -8)
    Box.BackgroundColor3 = default and CurrentThemeColor or Color3.fromRGB(40, 40, 40)
    Box.Text = default and "✓" or ""
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.Font = Enum.Font.GothamBold
    Box.TextSize = 10
    Box.Parent = CheckFrame
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 3)

    if default then table.insert(themeUpdateObjects, Box) end

    local isChecked = default
    trackedConnect(Box.MouseButton1Click, function()
        isChecked = not isChecked
        Box.BackgroundColor3 = isChecked and CurrentThemeColor or Color3.fromRGB(40, 40, 40)
        Box.Text = isChecked and "✓" or ""
        
        if isChecked then
            if not table.find(themeUpdateObjects, Box) then table.insert(themeUpdateObjects, Box) end
        else
            local index = table.find(themeUpdateObjects, Box)
            if index then table.remove(themeUpdateObjects, index) end
        end
        callback(isChecked)
    end)
end

local function attachInnerTextBox(parentFrame, text, default, topYOffset, callback)
    local BoxFrame = Instance.new("Frame")
    BoxFrame.Size = UDim2.new(1, 0, 0, 40)
    BoxFrame.Position = UDim2.new(0, 0, 0, topYOffset)
    BoxFrame.BackgroundTransparency = 1
    BoxFrame.Parent = parentFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.4, 0, 1, 0)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(120, 120, 120)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = BoxFrame

    local Input = Instance.new("TextBox")
    Input.Size = UDim2.new(0, 90, 0, 20)
    Input.Position = UDim2.new(1, -105, 0.5, -10)
    Input.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Input.Text = default
    Input.TextColor3 = Color3.fromRGB(200, 200, 200)
    Input.Font = Enum.Font.GothamMedium
    Input.TextSize = 10
    Input.ClearTextOnFocus = false
    Input.Parent = BoxFrame
    Instance.new("UICorner", Input).CornerRadius = UDim.new(0, 4)

    trackedConnect(Input.FocusLost, function()
        callback(Input.Text)
    end)
end

local function attachInnerKeybind(parentFrame, text, topYOffset, initialKey, bindingStateCheck, assignCallback)
    local RowFrame = Instance.new("Frame")
    RowFrame.Size = UDim2.new(1, 0, 0, 38)
    RowFrame.Position = UDim2.new(0, 0, 0, topYOffset)
    RowFrame.BackgroundTransparency = 1
    RowFrame.Parent = parentFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.5, 0, 1, 0)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(120, 120, 120)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = RowFrame

    local RebindButton = Instance.new("TextButton")
    RebindButton.Name = "DynamicBindBtn"
    RebindButton.Size = UDim2.new(0, 60, 0, 18)
    RebindButton.Position = UDim2.new(1, -75, 0.5, -9)
    RebindButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    RebindButton.Text = initialKey.Name
    RebindButton.TextColor3 = CurrentThemeColor 
    RebindButton.Font = Enum.Font.GothamBold
    RebindButton.TextSize = 9
    RebindButton.Parent = RowFrame
    Instance.new("UICorner", RebindButton).CornerRadius = UDim.new(0, 4)
    table.insert(themeUpdateObjects, RebindButton)

    trackedConnect(RebindButton.MouseButton1Click, function()
        if isBinding or isBindingUIKey or isBindingMTPKey then return end
        if bindingStateCheck == "AIM" then isBinding = true
        elseif bindingStateCheck == "MOUSET_TP" then isBindingMTPKey = true end
        RebindButton.Text = "..."
        RebindButton.TextColor3 = Color3.fromRGB(150, 150, 150)
    end)

    trackedConnect(UserInputService.InputBegan, function(input)
        local validation = false
        if bindingStateCheck == "AIM" and isBinding then validation = true
        elseif bindingStateCheck == "MOUSET_TP" and isBindingMTPKey then validation = true end

        if validation then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Settings.ToggleUIKey then
                    assignCallback(input.KeyCode)
                    RebindButton.Text = input.KeyCode.Name
                else
                    RebindButton.Text = initialKey.Name
                end
            elseif string.find(input.UserInputType.Name, "MouseButton") then
                assignCallback(input.UserInputType)
                RebindButton.Text = input.UserInputType.Name:gsub("MouseButton", "MB")
            end
            RebindButton.TextColor3 = CurrentThemeColor
            if bindingStateCheck == "AIM" then isBinding = false
            elseif bindingStateCheck == "MOUSET_TP" then isBindingMTPKey = false end
        end
    end)
end

local function attachInnerModeSelect(parentFrame, text, modesList, defaultMode, topYOffset, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 38)
    Container.Position = UDim2.new(0, 0, 0, topYOffset)
    Container.BackgroundTransparency = 1
    Container.Parent = parentFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.4, 0, 1, 0)
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(120, 120, 120)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container

    local Button = Instance.new("TextButton")
    Button.Name = "ModeSelectBtn"
    Button.Size = UDim2.new(0, 75, 0, 18)
    Button.Position = UDim2.new(1, -90, 0.5, -9)
    Button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Button.Text = defaultMode
    Button.TextColor3 = CurrentThemeColor
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 9
    Button.Parent = Container
    Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 4)
    table.insert(themeUpdateObjects, Button)

    local currentIndex = 1
    for idx, mode in ipairs(modesList) do if mode == defaultMode then currentIndex = idx end end

    trackedConnect(Button.MouseButton1Click, function()
        currentIndex = (currentIndex % #modesList) + 1
        local selectedMode = modesList[currentIndex]
        Button.Text = selectedMode
        callback(selectedMode)
    end)
end

--------------------------------------------------------------------------------
-- COMBAT WINDOW PIPELINES
--------------------------------------------------------------------------------
createModuleWithSettings(CombatPage, "AimAssist", Settings.Enabled, function(v) Settings.Enabled = v end, function(trayFrame)
    attachInnerSlider(trayFrame, "Smoothness", 0.01, 1.00, Settings.Smoothness, 4, function(v) Settings.Smoothness = v end)
    attachInnerKeybind(trayFrame, "Bind Key", 48, Settings.AimKey, "AIM", function(key) Settings.AimKey = key end)
    return 90 
end)

createModuleWithSettings(CombatPage, "WallCheck", Settings.WallCheck, function(v) Settings.WallCheck = v end, nil)

createModuleWithSettings(CombatPage, "FOV", Settings.FOVEnabled, function(v) 
    Settings.FOVEnabled = v 
    if FOVCircle then FOVCircle.Visible = v and menuInterfaceVisibilityState end
end, function(trayFrame)
    attachInnerSlider(trayFrame, "FOV Radius", 30, 500, Settings.FOV, 4, function(v)
        Settings.FOV = v
        if FOVCircle then FOVCircle.Size = UDim2.new(0, v * 2, 0, v * 2) end
    end)
    attachInnerSlider(trayFrame, "Camera FOV", 30, 120, Settings.CameraFOV, 48, function(v)
        Settings.CameraFOV = v
        Camera.FieldOfView = v
    end)
    return 96 
end)

--------------------------------------------------------------------------------
-- RENDER WINDOW PIPELINES
--------------------------------------------------------------------------------
createModuleWithSettings(RenderPage, "ESP", Settings.ESP, function(v) 
    Settings.ESP = v 
    if not v then cleanAllBoxes() end
end, nil)

createModuleWithSettings(RenderPage, "Chams", Settings.Chams, function(v) 
    Settings.Chams = v 
    if not v then cleanAllHighlights() end
end, nil)

createModuleWithSettings(RenderPage, "Nametags", Settings.Nametags, function(v) 
    Settings.Nametags = v 
    if not v then cleanAllBillboards() end
end, nil)

createModuleWithSettings(RenderPage, "Tracers", Settings.Tracers, function(v) 
    Settings.Tracers = v 
    if not v then cleanAllTracers() end
end, nil)

--------------------------------------------------------------------------------
-- UTILITY PIPELINES
--------------------------------------------------------------------------------
createModuleWithSettings(UtilityPage, "Noclip", Settings.Noclip, function(v) Settings.Noclip = v end, nil)

createModuleWithSettings(UtilityPage, "Flight", Settings.Flight, function(v) Settings.Flight = v end, function(trayFrame)
    attachInnerSlider(trayFrame, "Fly Speed", 10, 200, Settings.FlightSpeed, 4, function(v) Settings.FlightSpeed = v end)
    return 50
end)

createModuleWithSettings(UtilityPage, "MouseTP", Settings.MouseTP, function(v) Settings.MouseTP = v end, function(trayFrame)
    attachInnerKeybind(trayFrame, "TP Keybind", 4, Settings.MouseTPKey, "MOUSET_TP", function(key) Settings.MouseTPKey = key end)
    return 44
end)

createModuleWithSettings(UtilityPage, "Speed", Settings.Speed, function(v) 
    Settings.Speed = v 
    if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
    end
end, function(trayFrame)
    attachInnerModeSelect(trayFrame, "Method Mode", {"Normal", "CFrame", "TP"}, Settings.SpeedMode, 4, function(m) Settings.SpeedMode = m end)
    attachInnerSlider(trayFrame, "Speed Magnitude", 16, 250, Settings.SpeedValue, 46, function(v) Settings.SpeedValue = v end)
    return 94
end)

createModuleWithSettings(UtilityPage, "Infinite Jump", Settings.InfJump, function(v) Settings.InfJump = v end, nil)

createModuleWithSettings(UtilityPage, "Spinbot", Settings.Spinbot, function(v) Settings.Spinbot = v end, function(trayFrame)
    attachInnerSlider(trayFrame, "Rotation Speed", 5, 150, Settings.SpinbotSpeed, 4, function(v) Settings.SpinbotSpeed = v end)
    return 50
end)

createModuleWithSettings(UtilityPage, "Dupe", Settings.Dupe, function(v)
    Settings.Dupe = v
    if v then
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        
        if tool and backpack then
            local success, _ = pcall(function()
                local clone = tool:Clone()
                clone.Parent = backpack
            end)
            if success then
                showNotification("Duplicated: " .. tool.Name, 2.5)
            else
                showNotification("Duplication Failed.", 2.5)
            end
        else
            showNotification("Hold an item to duplicate!", 2.5)
        end
    end
end, nil)

--------------------------------------------------------------------------------
-- WORLD TAB PIPELINES
--------------------------------------------------------------------------------
local function refreshAtmosphereFX()
    local fx = Lighting:FindFirstChild("ShashelAtmosphereFX")
    if not Settings.Atmosphere then
        if fx then fx:Destroy() end
        return
    end
    if not fx then
        fx = Instance.new("ColorCorrectionEffect")
        fx.Name = "ShashelAtmosphereFX"
        fx.Parent = Lighting
    end
    
    local r, g, b = string.match(Settings.AtmosphereColor, "(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
    if r and g and b then
        fx.TintColor = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
    else
        fx.TintColor = Color3.fromRGB(255, 255, 255)
    end
    fx.Saturation = Settings.AtmosphereIntensity - 0.5
    fx.Contrast = Settings.AtmosphereIntensity / 2
end

createModuleWithSettings(WorldPage, "Atmosphere", Settings.Atmosphere, function(v)
    Settings.Atmosphere = v
    refreshAtmosphereFX()
end, function(trayFrame)
    attachInnerTextBox(trayFrame, "Color (R,G,B)", Settings.AtmosphereColor, 4, function(v)
        Settings.AtmosphereColor = v
        refreshAtmosphereFX()
    end)
    attachInnerSlider(trayFrame, "Intensity/Alpha", 0, 1, Settings.AtmosphereIntensity, 46, function(v)
        Settings.AtmosphereIntensity = v
        refreshAtmosphereFX()
    end)
    return 94
end)

createModuleWithSettings(WorldPage, "TimeChanger", Settings.TimeChanger, function(v)
    Settings.TimeChanger = v
    if not v then Lighting.ClockTime = 12 end
end, function(trayFrame)
    attachInnerSlider(trayFrame, "World Clock", 0, 24, Settings.TimeValue, 4, function(v)
        Settings.TimeValue = v
        if Settings.TimeChanger then Lighting.ClockTime = v end
    end)
    return 50
end)

createModuleWithSettings(WorldPage, "Freecam", Settings.Freecam, function(v)
    Settings.Freecam = v
    freecamActive = v
    if v then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if not freecamPart then
                freecamPart = Instance.new("Part")
                freecamPart.Size = Vector3.new(1, 1, 1)
                freecamPart.Transparency = 1
                freecamPart.CanCollide = false
                freecamPart.Anchored = true
                freecamPart.Parent = workspace
            end
            freecamPart.CFrame = Camera.CFrame
            Camera.CameraSubject = freecamPart
            Camera.CameraType = Enum.CameraType.Scriptable
        end
    else
        Camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        Camera.CameraType = Enum.CameraType.Custom
    end
end, function(trayFrame)
    attachInnerSlider(trayFrame, "Cam Velocity", 10, 150, Settings.FreecamSpeed, 4, function(v) Settings.FreecamSpeed = v end)
    return 50
end)

local function applyXrayRuntime()
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part:IsDescendantOf(LocalPlayer.Character) and not part.Parent:FindFirstChildOfClass("Humanoid") then
            if Settings.Xray then
                if not OriginalTransparencyCache[part] then
                    OriginalTransparencyCache[part] = part.Transparency
                end
                part.Transparency = Settings.XrayTransparency
            else
                if OriginalTransparencyCache[part] then
                    part.Transparency = OriginalTransparencyCache[part]
                end
            end
        end
    end
end

createModuleWithSettings(WorldPage, "Xray", Settings.Xray, function(v)
    Settings.Xray = v
    if not v then
        for part, original in pairs(OriginalTransparencyCache) do
            pcall(function() part.Transparency = original end)
        end
        OriginalTransparencyCache = {}
    else
        applyXrayRuntime()
    end
end, function(trayFrame)
    attachInnerSlider(trayFrame, "Alpha Level", 0, 1, Settings.XrayTransparency, 4, function(v)
        Settings.XrayTransparency = v
        if Settings.Xray then applyXrayRuntime() end
    end)
    return 50
end)

--------------------------------------------------------------------------------
-- OTHER OPTIONS WINDOW INTERFACES
--------------------------------------------------------------------------------
createModuleWithSettings(OtherPage, "TextGUI", Settings.TextGUI, function(v)
    Settings.TextGUI = v
    TextGuiContainerFrame.Visible = v
    updateTextGuiDisplay()
    if v then handleTextGuiSnapping(TextGuiContainerFrame) end
end, function(trayFrame)
    attachInnerSlider(trayFrame, "Global Text Size", 10, 26, Settings.TextGuiSize, 4, function(v)
        Settings.TextGuiSize = v
        updateTextGuiDisplay()
    end)
    attachInnerCheckbox(trayFrame, "Row Shadow Background", Settings.TextGuiShadow, 48, function(v)
        Settings.TextGuiShadow = v
        updateTextGuiDisplay()
    end)
    attachInnerCheckbox(trayFrame, "Text DropShadow", Settings.TextGuiTextShadow, 84, function(v)
        Settings.TextGuiTextShadow = v
        updateTextGuiDisplay()
    end)
    attachInnerCheckbox(trayFrame, "Enable Watermark", Settings.TextGuiWatermark, 120, function(v)
        Settings.TextGuiWatermark = v
        updateTextGuiDisplay()
    end)
    attachInnerTextBox(trayFrame, "Header Sub-Text Label", Settings.TextGuiCustomText, 156, function(v)
        Settings.TextGuiCustomText = v
        updateTextGuiDisplay()
    end)
    return 200
end)

--------------------------------------------------------------------------------
-- EMBEDDED GLOBAL SETTINGS CONTENT SETUP
--------------------------------------------------------------------------------
local BindRow = Instance.new("Frame")
BindRow.Size = UDim2.new(1, 0, 0, 44)
BindRow.BackgroundTransparency = 1
BindRow.Parent = SettingsPage

local BindLabel = Instance.new("TextLabel")
BindLabel.Size = UDim2.new(0, 110, 1, 0)
BindLabel.Position = UDim2.new(0, 15, 0, 0)
BindLabel.BackgroundTransparency = 1
BindLabel.Text = "UI Toggle Bind"
BindLabel.TextColor3 = VAPE_TEXT_COLOR
BindLabel.Font = Enum.Font.GothamMedium
BindLabel.TextSize = 11
BindLabel.TextXAlignment = Enum.TextXAlignment.Left
BindLabel.Parent = BindRow

local UIRebindBtn = Instance.new("TextButton")
UIRebindBtn.Name = "DynamicBindBtn"
UIRebindBtn.Size = UDim2.new(0, 50, 0, 18)
UIRebindBtn.Position = UDim2.new(1, -15, 0.5, 0)
UIRebindBtn.AnchorPoint = Vector2.new(1, 0.5)
UIRebindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
UIRebindBtn.Text = Settings.ToggleUIKey.Name
UIRebindBtn.TextColor3 = CurrentThemeColor 
UIRebindBtn.Font = Enum.Font.GothamBold
UIRebindBtn.TextSize = 10
UIRebindBtn.Parent = BindRow
Instance.new("UICorner", UIRebindBtn).CornerRadius = UDim.new(0, 4)
table.insert(themeUpdateObjects, UIRebindBtn)

trackedConnect(UIRebindBtn.MouseButton1Click, function()
    if isBindingUIKey or isBinding or isBindingMTPKey then return end
    isBindingUIKey = true
    UIRebindBtn.Text = "..."
    UIRebindBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
end)

trackedConnect(UserInputService.InputBegan, function(input)
    if isBindingUIKey then
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Settings.AimKey then
            Settings.ToggleUIKey = input.KeyCode
            UIRebindBtn.Text = input.KeyCode.Name
        else
            UIRebindBtn.Text = Settings.ToggleUIKey.Name
        end
        UIRebindBtn.TextColor3 = CurrentThemeColor
        isBindingUIKey = false
    end
end)

--------------------------------------------------------------------------------
-- GLOBAL MASTER SORT ENGINE CONTROL BUTTON BLOCK
--------------------------------------------------------------------------------
local SortRow = Instance.new("Frame")
SortRow.Size = UDim2.new(1, 0, 0, 44)
SortRow.BackgroundTransparency = 1
SortRow.Parent = SettingsPage

local SortLabel = Instance.new("TextLabel")
SortLabel.Size = UDim2.new(0, 100, 1, 0)
SortLabel.Position = UDim2.new(0, 15, 0, 0)
SortLabel.BackgroundTransparency = 1
SortLabel.Text = "Organize Windows"
SortLabel.TextColor3 = VAPE_TEXT_COLOR
SortLabel.Font = Enum.Font.GothamMedium
SortLabel.TextSize = 11
SortLabel.TextXAlignment = Enum.TextXAlignment.Left
SortLabel.Parent = SortRow

local SortActionBtn = Instance.new("TextButton")
SortActionBtn.Name = "ActionBtn"
SortActionBtn.Size = UDim2.new(0, 60, 0, 20)
SortActionBtn.Position = UDim2.new(1, -15, 0.5, 0)
SortActionBtn.AnchorPoint = Vector2.new(1, 0.5)
SortActionBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
SortActionBtn.Text = "SORT"
SortActionBtn.TextColor3 = CurrentThemeColor
SortActionBtn.Font = Enum.Font.GothamBold
SortActionBtn.TextSize = 10
SortActionBtn.Parent = SortRow
Instance.new("UICorner", SortActionBtn).CornerRadius = UDim.new(0, 4)
table.insert(themeUpdateObjects, SortActionBtn)

local windowSortOrderArray = {"Combat", "Render", "Utility", "World", "Inventory", "Minigames", "Other"}

trackedConnect(SortActionBtn.MouseButton1Click, function()
    local startX = LeftPanel.Position.X.Offset + LeftPanel.Size.X.Offset + 15
    local currentX = startX
    local currentY = LeftPanel.Position.Y.Offset
    local rowSpacingHeight = 320 
    local totalMaxScreenWidthBound = Camera.ViewportSize.X

    for _, windowName in ipairs(windowSortOrderArray) do
        local win = windowMapping[windowName]
        if win and win.Visible then
            if currentX + win.Size.X.Offset > totalMaxScreenWidthBound - 30 then
                currentX = startX
                currentY = currentY + rowSpacingHeight
            end
            
            win.Position = UDim2.new(LeftPanel.Position.X.Scale, currentX, LeftPanel.Position.Y.Scale, currentY)
            currentX = currentX + win.Size.X.Offset + 15
        end
    end
end)

--------------------------------------------------------------------------------
-- LIFECYCLE MANAGEMENT SECTOR
--------------------------------------------------------------------------------
local LifecycleArea = Instance.new("Frame")
LifecycleArea.Size = UDim2.new(1, 0, 0, 70) 
LifecycleArea.BackgroundTransparency = 1
LifecycleArea.Parent = SettingsPage

local DestroyRow = Instance.new("Frame")
DestroyRow.Size = UDim2.new(1, 0, 0, 32)
DestroyRow.BackgroundTransparency = 1
DestroyRow.Position = UDim2.new(0, 0, 0, 0)
DestroyRow.Parent = LifecycleArea

local DestroyBtn = Instance.new("TextButton")
DestroyBtn.Name = "MatchThemeActionBtn"
DestroyBtn.Size = UDim2.new(1, -30, 0, 24) 
DestroyBtn.Position = UDim2.new(0, 15, 0, 4)
DestroyBtn.BackgroundColor3 = Color3.fromRGB(26, 22, 22)
DestroyBtn.Text = "DESTROY"
DestroyBtn.TextColor3 = CurrentThemeColor
DestroyBtn.Font = Enum.Font.GothamMedium 
DestroyBtn.TextSize = 11
DestroyBtn.Parent = DestroyRow

local DestroyCorner = Instance.new("UICorner", DestroyBtn)
DestroyCorner.CornerRadius = UDim.new(0, 4)
local DestroyStroke = Instance.new("UIStroke", DestroyBtn)
DestroyStroke.Thickness = 1
DestroyStroke.Color = CurrentThemeColor
table.insert(themeUpdateObjects, DestroyBtn)

local ReInjectRow = Instance.new("Frame")
ReInjectRow.Size = UDim2.new(1, 0, 0, 32)
ReInjectRow.BackgroundTransparency = 1
ReInjectRow.Position = UDim2.new(0, 0, 0, 34)
ReInjectRow.Parent = LifecycleArea

local ReInjectBtn = Instance.new("TextButton")
ReInjectBtn.Name = "MatchThemeActionBtn"
ReInjectBtn.Size = UDim2.new(1, -30, 0, 24) 
ReInjectBtn.Position = UDim2.new(0, 15, 0, 4)
ReInjectBtn.BackgroundColor3 = Color3.fromRGB(22, 26, 24)
ReInjectBtn.Text = "REINJECT"
ReInjectBtn.TextColor3 = CurrentThemeColor
ReInjectBtn.Font = Enum.Font.GothamMedium 
ReInjectBtn.TextSize = 11
ReInjectBtn.Parent = ReInjectRow

local ReInjectCorner = Instance.new("UICorner", ReInjectBtn)
ReInjectCorner.CornerRadius = UDim.new(0, 4)
local ReInjectStroke = Instance.new("UIStroke", ReInjectBtn)
ReInjectStroke.Thickness = 1
ReInjectStroke.Color = CurrentThemeColor
table.insert(themeUpdateObjects, ReInjectBtn)

trackedConnect(DestroyBtn.MouseButton1Click, function()
    initiateScriptSelfDestruct()
end)

local ScriptSourceBackupString = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/your-repo-here/main.lua"))()]]

trackedConnect(ReInjectBtn.MouseButton1Click, function()
    local rawSourceString = nil
    local success, currentScript = pcall(function() return getfenv(0).script end)
    if success and currentScript and currentScript:IsA("LuaSourceContainer") then
        rawSourceString = currentScript.Source
    end
    
    if rawSourceString and rawSourceString ~= "" then
        local reexecuteClosure, compileError = loadstring(rawSourceString)
        if reexecuteClosure then
            initiateScriptSelfDestruct() 
            task.wait(0.1)
            task.spawn(reexecuteClosure)
            return
        end
    end
    
    local fallbackClosure, err = loadstring(ScriptSourceBackupString)
    if fallbackClosure then
        initiateScriptSelfDestruct()
        task.wait(0.1)
        task.spawn(fallbackClosure)
    else
        warn("[ShashelWare Lifecycles Re-entry Fault]: Execution registry was rejected.")
    end
end)

--------------------------------------------------------------------------------
-- VISUAL CUSTOMIZATION SECTION
--------------------------------------------------------------------------------
local LayoutSectionWrapper = Instance.new("Frame")
LayoutSectionWrapper.Size = UDim2.new(1, 0, 0, 75)
LayoutSectionWrapper.BackgroundTransparency = 1
LayoutSectionWrapper.Parent = SettingsPage

local ThemeListLayout = Instance.new("UIListLayout")
ThemeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ThemeListLayout.Parent = LayoutSectionWrapper

local ColorRow = Instance.new("Frame")
ColorRow.Size = UDim2.new(1, 0, 0, 70)
ColorRow.BackgroundTransparency = 1
ColorRow.LayoutOrder = 1
ColorRow.Parent = LayoutSectionWrapper

local ColorLabel = Instance.new("TextLabel")
ColorLabel.Size = UDim2.new(1, -20, 0, 20)
ColorLabel.Position = UDim2.new(0, 15, 0, 4)
ColorLabel.BackgroundTransparency = 1
ColorLabel.Text = "UI Theme Palette"
ColorLabel.TextColor3 = VAPE_TEXT_COLOR
ColorLabel.Font = Enum.Font.GothamMedium
ColorLabel.TextSize = 11
ColorLabel.TextXAlignment = Enum.TextXAlignment.Left
ColorLabel.Parent = ColorRow

local ColorContainer = Instance.new("ScrollingFrame")
ColorContainer.Size = UDim2.new(1, -30, 0, 36)
ColorContainer.Position = UDim2.new(0, 15, 0, 26)
ColorContainer.BackgroundTransparency = 1
ColorContainer.BorderSizePixel = 0
ColorContainer.ScrollBarThickness = 2
ColorContainer.CanvasSize = UDim2.new(0, 200, 0, 0)
ColorContainer.Parent = ColorRow

local ColorLayout = Instance.new("UIListLayout")
ColorLayout.FillDirection = Enum.FillDirection.Horizontal
ColorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ColorLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ColorLayout.Padding = UDim.new(0, 5)
ColorLayout.Parent = ColorContainer

local SpeedSliderFrame = Instance.new("Frame")
SpeedSliderFrame.Size = UDim2.new(1, 0, 0, 44)
SpeedSliderFrame.BackgroundTransparency = 1
SpeedSliderFrame.LayoutOrder = 2
SpeedSliderFrame.Visible = false
SpeedSliderFrame.Parent = LayoutSectionWrapper

local function setRainbowConfigState(enabled)
    Settings.RainbowMode = enabled
    SpeedSliderFrame.Visible = enabled
    if enabled then
        LayoutSectionWrapper.Size = UDim2.new(1, 0, 0, 120)
    else
        LayoutSectionWrapper.Size = UDim2.new(1, 0, 0, 75)
    end
end

local function createThemeOption(color, isRainbow)
    local Option = Instance.new("TextButton")
    Option.Size = UDim2.new(0, 18, 0, 18)
    Option.Text = ""
    Option.Parent = ColorContainer
    Instance.new("UICorner", Option).CornerRadius = UDim.new(1, 0)
    
    if isRainbow then
        local Gradient = Instance.new("UIGradient")
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 255))
        })
        Gradient.Parent = Option
        trackedConnect(Option.MouseButton1Click, function() setRainbowConfigState(true) end)
    else
        Option.BackgroundColor3 = color
        trackedConnect(Option.MouseButton1Click, function()
            setRainbowConfigState(false)
            updateUITheme(color)
        end)
    end
end

createThemeOption(Color3.fromRGB(46, 139, 107), false)  
createThemeOption(Color3.fromRGB(211, 47, 47), false)   
createThemeOption(Color3.fromRGB(123, 31, 162), false)  
createThemeOption(Color3.fromRGB(255, 255, 255), false)  
createThemeOption(Color3.fromRGB(0, 170, 255), false)   
createThemeOption(Color3.fromRGB(255, 105, 180), false)  
createThemeOption(Color3.fromRGB(255, 140, 0), false)   
createThemeOption(nil, true)                            

local inlineContainer = Instance.new("Frame")
inlineContainer.Size = UDim2.new(1, -10, 1, 0)
inlineContainer.BackgroundTransparency = 1
inlineContainer.Parent = SpeedSliderFrame

attachInnerSlider(inlineContainer, "Rainbow Speed", 0.1, 5, Settings.RainbowSpeed, 0, function(v) Settings.RainbowSpeed = v end)

--------------------------------------------------------------------------------
-- SIDEBAR NAVIGATION & AUTO-POSITIONING HOOK
--------------------------------------------------------------------------------
local categoryButtons = {}

local function calculateAutomaticTabPlacement()
    local rightmostEdge = LeftPanel.Position.X.Offset + LeftPanel.Size.X.Offset
    return UDim2.new(LeftPanel.Position.X.Scale, rightmostEdge + 15, LeftPanel.Position.Y.Scale, LeftPanel.Position.Y.Offset)
end

local function addCategory(name)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 36)
    Button.BorderSizePixel = 0
    Button.Text = "     " .. name
    Button.TextXAlignment = Enum.TextXAlignment.Left
    Button.TextColor3 = VAPE_TEXT_COLOR
    Button.Font = Enum.Font.GothamMedium
    Button.BackgroundTransparency = 1
    Button.Parent = CategoryScroll
    
    categoryButtons[name] = Button
    table.insert(themeUpdateObjects, Button)

    local associatedWindow = windowMapping[name]

    trackedConnect(Button.MouseButton1Click, function()
        if associatedWindow then
            local targetState = not associatedWindow.Visible
            savedTabStates[name] = targetState 
            associatedWindow.Visible = targetState
            
            if targetState then
                associatedWindow.Position = calculateAutomaticTabPlacement()
                Button.Name = "ActiveCategory"
                Button.TextColor3 = CurrentThemeColor
                Button.Font = Enum.Font.GothamBold
            else
                Button.Name = "CategoryBtn"
                Button.TextColor3 = VAPE_TEXT_COLOR
                Button.Font = Enum.Font.GothamMedium
            end
        end
    end)
end

addCategory("Combat")
addCategory("Render")
addCategory("Utility")
addCategory("World")
addCategory("Inventory")
addCategory("Minigames")
addCategory("Other")

trackedConnect(SettingsButton.MouseButton1Click, function()
    isMainPanelInSettingsMode = not isMainPanelInSettingsMode
    if isMainPanelInSettingsMode then
        SettingsButton.TextColor3 = CurrentThemeColor
        CategoryScroll.Visible = false
        SettingsPage.Visible = true
    else
        SettingsButton.TextColor3 = Color3.fromRGB(100, 100, 100)
        SettingsPage.Visible = false
        CategoryScroll.Visible = true
    end
end)

--------------------------------------------------------------------------------
-- VECTOR WORLD CALCULATORS
--------------------------------------------------------------------------------
local FOVCircle = Instance.new("Frame")
FOVCircle.Size = UDim2.new(0, Settings.FOV * 2, 0, Settings.FOV * 2)
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundColor3 = VAPE_BRAND_GREEN
FOVCircle.BackgroundTransparency = 1 
FOVCircle.Visible = false 
FOVCircle.Parent = ScreenGui

local CircleCorner = Instance.new("UICorner", FOVCircle)
CircleCorner.CornerRadius = UDim.new(1, 0)
local CircleStroke = Instance.new("UIStroke", FOVCircle)
CircleStroke.Thickness = 1
CircleStroke.Transparency = 0.5
table.insert(themeUpdateObjects, CircleStroke)

local function checkWallVisibility(targetPart)
    if not Settings.WallCheck then return true end
    if targetPart.Position.Magnitude < 5 then return false end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true 
    
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    
    return raycastResult == nil
end

local function getClosestTargetToMouse()
    if not Settings.Enabled then return nil end
    local closestTarget = nil
    local maxDistance = Settings.FOV
    local mousePosition = UserInputService:GetMouseLocation()
    local realMousePos = Vector2.new(mousePosition.X, mousePosition.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local head = character:FindFirstChild("Head")
            local root = character:FindFirstChild("HumanoidRootPart")

            if head and root and humanoid and humanoid.Health > 0 and root.Position.Magnitude > 5 then
                if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then continue end

                local screenPosition, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local distanceToMouse = (Vector2.new(screenPosition.X, screenPosition.Y) - realMousePos).Magnitude
                    if distanceToMouse < maxDistance and checkWallVisibility(head) then
                        closestTarget = head
                        maxDistance = distanceToMouse
                    end
                end
            end
        end
    end
    return closestTarget
end

local function forceSyncCameraAngles()
    local x, y, z = Camera.CFrame:ToOrientation()
    pcall(function()
        local controller = LocalPlayer.Controls:GetActiveController()
        if controller and controller.SetCameraAngles then
            controller:SetCameraAngles(Vector2.new(x, y))
        end
    end)
end

trackedConnect(UserInputService.InputBegan, function(input, gameProcessed)
    if getgenv().ShashelWareRunningUUID ~= CurrentScriptUUID then return end
    
    local activeInputTarget = (input.UserInputType == Enum.UserInputType.Keyboard) and input.KeyCode or input.UserInputType
    if not gameProcessed and macroBindsRegistry[activeInputTarget] then
        macroBindsRegistry[activeInputTarget]()
    end

    if isBinding or isBindingUIKey or isBindingMTPKey then return end
    if gameProcessed then return end
    
    if input.KeyCode == Settings.ToggleUIKey then
        menuInterfaceVisibilityState = not menuInterfaceVisibilityState
        LeftPanel.Visible = menuInterfaceVisibilityState
        
        for name, window in pairs(windowMapping) do
            if not menuInterfaceVisibilityState then
                window.Visible = false
            else
                window.Visible = savedTabStates[name]
                local btn = categoryButtons[name]
                if btn then
                    if savedTabStates[name] then
                        btn.Name = "ActiveCategory"
                        btn.TextColor3 = CurrentThemeColor
                        btn.Font = Enum.Font.GothamBold
                    else
                        btn.Name = "CategoryBtn"
                        btn.TextColor3 = VAPE_TEXT_COLOR
                        btn.Font = Enum.Font.GothamMedium
                    end
                end
            end
        end
        FOVCircle.Visible = (menuInterfaceVisibilityState and Settings.FOVEnabled)
    end

    if input.UserInputType == Settings.AimKey or input.KeyCode == Settings.AimKey then
        isAiming = true
        currentTarget = getClosestTargetToMouse()
    end

    if Settings.MouseTP and (input.KeyCode == Settings.MouseTPKey or input.UserInputType == Settings.MouseTPKey) then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local mouseRay = Camera:ViewportPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {char}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local result = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
            if result then root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0)) end
        end
    end
end)

trackedConnect(UserInputService.InputEnded, function(input)
    if getgenv().ShashelWareRunningUUID ~= CurrentScriptUUID then return end
    if not isBinding and not isBindingUIKey and not isBindingMTPKey and (input.UserInputType == Settings.AimKey or input.KeyCode == Settings.AimKey) then
        isAiming = false
        currentTarget = nil
        forceSyncCameraAngles() 
    end
end)

trackedConnect(UserInputService.JumpRequest, function()
    if getgenv().ShashelWareRunningUUID ~= CurrentScriptUUID then return end
    if Settings.InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Initialize elements
LeftPanel.Visible = false
CombatWindow.Visible = false
CombatWindow.Position = calculateAutomaticTabPlacement()
categoryButtons["Combat"].Name = "ActiveCategory"
categoryButtons["Combat"].TextColor3 = CurrentThemeColor
categoryButtons["Combat"].Font = Enum.Font.GothamBold

Camera.FieldOfView = Settings.CameraFOV
updateUITheme(CurrentThemeColor)

-- Fire Load Alert Banner
showNotification("ShashelWare Loaded!", 3.5)

-- Listen for dynamic Workspace context edits to retain runtime Xray states
trackedConnect(workspace.DescendantAdded, function(p)
    if Settings.Xray and p:IsA("BasePart") and not p:IsDescendantOf(LocalPlayer.Character) and not p.Parent:FindFirstChildOfClass("Humanoid") then
        OriginalTransparencyCache[p] = p.Transparency
        p.Transparency = Settings.XrayTransparency
    end
end)

--------------------------------------------------------------------------------
-- RUNTIME STEADY-STATE TICK LOOPS
--------------------------------------------------------------------------------
trackedConnect(RunService.RenderStepped, function(deltaTime)
    if getgenv().ShashelWareRunningUUID ~= CurrentScriptUUID then return end

    local mousePosition = UserInputService:GetMouseLocation()
    if FOVCircle and FOVCircle.Parent then
        FOVCircle.Position = UDim2.new(0, mousePosition.X, 0, mousePosition.Y)
    end

    if Settings.RainbowMode then
        rainbowHue = (rainbowHue + (deltaTime * (Settings.RainbowSpeed * 0.1))) % 1
        updateUITheme(Color3.fromHSV(rainbowHue, 1, 1))
    end

    local MyChar = LocalPlayer.Character
    local MyRoot = MyChar and MyChar:FindFirstChild("HumanoidRootPart")
    local MyHum = MyChar and MyChar:FindFirstChildOfClass("Humanoid")

    if Settings.Noclip and MyChar then
        for _, part in ipairs(MyChar:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end

    if Settings.Flight and MyRoot and MyHum then
        local flyDirection = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyDirection = flyDirection + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyDirection = flyDirection - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyDirection = flyDirection - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyDirection = flyDirection + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyDirection = flyDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyDirection = flyDirection - Vector3.new(0, 1, 0) end
        MyRoot.Velocity = flyDirection.Magnitude > 0 and flyDirection.Unit * Settings.FlightSpeed or Vector3.new(0, 0, 0)
    end

    if Settings.Speed and MyRoot and MyHum and MyHum.MoveDirection.Magnitude > 0 then
        if Settings.SpeedMode == "Normal" then
            MyHum.WalkSpeed = Settings.SpeedValue
        elseif Settings.SpeedMode == "CFrame" then
            MyHum.WalkSpeed = 16
            MyRoot.CFrame = MyRoot.CFrame + (MyHum.MoveDirection * (Settings.SpeedValue / 100))
        elseif Settings.SpeedMode == "TP" then
            MyHum.WalkSpeed = 16
            MyRoot.CFrame = MyRoot.CFrame + (MyHum.MoveDirection * (Settings.SpeedValue * deltaTime))
        end
    end

    if Settings.Spinbot and MyRoot then
        local currentX, currentY, currentZ = MyRoot.CFrame:ToOrientation()
        local newY = (currentY + math.rad(Settings.SpinbotSpeed * deltaTime * 20)) % (math.pi * 2)
        MyRoot.CFrame = CFrame.new(MyRoot.CFrame.Position) * CFrame.fromOrientation(currentX, newY, currentZ)
    end

    -- FREECAM PROCESSING BLOCK
    if freecamActive and freecamPart then
        local camDirection = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then camDirection = camDirection + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then camDirection = camDirection - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then camDirection = camDirection - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then camDirection = camDirection + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then camDirection = camDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then camDirection = camDirection - Vector3.new(0, 1, 0) end
        
        freecamPart.CFrame = freecamPart.CFrame + (camDirection * (Settings.FreecamSpeed * deltaTime))
    end

    -- AIM ASSIST SYSTEM
    if isAiming and Settings.Enabled and not isBinding and not isBindingUIKey and not isBindingMTPKey then
        if currentTarget and currentTarget.Parent and currentTarget.Parent:FindFirstChildOfClass("Humanoid") and currentTarget.Parent:FindFirstChildOfClass("Humanoid").Health > 0 and checkWallVisibility(currentTarget) then
            local targetLookCFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Position)
            local targetX, targetY, targetZ = targetLookCFrame:ToOrientation()
            local currentX, currentY, currentZ = Camera.CFrame:ToOrientation()
            local outputX = math.rad(math.clamp(math.deg(currentX) + (math.deg(targetX) - math.deg(currentX)) * Settings.Smoothness, -89, 89))
            local outputY = math.rad(math.clamp(math.deg(currentY) + (math.deg(targetY) - math.deg(currentY)) * Settings.Smoothness, -180, 180))
            Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.fromOrientation(outputX, outputY, 0)
        else
            currentTarget = nil
            forceSyncCameraAngles()
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if char and head and root and hum and hum.Health > 0 and root.Position.Magnitude > 5 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                local targetRenderColor = CurrentThemeColor
                local isTeammate = false

                if player.Team and LocalPlayer.Team then
                    if player.Team == LocalPlayer.Team then
                        isTeammate = true
                        targetRenderColor = Color3.fromRGB(0, 220, 120) 
                    else
                        targetRenderColor = player.TeamColor.Color 
                    end
                elseif player.TeamColor and not (#Teams:GetTeams() == 0) then
                    targetRenderColor = player.TeamColor.Color
                end

                if Settings.Chams then
                    if not ActiveHighlights[player] then
                        local hl = Instance.new("Highlight")
                        hl.Name = "ShashelCham"
                        hl.FillTransparency = 0.4
                        hl.OutlineTransparency = 0
                        hl.Adornee = char
                        hl.Parent = ScreenGui
                        ActiveHighlights[player] = hl
                    end
                    ActiveHighlights[player].FillColor = targetRenderColor
                    ActiveHighlights[player].OutlineColor = targetRenderColor
                    ActiveHighlights[player].Adornee = char
                else
                    if ActiveHighlights[player] then ActiveHighlights[player]:Destroy(); ActiveHighlights[player] = nil end
                end

                if Settings.ESP and onScreen then
                    local headWorld = head.Position + Vector3.new(0, 1.5, 0)
                    local legWorld = root.Position - Vector3.new(0, 3, 0)
                    local headScreen = Camera:WorldToViewportPoint(headWorld)
                    local legScreen = Camera:WorldToViewportPoint(legWorld)

                    local boxHeight = math.abs(headScreen.Y - legScreen.Y)
                    local boxWidth = boxHeight / 1.5

                    if not ActiveBoxes[player] then
                        local boxFrame = Instance.new("Frame")
                        boxFrame.BackgroundTransparency = 1
                        boxFrame.BorderSizePixel = 0
                        boxFrame.Parent = ScreenGui
                        local stroke = Instance.new("UIStroke")
                        stroke.Name = "Stroke"
                        stroke.Thickness = 1.5
                        stroke.Parent = boxFrame
                        ActiveBoxes[player] = boxFrame
                    end
                    
                    ActiveBoxes[player].Visible = true
                    ActiveBoxes[player].Size = UDim2.new(0, boxWidth, 0, boxHeight)
                    ActiveBoxes[player].Position = UDim2.new(0, headScreen.X - (boxWidth / 2), 0, headScreen.Y)
                    ActiveBoxes[player].Stroke.Color = targetRenderColor
                else
                    if ActiveBoxes[player] then ActiveBoxes[player].Visible = false end
                end

                if Settings.Nametags then
                    if not ActiveBillboards[player] then
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 200, 0, 50)
                        bb.AlwaysOnTop = true
                        bb.StudsOffset = Vector3.new(0, 2.5, 0)
                        bb.Adornee = head
                        bb.Parent = ScreenGui

                        local label = Instance.new("TextLabel")
                        label.Name = "TagLabel"
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamBold
                        label.TextSize = 12
                        label.Parent = bb
                        ActiveBillboards[player] = bb
                    end
                    
                    local tagPrefix = isTeammate and "[TEAM] " or ""
                    ActiveBillboards[player].TagLabel.Text = tagPrefix .. player.Name .. " [" .. math.round(hum.Health) .. "]"
                    ActiveBillboards[player].TagLabel.TextColor3 = targetRenderColor
                    ActiveBillboards[player].Adornee = head
                else
                    if ActiveBillboards[player] then ActiveBillboards[player]:Destroy(); ActiveBillboards[player] = nil end
                end

                if Settings.Tracers and onScreen then
                    if not ActiveTracers[player] then
                        local tracerLine = Instance.new("Frame")
                        tracerLine.BorderSizePixel = 0
                        tracerLine.AnchorPoint = Vector2.new(0.5, 0.5)
                        tracerLine.Parent = ScreenGui
                        ActiveTracers[player] = tracerLine
                    end

                    local startX = Camera.ViewportSize.X / 2
                    local startY = Camera.ViewportSize.Y
                    local endX = screenPos.X
                    local endY = screenPos.Y

                    local distance = math.sqrt((endX - startX)^2 + (endY - startY)^2)
                    local angle = math.deg(math.atan2(endY - startY, endX - startX))

                    local tracer = ActiveTracers[player]
                    tracer.Visible = true
                    tracer.BackgroundColor3 = targetRenderColor
                    tracer.Size = UDim2.new(0, distance, 0, 1.5)
                    tracer.Position = UDim2.new(0, (startX + endX) / 2, 0, (startY + endY) / 2)
                    tracer.Rotation = angle
                else
                    if ActiveTracers[player] then ActiveTracers[player].Visible = false end
                end
            else
                if ActiveBoxes[player] then ActiveBoxes[player].Visible = false end
                if ActiveHighlights[player] then ActiveHighlights[player]:Destroy(); ActiveHighlights[player] = nil end
                if ActiveBillboards[player] then ActiveBillboards[player]:Destroy(); ActiveBillboards[player] = nil end
                if ActiveTracers[player] then ActiveTracers[player].Visible = false end
            end
        end
    end
end)

trackedConnect(Players.PlayerRemoving, function(player)
    if ActiveBoxes[player] then ActiveBoxes[player]:Destroy(); ActiveBoxes[player] = nil end
    if ActiveHighlights[player] then ActiveHighlights[player]:Destroy(); ActiveHighlights[player] = nil end
    if ActiveBillboards[player] then ActiveBillboards[player]:Destroy(); ActiveBillboards[player] = nil end
    if ActiveTracers[player] then ActiveTracers[player]:Destroy(); ActiveTracers[player] = nil end
end)
