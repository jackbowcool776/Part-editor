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
-- =====================
-- =====================
-- PART EDITOR PILL
-- =====================
local Pill = newFrame(gui, UDim2.new(0,180,0,38), UDim2.new(0,20,0.5,-48), C.bg, 10)
newStroke(Pill, Color3.fromRGB(50,50,70), 1.5)
makeDraggable(Pill)

local PillBtn = newBtn(Pill, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    "✏️  Part Editor: OFF", C.bg, 11)
PillBtn.TextColor3 = C.sub

-- =====================
-- EDIT PANEL
-- =====================
local EditPanel = newFrame(gui, UDim2.new(0,270,0,400), UDim2.new(0,210,0.5,-200), C.bg, 20)
EditPanel.Visible = false
EditPanel.Active = true  -- blocks clicks from passing through
newStroke(EditPanel, C.accent, 1.5)

-- Title bar (draggable handle)
local EPBar = Instance.new("Frame")
EPBar.Size = UDim2.new(1,0,0,36)
EPBar.Position = UDim2.new(0,0,0,0)
EPBar.BackgroundColor3 = C.panel
EPBar.BorderSizePixel = 0
EPBar.ZIndex = 21
EPBar.Parent = EditPanel
local epc = Instance.new("UICorner") epc.CornerRadius = UDim.new(0,12) epc.Parent = EPBar
makeDraggable(EditPanel, EPBar)

local EPTitle = newLabel(EPBar, UDim2.new(1,-46,1,0), UDim2.new(0,10,0,0),
    "Part Editor", C.accent, Enum.Font.GothamBlack, 13, 22)

newBtn(EPBar, UDim2.new(0,26,0,26), UDim2.new(1,-32,0,5),
    "X", C.red, 22, function()
        EditPanel.Visible = false
        clearAll()
    end)

-- Part name
local EPPartName = newLabel(EditPanel, UDim2.new(1,-16,0,18),
    UDim2.new(0,8,0,42), "No part selected", C.sub, Enum.Font.Gotham, 11, 21)

-- ── SELECT MODE ──
newSectionLabel(EditPanel, 64, "SELECT MODE", 21)

local selSingleBtn = newBtn(EditPanel, UDim2.new(0.5,-6,0,28), UDim2.new(0,6,0,80),
    "Single", C.blue, 22)
local selMultiBtn  = newBtn(EditPanel, UDim2.new(0.5,-6,0,28), UDim2.new(0.5,2,0,80),
    "Multi", C.row, 22)

selSingleBtn.MouseButton1Click:Connect(function()
    selectMode = "single"
    clearAll()
    EditPanel.Visible = false
    selSingleBtn.BackgroundColor3 = C.blue
    selMultiBtn.BackgroundColor3  = C.row
    notify("Part Editor", "Single Select")
end)
selMultiBtn.MouseButton1Click:Connect(function()
    selectMode = "multi"
    clearAll()
    EditPanel.Visible = false
    selSingleBtn.BackgroundColor3 = C.row
    selMultiBtn.BackgroundColor3  = C.blue
    notify("Part Editor", "Multi Select")
end)

-- ── TRANSFORM ──
newSectionLabel(EditPanel, 116, "TRANSFORM", 21)

