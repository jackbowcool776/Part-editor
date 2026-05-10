-- Part Editor Script
-- Hover over parts to highlight them, click to edit or delete

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = 3
        })
    end)
end

-- =====================
-- STATE
-- =====================
local editorOn = false
local hoveredPart = nil
local selectedPart = nil
local originalColor = nil
local originalTransparency = nil
local originalMaterial = nil
local HOVER_COLOR = Color3.fromRGB(100, 220, 255)
local HOVER_TRANSPARENCY = 0.3

-- =====================
-- HOVER HIGHLIGHT
-- =====================
local function clearHover()
    if hoveredPart and hoveredPart.Parent then
        pcall(function()
            hoveredPart.Color = originalColor
            hoveredPart.Transparency = originalTransparency
        end)
    end
    hoveredPart = nil
    originalColor = nil
    originalTransparency = nil
end

local function setHover(part)
    if part == hoveredPart then return end
    clearHover()
    if not part or not part:IsA("BasePart") then return end
    -- Don't highlight character parts
    local char = LocalPlayer.Character
    if char and part:IsDescendantOf(char) then return end

    hoveredPart = part
    originalColor = part.Color
    originalTransparency = part.Transparency
    pcall(function()
        part.Color = HOVER_COLOR
        part.Transparency = HOVER_TRANSPARENCY
    end)
end

-- =====================
-- PART MENU GUI
-- =====================
local gui = Instance.new("ScreenGui")
gui.Name = "PartEditor"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
pcall(function() gui.Parent = game:GetService("CoreGui") end)

-- Status label at top of screen
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 300, 0, 30)
StatusLabel.Position = UDim2.new(0.5, -150, 0, 10)
StatusLabel.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
StatusLabel.BackgroundTransparency = 0.2
StatusLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 13
StatusLabel.Text = "Part Editor: OFF"
StatusLabel.BorderSizePixel = 0
StatusLabel.ZIndex = 10
StatusLabel.Visible = true
StatusLabel.Parent = gui
Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 8)

-- Part menu panel (shows when part is clicked)
local Menu = Instance.new("Frame")
Menu.Size = UDim2.new(0, 240, 0, 280)
Menu.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
Menu.BorderSizePixel = 0
Menu.Visible = false
Menu.ZIndex = 20
Menu.Parent = gui
Instance.new("UICorner", Menu).CornerRadius = UDim.new(0, 10)

local MenuStroke = Instance.new("UIStroke")
MenuStroke.Color = Color3.fromRGB(100, 220, 255)
MenuStroke.Thickness = 1.5
MenuStroke.Parent = Menu

local MenuTitle = Instance.new("TextLabel")
MenuTitle.Size = UDim2.new(1, -10, 0, 28)
MenuTitle.Position = UDim2.new(0, 5, 0, 5)
MenuTitle.BackgroundTransparency = 1
MenuTitle.TextColor3 = Color3.fromRGB(100, 220, 255)
MenuTitle.Font = Enum.Font.GothamBlack
MenuTitle.TextSize = 13
MenuTitle.Text = "✏️ Part Editor"
MenuTitle.ZIndex = 21
MenuTitle.Parent = Menu

local MenuClose = Instance.new("TextButton")
MenuClose.Size = UDim2.new(0, 24, 0, 24)
MenuClose.Position = UDim2.new(1, -28, 0, 4)
MenuClose.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
MenuClose.TextColor3 = Color3.fromRGB(255, 255, 255)
MenuClose.Font = Enum.Font.GothamBold
MenuClose.TextSize = 12
MenuClose.Text = "X"
MenuClose.BorderSizePixel = 0
MenuClose.ZIndex = 22
MenuClose.Parent = Menu
Instance.new("UICorner", MenuClose).CornerRadius = UDim.new(0, 6)

-- Part name label
local PartNameLabel = Instance.new("TextLabel")
PartNameLabel.Size = UDim2.new(1, -10, 0, 20)
PartNameLabel.Position = UDim2.new(0, 5, 0, 35)
PartNameLabel.BackgroundTransparency = 1
PartNameLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
PartNameLabel.Font = Enum.Font.Gotham
PartNameLabel.TextSize = 11
PartNameLabel.Text = "Part: None"
PartNameLabel.TextXAlignment = Enum.TextXAlignment.Left
PartNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
PartNameLabel.ZIndex = 21
PartNameLabel.Parent = Menu

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -16, 0, 1)
Divider.Position = UDim2.new(0, 8, 0, 58)
Divider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
Divider.BorderSizePixel = 0
Divider.ZIndex = 21
Divider.Parent = Menu

