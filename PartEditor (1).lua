-- Part Editor v3
-- Clean dark theme, no tabs, click part = edit panel opens
-- Dropdown triangle for Single/Multi select

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

local function notify(t, m)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title=t, Text=m, Duration=3})
    end)
end

-- =====================
-- COLORS
-- =====================
local C = {
    bg      = Color3.fromRGB(14, 14, 22),
    panel   = Color3.fromRGB(20, 20, 32),
    row     = Color3.fromRGB(28, 28, 44),
    input   = Color3.fromRGB(22, 22, 36),
    accent  = Color3.fromRGB(100, 220, 255),
    red     = Color3.fromRGB(200, 45, 45),
    green   = Color3.fromRGB(40, 160, 80),
    orange  = Color3.fromRGB(200, 120, 30),
    text    = Color3.fromRGB(220, 220, 230),
    sub     = Color3.fromRGB(110, 110, 140),
    hover   = Color3.fromRGB(100, 220, 255),
    sel     = Color3.fromRGB(255, 200, 60),
    blue    = Color3.fromRGB(40, 100, 200),
}

-- =====================
-- STATE
-- =====================
local editorOn       = false
local selectMode     = "single"
local hoveredPart    = nil
local singleSel      = nil
local multiSel       = {}
local origData       = {}
local stepValue      = 1
local transformMode  = "move"
local dropdownOpen   = false

local spawnerFolder  = Instance.new("Folder")
spawnerFolder.Name   = "SpawnedParts"
spawnerFolder.Parent = workspace

-- =====================
-- GUI ROOT
-- =====================
local gui = Instance.new("ScreenGui")
gui.Name           = "PartEditorV3"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.DisplayOrder   = 50
pcall(function() gui.Parent = game:GetService("CoreGui") end)

-- =====================
-- HELPERS
-- =====================
local function isCharPart(p)
    local c = LocalPlayer.Character
    return c and p:IsDescendantOf(c)
end

local function saveOrig(p)
    if not origData[p] then
        origData[p] = {color = p.Color, trans = p.Transparency}
    end
end

local function restoreOrig(p)
    if origData[p] and p and p.Parent then
        pcall(function()
            p.Color       = origData[p].color
            p.Transparency = origData[p].trans
        end)
        origData[p] = nil
    end
end

local function isInMulti(p)
    for _, v in ipairs(multiSel) do if v == p then return true end end
    return false
end

local function addMulti(p)
    if isInMulti(p) then return end
    saveOrig(p)
    pcall(function() p.Color = C.sel p.Transparency = 0.3 end)
    table.insert(multiSel, p)
end

local function removeMulti(p)
    for i, v in ipairs(multiSel) do
        if v == p then
            restoreOrig(p)
            table.remove(multiSel, i)
            return
        end
    end
end

local function clearAll()
    if singleSel then restoreOrig(singleSel) singleSel = nil end
    for _, p in ipairs(multiSel) do restoreOrig(p) end
    multiSel = {}
end

local function getTargets()
    if selectMode == "single" then
        return singleSel and {singleSel} or {}
    else
        local t = {}
        for _, p in ipairs(multiSel) do table.insert(t, p) end
        return t
    end
end

local function rayPart()
    local ray = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local rp  = RaycastParams.new()
    local ign = {spawnerFolder}
    local ch  = LocalPlayer.Character
    if ch then table.insert(ign, ch) end
    rp.FilterDescendantsInstances = ign
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, rp)
    return res and res.Instance
end

-- =====================
-- DRAG HELPER
-- =====================
local function makeDraggable(frame, handle)
    handle = handle or frame
    local drag, ds, fs = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true ds = i.Position fs = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            frame.Position = UDim2.new(fs.X.Scale, fs.X.Offset + d.X, fs.Y.Scale, fs.Y.Offset + d.Y)
        end
    end)
end

-- =====================
-- UI BUILDERS
-- =====================
local function newFrame(parent, size, pos, color, z)
    local f = Instance.new("Frame")
    f.Size = size f.Position = pos
    f.BackgroundColor3 = color or C.panel
    f.BorderSizePixel = 0 f.ZIndex = z or 10
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
    return f
end

local function newStroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or C.sub s.Thickness = thick or 1.5
    s.Parent = parent return s
end