local tmBtns = {}
for i, m in ipairs({"Move","Resize","Rotate"}) do
    local b = newBtn(EditPanel, UDim2.new(0,76,0,26), UDim2.new(0,6+(i-1)*86,0,132),
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

local axColors = {X=Color3.fromRGB(220,60,60), Y=Color3.fromRGB(60,200,60), Z=Color3.fromRGB(60,100,220)}
for i, axis in ipairs({"X","Y","Z"}) do
    local xOff = 6 + (i-1) * 86
    local col = axColors[axis]
    local dim = Color3.fromRGB(col.R*155, col.G*155, col.B*155)

    local function applyAxis(delta)
        for _, p in ipairs(getTargets()) do
            pcall(function()
                if transformMode == "move" then
                    local v = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                    p.CFrame = p.CFrame + v * delta
                elseif transformMode == "resize" then
                    local v = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                    p.Size = Vector3.new(math.max(0.05,p.Size.X+v.X*delta),math.max(0.05,p.Size.Y+v.Y*delta),math.max(0.05,p.Size.Z+v.Z*delta))
                elseif transformMode == "rotate" then
                    local rot = axis=="X" and CFrame.Angles(math.rad(delta*15),0,0) or axis=="Y" and CFrame.Angles(0,math.rad(delta*15),0) or CFrame.Angles(0,0,math.rad(delta*15))
                    p.CFrame = p.CFrame * rot
                end
            end)
        end
    end

    newBtn(EditPanel, UDim2.new(0,76,0,24), UDim2.new(0,xOff,0,164), axis.." +", col, 22, function() applyAxis(stepValue) end)
    newBtn(EditPanel, UDim2.new(0,76,0,24), UDim2.new(0,xOff,0,192), axis.." -", dim, 22, function() applyAxis(-stepValue) end)
end

-- Step size
newSectionLabel(EditPanel, 222, "STEP SIZE (0.1 - 500)", 21)
local StepBox = Instance.new("TextBox")
StepBox.Size = UDim2.new(1,-16,0,28)
StepBox.Position = UDim2.new(0,8,0,238)
StepBox.BackgroundColor3 = C.input StepBox.TextColor3 = C.text
StepBox.Font = Enum.Font.GothamBold StepBox.TextSize = 14
StepBox.Text = "1" StepBox.PlaceholderText = "e.g. 0.5, 1, 10"
StepBox.BorderSizePixel = 0 StepBox.ClearTextOnFocus = false StepBox.ZIndex = 22
StepBox.Parent = EditPanel
Instance.new("UICorner",StepBox).CornerRadius = UDim.new(0,8)
StepBox.Changed:Connect(function(prop)
    if prop ~= "Text" then return end
    local f = StepBox.Text:gsub("[^%d%.]","")
    local d = f:find("%.") if d then f=f:sub(1,d)..f:sub(d+1):gsub("%.","") end
    if f ~= StepBox.Text then StepBox.Text = f end
    local v = tonumber(f) if v then stepValue = math.clamp(v,0.1,500) end
end)
StepBox.FocusLost:Connect(function()
    local v = tonumber(StepBox.Text)
    stepValue = v and math.clamp(v,0.1,500) or stepValue
    StepBox.Text = tostring(stepValue)
end)

-- ── COLOR ──
newSectionLabel(EditPanel, 274, "COLOR", 21)
local colorList = {Color3.fromRGB(163,162,165),Color3.fromRGB(255,80,80),Color3.fromRGB(80,200,80),Color3.fromRGB(80,120,255),Color3.fromRGB(255,200,80),Color3.fromRGB(255,130,255),Color3.fromRGB(255,165,0),Color3.fromRGB(255,255,255)}
for i, col in ipairs(colorList) do
    local cb = Instance.new("TextButton")
    cb.Size=UDim2.new(0,26,0,22) cb.Position=UDim2.new(0,8+((i-1)%8)*31,0,290)
    cb.BackgroundColor3=col cb.Text="" cb.BorderSizePixel=0 cb.ZIndex=22 cb.Parent=EditPanel
    Instance.new("UICorner",cb).CornerRadius=UDim.new(0,4)
    cb.MouseButton1Click:Connect(function()
        for _, p in ipairs(getTargets()) do pcall(function() p.Color=col end) end
    end)
end

-- ── TRANSPARENCY ──
newSectionLabel(EditPanel, 318, "TRANSPARENCY", 21)
for i, tv in ipairs({{0,"Solid"},{0.5,"50%"},{0.9,"Ghost"},{1,"Hidden"}}) do
    newBtn(EditPanel,UDim2.new(0,57,0,24),UDim2.new(0,6+(i-1)*64,0,334),tv[2],C.row,22,function()
        for _, p in ipairs(getTargets()) do pcall(function() p.Transparency=tv[1] end) end
    end)
end

-- ── ACTIONS ──
newBtn(EditPanel,UDim2.new(0.5,-6,0,28),UDim2.new(0,6,0,366),"Reset",C.blue,22,function()
    for _, p in ipairs(getTargets()) do
        if origData[p] then pcall(function() p.Color=origData[p].color p.Transparency=origData[p].trans end) end
    end
end)
newBtn(EditPanel,UDim2.new(0.5,-6,0,28),UDim2.new(0.5,2,0,366),"🗑️ Delete",C.red,22,function()
    local count=0
    for _, p in ipairs(getTargets()) do
        pcall(function()
            for _,v in pairs(p:GetDescendants()) do
                if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ModuleScript") then v:Destroy() end
            end
            p:Destroy() count=count+1
        end)
    end
    clearAll() EditPanel.Visible=false
    notify("Part Editor","Deleted "..count.." part(s)")
end)

-- Pill toggle
-- PillBtn click connected AFTER SpawnPill is declared (see bottom of file)
local function turnOffEditor()
    editorOn = false
    PillBtn.Text = "✏️  Part Editor: OFF"
    PillBtn.TextColor3 = C.sub
    newStroke(Pill, Color3.fromRGB(50,50,70), 1.5)
    clearAll()
    clearHandles()
    hoveredPart = nil
    EditPanel.Visible = false
end

local function turnOnEditor()
    editorOn = true
    PillBtn.Text = "✏️  Part Editor: ON"
    PillBtn.TextColor3 = C.accent
    newStroke(Pill, C.accent, 1.5)
end

-- PART SPAWNER PILL + PANEL
-- =====================
local SpawnPill = newFrame(gui, UDim2.new(0,180,0,38), UDim2.new(0,20,0.5,28), C.bg, 10)
newStroke(SpawnPill, C.sub, 1.5)
makeDraggable(SpawnPill)

local SpawnPillBtn = newBtn(SpawnPill, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    "➕  Part Spawner: OFF", C.bg, 11)
SpawnPillBtn.TextColor3 = C.sub

-- Spawner panel (hidden by default)
local SpawnPanel = newFrame(gui, UDim2.new(0,240,0,310), UDim2.new(0,200,0.5,-155), C.bg, 15)
SpawnPanel.Visible = false
newStroke(SpawnPanel, C.sub, 1.5)

local SPBar = newFrame(SpawnPanel, UDim2.new(1,0,0,36), UDim2.new(0,0,0,0), C.panel, 16)
makeDraggable(SpawnPanel, SPBar)
newLabel(SPBar, UDim2.new(1,-50,1,0), UDim2.new(0,10,0,0),
    "➕ Part Spawner", C.accent, Enum.Font.GothamBlack, 13, 17)
newBtn(SPBar, UDim2.new(0,26,0,26), UDim2.new(1,-32,0,5),
    "X", C.red, 17, function()
        SpawnPanel.Visible = false
        SpawnPillBtn.Text = "➕  Part Spawner: OFF"
        SpawnPillBtn.TextColor3 = C.sub
        newStroke(SpawnPill, C.sub, 1.5)
    end)

local function turnOffSpawner()
    SpawnPanel.Visible = false
    SpawnPillBtn.Text = "➕  Part Spawner: OFF"
    SpawnPillBtn.TextColor3 = C.sub
    newStroke(SpawnPill, C.sub, 1.5)
end

local function turnOnSpawner()
    local pillPos = SpawnPill.AbsolutePosition
    local px = math.min(pillPos.X + SpawnPill.AbsoluteSize.X + 10, Camera.ViewportSize.X - 250)
    local py = math.min(pillPos.Y - 80, Camera.ViewportSize.Y - 320)
    SpawnPanel.Position = UDim2.new(0, px, 0, py)
    SpawnPanel.Visible = true
    SpawnPillBtn.Text = "➕  Part Spawner: ON"
    SpawnPillBtn.TextColor3 = C.accent
    newStroke(SpawnPill, C.accent, 1.5)
end

SpawnPillBtn.MouseButton1Click:Connect(function()
    if SpawnPanel.Visible then
        turnOffSpawner()
    else
        if editorOn then turnOffEditor() end
        turnOnSpawner()
    end
end)

local spawnShape    = "Block"
local spawnColor    = Color3.fromRGB(163,162,165)
local spawnAnchored = true
local spawnSize     = 4

newSectionLabel(SpawnPanel, 42, "SHAPE", 16)
local shapeNames = {"Block","Sphere","Wedge","Cylinder"}
local shapeBtns  = {}
for i, sh in ipairs(shapeNames) do
    local b = newBtn(SpawnPanel,UDim2.new(0,50,0,26),UDim2.new(0,6+(i-1)*56,0,58),
        sh:sub(1,4), C.row, 17)
    b.TextSize = 11
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
local anchorBtn = newBtn(SpawnPanel,UDim2.new(0.5,-6,0,28),UDim2.new(0,6,0,192),
    "Anchored", C.green, 17)
anchorBtn.MouseButton1Click:Connect(function()
    spawnAnchored = not spawnAnchored
    anchorBtn.Text = spawnAnchored and "Anchored" or "Unanchored"
    anchorBtn.BackgroundColor3 = spawnAnchored and C.green or C.orange
end)

newBtn(SpawnPanel,UDim2.new(0.5,-6,0,28),UDim2.new(0.5,2,0,192),
    "Clear All", C.red, 17, function()
        for _, p in pairs(spawnerFolder:GetChildren()) do pcall(function() p:Destroy() end) end
        notify("Part Spawner","Cleared all spawned parts!")
    end)

newBtn(SpawnPanel,UDim2.new(1,-16,0,34),UDim2.new(0,8,0,230),
    "➕  Spawn in Front", C.blue, 17, function()
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

newBtn(SpawnPanel,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,270),
    "Spawn at Camera", Color3.fromRGB(40,80,160), 17, function()
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
        part.CFrame   = Camera.CFrame * CFrame.new(0,0,-10)
        part.Parent   = spawnerFolder
        notify("Part Spawner","Spawned at camera!")
    end)

-- =====================
-- =====================
-- 3D TRANSFORM HANDLES
-- Studio-style arrows (move), rings (rotate), squares (resize)
-- =====================
local handlesFolder = Instance.new("Folder")
handlesFolder.Name = "PartEditorHandles"
handlesFolder.Parent = workspace

local activeHandles = {}
local handleDragging = false
local handleAxis = nil
local handleStartPos = nil
local handleStartCF = nil
local handleStartSize = nil
local handleStartMousePos = nil

local HANDLE_SIZE = 0.4
local HANDLE_LENGTH = 3.5
local ARROW_SIZE = 0.7

local AX_COLORS = {
    X = BrickColor.new("Bright red"),
    Y = BrickColor.new("Lime green"),
    Z = BrickColor.new("Bright blue"),
}
local AX_VECTORS = {
    X = Vector3.new(1,0,0),
    Y = Vector3.new(0,1,0),
    Z = Vector3.new(0,0,1),
}

local function makeHandlePart(parent, name, color, size, cframe)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = true
    p.BrickColor = color
    p.Material = Enum.Material.Neon
    p.Size = size
    p.CFrame = cframe
    p.CastShadow = false
    p.Parent = parent
    return p
end

local function clearHandles()
    for _, h in pairs(activeHandles) do
        pcall(function() h:Destroy() end)
    end
    activeHandles = {}
    handleDragging = false
end

local function buildHandles(target)
    clearHandles()
    if not target or not target.Parent then return end

    local cf = target.CFrame
    local sz = target.Size

    for _, axis in ipairs({"X","Y","Z"}) do
        local col = AX_COLORS[axis]
        local vec = AX_VECTORS[axis]
        local offset = cf:VectorToWorldSpace(vec * (sz * 0.5 + Vector3.new(HANDLE_LENGTH*0.5,HANDLE_LENGTH*0.5,HANDLE_LENGTH*0.5)))

        if transformMode == "move" then
            -- Shaft
            local shaft = makeHandlePart(handlesFolder, "Handle_"..axis,
                col,
                Vector3.new(
                    axis=="X" and HANDLE_LENGTH or HANDLE_SIZE,
                    axis=="Y" and HANDLE_LENGTH or HANDLE_SIZE,
                    axis=="Z" and HANDLE_LENGTH or HANDLE_SIZE
                ),
                CFrame.new(cf.Position + cf:VectorToWorldSpace(vec*(sz/2+Vector3.new(HANDLE_LENGTH/2,HANDLE_LENGTH/2,HANDLE_LENGTH/2))))
            )
            shaft.CFrame = CFrame.new(cf.Position) * (cf - cf.Position) * CFrame.new(vec * (math.max(sz.X,sz.Y,sz.Z)*0.5 + HANDLE_LENGTH*0.5 + 0.5))
            table.insert(activeHandles, shaft)

            -- Arrow tip
            local tip = makeHandlePart(handlesFolder, "HandleTip_"..axis,
                col, Vector3.new(ARROW_SIZE,ARROW_SIZE,ARROW_SIZE),
                shaft.CFrame * CFrame.new(0,0,0)
            )
            tip.CFrame = shaft.CFrame * CFrame.new(
                axis=="X" and HANDLE_LENGTH*0.5 or 0,
                axis=="Y" and HANDLE_LENGTH*0.5 or 0,
                axis=="Z" and HANDLE_LENGTH*0.5 or 0
            )
            tip.Shape = Enum.PartType.Ball
            table.insert(activeHandles, tip)

        elseif transformMode == "resize" then
            -- Square handle at each face
            local sq = makeHandlePart(handlesFolder, "Handle_"..axis,
                col, Vector3.new(ARROW_SIZE,ARROW_SIZE,ARROW_SIZE),
                cf * CFrame.new(vec * (math.max(sz.X,sz.Y,sz.Z)*0.5 + 0.8))
            )
            sq.CFrame = cf * CFrame.new(
                axis=="X" and (sz.X*0.5+0.8) or 0,
                axis=="Y" and (sz.Y*0.5+0.8) or 0,
                axis=="Z" and (sz.Z*0.5+0.8) or 0
            )
            table.insert(activeHandles, sq)

            -- Negative side
            local sqN = makeHandlePart(handlesFolder, "Handle_N"..axis,
                col, Vector3.new(ARROW_SIZE,ARROW_SIZE,ARROW_SIZE),
                cf * CFrame.new(-vec * (math.max(sz.X,sz.Y,sz.Z)*0.5 + 0.8))
            )
            sqN.CFrame = cf * CFrame.new(
                axis=="X" and -(sz.X*0.5+0.8) or 0,
                axis=="Y" and -(sz.Y*0.5+0.8) or 0,
                axis=="Z" and -(sz.Z*0.5+0.8) or 0
            )
            table.insert(activeHandles, sqN)

        elseif transformMode == "rotate" then
            -- Ring of small spheres around each axis
            local radius = math.max(sz.X,sz.Y,sz.Z)*0.5 + 1.2
            local steps = 16
            for s = 0, steps-1 do
                local angle = (s/steps) * math.pi * 2
                local pos
                if axis == "X" then
                    pos = cf * CFrame.new(0, math.cos(angle)*radius, math.sin(angle)*radius)
                elseif axis == "Y" then
                    pos = cf * CFrame.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)
                else
                    pos = cf * CFrame.new(math.cos(angle)*radius, math.sin(angle)*radius, 0)
                end
                local dot = makeHandlePart(handlesFolder, "Handle_"..axis,
                    col, Vector3.new(0.25,0.25,0.25), pos)
                dot.Shape = Enum.PartType.Ball
                table.insert(activeHandles, dot)
            end
        end
    end
