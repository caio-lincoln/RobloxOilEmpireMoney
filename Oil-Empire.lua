local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LOCAL_PLAYER = Players.LocalPlayer
if not LOCAL_PLAYER then
	return
end

local DEV_USER_IDS = {}

local function isAuthorized()
	if RunService:IsStudio() then
		return true
	end

	if DEV_USER_IDS[LOCAL_PLAYER.UserId] then
		return true
	end

	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == LOCAL_PLAYER.UserId then
		return true
	end

	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == LOCAL_PLAYER.UserId then
		return true
	end

	return false
end

if not isAuthorized() then
	return
end

local TOGGLE_KEYCODES = {
	[Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.F4] = true,
}

local enabled = false
local highlightsByPlayer = {}
local connections = {}

local function disconnectAll()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
end

local function cleanupHighlights()
	for _, h in pairs(highlightsByPlayer) do
		if h and h.Parent then
			h:Destroy()
		end
	end
	table.clear(highlightsByPlayer)
end

local function ensureGui()
	local pg = LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end

	local existing = pg:FindFirstChild("DevESPStatusGui")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DevESPStatusGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.fromOffset(12, 12)
	label.Size = UDim2.fromOffset(260, 36)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.GothamMedium
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "Dev ESP: OFF  (RightShift/F4)"
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.Parent = label

	gui.Parent = pg
	return gui
end

local function setGuiEnabled(isOn)
	local gui = ensureGui()
	if not gui then
		return
	end

	local label = gui:FindFirstChild("Status")
	if label and label:IsA("TextLabel") then
		label.Text = ("Dev ESP: %s  (RightShift/F4)"):format(isOn and "ON" or "OFF")
		label.BackgroundColor3 = isOn and Color3.fromRGB(10, 60, 20) or Color3.fromRGB(20, 20, 20)
	end
end

local function getCharacterRoot(character)
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function createOrUpdateHighlightForPlayer(player, characterOverride)
	if player == LOCAL_PLAYER then
		return
	end

	local character = characterOverride or player.Character
	local root = getCharacterRoot(character)
	if not root then
		return
	end

	local existing = highlightsByPlayer[player]
	if existing and existing.Parent then
		existing.Adornee = character
		return
	end

	local h = Instance.new("Highlight")
	h.Name = "DevESPHighlight"
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = character
	h.FillTransparency = 0.65
	h.OutlineTransparency = 0
	h.FillColor = Color3.fromRGB(0, 170, 255)
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.Parent = root

	highlightsByPlayer[player] = h
end

local function hookPlayer(player)
	if player == LOCAL_PLAYER then
		return
	end

	table.insert(connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			if not enabled then
				return
			end

			if not getCharacterRoot(character) then
				character:WaitForChild("HumanoidRootPart", 5)
			end

			if enabled then
				createOrUpdateHighlightForPlayer(player, character)
			end
		end)
	end))

	table.insert(connections, player.CharacterRemoving:Connect(function()
		local h = highlightsByPlayer[player]
		if h and h.Parent then
			h:Destroy()
		end
		highlightsByPlayer[player] = nil
	end))
end

local function enable()
	if enabled then
		return
	end
	enabled = true
	setGuiEnabled(true)

	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
		createOrUpdateHighlightForPlayer(p)
	end

	table.insert(connections, Players.PlayerAdded:Connect(function(p)
		hookPlayer(p)
		task.defer(function()
			if enabled then
				createOrUpdateHighlightForPlayer(p)
			end
		end)
	end))

	table.insert(connections, Players.PlayerRemoving:Connect(function(p)
		local h = highlightsByPlayer[p]
		if h and h.Parent then
			h:Destroy()
		end
		highlightsByPlayer[p] = nil
	end))

end

local function disable()
	if not enabled then
		return
	end
	enabled = false
	setGuiEnabled(false)
	disconnectAll()
	cleanupHighlights()
end

setGuiEnabled(false)

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard and TOGGLE_KEYCODES[input.KeyCode] then
		if enabled then
			disable()
		else
			enable()
		end
	end
end))
