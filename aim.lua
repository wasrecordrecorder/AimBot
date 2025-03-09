
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Aimbot & Hitboxes Suite",
    SubTitle = "Integrated",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 400),
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Aimbot = Window:AddTab({Title = "Aimbot", Icon = "crosshair"}),
    Hitboxes = Window:AddTab({Title = "Hitboxes", Icon = "box"}),
    TriggerBot = Window:AddTab({Title = "Trigger Bot", Icon = "target"}),
    Visuals = Window:AddTab({Title = "Visuals", Icon = "eye"}),
    Settings = Window:AddTab({Title = "Settings", Icon = "settings"})
}

local config = {
    FOV = 150,                   
    Smoothing = 1,                
    AimbotEnabled = false,        
    AimbotToggleKey = Enum.KeyCode.F,
    AimbotPart = "Head",
    HitboxesEnabled = false,     
    HitboxMultiplier = 6,         
    TriggerBotEnabled = false,    
    TriggerBotToggleKey = Enum.KeyCode.T, 
    TriggerBotTeamCheck = true,   
    TriggerBotDelay = 0.1,         

    ESPEnabled = false,       
    ESPColor = Color3.new(1, 1, 1), 
    ESPShowNames = true,          
    ESPShowDistance = true,       
    ESPMaxDistance = 500,
    ESPShowHealth = false,
    ESPHeadDot = false     
}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer


local statusCircle = Drawing.new("Circle")
statusCircle.Visible = true
statusCircle.Thickness = 2
statusCircle.Radius = 15
statusCircle.Color = Color3.fromRGB(255, 0, 0) 
statusCircle.Position = Vector2.new(30, workspace.CurrentCamera.ViewportSize.Y - 30)

local dragging = false
local dragOffset = Vector2.new(0, 0)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = UserInputService:GetMouseLocation()
        if (mousePos - statusCircle.Position).Magnitude <= statusCircle.Radius then
            dragging = true
            dragOffset = statusCircle.Position - mousePos
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mousePos = UserInputService:GetMouseLocation()
        statusCircle.Position = mousePos + dragOffset
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)


local function getClosestVisiblePlayer(camera)
    local ray = Ray.new(camera.CFrame.Position, camera.CFrame.LookVector)
    local closestPlayer = nil
    local closestDistance = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character and character:FindFirstChild("Head") then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local headPosition = character.Head.Position
                    local targetPosition = ray:ClosestPoint(headPosition)
                    local distance = (targetPosition - headPosition).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end


local FOVring = nil
local aimbotConnection = nil

local function updateAimbot()
    if config.AimbotEnabled and FOVring then
        local currentCamera = workspace.CurrentCamera
        local crosshairPosition = currentCamera.ViewportSize / 2
        local closestPlayer = getClosestVisiblePlayer(currentCamera)
        if closestPlayer and closestPlayer.Character then
            local character = closestPlayer.Character
            local targetPart = nil

            if config.AimbotPart == "Legs" then
                targetPart = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
            else
                targetPart = character:FindFirstChild(config.AimbotPart)
            end

            if targetPart then
                local targetPosition = targetPart.Position
                local targetScreenPos, onScreen = currentCamera:WorldToScreenPoint(targetPosition)
                if onScreen then
                    local distanceToCrosshair = (Vector2.new(targetScreenPos.X, targetScreenPos.Y) - crosshairPosition).Magnitude
                    if distanceToCrosshair < config.FOV then
                        currentCamera.CFrame = currentCamera.CFrame:Lerp(CFrame.new(currentCamera.CFrame.Position, targetPosition), config.Smoothing)
                    end
                end
            end
        end
    end
end


local function EnableAimbot()
    config.AimbotEnabled = true
    FOVring = Drawing.new("Circle")
    FOVring.Visible = true
    FOVring.Thickness = 1.5
    FOVring.Radius = config.FOV
    FOVring.Transparency = 1
    FOVring.Color = Color3.fromRGB(255, 128, 128)
    FOVring.Position = workspace.CurrentCamera.ViewportSize / 2
    aimbotConnection = RunService.RenderStepped:Connect(updateAimbot)
    statusCircle.Color = Color3.fromRGB(0, 255, 0)
end

local function DisableAimbot()
    config.AimbotEnabled = false
    if FOVring then
        FOVring:Remove()
        FOVring = nil
    end
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
    statusCircle.Color = Color3.fromRGB(255, 0, 0) 
end

local function toggleAimbot()
    if config.AimbotEnabled then
        DisableAimbot()
    else
        EnableAimbot()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == config.AimbotToggleKey then
        toggleAimbot()
    end
end)

local originalHeadSizes = {}
local lastHitboxTarget = nil