end

-- Handle dragging
local handleDragConn = nil

local function getHandleAxis(part)
    if not part or not part.Name:find("Handle_") then return nil end
    local name = part.Name
    local neg = name:find("_N") ~= nil
    local axis = name:sub(-1)
    if axis ~= "X" and axis ~= "Y" and axis ~= "Z" then return nil, nil end
    return axis, neg
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not editorOn then return end
    local target = getTargets()[1]
    if not target then return end

    local hit = Mouse.Target
    local axis, neg = getHandleAxis(hit)
    if not axis then return end

    handleDragging = true
    handleAxis = axis
    handleStartCF = target.CFrame
    handleStartSize = target.Size
    handleStartMousePos = UserInputService:GetMouseLocation()

    if handleDragConn then handleDragConn:Disconnect() end
    handleDragConn = RunService.RenderStepped:Connect(function()
        if not handleDragging then
            handleDragConn:Disconnect() handleDragConn = nil return
        end
        local target2 = getTargets()[1]
        if not target2 then return end

        local curMouse = UserInputService:GetMouseLocation()
        local delta = (curMouse - handleStartMousePos)
        local amount = (axis=="X" and delta.X or axis=="Y" and -delta.Y or delta.X) * 0.05

        pcall(function()
            if transformMode == "move" then
                local v = AX_VECTORS[axis]
                target2.CFrame = handleStartCF + Camera.CFrame:VectorToWorldSpace(
                    Vector3.new(
                        axis=="X" and amount or 0,
                        axis=="Y" and amount or 0,
                        axis=="Z" and amount or 0
                    )
                ) * Vector3.new(0,0,0)
                -- simpler: just move along world axis
                target2.CFrame = handleStartCF + v * amount * (neg and -1 or 1) * 10
            elseif transformMode == "resize" then
                local v = AX_VECTORS[axis]
                local newSize = handleStartSize + v * amount * (neg and -1 or 1) * 10
                target2.Size = Vector3.new(math.max(0.1,newSize.X),math.max(0.1,newSize.Y),math.max(0.1,newSize.Z))
            elseif transformMode == "rotate" then
                local rad = amount * 2
                local rot = axis=="X" and CFrame.Angles(rad,0,0) or axis=="Y" and CFrame.Angles(0,rad,0) or CFrame.Angles(0,0,rad)
                target2.CFrame = handleStartCF * rot
            end
        end)

        buildHandles(target2)
    end)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        handleDragging = false
    end