local function makeMenuBtn(yPos, text, color, fn)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 34)
    btn.Position = UDim2.new(0, 8, 0, yPos)
    btn.BackgroundColor3 = color or Color3.fromRGB(35, 35, 55)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = text
    btn.BorderSizePixel = 0
    btn.ZIndex = 22
    btn.Parent = Menu
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    btn.MouseButton1Click:Connect(fn)
    return btn
end

-- Color picker label
local ColorLabel = Instance.new("TextLabel")
ColorLabel.Size = UDim2.new(1, -16, 0, 16)
ColorLabel.Position = UDim2.new(0, 8, 0, 64)
ColorLabel.BackgroundTransparency = 1
ColorLabel.TextColor3 = Color3.fromRGB(130, 130, 160)
ColorLabel.Font = Enum.Font.GothamBold
ColorLabel.TextSize = 10
ColorLabel.TextXAlignment = Enum.TextXAlignment.Left
ColorLabel.Text = "── COLOR ──"
ColorLabel.ZIndex = 21
ColorLabel.Parent = Menu

-- Color buttons row
local COLORS_LIST = {
    {Color3.fromRGB(255,80,80), "Red"},
    {Color3.fromRGB(80,200,80), "Green"},
    {Color3.fromRGB(80,120,255), "Blue"},
    {Color3.fromRGB(255,200,80), "Yellow"},
    {Color3.fromRGB(255,130,255), "Pink"},
    {Color3.fromRGB(255,165,0), "Orange"},
    {Color3.fromRGB(255,255,255), "White"},
    {Color3.fromRGB(30,30,30), "Black"},
}

for i, colorData in ipairs(COLORS_LIST) do
    local col, name = colorData[1], colorData[2]
    local x = ((i-1) % 4)
    local y = math.floor((i-1) / 4)
    local cb = Instance.new("TextButton")
    cb.Size = UDim2.new(0, 48, 0, 24)
    cb.Position = UDim2.new(0, 8 + x * 54, 0, 82 + y * 28)
    cb.BackgroundColor3 = col
    cb.Text = ""
    cb.BorderSizePixel = 0
    cb.ZIndex = 22
    cb.Parent = Menu
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 5)
    cb.MouseButton1Click:Connect(function()
        if selectedPart and selectedPart.Parent then
            pcall(function() selectedPart.Color = col end)
            notify("Part Editor", "Color set to "..name)
        end
    end)
end

-- Transparency slider label
local TransLabel = Instance.new("TextLabel")
TransLabel.Size = UDim2.new(1, -16, 0, 16)
TransLabel.Position = UDim2.new(0, 8, 0, 142)
TransLabel.BackgroundTransparency = 1
TransLabel.TextColor3 = Color3.fromRGB(130, 130, 160)
TransLabel.Font = Enum.Font.GothamBold
TransLabel.TextSize = 10
TransLabel.TextXAlignment = Enum.TextXAlignment.Left
TransLabel.Text = "── TRANSPARENCY ──"
TransLabel.ZIndex = 21
TransLabel.Parent = Menu

local transValues = {
    {0, "Solid"},
    {0.5, "50%"},
    {0.9, "90%"},
    {1, "Invisible"},
}
for i, tv in ipairs(transValues) do
    local val, label = tv[1], tv[2]
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, 50, 0, 22)
    tb.Position = UDim2.new(0, 8 + (i-1) * 55, 0, 160)
    tb.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    tb.TextColor3 = Color3.fromRGB(220, 220, 220)
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 10
    tb.Text = label
    tb.BorderSizePixel = 0
    tb.ZIndex = 22
    tb.Parent = Menu
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 5)
    tb.MouseButton1Click:Connect(function()
        if selectedPart and selectedPart.Parent then
            pcall(function() selectedPart.Transparency = val end)
        end
    end)
end