local function updateHitboxes()
    if config.HitboxesEnabled then
        local currentCamera = workspace.CurrentCamera
        local closestPlayer = getClosestVisiblePlayer(currentCamera)
        if closestPlayer and closestPlayer ~= LocalPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("Head") then
            local head = closestPlayer.Character.Head
            if lastHitboxTarget and lastHitboxTarget ~= closestPlayer then
                if lastHitboxTarget.Character and lastHitboxTarget.Character:FindFirstChild("Head") and originalHeadSizes[lastHitboxTarget] then
                    lastHitboxTarget.Character.Head.Size = originalHeadSizes[lastHitboxTarget]
                    originalHeadSizes[lastHitboxTarget] = nil
                end
            end
            lastHitboxTarget = closestPlayer
            if not originalHeadSizes[closestPlayer] then
                originalHeadSizes[closestPlayer] = head.Size
            end
            head.Size = originalHeadSizes[closestPlayer] * config.HitboxMultiplier
        else
            if lastHitboxTarget and lastHitboxTarget.Character and lastHitboxTarget.Character:FindFirstChild("Head") and originalHeadSizes[lastHitboxTarget] then
                lastHitboxTarget.Character.Head.Size = originalHeadSizes[lastHitboxTarget]
                originalHeadSizes[lastHitboxTarget] = nil
            end
            lastHitboxTarget = nil
        end
    else
        if lastHitboxTarget and lastHitboxTarget.Character and lastHitboxTarget.Character:FindFirstChild("Head") and originalHeadSizes[lastHitboxTarget] then
            lastHitboxTarget.Character.Head.Size = originalHeadSizes[lastHitboxTarget]
            originalHeadSizes[lastHitboxTarget] = nil
        end
        lastHitboxTarget = nil
    end
end

RunService.RenderStepped:Connect(updateHitboxes)

local triggerBotConnection = nil
local lastTriggerShot = 0

local function isTargetVisible(target)
    if not (target and target.Character and target.Character:FindFirstChild("Head")) then
        return false
    end
    local currentCamera = workspace.CurrentCamera
    local origin = currentCamera.CFrame.Position
    local targetHead = target.Character.Head
    local direction = targetHead.Position - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    if LocalPlayer.Character then
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    else
        rayParams.FilterDescendantsInstances = {}
    end
    local result = workspace:Raycast(origin, direction, rayParams)
    if result and result.Instance and result.Instance:IsDescendantOf(target.Character) then
        return true
    end
    return false
end

local function updateTriggerBot()
    if config.TriggerBotEnabled then
        local currentCamera = workspace.CurrentCamera
        local crosshairPosition = currentCamera.ViewportSize / 2
        local closestPlayer = getClosestVisiblePlayer(currentCamera)
        if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("Head") then
            if config.TriggerBotTeamCheck and closestPlayer.Team == LocalPlayer.Team then
                return
            end
            local targetHead = closestPlayer.Character.Head
            local headScreenPosition = currentCamera:WorldToScreenPoint(targetHead.Position)
            local distanceToCrosshair = (Vector2.new(headScreenPosition.X, headScreenPosition.Y) - crosshairPosition).Magnitude
            if distanceToCrosshair < config.FOV then
                if isTargetVisible(closestPlayer) then
                    if tick() - lastTriggerShot >= config.TriggerBotDelay then
                        local VirtualUser = game:GetService("VirtualUser")
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton1(Vector2.new())
                        lastTriggerShot = tick()
                    end
                end
            end
        end
    end
end

local function EnableTriggerBot()
    config.TriggerBotEnabled = true
    triggerBotConnection = RunService.RenderStepped:Connect(updateTriggerBot)
end

local function DisableTriggerBot()
    config.TriggerBotEnabled = false
    if triggerBotConnection then
        triggerBotConnection:Disconnect()
        triggerBotConnection = nil
    end
end

local function toggleTriggerBot()
    if config.TriggerBotEnabled then
        DisableTriggerBot()
    else
        EnableTriggerBot()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == config.TriggerBotToggleKey then
        toggleTriggerBot()
    end
end)

local ESP = { Objects = {} }