local function newLabel(parent, size, pos, text, color, font, tsize, z, xalign)
    local l = Instance.new("TextLabel")
    l.Size = size l.Position = pos l.BackgroundTransparency = 1
    l.TextColor3 = color or C.text l.Font = font or Enum.Font.GothamBold
    l.TextSize = tsize or 12 l.Text = text l.ZIndex = z or 11
    l.TextXAlignment = xalign or Enum.TextXAlignment.Left
    l.TextWrapped = true l.Parent = parent return l
end

local function newBtn(parent, size, pos, text, color, z, fn)
    local b = Instance.new("TextButton")
    b.Size = size b.Position = pos b.BackgroundColor3 = color or C.row
    b.TextColor3 = C.text b.Font = Enum.Font.GothamBold b.TextSize = 12
    b.Text = text b.BorderSizePixel = 0 b.ZIndex = z or 12 b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    if fn then b.MouseButton1Click:Connect(fn) end
    return b
end

local function newSectionLabel(parent, y, text, z)
    newLabel(parent, UDim2.new(1,-16,0,14), UDim2.new(0,8,0,y),
        "── "..text.." ──", C.sub, Enum.Font.GothamBold, 9, z or 11)
end

-- =====================
-- MAIN TOGGLE BUTTON (draggable pill)
-- =====================
local Pill = newFrame(gui, UDim2.new(0,170,0,38), UDim2.new(0,20,0.5,-19), C.bg, 10)
newStroke(Pill, C.sub, 1.5)
makeDraggable(Pill)

local PillBtn = newBtn(Pill, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    "✏️  Part Editor: OFF", C.bg, 11)
PillBtn.TextColor3 = C.sub
PillBtn.MouseButton1Click:Connect(function()
    editorOn = not editorOn
    if editorOn then
        PillBtn.Text = "✏️  Part Editor: ON"
        PillBtn.TextColor3 = C.accent
        newStroke(Pill, C.accent, 1.5)
    else
        PillBtn.Text = "✏️  Part Editor: OFF"
        PillBtn.TextColor3 = C.sub
        newStroke(Pill, C.sub, 1.5)
        clearAll()
        hoveredPart = nil
        EditPanel.Visible = false
    end
end)

-- =====================
-- EDIT PANEL (opens on click)
-- Opens right of pill by default, draggable
-- =====================
local EditPanel = newFrame(gui, UDim2.new(0,260,0,340), UDim2.new(0,200,0.5,-170), C.bg, 20)
EditPanel.Visible = false
newStroke(EditPanel, C.accent, 1.5)

-- Title bar (draggable)
local EPBar = newFrame(EditPanel, UDim2.new(1,0,0,36), UDim2.new(0,0,0,0), C.panel, 21)
EPBar.CornerRadius = UDim.new(0,12) -- already done by newFrame
makeDraggable(EditPanel, EPBar)

local EPTitle = newLabel(EPBar, UDim2.new(1,-80,1,0), UDim2.new(0,12,0,0),
    "Selected Part", C.accent, Enum.Font.GothamBlack, 13, 22)

-- Select mode button + dropdown
local ModeBtn = newBtn(EPBar, UDim2.new(0,90,0,26), UDim2.new(1,-136,0,5),
    "Single  ▼", C.row, 22)
ModeBtn.TextSize = 11

-- Close button
local EPClose = newBtn(EPBar, UDim2.new(0,26,0,26), UDim2.new(1,-32,0,5),
    "X", C.red, 22, function()
        EditPanel.Visible = false
        clearAll()
    end)
EPClose.Font = Enum.Font.GothamBlack

-- Dropdown
local Dropdown = newFrame(gui, UDim2.new(0,130,0,70), UDim2.new(0,0,0,0), C.panel, 50)
Dropdown.Visible = false
newStroke(Dropdown, C.accent, 1.5)

local function closeDropdown()
    dropdownOpen = false
    Dropdown.Visible = false
end

local function openDropdown()
    dropdownOpen = true
    -- Position below ModeBtn
    local absPos = ModeBtn.AbsolutePosition
    local absSize = ModeBtn.AbsoluteSize
    Dropdown.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
    Dropdown.Visible = true
end

