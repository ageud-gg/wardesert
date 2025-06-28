local ESPSection = win:Tab("ESP")

local ESPEnabled = false
local ShowBoxes = false
local ShowTracers = false
local ShowDistance = false
local UseChams = false
local OnlyEnemies = false

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local espCache = {}
local playerConnections = {}

local function isEnemy(player)
	return player.Team ~= LocalPlayer.Team
end

local function clearESP()
	for _, esp in pairs(espCache) do
		for _, line in pairs(esp.Lines or {}) do
			pcall(function() line.Visible = false end)
		end
		pcall(function() esp.Text.Visible = false end)
		if esp.Highlight then
			esp.Highlight.Enabled = false
		end
	end
end

local function removeESP(player)
	if espCache[player] then
		for _, obj in pairs(espCache[player].Lines or {}) do pcall(function() obj:Remove() end) end
		pcall(function() espCache[player].Text:Remove() end)
		if espCache[player].Highlight then
			espCache[player].Highlight:Destroy()
		end
		espCache[player] = nil
	end

	if playerConnections[player] then
		pcall(function() playerConnections[player]:Disconnect() end)
		playerConnections[player] = nil
	end
end

local function createESP(player, character)
	if espCache[player] then return end
	if not character:FindFirstChild("Head") or not character:FindFirstChild("HumanoidRootPart") then return end

	local lines = {
		Top = Drawing.new("Line"),
		Bottom = Drawing.new("Line"),
		Left = Drawing.new("Line"),
		Right = Drawing.new("Line"),
		Tracer = Drawing.new("Line")
	}

	for _, line in pairs(lines) do
		line.Visible = false
		line.Thickness = 2
	end
	lines.Tracer.Thickness = 1.5

	local text = Drawing.new("Text")
	text.Size = 16
	text.Color = Color3.new(1, 1, 1)
	text.Center = true
	text.Outline = true
	text.Visible = false

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.new(0, 0, 0)
	highlight.Enabled = false
	highlight.Parent = character

	espCache[player] = {
		Character = character,
		Lines = lines,
		Text = text,
		Highlight = highlight
	}

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		playerConnections[player] = humanoid.Died:Connect(function()
			removeESP(player)
		end)
	end
end

local function trackPlayer(player)
	if player == LocalPlayer then return end

	if player.Character then
		createESP(player, player.Character)
	end

	-- Remove previous connections if any
	if playerConnections[player] and typeof(playerConnections[player]) == "RBXScriptConnection" then
		playerConnections[player]:Disconnect()
	end

	playerConnections[player] = player.CharacterAdded:Connect(function(char)
		task.wait(0.25)
		createESP(player, char)
	end)

	player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeESP(player)
		end
	end)
end

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(removeESP)

local playerList = {}

local function refreshPlayerList()
	playerList = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			table.insert(playerList, p)
		end
	end
end

refreshPlayerList()
Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(refreshPlayerList)

local updateIndex = 1
local updatesPerFrame = 6

RunService.RenderStepped:Connect(function()
	if not ESPEnabled then
		clearESP()
		return
	end

	local screenBottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

	for i = 1, updatesPerFrame do
		if #playerList == 0 then break end
		local player = playerList[updateIndex]
		updateIndex = updateIndex + 1
		if updateIndex > #playerList then updateIndex = 1 end

		local esp = espCache[player]
		if not esp then continue end
		local char = esp.Character
		if not char or not char:FindFirstChild("Head") or not char:FindFirstChild("HumanoidRootPart") then
			for _, l in pairs(esp.Lines) do l.Visible = false end
			esp.Text.Visible = false
			esp.Highlight.Enabled = false
			continue
		end

		local humanoid = char:FindFirstChildWhichIsA("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			for _, l in pairs(esp.Lines) do l.Visible = false end
			esp.Text.Visible = false
			esp.Highlight.Enabled = false
			continue
		end

		if OnlyEnemies and not isEnemy(player) then
			for _, l in pairs(esp.Lines) do l.Visible = false end
			esp.Text.Visible = false
			esp.Highlight.Enabled = false
			continue
		end

		local headPos, onScreen1 = Camera:WorldToViewportPoint(char.Head.Position)
		local rootPos, onScreen2 = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position - Vector3.new(0, 3, 0))

		if not (onScreen1 and onScreen2) then
			for _, l in pairs(esp.Lines) do l.Visible = false end
			esp.Text.Visible = false
			esp.Highlight.Enabled = false
			continue
		end

		local teamColor = player.Team and player.Team.TeamColor.Color or Color3.new(1, 1, 1)

		local boxHeight = math.abs(headPos.Y - rootPos.Y)
		local boxWidth = boxHeight / 2
		local topLeft = Vector2.new(rootPos.X - boxWidth / 2, headPos.Y)
		local topRight = Vector2.new(rootPos.X + boxWidth / 2, headPos.Y)
		local bottomLeft = Vector2.new(rootPos.X - boxWidth / 2, headPos.Y + boxHeight)
		local bottomRight = Vector2.new(rootPos.X + boxWidth / 2, headPos.Y + boxHeight)

		local lines = esp.Lines
		lines.Top.From = topLeft
		lines.Top.To = topRight
		lines.Bottom.From = bottomLeft
		lines.Bottom.To = bottomRight
		lines.Left.From = topLeft
		lines.Left.To = bottomLeft
		lines.Right.From = topRight
		lines.Right.To = bottomRight

		for name, line in pairs(lines) do
			if name ~= "Tracer" then
				line.Color = teamColor
				line.Visible = ShowBoxes and ESPEnabled
			end
		end

		lines.Tracer.Color = teamColor
		lines.Tracer.From = screenBottom
		lines.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
		lines.Tracer.Visible = ShowTracers and ESPEnabled

		if ShowDistance and ESPEnabled then
			local dist = (Camera.CFrame.Position - char.HumanoidRootPart.Position).Magnitude
			esp.Text.Text = math.floor(dist) .. "m"
			esp.Text.Position = Vector2.new(rootPos.X, topLeft.Y - 15)
			esp.Text.Visible = true
		else
			esp.Text.Visible = false
		end

		if UseChams and ESPEnabled then
			esp.Highlight.FillColor = teamColor
			esp.Highlight.Adornee = char
			esp.Highlight.Enabled = true
		else
			esp.Highlight.Enabled = false
		end
	end
end)

ESPSection:Toggle("ESP Enabled", false, function(v)
	ESPEnabled = v
	if v then
		refreshPlayerList()
		for _, p in pairs(playerList) do
			if p.Character then createESP(p, p.Character) end
		end
	else
		clearESP()
	end
end)

ESPSection:Toggle("Boxes", false, function(v) ShowBoxes = v end)
ESPSection:Toggle("Tracers", false, function(v) ShowTracers = v end)
ESPSection:Toggle("Distance Display", false, function(v) ShowDistance = v end)
ESPSection:Toggle("Chams (Highlight)", false, function(v) UseChams = v end)
ESPSection:Toggle("Only Show Enemies", false, function(v) OnlyEnemies = v end)