-- Action buttons
makeMenuBtn(192, "🔄 Reset Part", Color3.fromRGB(60, 80, 140), function()
    if selectedPart and selectedPart.Parent then
        pcall(function()
            selectedPart.Color = originalColor or Color3.fromRGB(163, 162, 165)
            selectedPart.Transparency = originalTransparency or 0
        end)
        notify("Part Editor", "Part reset!")
    end
end)

makeMenuBtn(232, "🗑️ Delete Part", Color3.fromRGB(180, 40, 40), function()
    if selectedPart and selectedPart.Parent then
        local name = selectedPart.Name
        -- Remove all scripts inside the part first
        for _, v in pairs(selectedPart:GetDescendants()) do
            if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ModuleScript") then
                pcall(function() v:Destroy() end)
            end
        end
        pcall(function() selectedPart:Destroy() end)
        selectedPart = nil
        Menu.Visible = false
        notify("Part Editor", "Deleted: "..name)
    end
end)

MenuClose.MouseButton1Click:Connect(function()
    Menu.Visible = false
    -- Restore selected part appearance
    if selectedPart and selectedPart.Parent then
        if editorOn then
            -- Keep hover if still hovering
        end
    end
    selectedPart = nil
end)

-- =====================
-- MAIN TOGGLE BUTTON
-- =====================
local ToggleFrame = Instance.new("Frame")
ToggleFrame.Size = UDim2.new(0, 160, 0, 36)
ToggleFrame.Position = UDim2.new(0, 20, 0.5, -18)
ToggleFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
ToggleFrame.BorderSizePixel = 0
ToggleFrame.ZIndex = 10
ToggleFrame.Parent = gui
Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", ToggleFrame).Color = Color3.fromRGB(60, 60, 90)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13
ToggleBtn.Text = "✏️ Part Editor: OFF"
ToggleBtn.ZIndex = 11
ToggleBtn.Parent = ToggleFrame

-- Drag toggle frame
local dragging, dragStart, frameStart = false, nil, nil
ToggleFrame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragStart = i.Position frameStart = ToggleFrame.Position
    end
end)
ToggleFrame.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        ToggleFrame.Position = UDim2.new(
            frameStart.X.Scale, frameStart.X.Offset + d.X,
            frameStart.Y.Scale, frameStart.Y.Offset + d.Y
        )
    end
end)

ToggleBtn.MouseButton1Click:Connect(function()
    editorOn = not editorOn
    if editorOn then
        ToggleBtn.Text = "✏️ Part Editor: ON"
        ToggleBtn.TextColor3 = Color3.fromRGB(100, 220, 255)
        StatusLabel.Text = "🖱️ Hover over a part, click to edit"
        StatusLabel.Visible = true
    else
        clearHover()
        Menu.Visible = false
        selectedPart = nil
        ToggleBtn.Text = "✏️ Part Editor: OFF"
        ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        StatusLabel.Visible = false
    end
end)

-- =====================
-- HOVER + CLICK LOGIC
-- =====================
RunService.RenderStepped:Connect(function()
    if not editorOn then return end
    if Menu.Visible then return end -- don't change hover while menu is open

    local unitRay = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local raycastParams = RaycastParams.new()
    local char = LocalPlayer.Character
    if char then
        raycastParams.FilterDescendantsInstances = {char}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    end

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
    if result and result.Instance then
        setHover(result.Instance)
        StatusLabel.Text = "🖱️ "..result.Instance.Name.." — click to edit"
    else
        clearHover()
        StatusLabel.Text = "🖱️ Hover over a part, click to edit"
    end
end)

-- Click to open menu
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not editorOn then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not hoveredPart then return end

    -- Open menu at mouse position
    selectedPart = hoveredPart
    PartNameLabel.Text = "Part: "..selectedPart.Name

    local mousePos = UserInputService:GetMouseLocation()
    local menuX = math.min(mousePos.X + 10, Camera.ViewportSize.X - 250)
    local menuY = math.min(mousePos.Y - 10, Camera.ViewportSize.Y - 290)
    Menu.Position = UDim2.new(0, menuX, 0, menuY)
    Menu.Visible = true

    clearHover()
end)

notify("Part Editor", "Loaded! Toggle with the button on the left.")
print("[Part Editor] Loaded!")