local function setMode(mode)
    selectMode = mode
    clearAll()
    EditPanel.Visible = false
    if mode == "single" then
        ModeBtn.Text = "Single  ▼"
    else
        ModeBtn.Text = "Multi  ▼"
    end
    closeDropdown()
end

local dSingle = newBtn(Dropdown, UDim2.new(1,-8,0,28), UDim2.new(0,4,0,4),
    "Single Select", C.row, 51, function() setMode("single") end)
local dMulti = newBtn(Dropdown, UDim2.new(1,-8,0,28), UDim2.new(0,4,0,36),
    "Multi Select", C.row, 51, function() setMode("multi") end)

ModeBtn.MouseButton1Click:Connect(function()
    if dropdownOpen then closeDropdown() else openDropdown() end
end)

-- Close dropdown when clicking elsewhere
UserInputService.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and dropdownOpen then
        task.wait()
        closeDropdown()
    end
end)

-- Part name label
local EPPartName = newLabel(EditPanel, UDim2.new(1,-16,0,18),
    UDim2.new(0,8,0,42), "None selected", C.sub, Enum.Font.Gotham, 11, 21)

-- =====================
-- TRANSFORM SECTION
-- =====================
newSectionLabel(EditPanel, 64, "TRANSFORM", 21)

-- Mode row
local tmBtns = {}
for i, m in ipairs({"Move","Resize","Rotate"}) do
    local b = newBtn(EditPanel, UDim2.new(0,72,0,26), UDim2.new(0,6+(i-1)*82,0,80),
        m, C.row, 22)
    b.TextSize = 11
    table.insert(tmBtns, b)
    b.MouseButton1Click:Connect(function()
        transformMode = m:lower()
        for _, mb in ipairs(tmBtns) do mb.BackgroundColor3 = C.row end
        b.BackgroundColor3 = C.blue
    end)
    if m == "Move" then b.BackgroundColor3 = C.blue end
end

-- Axis buttons
local axColors = {
    X = Color3.fromRGB(220,60,60),
    Y = Color3.fromRGB(60,200,60),
    Z = Color3.fromRGB(60,100,220),
}
for i, axis in ipairs({"X","Y","Z"}) do
    local xOff = 6 + (i-1) * 82
    local col = axColors[axis]
    local dimCol = Color3.fromRGB(col.R*155, col.G*155, col.B*155)

    newBtn(EditPanel, UDim2.new(0,72,0,24), UDim2.new(0,xOff,0,112),
        axis.." +", col, 22, function()
            for _, p in ipairs(getTargets()) do
                pcall(function()
                    if transformMode == "move" then
                        local v = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                        p.CFrame = p.CFrame + v * stepValue
                    elseif transformMode == "resize" then
                        local v = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                        p.Size = Vector3.new(math.max(0.05,p.Size.X+v.X*stepValue),math.max(0.05,p.Size.Y+v.Y*stepValue),math.max(0.05,p.Size.Z+v.Z*stepValue))
                    elseif transformMode == "rotate" then
                        local rot = axis=="X" and CFrame.Angles(math.rad(stepValue*15),0,0) or axis=="Y" and CFrame.Angles(0,math.rad(stepValue*15),0) or CFrame.Angles(0,0,math.rad(stepValue*15))
                        p.CFrame = p.CFrame * rot
                    end
                end)
            end
        end)

    newBtn(EditPanel, UDim2.new(0,72,0,24), UDim2.new(0,xOff,0,140),
        axis.." -", dimCol, 22, function()
            for _, p in ipairs(getTargets()) do
                pcall(function()
                    if transformMode == "move" then
                        local v = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                        p.CFrame = p.CFrame - v * stepValue
                    elseif transformMode == "resize" then
                        local v = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                        p.Size = Vector3.new(math.max(0.05,p.Size.X-v.X*stepValue),math.max(0.05,p.Size.Y-v.Y*stepValue),math.max(0.05,p.Size.Z-v.Z*stepValue))
                    elseif transformMode == "rotate" then
                        local rot = axis=="X" and CFrame.Angles(math.rad(-stepValue*15),0,0) or axis=="Y" and CFrame.Angles(0,math.rad(-stepValue*15),0) or CFrame.Angles(0,0,math.rad(-stepValue*15))
                        p.CFrame = p.CFrame * rot
                    end
                end)
            end
        end)
end

-- Step input
newSectionLabel(EditPanel, 170, "STEP SIZE (0.1 - 500)", 21)

