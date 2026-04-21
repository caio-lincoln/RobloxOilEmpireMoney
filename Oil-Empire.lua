-- Oil Empire🛢️ Auto Farm, Auto Sell, keyless - open source | Made by dkxn

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lp       = Players.LocalPlayer
local username = lp.Name
local enabled    = false
local tweenSpeed = 0.1
local useTween   = true
local farmThread = nil
local antiAfkOn  = false
local antiAfkConn = nil
local stealEnabled = false
local stealThread  = nil

local function setAntiAfk(on)
    antiAfkOn = on
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
    if on then
        antiAfkConn = lp.Idled:Connect(function()
            local vp = game:GetService("VirtualInputManager")
            vp:SendKeyEvent(true,  Enum.KeyCode.W, false, game)
            task.wait(0.1)
            vp:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        end)
    end
end
local function getPlayerPlot()
    local plotsFolder = workspace:FindFirstChild("Plots")
    if not plotsFolder then return nil end
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local ok, label = pcall(function()
            return plot.OwnerTag.BillboardGui.Main.TextLabel
        end)
        if ok and label then
            local owner = label.Text:match("^(.+)'s")
            if owner == username then return plot end
        end
    end
    return nil
end
local function getBuildings()
    local plot = getPlayerPlot()
    return plot and plot:FindFirstChild("Buildings") or nil
