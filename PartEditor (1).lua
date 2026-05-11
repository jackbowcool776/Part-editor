-- Part Editor v2
-- Tower Creator style resize/move/rotate + single & multi select

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

local BG     = Color3.fromRGB(14,14,22)
local ACCENT = Color3.fromRGB(100,220,255)
local ROW    = Color3.fromRGB(26,26,40)
local RED    = Color3.fromRGB(200,45,45)
local GREEN  = Color3.fromRGB(40,160,80)
local SELECTED_COLOR = Color3.fromRGB(255,200,60)
local HOVER_COLOR    = Color3.fromRGB(100,220,255)

-- =====================
-- STATE
-- =====================
local editorOn       = false
local selectMode     = "single"
local hoveredPart    = nil
local singleSelected = nil
local selectedParts  = {}
local origData       = {}   -- [part] = {color, transparency}
local stepValue      = 1
local transformMode  = "move"

local spawnerFolder = Instance.new("Folder")
spawnerFolder.Name   = "SpawnedParts"
spawnerFolder.Parent = workspace

-- =====================
-- GUI ROOT
-- =====================
local gui = Instance.new("ScreenGui")
gui.Name             = "PartEditorV2"
gui.ResetOnSpawn     = false
gui.ZIndexBehavior   = Enum.ZIndexBehavior.Global
gui.DisplayOrder     = 50
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
        origData[p] = {color=p.Color, transparency=p.Transparency}
    end
end

local function restoreOrig(p)
    if origData[p] and p.Parent then
        pcall(function()
            p.Color        = origData[p].color
            p.Transparency = origData[p].transparency
        end)
        origData[p] = nil
    end
end

local function isSelected(p)
    for _, d in ipairs(selectedParts) do if d == p then return true end end
    return false
end

local function addToMulti(p)
    if isSelected(p) then return end
    saveOrig(p)
    pcall(function() p.Color = SELECTED_COLOR p.Transparency = 0.3 end)
    table.insert(selectedParts, p)
end

local function removeFromMulti(p)
    for i, d in ipairs(selectedParts) do
        if d == p then
            restoreOrig(p)
            table.remove(selectedParts, i)
            return
        end
    end
end

local function clearAll()
    for _, p in ipairs(selectedParts) do restoreOrig(p) end
    selectedParts = {}
    if singleSelected then restoreOrig(singleSelected) end
    singleSelected = nil
end

local function getTargets()
    if selectMode == "single" then
        return singleSelected and {singleSelected} or {}
    else
        local t = {}
        for _, p in ipairs(selectedParts) do table.insert(t, p) end
        return t
    end
end

-- =====================
-- RAYCAST
-- =====================
local function rayPart()
    local ray = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local rp  = RaycastParams.new()
    local ign = {spawnerFolder}
    local c   = LocalPlayer.Character
    if c then table.insert(ign, c) end
    rp.FilterDescendantsInstances = ign
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local res = workspace:Raycast(ray.Origin, ray.Direction*2000, rp)
    return res and res.Instance
end

-- =====================
-- HOVER
-- =====================
local function applyHover(p)
    if p == hoveredPart then return end
    if hoveredPart and hoveredPart ~= singleSelected and not isSelected(hoveredPart) then
        restoreOrig(hoveredPart)
    end
    hoveredPart = p
    if p and p ~= singleSelected and not isSelected(p) then
        saveOrig(p)
        pcall(function() p.Color = HOVER_COLOR p.Transparency = 0.35 end)
    end
end

local function clearHover()
    if hoveredPart and hoveredPart ~= singleSelected and not isSelected(hoveredPart) then
        restoreOrig(hoveredPart)
    end
    hoveredPart = nil
end

-- =====================
-- DRAGGABLE FRAME HELPER
-- =====================
local function makeDraggable(frame)
    local drag, ds, fs = false, nil, nil
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag=true ds=i.Position fs=frame.Position
        end
    end)
    frame.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position-ds
            frame.Position = UDim2.new(fs.X.Scale,fs.X.Offset+d.X,fs.Y.Scale,fs.Y.Offset+d.Y)
        end
    end)
end

local function makeFrame(size, pos, parent, z)
    local f = Instance.new("Frame")
    f.Size = size f.Position = pos f.BackgroundColor3 = BG
    f.BorderSizePixel = 0 f.ZIndex = z or 10 f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,12)
    local s = Instance.new("UIStroke") s.Color=Color3.fromRGB(50,50,80) s.Parent=f
    return f, s
end

local function makeLbl(parent, size, pos, text, color, font, tsize, z, xalign)
    local l = Instance.new("TextLabel")
    l.Size=size l.Position=pos l.BackgroundTransparency=1
    l.TextColor3=color or Color3.new(1,1,1) l.Font=font or Enum.Font.GothamBold
    l.TextSize=tsize or 12 l.Text=text l.ZIndex=z or 11 l.Parent=parent
    l.TextXAlignment = xalign or Enum.TextXAlignment.Center
    return l
