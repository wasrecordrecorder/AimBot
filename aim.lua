-- Загрузка Fluent библиотеки и её дополнений
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Создание окна Fluent
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
    Settings = Window:AddTab({Title = "Settings", Icon = "settings"})
}

-- Конфигурация
local config = {
    FOV = 150,              -- Радиус FOV для аимбота
    Smoothing = 1,          -- Коэффициент сглаживания (0.01 - 1)
    AimbotEnabled = false,  -- Статус аимбота (включен/выключен)
    AimbotToggleKey = Enum.KeyCode.F, -- Клавиша для переключения аимбота
    HitboxesEnabled = false, -- Статус хитбоксов
    HitboxMultiplier = 6,    -- Множитель размера головы для хитбоксов
}

-- Сервисы
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-------------------------------------------------
-- DRAGGABLE STATUS ИНДИКАТОР (для аимбота)
-------------------------------------------------
local statusCircle = Drawing.new("Circle")
statusCircle.Visible = true
statusCircle.Thickness = 2
statusCircle.Radius = 15
statusCircle.Color = Color3.fromRGB(255, 0, 0) -- красный – аимбот выключен
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

-------------------------------------------------
-- ФУНКЦИЯ ПОИСКА БЛИЖАЙШЕГО ВИДИМОГО ИГРОКА
-------------------------------------------------
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

-------------------------------------------------
-- АИМБОТ
-------------------------------------------------
local FOVring = nil
local aimbotConnection = nil

local function updateAimbot()
    if config.AimbotEnabled and FOVring then
        local currentCamera = workspace.CurrentCamera
        local crosshairPosition = currentCamera.ViewportSize / 2
        local closestPlayer = getClosestVisiblePlayer(currentCamera)
        if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("Head") then
            local headPosition = closestPlayer.Character.Head.Position
            local headScreenPosition = currentCamera:WorldToScreenPoint(headPosition)
            local distanceToCrosshair = (Vector2.new(headScreenPosition.X, headScreenPosition.Y) - crosshairPosition).Magnitude
            if distanceToCrosshair < config.FOV then
                currentCamera.CFrame = currentCamera.CFrame:Lerp(CFrame.new(currentCamera.CFrame.Position, headPosition), config.Smoothing)
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
    statusCircle.Color = Color3.fromRGB(0, 255, 0)  -- зелёный – включён
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
    statusCircle.Color = Color3.fromRGB(255, 0, 0)  -- красный – выключён
end

local function toggleAimbot()
    if config.AimbotEnabled then
        DisableAimbot()
    else
        EnableAimbot()
    end
end

-- Слушатель нажатия клавиши для переключения аимбота
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == config.AimbotToggleKey then
        toggleAimbot()
    end
end)

-------------------------------------------------
-- ХИТБОКСЫ
-------------------------------------------------
local originalHeadSizes = {}
local lastHitboxTarget = nil

local function updateHitboxes()
    if config.HitboxesEnabled then
        local currentCamera = workspace.CurrentCamera
        local closestPlayer = getClosestVisiblePlayer(currentCamera)
        -- Дополнительная проверка, чтобы случайно не изменить голову LocalPlayer
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

-------------------------------------------------
-- Fluent GUI: ВКЛАДКА АИМБОТА
-------------------------------------------------
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

Tabs.Aimbot:AddDropdown("ToggleKey", {
    Title = "Toggle Aimbot Key",
    Values = {"F", "G", "H", "Q", "E", "R"},
    Default = "F",
    Callback = function(value)
        config.AimbotToggleKey = Enum.KeyCode[value]
    end
})

-------------------------------------------------
-- Fluent GUI: ВКЛАДКА ХИТБОКСОВ
-------------------------------------------------
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

-------------------------------------------------
-- Настройки сохранения
-------------------------------------------------
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:SetIgnoreIndexes({"FOVring", "statusCircle", "originalHeadSizes", "aimbotConnection"})
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)