end
local function getRefineries(buildings)
    local list = {}
    for _, m in ipairs(buildings:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("Type") == "Refinery" then
            list[#list + 1] = m
        end
    end
    return list
end
local function increaseProduction(refinery)
    local productionRate = refinery:GetAttribute("ProductionRate")
    if type(productionRate) == "number" then
        refinery:SetAttribute("ProductionRate", productionRate * 1.2)
    end
end
local function stealRefinery(refinery)
    local owner = refinery:GetAttribute("Owner")
    if owner ~= username then
        refinery:SetAttribute("Owner", username)
    end
end
local function stealRefineries(refineries)
    for _, refinery in ipairs(refineries) do
        local prompt = refinery:FindFirstChild("StealPrompt", true)
        if not prompt then
            for _, d in ipairs(refinery:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Name:lower():find("steal") then
                    prompt = d
                    break
                end
            end
        end
        if prompt and prompt:IsA("ProximityPrompt") then
            pcall(function()
                if not refinery:GetAttribute("Stealable") then
                    refinery:SetAttribute("Stealable", true)
                end
            end)
            pcall(function()
                fireproximityprompt(prompt)
            end)
        end
    end
end
local function stealLoop()
    while stealEnabled do
        local buildings = getBuildings()
        if not buildings then task.wait(1) continue end
        local list = getRefineries(buildings)
        if #list == 0 then task.wait(1) continue end
        stealRefineries(list)
        task.wait(0.5)
    end
end
local function getValues(model)
    local ok, obj = pcall(function() return model.Primary.Info.Main.Value end)
    if not ok or not obj then return 0, 0 end
    local text = (obj.Text or obj.Value or "")
    local c, m = text:match("^(%d+)/(%d+)$")
    return tonumber(c) or 0, tonumber(m) or 0
end
local function getPrimary(model)
    local p = model:FindFirstChild("Primary")
    if p and p:IsA("BasePart") then return p end
    return model.PrimaryPart
end
local function teleport(targetCF)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    hrp.Anchored = true
    if hum then hum.PlatformStand = true end
    if useTween and tweenSpeed > 0.05 then
        local startCF  = hrp.CFrame
        local elapsed  = 0
        local duration = tweenSpeed
        repeat
            local dt = task.wait()
            elapsed  = elapsed + dt
            local a  = math.min(elapsed / duration, 1)
            hrp.CFrame = startCF:Lerp(targetCF, 1 - (1 - a) ^ 3)
        until elapsed >= duration or not enabled or not hrp.Parent
    end
    if hrp.Parent then hrp.CFrame = targetCF end
    hrp.Anchored = false
    if hum then hum.PlatformStand = false end
end
local function farmLoop()
    while enabled do
        local buildings = getBuildings()
        if not buildings then task.wait(1) continue end
        local list = getRefineries(buildings)
        if #list == 0 then task.wait(1) continue end
        table.sort(list, function(a, b)
            local ca, ma = getValues(a)
            local cb, mb = getValues(b)
            local fa = (ma > 0) and (ca / ma) or 0
            local fb = (mb > 0) and (cb / mb) or 0
            return fa > fb
        end)
        local visited = 0
        for _, model in ipairs(list) do
            if not enabled then break end
            if not model.Parent then continue end
            local cur, max = getValues(model)
            if max > 0 and cur == max then
                local primary = getPrimary(model)
                if primary then
                    teleport(primary.CFrame)
                    visited = visited + 1
                    task.wait(0.05)
                end
            end
        end
        if visited == 0 then
            task.wait(0.5)
        end
    end
end

local sellPrice   = 10
local minGasoline = 10000
local sellThread  = nil
local sellStore, sellPrompt, sellRemote
local function cacheSellAssets()
    local stores = workspace:FindFirstChild("Stores")
    if not stores then return false end
    sellStore = stores:FindFirstChild("Sell")
    if not sellStore then return false end
    local prompt = sellStore:FindFirstChild("SellGas", true)
    if not prompt then
        for _, v in ipairs(sellStore:GetDescendants()) do
            if v:IsA("ProximityPrompt") then prompt = v; break end
        end
    end
    sellPrompt = prompt
    for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name:lower():find("sell") then
            sellRemote = v
            break
        end
    end
    if not sellRemote then
        for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if v:IsA("RemoteEvent") and (
                v.Name:lower():find("gas") or
                v.Name:lower():find("store") or
                v.Name:lower():find("shop")
            ) then
                sellRemote = v
                break
            end
        end
    end
    if not sellRemote then
    end
    return true
end
local function vimClick(btn)
    local vp  = game:GetService("VirtualInputManager")
    local pos = btn.AbsolutePosition + btn.AbsoluteSize * 0.5
    vp:SendMouseButtonEvent(pos.X, pos.Y, 0, true,  game, 0)
    task.wait(0.08)
    vp:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
end
local function doTeleportToStore()
    local standPart = sellStore:FindFirstChild("Primary", true)
    if not standPart or not standPart:IsA("BasePart") then
        for _, v in ipairs(sellStore:GetDescendants()) do
            if v:IsA("BasePart") then standPart = v; break end
        end
    end
    if not standPart then return nil end
    local char = lp.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return nil end
    local savedCF = hrp.CFrame
    hrp.Anchored = true
    if hum then hum.PlatformStand = true end
    hrp.CFrame = standPart.CFrame * CFrame.new(0, 4, 0)
    task.wait()
    hrp.Anchored = false
    if hum then hum.PlatformStand = false end
    return savedCF
end
local function doTeleportBack(savedCF)
    if not savedCF then return end
    local char = lp.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return end
    hrp.Anchored = true
    if hum then hum.PlatformStand = true end
    hrp.CFrame = savedCF
    task.wait()
    hrp.Anchored = false
    if hum then hum.PlatformStand = false end
end
local function closeGui()
    local sellGui = lp.PlayerGui.Main.SellGas
    pcall(function()
        local closeBtn = sellGui.Close
        local oldZ = closeBtn.ZIndex
        closeBtn.ZIndex = 9999
        task.wait()
        vimClick(closeBtn)
        closeBtn.ZIndex = oldZ
    end)
    task.wait(0.3)
    if sellGui.Visible then
        pcall(function()
            local vp = game:GetService("VirtualInputManager")
            vp:SendKeyEvent(true,  Enum.KeyCode.Escape, false, game)
            task.wait(0.05)
            vp:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
        end)
        task.wait(0.2)
    end
    if sellGui.Visible then
        pcall(function()
            sellGui.Visible = false
            local mainGui = lp.PlayerGui:FindFirstChild("Main")
            if mainGui then
                for _, v in ipairs(mainGui:GetChildren()) do
                    local lname = v.Name:lower()
                    if v:IsA("Frame") and (
                        lname:find("blur") or lname:find("dark") or
                        lname:find("overlay") or lname:find("dim") or
                        lname:find("bg") or lname:find("background")
                    ) then
                        v.Visible = false
                    end
                end
                local lighting = game:GetService("Lighting")
                for _, v in ipairs(lighting:GetChildren()) do
                    if v:IsA("BlurEffect") then
                        v.Enabled = false
                        task.delay(2, function() v.Enabled = true end)
                    end
                end
            end
        end)
    end
end
local function trySell()
    local sellGui = lp.PlayerGui.Main.SellGas
    local sellBtn = sellGui.Main.Sell
    if sellRemote then
        local ok, err = pcall(function() sellRemote:FireServer() end)
        if ok then
            return true
        else
        end
    end
    local ok2, err2 = pcall(function() vimClick(sellBtn) end)
    if ok2 then
        return true
    else
    end
    return false
end
local function sellLoop()
    if not sellStore then
        if not cacheSellAssets() then
            sellEnabled = false
            return
        end
    end
    while sellEnabled do
        local okP, price = pcall(function()
            return game:GetService("ReplicatedStorage").GasPrice.Value
        end)
        if not okP or type(price) ~= "number" then
            task.wait(2); continue
        end
        local okG, gasoline = pcall(function()
            return lp.leaderstats.Gasoline.Value
        end)
        local hasEnoughGas = okG and type(gasoline) == "number" and gasoline >= minGasoline
        if price >= sellPrice and hasEnoughGas then
            local wasEnabled = enabled
            if wasEnabled then
                enabled = false
                if farmThread then task.cancel(farmThread); farmThread = nil end
            end
            if sellPrompt then
                pcall(function() fireproximityprompt(sellPrompt) end)
                task.wait(0.6)
            end
            trySell()
            if wasEnabled then
                enabled = true
                farmThread = task.spawn(farmLoop)
            end
            task.wait(5)
        else
            task.wait(1)
        end
    end
end
pcall(function()
    local old = game:GetService("CoreGui"):FindFirstChild("DrillFarmGUI")
    if old then old:Destroy() end
end)
local gui = Instance.new("ScreenGui")
gui.Name           = "DrillFarmGUI"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder   = 999
do
    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not ok then gui.Parent = lp:WaitForChild("PlayerGui") end
end
local function corner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 10)
end
local function stroke(parent, col, thick)
    local s = Instance.new("UIStroke", parent)
    s.Color     = col or Color3.fromRGB(45, 45, 45)
    s.Thickness = thick or 1
end
local SWITCH_ON_BG   = Color3.fromRGB(40, 110, 80)
local SWITCH_ON_KNOB = Color3.fromRGB(120, 220, 170)
local SWITCH_OFF_BG  = Color3.fromRGB(22, 22, 22)
local SWITCH_OFF_KNOB = Color3.fromRGB(60, 60, 60)
local function mkSwitch(parent, startOn)
    local bg = Instance.new("Frame", parent)
    bg.Size             = UDim2.new(0, 48, 0, 26)
    bg.Position         = UDim2.new(1, -62, 0.5, -13)
    bg.BackgroundColor3 = startOn and SWITCH_ON_BG or SWITCH_OFF_BG
    bg.BorderSizePixel  = 0
    corner(bg, 99)
    stroke(bg, Color3.fromRGB(30,30,30))
    local knob = Instance.new("Frame", bg)
    knob.Size             = UDim2.new(0, 20, 0, 20)
    knob.Position         = startOn and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)
    knob.BackgroundColor3 = startOn and SWITCH_ON_KNOB or SWITCH_OFF_KNOB
    knob.BorderSizePixel  = 0
    corner(knob, 99)
    local btn = Instance.new("TextButton", bg)
    btn.Size             = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text             = ""
    return bg, knob, btn
end
local function animSwitch(bg, knob, on)
    TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        Position         = on and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10),
        BackgroundColor3 = on and SWITCH_ON_KNOB or SWITCH_OFF_KNOB,
    }):Play()
    TweenService:Create(bg, TweenInfo.new(0.18), {
        BackgroundColor3 = on and SWITCH_ON_BG or SWITCH_OFF_BG,
    }):Play()
