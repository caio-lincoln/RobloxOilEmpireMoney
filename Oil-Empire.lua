local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

if not RunService:IsClient() then
	return
end

local LOCAL_PLAYER = Players.LocalPlayer
while not LOCAL_PLAYER do
	task.wait()
	LOCAL_PLAYER = Players.LocalPlayer
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

	if game.PrivateServerId ~= "" and (game.PrivateServerOwnerId == LOCAL_PLAYER.UserId or game.PrivateServerOwnerId == 0) then
		return true
	end

	return false
end

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
	local pg = LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui") or LOCAL_PLAYER:WaitForChild("PlayerGui", 10)
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

local function setGuiStatus(text, isOn)
	local gui = ensureGui()
	if not gui then
		return
	end

	local label = gui:FindFirstChild("Status")
	if label and label:IsA("TextLabel") then
		label.Text = text
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
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = character
	h.FillTransparency = 0.65
	h.OutlineTransparency = 0
	h.FillColor = Color3.fromRGB(0, 170, 255)
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.Parent = workspace

	highlightsByPlayer[player] = h
end

local function hasLineOfSight(targetRoot)
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	local origin = camera.CFrame.Position
	local direction = targetRoot.Position - origin
	if direction.Magnitude < 0.01 then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local localChar = LOCAL_PLAYER.Character
	if localChar then
		table.insert(ignore, localChar)
	end
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(origin, direction, params)
	if not result then
		return true
	end

	if result.Instance and result.Instance:IsDescendantOf(targetRoot.Parent) then
		return true
	end

	return false
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
	setGuiStatus("Dev Overlay: ON  (RightShift/F4)", true)

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

	table.insert(connections, RunService.RenderStepped:Connect(function()
		if not enabled then
			return
		end

		for player, highlight in pairs(highlightsByPlayer) do
			if not highlight or not highlight.Parent then
				highlightsByPlayer[player] = nil
			else
				local character = player.Character
				local root = getCharacterRoot(character)
				if character and root and highlight.Adornee == character then
					highlight.Enabled = hasLineOfSight(root)
				else
					highlight.Enabled = false
				end
			end
		end
	end))
end

local function disable()
	if not enabled then
		return
	end
	enabled = false
	setGuiStatus("Dev Overlay: OFF  (RightShift/F4)", false)
	disconnectAll()
	cleanupHighlights()
end

if isAuthorized() then
	setGuiStatus("Dev Overlay: OFF  (RightShift/F4)", false)
else
	setGuiStatus("Dev Overlay: BLOQUEADO (sem autorização)", false)
end

ContextActionService:BindAction("DevOverlayToggle", function(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if not isAuthorized() then
		return Enum.ContextActionResult.Pass
	end

	if enabled then
		disable()
	else
		enable()
	end

	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.RightShift, Enum.KeyCode.F4)