function ESP:Create(player)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = config.ESPColor
    box.Thickness = 1
    box.Filled = false

    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Outline = true
    text.Font = 2
    text.Size = 14
    text.Color = config.ESPColor

    local healthBarOutline = Drawing.new("Square")
    healthBarOutline.Visible = false
    healthBarOutline.Color = Color3.new(0, 0, 0)
    healthBarOutline.Thickness = 1
    healthBarOutline.Filled = false

    local healthBar = Drawing.new("Square")
    healthBar.Visible = false
    healthBar.Filled = true

    local healthText = Drawing.new("Text")
    healthText.Visible = false
    healthText.Center = false
    healthText.Outline = true
    healthText.Font = 2
    healthText.Size = 12
    healthText.Color = config.ESPColor

    local headDot = Drawing.new("Circle")
    headDot.Visible = false
    headDot.Radius = 5
    headDot.Filled = true
    headDot.Color = config.ESPColor

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not player.Character or not player.Character:FindFirstChild("Humanoid") then
            box.Visible = false
            text.Visible = false
            healthBarOutline.Visible = false
            healthBar.Visible = false
            healthText.Visible = false
            headDot.Visible = false
            return
        end
        
        local character = player.Character
        local camera = workspace.CurrentCamera
        local cf, size = character:GetBoundingBox()
        local corners = {}
        for x = -0.5, 0.5, 1 do
            for y = -0.5, 0.5, 1 do
                for z = -0.5, 0.5, 1 do
                    local offset = Vector3.new(x * size.X, y * size.Y, z * size.Z)
                    local worldPos = (cf + offset).Position
                    local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
                    if onScreen then
                        table.insert(corners, Vector2.new(screenPos.X, screenPos.Y))
                    end
                end
            end
        end

        if #corners > 0 then
            local minX = math.huge
            local maxX = -math.huge
            local minY = math.huge
            local maxY = -math.huge
            for _, pos in ipairs(corners) do
                minX = math.min(minX, pos.X)
                maxX = math.max(maxX, pos.X)
                minY = math.min(minY, pos.Y)
                maxY = math.max(maxY, pos.Y)
            end

            local boxWidth = maxX - minX
            local boxHeight = maxY - minY
            box.Position = Vector2.new(minX, minY)
            box.Size = Vector2.new(boxWidth, boxHeight)
            box.Visible = true

            local distance = 0
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                distance = (workspace.CurrentCamera.CFrame.Position - cf.Position).Magnitude
            end
            local label = ""
            if config.ESPShowNames then
                label = player.Name
            end
            if config.ESPShowDistance then
                label = label .. string.format(" [%.0f]", distance)
            end
            text.Text = label
            text.Position = Vector2.new(box.Position.X + box.Size.X/2, box.Position.Y - 20)
            text.Visible = true

            if config.ESPShowHealth then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    local healthColor
                    if healthPercent > 0.7 then
                        healthColor = Color3.new(0, 1, 0)    
                    elseif healthPercent > 0.3 then
                        healthColor = Color3.new(1, 0.65, 0)   
                    else
                        healthColor = Color3.new(1, 0, 0)     
                    end
                    healthBar.Color = healthColor

                    local margin = 2
                    local barWidth = 5 * 0.7 
                    local barX = box.Position.X - barWidth - margin
                    local barY = box.Position.Y
                    healthBarOutline.Position = Vector2.new(barX, barY)
                    healthBarOutline.Size = Vector2.new(barWidth, box.Size.Y)
                    healthBarOutline.Visible = true

                    local filledHeight = box.Size.Y * healthPercent
                    local filledY = barY + (box.Size.Y - filledHeight)
                    healthBar.Position = Vector2.new(barX, filledY)
                    healthBar.Size = Vector2.new(barWidth, filledHeight)
                    healthBar.Visible = true

                    healthText.Text = string.format("HP: %d%%", math.floor(healthPercent * 100))
                    healthText.Position = Vector2.new(barX - 40, barY + box.Size.Y/2 - 6)
                    healthText.Visible = true
                else
                    healthBar.Visible = false
                    healthBarOutline.Visible = false
                    healthText.Visible = false
                end
            else
                healthBar.Visible = false
                healthBarOutline.Visible = false
                healthText.Visible = false
            end

            if config.ESPHeadDot and character:FindFirstChild("Head") then
                local head = character.Head
                local headScreenPos, headOnScreen = camera:WorldToViewportPoint(head.Position)
                if headOnScreen then
                    headDot.Position = Vector2.new(headScreenPos.X, headScreenPos.Y)
                    headDot.Radius = 5
                    headDot.Color = config.ESPColor
                    headDot.Visible = true
                else
                    headDot.Visible = false
                end
            else
                headDot.Visible = false
            end
        else
            box.Visible = false
            text.Visible = false
            healthBar.Visible = false
            healthBarOutline.Visible = false
            healthText.Visible = false
            headDot.Visible = false
        end
    end)
    
    self.Objects[player] = {
        Box = box,
        Text = text,
        HealthBar = healthBar,
        HealthBarOutline = healthBarOutline,
        HealthText = healthText,
        HeadDot = headDot,
        Connection = connection
    }
end