end
local MAIN_W   = 320
local MAX_H    = 400
local TITLE_H  = 46
local RADIUS   = 14
local main = Instance.new("Frame", gui)
main.Name              = "Main"
main.Size              = UDim2.new(0, MAIN_W, 0, MAX_H)
main.Position          = UDim2.new(0.5, -MAIN_W/2, 0.3, 0)
main.BackgroundColor3  = Color3.fromRGB(8, 8, 8)
main.BorderSizePixel   = 0
main.ClipsDescendants  = true
corner(main, RADIUS)
stroke(main, Color3.fromRGB(32, 32, 32))
local shimmer = Instance.new("Frame", main)
shimmer.Size             = UDim2.new(1,0,0,1)
shimmer.BackgroundColor3 = Color3.fromRGB(38,38,38)
shimmer.BorderSizePixel  = 0
shimmer.ZIndex           = 5
local titleBar = Instance.new("Frame", main)
titleBar.Size             = UDim2.new(1,0,0,TITLE_H)
titleBar.BackgroundColor3 = Color3.fromRGB(10,10,10)
titleBar.BorderSizePixel  = 0
corner(titleBar, RADIUS)
local titleBarBottom = Instance.new("Frame", titleBar)
titleBarBottom.Size             = UDim2.new(1,0,0,RADIUS)
titleBarBottom.Position         = UDim2.new(0,0,1,-RADIUS)
titleBarBottom.BackgroundColor3 = Color3.fromRGB(10,10,10)
titleBarBottom.BorderSizePixel  = 0
local accentBar = Instance.new("Frame", titleBar)
accentBar.Size             = UDim2.new(0,2,0,16)
accentBar.Position         = UDim2.new(0,16,0.5,-8)
accentBar.BackgroundColor3 = Color3.fromRGB(120,200,160)
accentBar.BorderSizePixel  = 0
corner(accentBar, 2)
local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Text              = "Oil Empire🛢️"
titleLabel.Size              = UDim2.new(1,-95,0,16)
titleLabel.Position          = UDim2.new(0,26,0,7)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3        = Color3.fromRGB(200,200,200)
titleLabel.TextSize          = 12
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
local bylineLabel = Instance.new("TextLabel", titleBar)
bylineLabel.Text             = "made by dekxonn"
bylineLabel.RichText         = true
bylineLabel.Size             = UDim2.new(1,-95,0,11)
bylineLabel.Position         = UDim2.new(0,26,0,25)
bylineLabel.BackgroundTransparency = 1
bylineLabel.TextColor3       = Color3.fromRGB(144,144,144)
bylineLabel.TextSize         = 9
bylineLabel.Font             = Enum.Font.Gotham
bylineLabel.TextXAlignment   = Enum.TextXAlignment.Left
local minBtn = Instance.new("TextButton", titleBar)
minBtn.Text              = "—"
minBtn.Size              = UDim2.new(0,26,0,26)
minBtn.Position          = UDim2.new(1,-62,0.5,-13)
minBtn.BackgroundColor3  = Color3.fromRGB(22,22,22)
minBtn.TextColor3        = Color3.fromRGB(120,120,120)
minBtn.TextSize          = 16
minBtn.Font              = Enum.Font.GothamBold
minBtn.BorderSizePixel   = 0
corner(minBtn, 6)
stroke(minBtn, Color3.fromRGB(36,36,36))
local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Text             = "×"
closeBtn.Size             = UDim2.new(0,26,0,26)
closeBtn.Position         = UDim2.new(1,-31,0.5,-13)
closeBtn.BackgroundColor3 = Color3.fromRGB(28,12,12)
closeBtn.TextColor3       = Color3.fromRGB(160,55,55)
closeBtn.TextSize         = 18
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
corner(closeBtn, 6)
local titleSep = Instance.new("Frame", main)
titleSep.Size             = UDim2.new(1,0,0,1)
titleSep.Position         = UDim2.new(0,0,0,TITLE_H)
titleSep.BackgroundColor3 = Color3.fromRGB(18,18,18)
titleSep.BorderSizePixel  = 0
local scroll = Instance.new("ScrollingFrame", main)
scroll.Size                  = UDim2.new(1,0,1,-(TITLE_H+1))
scroll.Position              = UDim2.new(0,0,0,TITLE_H+1)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = Color3.fromRGB(50,50,50)
scroll.CanvasSize             = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.ScrollingDirection     = Enum.ScrollingDirection.Y
scroll.ElasticBehavior        = Enum.ElasticBehavior.Never
local listLayout = Instance.new("UIListLayout", scroll)
listLayout.SortOrder    = Enum.SortOrder.LayoutOrder
listLayout.Padding      = UDim.new(0,8)
listLayout.FillDirection = Enum.FillDirection.Vertical
local listPad = Instance.new("UIPadding", scroll)
listPad.PaddingTop    = UDim.new(0,10)
listPad.PaddingBottom = UDim.new(0,10)
listPad.PaddingLeft   = UDim.new(0,14)
listPad.PaddingRight  = UDim.new(0,14)
local function mkSectionHeader(labelText, order, startCollapsed)
    local collapsed = startCollapsed and true or false
    local cards = {}
    local hdr = Instance.new("Frame", scroll)
    hdr.Size              = UDim2.new(1,0,0,26)
    hdr.BackgroundTransparency = 1
    hdr.LayoutOrder       = order
    local btn = Instance.new("TextButton", hdr)
    btn.Size              = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text              = ""
    local lbl = Instance.new("TextLabel", hdr)
    lbl.Text              = labelText
    lbl.Size              = UDim2.new(1,-20,1,0)
    lbl.Position          = UDim2.new(0,0,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3        = Color3.fromRGB(100,100,100)
    lbl.TextSize          = 11
    lbl.Font              = Enum.Font.GothamBold
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    local chevron = Instance.new("TextLabel", hdr)
    chevron.Text              = collapsed and "▶" or "▼"
    chevron.Size              = UDim2.new(0,16,1,0)
    chevron.Position          = UDim2.new(1,-16,0,0)
    chevron.BackgroundTransparency = 1
    chevron.TextColor3        = Color3.fromRGB(80,80,80)
    chevron.TextSize          = 10
    chevron.Font              = Enum.Font.GothamBold
    chevron.TextXAlignment    = Enum.TextXAlignment.Right
    local function applyState()
        chevron.Text = collapsed and "▶" or "▼"
        for _, c in ipairs(cards) do
            c.Visible = not collapsed
        end
    end
    btn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        applyState()
    end)
    local function register(card)
        table.insert(cards, card)
        card.Visible = not collapsed
    end
    return register