local StepBox = Instance.new("TextBox")
StepBox.Size = UDim2.new(1,-16,0,28)
StepBox.Position = UDim2.new(0,8,0,186)
StepBox.BackgroundColor3 = C.input
StepBox.TextColor3 = C.text
StepBox.Font = Enum.Font.GothamBold
StepBox.TextSize = 14
StepBox.Text = "1"
StepBox.PlaceholderText = "e.g. 0.5, 1, 10, 100"
StepBox.BorderSizePixel = 0
StepBox.ClearTextOnFocus = false
StepBox.ZIndex = 22
StepBox.Parent = EditPanel
Instance.new("UICorner", StepBox).CornerRadius = UDim.new(0,8)

StepBox.Changed:Connect(function(prop)
    if prop ~= "Text" then return end
    local filtered = StepBox.Text:gsub("[^%d%.]","")
    -- one decimal point only
    local dot = filtered:find("%.")
    if dot then filtered = filtered:sub(1,dot)..filtered:sub(dot+1):gsub("%.","") end
    if filtered ~= StepBox.Text then StepBox.Text = filtered end
    local v = tonumber(filtered)
    if v then stepValue = math.clamp(v, 0.1, 500) end
end)
StepBox.FocusLost:Connect(function()
    local v = tonumber(StepBox.Text)
    stepValue = v and math.clamp(v,0.1,500) or stepValue
    StepBox.Text = tostring(stepValue)
end)

-- =====================
-- APPEARANCE SECTION
-- =====================
newSectionLabel(EditPanel, 222, "COLOR", 21)

local colorList = {
    Color3.fromRGB(163,162,165), Color3.fromRGB(255,80,80),
    Color3.fromRGB(80,200,80),   Color3.fromRGB(80,120,255),
    Color3.fromRGB(255,200,80),  Color3.fromRGB(255,130,255),
    Color3.fromRGB(255,165,0),   Color3.fromRGB(255,255,255),
}
for i, col in ipairs(colorList) do
    local cb = Instance.new("TextButton")
    cb.Size = UDim2.new(0,24,0,20)
    cb.Position = UDim2.new(0,8+((i-1)%8)*29,0,238)
    cb.BackgroundColor3 = col cb.Text = "" cb.BorderSizePixel = 0 cb.ZIndex = 22
    cb.Parent = EditPanel
    Instance.new("UICorner",cb).CornerRadius = UDim.new(0,4)
    cb.MouseButton1Click:Connect(function()
        for _, p in ipairs(getTargets()) do pcall(function() p.Color = col end) end
    end)
end

newSectionLabel(EditPanel, 264, "TRANSPARENCY", 21)
local tOpts = {{0,"Solid"},{0.5,"50%"},{0.9,"Ghost"},{1,"Hidden"}}
for i, tv in ipairs(tOpts) do
    newBtn(EditPanel,UDim2.new(0,54,0,22),UDim2.new(0,6+(i-1)*60,0,280),
        tv[2], C.row, 22, function()
            for _, p in ipairs(getTargets()) do pcall(function() p.Transparency=tv[1] end) end
        end)
end

-- =====================
-- DELETE / RESET
-- =====================
newBtn(EditPanel,UDim2.new(0.5,-6,0,26),UDim2.new(0,6,0,310),
    "Reset",C.blue,22,function()
        for _, p in ipairs(getTargets()) do
            if origData[p] then
                pcall(function() p.Color=origData[p].color p.Transparency=origData[p].trans end)
            end
        end
    end)

newBtn(EditPanel,UDim2.new(0.5,-6,0,26),UDim2.new(0.5,2,0,310),
    "🗑️ Delete",C.red,22,function()
        local count = 0
        for _, p in ipairs(getTargets()) do
            pcall(function()
                for _, v in pairs(p:GetDescendants()) do
                    if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ModuleScript") then v:Destroy() end
                end
                p:Destroy() count = count + 1
            end)
        end
        clearAll() EditPanel.Visible = false
        notify("Part Editor", "Deleted "..count.." part(s)")
    end)

-- =====================
-- PART SPAWNER PANEL
-- =====================
local SpawnPanel = newFrame(gui, UDim2.new(0,200,0,280), UDim2.new(0,20,0.5,30), C.bg, 15)
newStroke(SpawnPanel, C.sub, 1.5)
makeDraggable(SpawnPanel)