end

local function makeBtn(parent, size, pos, text, col, z, fn)
    local b = Instance.new("TextButton")
    b.Size=size b.Position=pos b.BackgroundColor3=col or ROW
    b.TextColor3=Color3.new(1,1,1) b.Font=Enum.Font.GothamBold b.TextSize=11
    b.Text=text b.BorderSizePixel=0 b.ZIndex=z or 12 b.Parent=parent
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    if fn then b.MouseButton1Click:Connect(fn) end
    return b
end

-- =====================
-- MAIN PANEL
-- =====================
local MP, mpS = makeFrame(UDim2.new(0,180,0,260),UDim2.new(0,20,0.5,-130),gui,10)
makeDraggable(MP)
mpS.Color = Color3.fromRGB(60,60,100)
makeLbl(MP,UDim2.new(1,-10,0,24),UDim2.new(0,5,0,5),"✏️ Part Editor",ACCENT,Enum.Font.GothamBlack,13,11,Enum.TextXAlignment.Left)

local function mpSection(y, text)
    makeLbl(MP,UDim2.new(1,-16,0,14),UDim2.new(0,8,0,y),text,Color3.fromRGB(100,100,140),Enum.Font.GothamBold,9,11,Enum.TextXAlignment.Left)
end

mpSection(32,"── SELECT MODE ──")
local btnSingle = makeBtn(MP,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,48),"Single Select",Color3.fromRGB(40,100,180),12)
local btnMulti  = makeBtn(MP,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,80),"Multi Select",ROW,12)

mpSection(116,"── EDITOR ──")
local btnToggle = makeBtn(MP,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,132),"Editor: OFF",ROW,12)

mpSection(168,"── WINDOWS ──")
local btnOpenTrans  = makeBtn(MP,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,184),"Transform Tool",Color3.fromRGB(40,80,180),12)
local btnOpenDelete = makeBtn(MP,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,216),"Edit / Delete",Color3.fromRGB(140,40,40),12)

-- =====================
-- TRANSFORM PANEL
-- =====================
local TP, tpS = makeFrame(UDim2.new(0,230,0,210),UDim2.new(0,210,0.5,-105),gui,20)
TP.Visible = false tpS.Color = ACCENT
makeDraggable(TP)
makeLbl(TP,UDim2.new(1,-50,0,24),UDim2.new(0,8,0,5),"🔧 Transform",ACCENT,Enum.Font.GothamBlack,13,21,Enum.TextXAlignment.Left)
local tpClose = makeBtn(TP,UDim2.new(0,22,0,22),UDim2.new(1,-28,0,4),"X",RED,22,function() TP.Visible=false end)

-- Mode row
local modes = {"Move","Resize","Rotate"}
local modeBtns = {}
for i, m in ipairs(modes) do
    local b = makeBtn(TP,UDim2.new(0,62,0,24),UDim2.new(0,6+(i-1)*72,0,34),m,ROW,22)
    table.insert(modeBtns,b)
    b.MouseButton1Click:Connect(function()
        transformMode = m:lower()
        for _, mb in ipairs(modeBtns) do mb.BackgroundColor3=ROW end
        b.BackgroundColor3 = Color3.fromRGB(40,100,180)
    end)
end
modeBtns[1].BackgroundColor3 = Color3.fromRGB(40,100,180)

makeLbl(TP,UDim2.new(1,-16,0,14),UDim2.new(0,8,0,64),"── AXIS ──",Color3.fromRGB(100,100,140),Enum.Font.GothamBold,9,21,Enum.TextXAlignment.Left)

local axCols = {X=Color3.fromRGB(220,60,60),Y=Color3.fromRGB(60,200,60),Z=Color3.fromRGB(60,100,220)}
for i, axis in ipairs({"X","Y","Z"}) do
    local xOff = 6+(i-1)*74
    local col = axCols[axis]
    local upBtn = makeBtn(TP,UDim2.new(0,66,0,24),UDim2.new(0,xOff,0,80),axis.."+",col,22)
    local dnBtn = makeBtn(TP,UDim2.new(0,66,0,24),UDim2.new(0,xOff,0,108),axis.."-",Color3.fromRGB(col.R*0.7,col.G*0.7,col.B*0.7),22)

    local function apply(delta)
        for _, p in ipairs(getTargets()) do
            pcall(function()
                if transformMode=="move" then
                    local av = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                    p.CFrame = p.CFrame + av*delta
                elseif transformMode=="resize" then
                    local av = axis=="X" and Vector3.new(1,0,0) or axis=="Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                    p.Size = Vector3.new(math.max(0.05,p.Size.X+av.X*delta),math.max(0.05,p.Size.Y+av.Y*delta),math.max(0.05,p.Size.Z+av.Z*delta))
                elseif transformMode=="rotate" then
                    local rot = axis=="X" and CFrame.Angles(math.rad(delta*15),0,0) or axis=="Y" and CFrame.Angles(0,math.rad(delta*15),0) or CFrame.Angles(0,0,math.rad(delta*15))
                    p.CFrame = p.CFrame * rot
                end
            end)
        end
    end
    upBtn.MouseButton1Click:Connect(function() apply(stepValue) end)
    dnBtn.MouseButton1Click:Connect(function() apply(-stepValue) end)