end
local function mkCard(h, order)
    local f = Instance.new("Frame", scroll)
    f.Size             = UDim2.new(1,0,0,h)
    f.BackgroundColor3 = Color3.fromRGB(14,14,14)
    f.BorderSizePixel  = 0
    f.LayoutOrder      = order
    corner(f, 10)
    stroke(f, Color3.fromRGB(24,24,24))
    return f
end
local function mkLabel(parent, text, size, x, y, w, h_, bold, color)
    local l = Instance.new("TextLabel", parent)
    l.Text              = text
    l.Size              = UDim2.new(w,0,0,h_)
    l.Position          = UDim2.new(0,x,0,y)
    l.BackgroundTransparency = 1
    l.TextColor3        = color or Color3.fromRGB(155,155,155)
    l.TextSize          = size
    l.Font              = bold and Enum.Font.GothamSemibold or Enum.Font.Gotham
    l.TextXAlignment    = Enum.TextXAlignment.Left
    return l
end
local reg1 = mkSectionHeader("REFINERY AUTO PICKUP", 1, false)
local statusCard = mkCard(44, 2)
reg1(statusCard)
local statusDot = Instance.new("Frame", statusCard)
statusDot.Size             = UDim2.new(0,7,0,7)
statusDot.Position         = UDim2.new(0,14,0,12)
statusDot.BackgroundColor3 = Color3.fromRGB(50,50,50)
statusDot.BorderSizePixel  = 0
corner(statusDot, 99)
local statusLabel = mkLabel(statusCard,"INACTIVE",11,28,6,0.75,16,true,Color3.fromRGB(65,65,65))
local drillCountLabel = mkLabel(statusCard,"0 refineries found",10,28,24,0.75,14,false,Color3.fromRGB(120,120,120))
local farmCard = mkCard(50, 3)
reg1(farmCard)
mkLabel(farmCard,"Auto Pickup",13,14,10,0.7,18,true)
do local l=mkLabel(farmCard,"Collects full refineries",12,14,28,0,15,false,Color3.fromRGB(70,70,70)); l.Size=UDim2.new(0,152,0,15); l.TextTruncate=Enum.TextTruncate.AtEnd end
local switchBg, switchKnob, switchBtn = mkSwitch(farmCard, false)
local sliderCard = mkCard(68, 5)
reg1(sliderCard)
mkLabel(sliderCard,"Tween Speed",13,14,9,0.55,18,true)
do local l=mkLabel(sliderCard,"Duration per tween",12,14,27,0,14,false,Color3.fromRGB(70,70,70)); l.Size=UDim2.new(0,152,0,14); l.TextTruncate=Enum.TextTruncate.AtEnd end
local speedVal = Instance.new("TextLabel", sliderCard)
speedVal.Text              = "0.1s"
speedVal.Size              = UDim2.new(0.45,-14,0,22)
speedVal.Position          = UDim2.new(0.55,0,0,9)
speedVal.BackgroundTransparency = 1
speedVal.TextColor3        = Color3.fromRGB(155,155,155)
speedVal.TextSize          = 18
speedVal.Font              = Enum.Font.GothamBold
speedVal.TextXAlignment    = Enum.TextXAlignment.Right
local track = Instance.new("Frame", sliderCard)
track.Size             = UDim2.new(1,-28,0,4)
track.Position         = UDim2.new(0,14,0,52)
track.BackgroundColor3 = Color3.fromRGB(36,36,36)
track.BorderSizePixel  = 0
corner(track, 99)
local MIN_S, MAX_S = 0.1, 1.0
local fill = Instance.new("Frame", track)
fill.Size             = UDim2.new(0,0,1,0)
fill.BackgroundColor3 = Color3.fromRGB(150,150,150)
fill.BorderSizePixel  = 0
corner(fill, 99)
local knob = Instance.new("Frame", track)
knob.Size             = UDim2.new(0,14,0,14)
knob.AnchorPoint      = Vector2.new(0.5,0.5)
knob.Position         = UDim2.new(0,0,0.5,0)
knob.BackgroundColor3 = Color3.fromRGB(225,225,225)
knob.BorderSizePixel  = 0
knob.ZIndex           = 3
corner(knob, 99)
mkLabel(sliderCard,"0.1s",11,14,57,0,13,false,Color3.fromRGB(55,55,55))
local rmax = mkLabel(sliderCard,"1.0s",11,0,57,1,13,false,Color3.fromRGB(55,55,55))
rmax.TextXAlignment = Enum.TextXAlignment.Right
rmax.Position = UDim2.new(1,-44,0,57)
local reg2 = mkSectionHeader("AUTOSELL", 10, false)
local gasPriceCard = mkCard(72, 10.5)
reg2(gasPriceCard)
mkLabel(gasPriceCard,"GAS PRICE",11,14,8,0.5,13,true,Color3.fromRGB(80,80,80))
local gasPriceVal = Instance.new("TextLabel", gasPriceCard)
gasPriceVal.Text              = "$—"
gasPriceVal.Size              = UDim2.new(0.5,0,0,22)
gasPriceVal.Position          = UDim2.new(0,14,0,20)
gasPriceVal.BackgroundTransparency = 1
gasPriceVal.TextColor3        = Color3.fromRGB(110,210,160)
gasPriceVal.TextSize          = 18
gasPriceVal.Font              = Enum.Font.GothamBold
gasPriceVal.TextXAlignment    = Enum.TextXAlignment.Left
mkLabel(gasPriceCard,"SELL PRICE",11,0,8,1,13,true,Color3.fromRGB(80,80,80)).Position = UDim2.new(0.5,4,0,8)
local sellPriceVal = Instance.new("TextLabel", gasPriceCard)
sellPriceVal.Text              = "—"
sellPriceVal.Size              = UDim2.new(0.5,-8,0,22)
sellPriceVal.Position          = UDim2.new(0.5,4,0,20)
sellPriceVal.BackgroundTransparency = 1
sellPriceVal.TextColor3        = Color3.fromRGB(110,210,160)
sellPriceVal.TextSize          = 18
sellPriceVal.Font              = Enum.Font.GothamBold
sellPriceVal.TextXAlignment    = Enum.TextXAlignment.Left
local divider = Instance.new("Frame", gasPriceCard)
divider.Size             = UDim2.new(0,1,0,30)
divider.Position         = UDim2.new(0.5,0,0,10)
divider.BackgroundColor3 = Color3.fromRGB(30,30,30)
divider.BorderSizePixel  = 0
local timerSep = Instance.new("Frame", gasPriceCard)
timerSep.Size             = UDim2.new(1,-28,0,1)
timerSep.Position         = UDim2.new(0,14,0,46)
timerSep.BackgroundColor3 = Color3.fromRGB(24,24,24)
timerSep.BorderSizePixel  = 0
local gasTimerLabel = Instance.new("TextLabel", gasPriceCard)
gasTimerLabel.Text              = "✦ Next Price in: — ✦"
gasTimerLabel.Size              = UDim2.new(1,-28,0,16)
gasTimerLabel.Position          = UDim2.new(0,14,0,51)
gasTimerLabel.BackgroundTransparency = 1
gasTimerLabel.TextColor3        = Color3.fromRGB(130,130,130)
gasTimerLabel.TextSize          = 11
gasTimerLabel.Font              = Enum.Font.GothamSemibold
gasTimerLabel.TextXAlignment    = Enum.TextXAlignment.Center
local sellCard = mkCard(50, 11)
reg2(sellCard)
mkLabel(sellCard,"Auto Sell",13,14,10,0.7,18,true)
do local l=mkLabel(sellCard,"Sells when price ≥ target",12,14,28,0,15,false,Color3.fromRGB(70,70,70)); l.Size=UDim2.new(0,152,0,15); l.TextTruncate=Enum.TextTruncate.AtEnd end
local sellSwitchBg, sellSwitchKnob, sellSwitchBtn = mkSwitch(sellCard, false)
local priceCard = mkCard(58, 12)
reg2(priceCard)
mkLabel(priceCard,"Min Gas Price",13,14,9,0.6,18,true)
local minusBtn = Instance.new("TextButton", priceCard)
minusBtn.Text             = "−"
minusBtn.Size             = UDim2.new(0,28,0,28)
minusBtn.Position         = UDim2.new(1,-110,0.5,-14)
minusBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
minusBtn.TextColor3       = Color3.fromRGB(160,160,160)
minusBtn.TextSize         = 18
minusBtn.Font             = Enum.Font.GothamBold
minusBtn.BorderSizePixel  = 0
corner(minusBtn, 7)
stroke(minusBtn, Color3.fromRGB(45,45,45))
local priceDisplay = Instance.new("TextLabel", priceCard)
priceDisplay.Text              = "10"
priceDisplay.Size              = UDim2.new(0,36,0,28)
priceDisplay.Position          = UDim2.new(1,-78,0.5,-14)
priceDisplay.BackgroundColor3  = Color3.fromRGB(14,14,14)
priceDisplay.TextColor3        = Color3.fromRGB(220,220,220)
priceDisplay.TextSize          = 16
priceDisplay.Font              = Enum.Font.GothamBold
priceDisplay.TextXAlignment    = Enum.TextXAlignment.Center
corner(priceDisplay, 6)
stroke(priceDisplay, Color3.fromRGB(38,38,38))
local plusBtn = Instance.new("TextButton", priceCard)
plusBtn.Text             = "+"
plusBtn.Size             = UDim2.new(0,28,0,28)
plusBtn.Position         = UDim2.new(1,-38,0.5,-14)
plusBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
plusBtn.TextColor3       = Color3.fromRGB(160,160,160)
plusBtn.TextSize         = 18
plusBtn.Font             = Enum.Font.GothamBold
plusBtn.BorderSizePixel  = 0
corner(plusBtn, 7)
stroke(plusBtn, Color3.fromRGB(45,45,45))
local gasCard = mkCard(82, 13)
reg2(gasCard)
mkLabel(gasCard,"Min Gasoline",13,14,9,0.6,18,true)
do local l=mkLabel(gasCard,"Min gas before selling",12,14,27,0,14,false,Color3.fromRGB(70,70,70)); l.Size=UDim2.new(0,152,0,14); l.TextTruncate=Enum.TextTruncate.AtEnd end
local gasVal = Instance.new("TextLabel", gasCard)
gasVal.Text              = "10K"
gasVal.Size              = UDim2.new(0.5,-22,0,22)
gasVal.Position          = UDim2.new(0.5,4,0,9)
gasVal.BackgroundTransparency = 1
gasVal.TextColor3        = Color3.fromRGB(155,155,155)
gasVal.TextSize          = 16
gasVal.Font              = Enum.Font.GothamBold
gasVal.TextXAlignment    = Enum.TextXAlignment.Right
local gasTrack = Instance.new("Frame", gasCard)
gasTrack.Size             = UDim2.new(1,-28,0,4)
gasTrack.Position         = UDim2.new(0,14,0,52)
gasTrack.BackgroundColor3 = Color3.fromRGB(36,36,36)
gasTrack.BorderSizePixel  = 0
corner(gasTrack, 99)
local GAS_MIN, GAS_MAX = 1000, 10000000
local gasInitAlpha = (minGasoline - GAS_MIN) / (GAS_MAX - GAS_MIN)
local GAS_Z1_START, GAS_Z1_END, GAS_Z1_STEP = 1000,    100000,   1000
local GAS_Z2_START, GAS_Z2_END, GAS_Z2_STEP = 100000,  1000000,  25000
local GAS_Z3_START, GAS_Z3_END, GAS_Z3_STEP = 1000000, 10000000, 100000
local GAS_Z1_STEPS = (GAS_Z1_END - GAS_Z1_START) / GAS_Z1_STEP
local GAS_Z2_STEPS = (GAS_Z2_END - GAS_Z2_START) / GAS_Z2_STEP
local GAS_Z3_STEPS = (GAS_Z3_END - GAS_Z3_START) / GAS_Z3_STEP
local GAS_TOTAL_STEPS = GAS_Z1_STEPS + GAS_Z2_STEPS + GAS_Z3_STEPS
local GAS_Z1_ALPHA = GAS_Z1_STEPS / GAS_TOTAL_STEPS
local GAS_Z2_ALPHA = GAS_Z1_ALPHA + GAS_Z2_STEPS / GAS_TOTAL_STEPS
local gasFill = Instance.new("Frame", gasTrack)
gasFill.Size             = UDim2.new(gasInitAlpha,0,1,0)
gasFill.BackgroundColor3 = Color3.fromRGB(150,150,150)
gasFill.BorderSizePixel  = 0
corner(gasFill, 99)
local gasKnob = Instance.new("Frame", gasTrack)
gasKnob.Size             = UDim2.new(0,14,0,14)
gasKnob.AnchorPoint      = Vector2.new(0.5,0.5)
gasKnob.Position         = UDim2.new(gasInitAlpha,0,0.5,0)
gasKnob.BackgroundColor3 = Color3.fromRGB(225,225,225)
gasKnob.BorderSizePixel  = 0
gasKnob.ZIndex           = 3
corner(gasKnob, 99)
local gasRangeMin = mkLabel(gasCard,"1K",11,14,68,0,13,false,Color3.fromRGB(55,55,55))
local gasRangeMax = mkLabel(gasCard,"10M",11,0,68,1,13,false,Color3.fromRGB(55,55,55))
gasRangeMax.TextXAlignment = Enum.TextXAlignment.Right
gasRangeMax.Position = UDim2.new(1,-14,0,68)
local reg3 = mkSectionHeader("AUTO STEAL", 90, false)
local stealStatusCard = mkCard(44, 91)
reg3(stealStatusCard)
local stealStatusDot = Instance.new("Frame", stealStatusCard)
stealStatusDot.Size             = UDim2.new(0,7,0,7)
stealStatusDot.Position         = UDim2.new(0,14,0,12)
stealStatusDot.BackgroundColor3 = Color3.fromRGB(50,50,50)
stealStatusDot.BorderSizePixel  = 0
corner(stealStatusDot, 99)
local stealStatusLabel = mkLabel(stealStatusCard,"INACTIVE",11,28,6,0.75,16,true,Color3.fromRGB(65,65,65))
local stealCard = mkCard(50, 92)
reg3(stealCard)
mkLabel(stealCard,"Auto Steal",13,14,10,0.7,18,true)
do local l=mkLabel(stealCard,"Steals refineries faster",12,14,28,0,15,false,Color3.fromRGB(70,70,70)); l.Size=UDim2.new(0,152,0,15); l.TextTruncate=Enum.TextTruncate.AtEnd end
local stealSwitchBg, stealSwitchKnob, stealSwitchBtn = mkSwitch(stealCard, false)
local productionCard = mkCard(58, 93)
reg3(productionCard)
mkLabel(productionCard,"Increase Production",13,14,9,0.7,18,true)
do local l=mkLabel(productionCard,"Boosts ProductionRate attribute",12,14,27,0,14,false,Color3.fromRGB(70,70,70)); l.Size=UDim2.new(0,190,0,14); l.TextTruncate=Enum.TextTruncate.AtEnd end
local increaseProductionBtn = Instance.new("TextButton", productionCard)
increaseProductionBtn.Text             = "Run"
increaseProductionBtn.Size             = UDim2.new(0,70,0,28)
increaseProductionBtn.Position         = UDim2.new(1,-84,0.5,-14)
increaseProductionBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
increaseProductionBtn.TextColor3       = Color3.fromRGB(160,160,160)
increaseProductionBtn.TextSize         = 14
increaseProductionBtn.Font             = Enum.Font.GothamBold
increaseProductionBtn.BorderSizePixel  = 0
corner(increaseProductionBtn, 7)
stroke(increaseProductionBtn, Color3.fromRGB(45,45,45))
increaseProductionBtn.MouseButton1Click:Connect(function()
    local buildings = getBuildings()
    if not buildings then return end
    for _, refinery in ipairs(getRefineries(buildings)) do
        increaseProduction(refinery)
    end
end)
local afkCard = mkCard(44, 98)
local afkCheckBg = Instance.new("Frame", afkCard)
afkCheckBg.Size             = UDim2.new(0,18,0,18)
afkCheckBg.Position         = UDim2.new(0,14,0.5,-9)
afkCheckBg.BackgroundColor3 = Color3.fromRGB(22,22,22)
afkCheckBg.BorderSizePixel  = 0
corner(afkCheckBg, 4)
stroke(afkCheckBg, Color3.fromRGB(50,50,50))
local afkCheckMark = Instance.new("TextLabel", afkCheckBg)
afkCheckMark.Text              = ""
afkCheckMark.Size              = UDim2.new(1,0,1,0)
afkCheckMark.BackgroundTransparency = 1
afkCheckMark.TextColor3        = Color3.fromRGB(120,220,170)
afkCheckMark.TextSize          = 13
afkCheckMark.Font              = Enum.Font.GothamBold
afkCheckMark.TextXAlignment    = Enum.TextXAlignment.Center
local afkLabel = Instance.new("TextLabel", afkCard)
afkLabel.Text              = "Anti-AFK"
afkLabel.Size              = UDim2.new(1,-80,0,16)
afkLabel.Position          = UDim2.new(0,40,0.5,-12)
afkLabel.BackgroundTransparency = 1
afkLabel.TextColor3        = Color3.fromRGB(155,155,155)
afkLabel.TextSize          = 13
afkLabel.Font              = Enum.Font.GothamSemibold
afkLabel.TextXAlignment    = Enum.TextXAlignment.Left
local afkSub = Instance.new("TextLabel", afkCard)
afkSub.Text              = "Prevents idle kick"
afkSub.Size              = UDim2.new(1,-80,0,13)
afkSub.Position          = UDim2.new(0,40,0.5,4)
afkSub.BackgroundTransparency = 1
afkSub.TextColor3        = Color3.fromRGB(60,60,60)
afkSub.TextSize          = 10
afkSub.Font              = Enum.Font.Gotham
afkSub.TextXAlignment    = Enum.TextXAlignment.Left
local afkBtn = Instance.new("TextButton", afkCard)
afkBtn.Size              = UDim2.new(1,0,1,0)
afkBtn.BackgroundTransparency = 1
afkBtn.Text              = ""
afkBtn.MouseButton1Click:Connect(function()
    antiAfkOn = not antiAfkOn
    setAntiAfk(antiAfkOn)
    if antiAfkOn then
        afkCheckMark.Text = "✓"
        TweenService:Create(afkCheckBg, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30,75,55)
        }):Play()
    else
        afkCheckMark.Text = ""
        TweenService:Create(afkCheckBg, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(22,22,22)
        }):Play()
    end