local SPBar = newFrame(SpawnPanel, UDim2.new(1,0,0,36), UDim2.new(0,0,0,0), C.panel, 16)
newLabel(SPBar, UDim2.new(1,-10,1,0), UDim2.new(0,10,0,0),
    "➕ Part Spawner", C.accent, Enum.Font.GothamBlack, 13, 17)

local spawnShape    = "Block"
local spawnColor    = Color3.fromRGB(163,162,165)
local spawnAnchored = true
local spawnSize     = 4

newSectionLabel(SpawnPanel, 42, "SHAPE", 16)
local shapeNames = {"Block","Sphere","Wedge","Cylinder"}
local shapeBtns  = {}
for i, sh in ipairs(shapeNames) do
    local b = newBtn(SpawnPanel,UDim2.new(0,40,0,24),UDim2.new(0,6+(i-1)*46,0,58),
        sh:sub(1,4), C.row, 17)
    b.TextSize = 10
    table.insert(shapeBtns,b)
    b.MouseButton1Click:Connect(function()
        spawnShape = sh
        for _, sb in ipairs(shapeBtns) do sb.BackgroundColor3=C.row end
        b.BackgroundColor3 = C.blue
    end)
    if sh=="Block" then b.BackgroundColor3=C.blue end
end

newSectionLabel(SpawnPanel, 88, "SIZE", 16)
local SizeBox = Instance.new("TextBox")
SizeBox.Size = UDim2.new(1,-16,0,26)
SizeBox.Position = UDim2.new(0,8,0,104)
SizeBox.BackgroundColor3 = C.input SizeBox.TextColor3 = C.text
SizeBox.Font = Enum.Font.GothamBold SizeBox.TextSize = 13
SizeBox.Text = "4" SizeBox.PlaceholderText = "Size (0.1-100)"
SizeBox.BorderSizePixel = 0 SizeBox.ClearTextOnFocus = false SizeBox.ZIndex = 17
SizeBox.Parent = SpawnPanel
Instance.new("UICorner",SizeBox).CornerRadius=UDim.new(0,7)
SizeBox.Changed:Connect(function(p)
    if p~="Text" then return end
    local f=SizeBox.Text:gsub("[^%d%.]","")
    local d=f:find("%.") if d then f=f:sub(1,d)..f:sub(d+1):gsub("%.","") end
    if f~=SizeBox.Text then SizeBox.Text=f end
    local v=tonumber(f) if v then spawnSize=math.clamp(v,0.1,100) end
end)

newSectionLabel(SpawnPanel, 136, "COLOR", 16)
local spawnColors = {
    Color3.fromRGB(163,162,165), Color3.fromRGB(255,80,80),
    Color3.fromRGB(80,200,80),   Color3.fromRGB(80,120,255),
    Color3.fromRGB(255,200,80),  Color3.fromRGB(255,130,255),
    Color3.fromRGB(255,255,255), Color3.fromRGB(30,30,30),
}
local spColorBtns = {}
for i, col in ipairs(spawnColors) do
    local cb = Instance.new("TextButton")
    cb.Size=UDim2.new(0,20,0,18) cb.Position=UDim2.new(0,6+((i-1)%8)*23,0,152)
    cb.BackgroundColor3=col cb.Text="" cb.BorderSizePixel=0 cb.ZIndex=17 cb.Parent=SpawnPanel
    Instance.new("UICorner",cb).CornerRadius=UDim.new(0,4)
    table.insert(spColorBtns,cb)
    cb.MouseButton1Click:Connect(function()
        spawnColor=col
        for _, b in ipairs(spColorBtns) do b.BorderSizePixel=0 end
        cb.BorderSizePixel=2
    end)
end
spColorBtns[1].BorderSizePixel=2

newSectionLabel(SpawnPanel, 176, "OPTIONS", 16)
local anchorBtn = newBtn(SpawnPanel,UDim2.new(0.5,-6,0,26),UDim2.new(0,6,0,192),
    "Anchored", C.green, 17)
anchorBtn.MouseButton1Click:Connect(function()
    spawnAnchored = not spawnAnchored
    anchorBtn.Text = spawnAnchored and "Anchored" or "Unanchored"
    anchorBtn.BackgroundColor3 = spawnAnchored and C.green or C.orange
end)