end)

-- =====================
-- HOVER LOOP
-- =====================
RunService.RenderStepped:Connect(function()
    if not editorOn then
        clearHandles()
        return
    end

    -- Update handles for selected part
    local targets = getTargets()
    if #targets > 0 then
        buildHandles(targets[1])
    else
        clearHandles()
    end

    if dropdownOpen then return end
    local p = rayPart()
    if p and p:IsA("BasePart") and not isCharPart(p) and not p:IsDescendantOf(handlesFolder) then
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
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not editorOn then return end
    if proc then return end  -- proc=true means GUI handled it (Active panels block clicks)

    local p = Mouse.Target
    if not p then
        if selectMode == "single" then
            if singleSel then restoreOrig(singleSel) singleSel = nil end
            EditPanel.Visible = false
            clearHandles()
        end
        return
    end
    if p:IsDescendantOf(gui) then return end
    if p:IsDescendantOf(handlesFolder) then return end -- ignore handle parts

    if selectMode == "single" then
        if singleSel then restoreOrig(singleSel) singleSel = nil end

        if p:IsA("BasePart") and not isCharPart(p) then
            singleSel = p
            saveOrig(p)
            pcall(function() p.Color=C.sel p.Transparency=0.3 end)
            EPPartName.Text = p.Name.." ("..math.floor(p.Size.X).."x"..math.floor(p.Size.Y).."x"..math.floor(p.Size.Z)..")"
            EPTitle.Text = p.Name
            local mp = UserInputService:GetMouseLocation()
            EditPanel.Position = UDim2.new(0,math.min(mp.X+16,Camera.ViewportSize.X-280),0,math.min(mp.Y-16,Camera.ViewportSize.Y-410))
            EditPanel.Visible = true
        else
            EditPanel.Visible = false
        end

    elseif selectMode == "multi" then
        if p:IsA("BasePart") and not isCharPart(p) then
            if isInMulti(p) then
                removeMulti(p)
                if #multiSel == 0 then EditPanel.Visible = false end
            else
                addMulti(p)
                EPTitle.Text = #multiSel.." parts selected"
                EPPartName.Text = "Latest: "..p.Name
                local mp = UserInputService:GetMouseLocation()
                EditPanel.Position = UDim2.new(0,math.min(mp.X+16,Camera.ViewportSize.X-280),0,math.min(mp.Y-16,Camera.ViewportSize.Y-410))
                EditPanel.Visible = true
            end
        end
    end
end)

-- Connect pill button now that all functions are declared
PillBtn.MouseButton1Click:Connect(function()
    if editorOn then
        turnOffEditor()
    else
        turnOffSpawner()
        turnOnEditor()
    end
end)

notify("Part Editor", "Loaded! Click the pills on the left to get started.")
print("[Part Editor v3] Loaded!")