end)
local footerFrame = Instance.new("Frame", scroll)
footerFrame.Size              = UDim2.new(1,0,0,22)
footerFrame.BackgroundTransparency = 1
footerFrame.LayoutOrder       = 99
local footerLbl = Instance.new("TextLabel", footerFrame)
footerLbl.Text              = "made by dekxonn"
footerLbl.Size              = UDim2.new(1,0,1,0)
footerLbl.BackgroundTransparency = 1
footerLbl.TextColor3        = Color3.fromRGB(144,144,144)
footerLbl.TextSize          = 10
footerLbl.Font              = Enum.Font.Gotham
footerLbl.TextXAlignment    = Enum.TextXAlignment.Center
do
    local dragging, dStart, dPos = false, nil, nil
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dStart = i.Position; dPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - dStart
            main.Position = UDim2.new(dPos.X.Scale, dPos.X.Offset+d.X, dPos.Y.Scale, dPos.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0,MAIN_W,0,TITLE_H) or UDim2.new(0,MAIN_W,0,MAX_H)
    }):Play()
    scroll.Visible       = not minimized
    titleSep.Visible     = not minimized
    titleBarBottom.Visible = not minimized
    minBtn.Text          = "—"
end)
closeBtn.MouseButton1Click:Connect(function()
    enabled      = false
    sellEnabled  = false
    stealEnabled = false
    setAntiAfk(false)
    if farmThread  then task.cancel(farmThread);  farmThread  = nil end
    if sellThread  then task.cancel(sellThread);  sellThread  = nil end
    if stealThread then task.cancel(stealThread); stealThread = nil end
    TweenService:Create(main, TweenInfo.new(0.15), {Size = UDim2.new(0,MAIN_W,0,0)}):Play()
    task.delay(0.18, function() gui:Destroy() end)
end)
local function updateFarmVisual()
    animSwitch(switchBg, switchKnob, enabled)
    TweenService:Create(statusDot, TweenInfo.new(0.18), {
        BackgroundColor3 = enabled and Color3.fromRGB(120,220,170) or Color3.fromRGB(50,50,50)
    }):Play()
    statusLabel.Text       = enabled and "ACTIVE" or "INACTIVE"
    statusLabel.TextColor3 = enabled and Color3.fromRGB(195,195,195) or Color3.fromRGB(65,65,65)