function ESP:Remove(player)
    if self.Objects[player] then
        self.Objects[player].Box:Remove()
        self.Objects[player].Text:Remove()
        self.Objects[player].HealthBar:Remove()
        self.Objects[player].HealthBarOutline:Remove()
        self.Objects[player].HealthText:Remove()
        self.Objects[player].HeadDot:Remove()
        self.Objects[player].Connection:Disconnect()
        self.Objects[player] = nil
    end
end

function ESP:Update()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if config.ESPEnabled then
                if not self.Objects[player] then
                    self:Create(player)
                end
            else
                if self.Objects[player] then
                    self:Remove(player)
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    ESP:Update()
end)

Tabs.Aimbot:AddToggle("AimbotToggle", {
    Title = "Enable Aimbot",
    Default = false,
    Callback = function(value)
        if value then
            EnableAimbot()
        else
            DisableAimbot()
        end
    end
})

Tabs.Aimbot:AddSlider("FOVSlider", {
    Title = "Aimbot FOV",
    Default = config.FOV,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value)
        config.FOV = value
        if FOVring then
            FOVring.Radius = value
        end
    end
})

Tabs.Aimbot:AddSlider("SmoothingSlider", {
    Title = "Smoothing",
    Default = config.Smoothing * 100,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(value)
        config.Smoothing = value / 100
    end
})

Tabs.Aimbot:AddDropdown("AimbotPart", {
    Title = "Aim Part",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "Legs"},
    Default = "Head",
    Callback = function(value)
        config.AimbotPart = value
    end
})


Tabs.Aimbot:AddDropdown("ToggleKey", {
    Title = "Toggle Aimbot Key",
    Values = {"F", "G", "H", "Q", "E", "R"},
    Default = "F",
    Callback = function(value)
        config.AimbotToggleKey = Enum.KeyCode[value]
    end
})

Tabs.Hitboxes:AddToggle("HitboxesToggle", {
    Title = "Enable Hitboxes",
    Default = false,
    Callback = function(value)
        config.HitboxesEnabled = value
    end
})

Tabs.Hitboxes:AddSlider("HitboxMultiplier", {
    Title = "Hitbox Multiplier",
    Default = config.HitboxMultiplier,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(value)
        config.HitboxMultiplier = value
    end
})


Tabs.TriggerBot:AddToggle("TriggerBotToggle", {
    Title = "Enable Trigger Bot",
    Default = false,
    Callback = function(value)
        if value then
            EnableTriggerBot()
        else
            DisableTriggerBot()
        end
    end
})

Tabs.TriggerBot:AddToggle("TriggerBotTeamCheck", {
    Title = "Team Check",
    Default = config.TriggerBotTeamCheck,
    Callback = function(value)
        config.TriggerBotTeamCheck = value
    end
})

Tabs.TriggerBot:AddDropdown("TriggerBotToggleKey", {
    Title = "Toggle Trigger Bot Key",
    Values = {"T", "Y", "U", "G", "H", "J"},
    Default = "T",
    Callback = function(value)
        config.TriggerBotToggleKey = Enum.KeyCode[value]
    end
})

Tabs.TriggerBot:AddSlider("TriggerBotDelay", {
    Title = "Trigger Delay (ms)",
    Default = config.TriggerBotDelay * 1000,
    Min = 0,
    Max = 1000,
    Rounding = 0,
    Callback = function(value)
        config.TriggerBotDelay = value / 1000
    end
})

Tabs.Visuals:AddToggle("ESPToggle", {
    Title = "Enable ESP",
    Default = false,
    Callback = function(value)
        config.ESPEnabled = value
    end
})

Tabs.Visuals:AddToggle("ESPNames", {
    Title = "Show Names",
    Default = true,
    Callback = function(value)
        config.ESPShowNames = value
    end
})

Tabs.Visuals:AddToggle("ESPDistance", {
    Title = "Show Distance",
    Default = true,
    Callback = function(value)
        config.ESPShowDistance = value
    end
})
Tabs.Visuals:AddToggle("ESPHealthBar", {
    Title = "Show Health Bar",
    Default = false,
    Callback = function(value)
        config.ESPShowHealth = value
    end
})
Tabs.Visuals:AddToggle("ESPHeadDot", {
    Title = "Draw Head Dot",
    Default = false,
    Callback = function(value)
        config.ESPHeadDot = value
    end
})


Tabs.Visuals:AddSlider("ESPMaxDistance", {
    Title = "Max Distance",
    Default = config.ESPMaxDistance,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    Callback = function(value)
        config.ESPMaxDistance = value
    end
})


-------------------------------------------------
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:SetIgnoreIndexes({"FOVring", "statusCircle", "originalHeadSizes", "aimbotConnection", "triggerBotConnection"})
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)