end

makeLbl(TP,UDim2.new(1,-16,0,14),UDim2.new(0,8,0,140),"── STEP SIZE ──",Color3.fromRGB(100,100,140),Enum.Font.GothamBold,9,21,Enum.TextXAlignment.Left)

local stepBox = Instance.new("TextBox")
stepBox.Size = UDim2.new(1,-16,0,28)
stepBox.Position = UDim2.new(0,8,0,156)
stepBox.BackgroundColor3 = ROW
stepBox.TextColor3 = Color3.new(1,1,1)
stepBox.Font = Enum.Font.GothamBold
stepBox.TextSize = 14
stepBox.Text = "1"
stepBox.PlaceholderText = "Step (0.1 - 500)"
stepBox.BorderSizePixel = 0
stepBox.ClearTextOnFocus = false
stepBox.ZIndex = 22
stepBox.Parent = TP
Instance.new("UICorner", stepBox).CornerRadius = UDim.new(0,7)

-- Numbers and decimal only
stepBox.Changed:Connect(function(prop)
    if prop == "Text" then
        local filtered = stepBox.Text:gsub("[^%d%.]", "")
        -- Only allow one decimal point
        local first = filtered:find("%.")
        if first then
            filtered = filtered:sub(1,first)..filtered:sub(first+1):gsub("%.", "")
        end
        if filtered ~= stepBox.Text then stepBox.Text = filtered end
        local v = tonumber(filtered)
        if v then stepValue = math.clamp(v, 0.1, 500) end
    end
end)

stepBox.FocusLost:Connect(function()
    local v = tonumber(stepBox.Text)
    if v then
        stepValue = math.clamp(v, 0.1, 500)
        stepBox.Text = tostring(stepValue)
    else
        stepBox.Text = tostring(stepValue)
    end
end)

-- =====================
-- EDIT/DELETE PANEL
-- =====================
local EP, epS = makeFrame(UDim2.new(0,210,0,250),UDim2.new(0,210,0.5,20),gui,20)
EP.Visible = false epS.Color = RED
makeDraggable(EP)
makeLbl(EP,UDim2.new(1,-50,0,24),UDim2.new(0,8,0,5),"🎨 Edit / Delete",Color3.fromRGB(200,80,80),Enum.Font.GothamBlack,13,21,Enum.TextXAlignment.Left)
makeBtn(EP,UDim2.new(0,22,0,22),UDim2.new(1,-28,0,4),"X",RED,22,function() EP.Visible=false end)

makeLbl(EP,UDim2.new(1,-16,0,14),UDim2.new(0,8,0,32),"── COLOR ──",Color3.fromRGB(100,100,140),Enum.Font.GothamBold,9,21,Enum.TextXAlignment.Left)
local eColors = {Color3.fromRGB(255,80,80),Color3.fromRGB(80,200,80),Color3.fromRGB(80,120,255),Color3.fromRGB(255,200,80),Color3.fromRGB(255,130,255),Color3.fromRGB(255,165,0),Color3.fromRGB(255,255,255),Color3.fromRGB(30,30,30)}
for i, col in ipairs(eColors) do
    local cb = Instance.new("TextButton")
    cb.Size=UDim2.new(0,38,0,22) cb.Position=UDim2.new(0,8+((i-1)%4)*48,0,48+math.floor((i-1)/4)*26)
    cb.BackgroundColor3=col cb.Text="" cb.BorderSizePixel=0 cb.ZIndex=22 cb.Parent=EP
    Instance.new("UICorner",cb).CornerRadius=UDim.new(0,5)
    cb.MouseButton1Click:Connect(function()
        for _, p in ipairs(getTargets()) do pcall(function() p.Color=col end) end
    end)
end