end
local function updateStealVisual()
    animSwitch(stealSwitchBg, stealSwitchKnob, stealEnabled)
    TweenService:Create(stealStatusDot, TweenInfo.new(0.18), {
        BackgroundColor3 = stealEnabled and Color3.fromRGB(120,220,170) or Color3.fromRGB(50,50,50)
    }):Play()
    stealStatusLabel.Text       = stealEnabled and "ACTIVE" or "INACTIVE"
    stealStatusLabel.TextColor3 = stealEnabled and Color3.fromRGB(195,195,195) or Color3.fromRGB(65,65,65)
end
switchBtn.MouseButton1Click:Connect(function()
    enabled = not enabled
    updateFarmVisual()
    if enabled then
        if farmThread then task.cancel(farmThread) end
        farmThread = task.spawn(farmLoop)
    else
        if farmThread then task.cancel(farmThread); farmThread = nil end
    end
end)
stealSwitchBtn.MouseButton1Click:Connect(function()
    stealEnabled = not stealEnabled
    updateStealVisual()
    if stealEnabled then
        if stealThread then task.cancel(stealThread) end
        stealThread = task.spawn(stealLoop)
    else
        if stealThread then task.cancel(stealThread); stealThread = nil end
    end
end)
local function setSlider(alpha)
    alpha      = math.clamp(alpha, 0, 1)
    tweenSpeed = MIN_S + (MAX_S - MIN_S) * alpha
    tweenSpeed = math.floor(tweenSpeed * 10 + 0.5) / 10
    speedVal.Text  = string.format("%.1fs", tweenSpeed)
    fill.Size      = UDim2.new(alpha, 0, 1, 0)
    knob.Position  = UDim2.new(alpha, 0, 0.5, 0)
