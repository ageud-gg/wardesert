local player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

local Aiming = false
local FOVAngle = 45
local FOVCircleRadius = 200
local ShowFOVCircle = true

-- Drawing API Circle
local circle = Drawing.new("Circle")
circle.Thickness = 2
circle.Transparency = 1
circle.Color = Color3.fromRGB(255, 0, 0)
circle.Visible = ShowFOVCircle
circle.Filled = false

-- GUI Cleanup
pcall(function()
	if game.CoreGui:FindFirstChild("FOVGui") then
		game.CoreGui.FOVGui:Destroy()
	end
end)

-- GUI
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "FOVGui"

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 200, 0, 40)
toggleBtn.Position = UDim2.new(0, 20, 0, 100)
toggleBtn.Text = "Toggle FOV Circle"
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Parent = gui

local radiusBox = Instance.new("TextBox")
radiusBox.Size = UDim2.new(0, 200, 0, 40)
radiusBox.Position = UDim2.new(0, 20, 0, 150)
radiusBox.PlaceholderText = "FOV Radius (" .. FOVCircleRadius .. ")"
radiusBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
radiusBox.TextColor3 = Color3.fromRGB(255, 255, 255)
radiusBox.ClearTextOnFocus = true
radiusBox.Text = ""
radiusBox.Parent = gui

for _, v in pairs({toggleBtn, radiusBox}) do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = v
end

-- Button Actions
toggleBtn.MouseButton1Click:Connect(function()
	ShowFOVCircle = not ShowFOVCircle
	circle.Visible = ShowFOVCircle
end)

radiusBox.FocusLost:Connect(function()
	local num = tonumber(radiusBox.Text)
	if num and num > 0 then
		FOVCircleRadius = num
		circle.Radius = FOVCircleRadius
		radiusBox.PlaceholderText = "FOV Radius (" .. FOVCircleRadius .. ")"
		radiusBox.Text = ""
	end
end)

-- Helper Functions
local function isEnemy(other)
	return other.Team ~= player.Team
end

local function getTargetPart(char)
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function isVisible(pos, char)
	local ray = Ray.new(camera.CFrame.Position, (pos - camera.CFrame.Position).Unit * 1000)
	local hit = workspace:FindPartOnRay(ray, player.Character or nil)
	return not hit or hit:IsDescendantOf(char)
end

local function calculateFOV(pos)
	local camVec = (pos - camera.CFrame.Position).Unit
	local camLook = camera.CFrame.LookVector
	local dot = math.clamp(camLook:Dot(camVec), -1, 1)
	return math.acos(dot) * (180 / math.pi)
end

local function isInFOVCircle(pos)
	local screenPoint, onScreen = camera:WorldToViewportPoint(pos)
	if onScreen then
		local mousePos = UserInputService:GetMouseLocation()
		local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
		return dist <= FOVCircleRadius
	end
	return false
end

local function getClosestEnemy()
	local closest = nil
	local shortest = math.huge

	for _, other in ipairs(game.Players:GetPlayers()) do
		if other ~= player and other.Team and player.Team and isEnemy(other) and other.Character then
			local part = getTargetPart(other.Character)
			if part then
				local screenPoint, onScreen = camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local mousePos = UserInputService:GetMouseLocation()
					local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
					local angle = calculateFOV(part.Position)
					if dist < shortest and angle <= FOVAngle and isInFOVCircle(part.Position) and isVisible(part.Position, other.Character) then
						shortest = dist
						closest = other
					end
				end
			end
		end
	end

	return closest
end

local function AimLock()
	local target = getClosestEnemy()
	if target and target.Character then
		local part = getTargetPart(target.Character)
		if part then
			local camPos = camera.CFrame.Position
			camera.CFrame = camera.CFrame:Lerp(CFrame.new(camPos, part.Position), 0.15)
		end
	end
end

-- Controls
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.E then
		Aiming = not Aiming
		rconsoleprint("[Aimlock] Aiming toggled: " .. tostring(Aiming) .. "\n")
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		Aiming = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		Aiming = false
	end
end)

-- RenderStepped loop
RunService.RenderStepped:Connect(function()
	circle.Position = UserInputService:GetMouseLocation()
	circle.Radius = FOVCircleRadius
	circle.Visible = ShowFOVCircle

	if Aiming then
		AimLock()
	end
end)