newBtn(SpawnPanel,UDim2.new(0.5,-6,0,26),UDim2.new(0.5,2,0,192),
    "Clear All", C.red, 17, function()
        for _, p in pairs(spawnerFolder:GetChildren()) do pcall(function() p:Destroy() end) end
        notify("Part Spawner","Cleared all spawned parts!")
    end)

newBtn(SpawnPanel,UDim2.new(1,-16,0,32),UDim2.new(0,8,0,226),
    "➕ Spawn in Front", C.blue, 17, function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then notify("Part Spawner","No character!") return end
        local part
        if spawnShape == "Wedge" then
            part = Instance.new("WedgePart")
        else
            part = Instance.new("Part")
            if spawnShape == "Sphere" then part.Shape = Enum.PartType.Ball
            elseif spawnShape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
        end
        part.Name     = "SpawnedPart"
        part.Size     = Vector3.new(spawnSize,spawnSize,spawnSize)
        part.Color    = spawnColor
        part.Anchored = spawnAnchored
        part.CanCollide = true
        part.CFrame   = root.CFrame * CFrame.new(0,0,-(spawnSize/2+5))
        part.Parent   = spawnerFolder
        notify("Part Spawner", spawnShape.." spawned! Size: "..spawnSize)
    end)

-- =====================
-- HOVER LOOP
-- =====================
RunService.RenderStepped:Connect(function()
    if not editorOn then return end
    if dropdownOpen then return end
    local p = rayPart()
    if p and p:IsA("BasePart") and not isCharPart(p) then
        -- hover highlight
        if p ~= hoveredPart then
            if hoveredPart and hoveredPart ~= singleSel and not isInMulti(hoveredPart) then
                restoreOrig(hoveredPart)
            end
            hoveredPart = p
            if p ~= singleSel and not isInMulti(p) then
                saveOrig(p) pcall(function() p.Color=C.hover p.Transparency=0.35 end)
            end
        end
    else
        if hoveredPart and hoveredPart ~= singleSel and not isInMulti(hoveredPart) then
            restoreOrig(hoveredPart)
        end
        hoveredPart = nil
    end
end)

-- =====================
-- CLICK LOGIC
-- =====================
UserInputService.InputBegan:Connect(function(input, proc)
    if proc then return end
    if not editorOn then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    local p = rayPart()

    if selectMode == "single" then
        -- restore old
        if singleSel then restoreOrig(singleSel) singleSel = nil end

        if p and p:IsA("BasePart") and not isCharPart(p) then
            singleSel = p
            saveOrig(p)
            pcall(function() p.Color=C.sel p.Transparency=0.3 end)

            -- open / update edit panel
            EPPartName.Text = p.Name.." ("..tostring(math.floor(p.Size.X)).."x"..tostring(math.floor(p.Size.Y)).."x"..tostring(math.floor(p.Size.Z))..")"
            EPTitle.Text = p.Name

            -- position panel near click but on screen
            local mp = UserInputService:GetMouseLocation()
            local px = math.min(mp.X + 16, Camera.ViewportSize.X - 270)
            local py = math.min(mp.Y - 16, Camera.ViewportSize.Y - 350)
            EditPanel.Position = UDim2.new(0, px, 0, py)
            EditPanel.Visible = true
        else
            -- clicked sky — close panel
            EditPanel.Visible = false
        end

    elseif selectMode == "multi" then
        if p and p:IsA("BasePart") and not isCharPart(p) then
            if isInMulti(p) then
                removeMulti(p)
                if #multiSel == 0 then EditPanel.Visible = false end
            else
                addMulti(p)
                EPTitle.Text = #multiSel.." parts"
                EPPartName.Text = "Multi-select: "..#multiSel.." part(s)"
                local mp = UserInputService:GetMouseLocation()
                local px = math.min(mp.X+16, Camera.ViewportSize.X-270)
                local py = math.min(mp.Y-16, Camera.ViewportSize.Y-350)
                EditPanel.Position = UDim2.new(0,px,0,py)
                EditPanel.Visible = true
            end
        end
    end
end)

notify("Part Editor", "Loaded! Click the pill to enable, then click any part.")
print("[Part Editor v3] Loaded!")