end
local function alphaFromX(x)
    return (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
end
track.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderActive = true; setSlider(alphaFromX(i.Position.X))
    end
end)
knob.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then sliderActive = true end
end)
UserInputService.InputChanged:Connect(function(i)
    if sliderActive and i.UserInputType == Enum.UserInputType.MouseMovement then
        setSlider(alphaFromX(i.Position.X))
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then sliderActive = false end
end)
sellSwitchBtn.MouseButton1Click:Connect(function()
    sellEnabled = not sellEnabled
    animSwitch(sellSwitchBg, sellSwitchKnob, sellEnabled)
    if sellEnabled then
        if sellThread then task.cancel(sellThread) end
        sellThread = task.spawn(sellLoop)
    else
        if sellThread then task.cancel(sellThread); sellThread = nil end
    end
end)
local function updatePrice(delta)
    sellPrice = math.clamp(sellPrice + delta, 1, 30)
    priceDisplay.Text = tostring(sellPrice)
end
local function btnHold(btn, delta)
    btn.MouseButton1Down:Connect(function()
        updatePrice(delta)
        local held = true
        task.spawn(function()
            task.wait(0.4)
            while held do
                updatePrice(delta)
                task.wait(0.1)
            end
        end)
        btn.MouseButton1Up:Connect(function() held = false end)
    end)