makeLbl(EP,UDim2.new(1,-16,0,14),UDim2.new(0,8,0,104),"── TRANSPARENCY ──",Color3.fromRGB(100,100,140),Enum.Font.GothamBold,9,21,Enum.TextXAlignment.Left)
local tOpts = {{0,"Solid"},{0.5,"50%"},{0.9,"Ghost"},{1,"Hidden"}}
for i, tv in ipairs(tOpts) do
    makeBtn(EP,UDim2.new(0,44,0,22),UDim2.new(0,6+(i-1)*50,0,120),tv[2],ROW,22,function()
        for _, p in ipairs(getTargets()) do pcall(function() p.Transparency=tv[1] end) end
    end)
end

makeLbl(EP,UDim2.new(1,-16,0,14),UDim2.new(0,8,0,150),"── MATERIAL ──",Color3.fromRGB(100,100,140),Enum.Font.GothamBold,9,21,Enum.TextXAlignment.Left)
local mats = {{"SmoothPlastic",Enum.Material.SmoothPlastic},{"Wood",Enum.Material.Wood},{"Metal",Enum.Material.Metal},{"Neon",Enum.Material.Neon}}
for i, mv in ipairs(mats) do
    makeBtn(EP,UDim2.new(0,44,0,20),UDim2.new(0,6+(i-1)*50,0,166),mv[1],ROW,22,function()
        for _, p in ipairs(getTargets()) do pcall(function() p.Material=mv[2] end) end
    end)
end

makeBtn(EP,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,194),"Reset Appearance",Color3.fromRGB(40,80,180),22,function()
    for _, p in ipairs(getTargets()) do
        if origData[p] then
            pcall(function() p.Color=origData[p].color p.Transparency=origData[p].transparency end)
        end
    end
end)

makeBtn(EP,UDim2.new(1,-16,0,28),UDim2.new(0,8,0,226),"🗑️ Delete Selected",RED,22,function()
    local count=0
    for _, p in ipairs(getTargets()) do
        pcall(function()
            for _, v in pairs(p:GetDescendants()) do
                if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ModuleScript") then v:Destroy() end
            end
            p:Destroy() count=count+1
        end)
    end
    clearAll() EP.Visible=false
    notify("Part Editor","Deleted "..count.." part(s)")
end)

-- =====================
-- BUTTON LOGIC
-- =====================
btnSingle.MouseButton1Click:Connect(function()
    selectMode="single" clearAll() TP.Visible=false EP.Visible=false
    btnSingle.BackgroundColor3=Color3.fromRGB(40,100,180) btnMulti.BackgroundColor3=ROW
    notify("Part Editor","Single Select — click a part to select it")
end)
btnMulti.MouseButton1Click:Connect(function()
    selectMode="multi" clearAll() TP.Visible=false EP.Visible=false
    btnMulti.BackgroundColor3=Color3.fromRGB(40,100,180) btnSingle.BackgroundColor3=ROW
    notify("Part Editor","Multi Select — click parts to add/remove, click again to deselect")
end)

btnToggle.MouseButton1Click:Connect(function()
    editorOn = not editorOn
    if editorOn then
        btnToggle.Text="Editor: ON" btnToggle.BackgroundColor3=GREEN
    else
        btnToggle.Text="Editor: OFF" btnToggle.BackgroundColor3=ROW
        clearHover() clearAll() TP.Visible=false EP.Visible=false
    end
end)

btnOpenTrans.MouseButton1Click:Connect(function()
    if #getTargets()==0 then notify("Part Editor","Select a part first!") return end
    TP.Visible=true
end)
btnOpenDelete.MouseButton1Click:Connect(function()
    if #getTargets()==0 then notify("Part Editor","Select a part first!") return end
    EP.Visible=true
end)

-- =====================
-- HOVER LOOP
-- =====================
RunService.RenderStepped:Connect(function()
    if not editorOn then return end
    local p = rayPart()
    if p and p:IsA("BasePart") and not isCharPart(p) then
        applyHover(p)
    else
        clearHover()
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
        -- restore old selection
        if singleSelected then
            restoreOrig(singleSelected)
            singleSelected = nil
        end
        TP.Visible = false

        if p and p:IsA("BasePart") and not isCharPart(p) then
            singleSelected = p
            saveOrig(p)
            pcall(function() p.Color=SELECTED_COLOR p.Transparency=0.3 end)
            -- update transform panel title
            for _, c in pairs(TP:GetChildren()) do
                if c:IsA("TextLabel") and c.Text:find("Transform") then
                    c.Text = "🔧 "..p.Name break
                end
            end
        end
        -- clicking sky = closes (TP already hidden above, EP stays)

    elseif selectMode == "multi" then
        if p and p:IsA("BasePart") and not isCharPart(p) then
            if isSelected(p) then
                removeFromMulti(p)
            else
                addToMulti(p)
            end
        end
    end
end)

notify("Part Editor v2","Loaded! Enable editor, pick a select mode, then click parts.")
print("[Part Editor v2] Loaded!")