end
btnHold(minusBtn, -1)
btnHold(plusBtn,   1)
local function formatGas(v)
    if v >= 1000000 then return string.format("%.1fM", v/1000000)
    elseif v >= 1000 then return string.format("%dK", math.floor(v/1000))
    else return tostring(v) end
end
local function gasAlphaToValue(alpha)
    alpha = math.clamp(alpha, 0, 1)
    if alpha <= GAS_Z1_ALPHA then
        local step = math.floor(alpha / GAS_Z1_ALPHA * GAS_Z1_STEPS + 0.5)
        return GAS_Z1_START + step * GAS_Z1_STEP
    elseif alpha <= GAS_Z2_ALPHA then
        local zAlpha = (alpha - GAS_Z1_ALPHA) / (GAS_Z2_ALPHA - GAS_Z1_ALPHA)
        local step   = math.floor(zAlpha * GAS_Z2_STEPS + 0.5)
        return GAS_Z2_START + step * GAS_Z2_STEP
    else
        local zAlpha = (alpha - GAS_Z2_ALPHA) / (1 - GAS_Z2_ALPHA)
        local step   = math.floor(zAlpha * GAS_Z3_STEPS + 0.5)
        return GAS_Z3_START + step * GAS_Z3_STEP
    end
end
local function gasValueToAlpha(v)
    if v <= GAS_Z1_END then
        local step = (v - GAS_Z1_START) / GAS_Z1_STEP
        return step / GAS_TOTAL_STEPS
    elseif v <= GAS_Z2_END then
        local step = (v - GAS_Z2_START) / GAS_Z2_STEP
        return GAS_Z1_ALPHA + step / GAS_TOTAL_STEPS
    else
        local step = (v - GAS_Z3_START) / GAS_Z3_STEP
        return GAS_Z2_ALPHA + step / GAS_TOTAL_STEPS
    end
end
local gasSliderActive = false
local function setGasSlider(alpha)
    alpha       = math.clamp(alpha, 0, 1)
    minGasoline = gasAlphaToValue(alpha)
    local snappedAlpha = gasValueToAlpha(minGasoline)
    gasVal.Text       = formatGas(minGasoline)
    gasFill.Size      = UDim2.new(snappedAlpha, 0, 1, 0)
    gasKnob.Position  = UDim2.new(snappedAlpha, 0, 0.5, 0)
end
local function gasAlphaFromX(x)
    return (x - gasTrack.AbsolutePosition.X) / gasTrack.AbsoluteSize.X
end
gasTrack.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        gasSliderActive = true; setGasSlider(gasAlphaFromX(i.Position.X))
    end
end)
gasKnob.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then gasSliderActive = true end
end)
UserInputService.InputChanged:Connect(function(i)
    if gasSliderActive and i.UserInputType == Enum.UserInputType.MouseMovement then
        setGasSlider(gasAlphaFromX(i.Position.X))
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then gasSliderActive = false end
end)
for _, btn in ipairs({closeBtn, minBtn, minusBtn, plusBtn}) do
    local norm = btn.BackgroundColor3
    local hov  = btn == closeBtn and Color3.fromRGB(55,22,22)
              or btn == minBtn   and Color3.fromRGB(40,40,40)
              or                     Color3.fromRGB(42,42,42)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = hov}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = norm}):Play()
    end)
end
local counterConn1, counterConn2
local function refreshCounter()
    local buildings = getBuildings()
    if not buildings then
        drillCountLabel.Text       = "plot not found"
        drillCountLabel.TextColor3 = Color3.fromRGB(55,35,35)
        return
    end
    local n = #getRefineries(buildings)
    drillCountLabel.Text       = n .. " refiner" .. (n == 1 and "y" or "ies") .. " found"
    drillCountLabel.TextColor3 = Color3.fromRGB(120,120,120)
end
local function hookCounter()
    if counterConn1 then counterConn1:Disconnect() end
    if counterConn2 then counterConn2:Disconnect() end
    local buildings = getBuildings()
    if not buildings then return end
    counterConn1 = buildings.ChildAdded:Connect(refreshCounter)
    counterConn2 = buildings.ChildRemoved:Connect(refreshCounter)
    refreshCounter()
end
task.spawn(function()
    while gui.Parent do hookCounter(); task.wait(5) end
end)
task.spawn(function()
    while gui.Parent do
        local okP, price = pcall(function()
            return game:GetService("ReplicatedStorage").GasPrice.Value
        end)
        local priceAbove = okP and type(price) == "number" and price >= sellPrice
        if okP and price then
            gasPriceVal.Text       = "$" .. tostring(price)
            gasPriceVal.TextColor3 = priceAbove
                and Color3.fromRGB(110,210,160)
                or  Color3.fromRGB(180,80,80)
        end
        local okT, timerTxt = pcall(function()
            return lp.PlayerGui.Main.SellGas.NextStock.Text
        end)
        if okT and timerTxt and tostring(timerTxt) ~= "" then
            gasTimerLabel.Text = "Next Price in: " .. tostring(timerTxt)
        else
            gasTimerLabel.Text = "Next Price in: —"
        end
        local okS, spRaw = pcall(function()
            return lp.PlayerGui.Main.SellGas.Main.Sell.TextLabel.Text
        end)
        local extracted = (okS and spRaw) and spRaw:match("%$[%d,]+") or "—"
        sellPriceVal.Text = extracted
        do
            local gasPriceStr = (okP and price) and ("$"..tostring(price)) or "$—"
            local sellStr     = extracted ~= "—" and extracted or "$—"
            local gasColor    = priceAbove and "#6ED8A8" or "#D06060"
            local sellColor   = "#6ED8A8"
            local tagColor    = sellEnabled and "#DEDEDE" or "#888888"
            local tagText     = sellEnabled and "ON" or "OFF"
            bylineLabel.Text = string.format(
                '<font color="%s">Gas %s</font>  <font color="%s">Sell %s</font>  <font color="%s">[AutoSell %s]</font>',
                gasColor, gasPriceStr, sellColor, sellStr, tagColor, tagText
            )
        end
        task.wait(1)
    end
end)
