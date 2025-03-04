-- Configuration
local config = {
    TeamCheck = false, 
    FOV = 150,
    Smoothing = 1,
    KeyToToggle = Enum.KeyCode.F,
}

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- GUI: FOV ring (создается/удаляется при переключении aimbot)
local FOVring = nil

-- Создаем индикатор статуса aimbot'а (отображается в левом нижнем углу)
local statusCircle = Drawing.new("Circle")
statusCircle.Visible = true
statusCircle.Thickness = 2
statusCircle.Radius = 15  -- можно изменить размер по желанию (не слишком маленький, но компактный)
statusCircle.Color = Color3.fromRGB(255, 0, 0) -- изначально выключен – красный
statusCircle.Position = Vector2.new(30, workspace.CurrentCamera.ViewportSize.Y - 30)

-- Переменные для перетаскивания индикатора
local dragging = false
local dragOffset = Vector2.new(0, 0)

-- Обработка нажатия левой кнопки мыши для начала перетаскивания
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = UserInputService:GetMouseLocation()
        -- Проверяем, находится ли курсор внутри кружка (используем расстояние от центра)
        if (mousePos - statusCircle.Position).Magnitude <= statusCircle.Radius then
            dragging = true
            dragOffset = statusCircle.Position - mousePos
        end
    end
end)

-- Обработка движения мыши при перетаскивании
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mousePos = UserInputService:GetMouseLocation()
        statusCircle.Position = mousePos + dragOffset
    end
end)

-- Завершение перетаскивания по отпусканию кнопки мыши
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Функция для поиска ближайшего видимого игрока, исключая мёртвых (0 хп или ниже)
local function getClosestVisiblePlayer(camera)
    local ray = Ray.new(camera.CFrame.Position, camera.CFrame.LookVector)
    local closestPlayer = nil
    local closestDistance = math.huge
    
    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= game.Players.LocalPlayer then
            local character = player.Character
            if character and character:FindFirstChild("Head") then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then  -- Проверка здоровья
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

local aimbotEnabled = false
local aimbotConnection

-- Обновление aimbot'а (направление камеры на голову ближайшего игрока)
local function updateAimbot()
    if aimbotEnabled and FOVring then
        local currentCamera = workspace.CurrentCamera
        local crosshairPosition = currentCamera.ViewportSize / 2
        local closestPlayer = getClosestVisiblePlayer(currentCamera)
        
        if closestPlayer then
            local headPosition = closestPlayer.Character.Head.Position
            local headScreenPosition = currentCamera:WorldToScreenPoint(headPosition)
            local distanceToCrosshair = (Vector2.new(headScreenPosition.X, headScreenPosition.Y) - crosshairPosition).Magnitude
            
            if distanceToCrosshair < config.FOV then
                currentCamera.CFrame = currentCamera.CFrame:Lerp(CFrame.new(currentCamera.CFrame.Position, headPosition), config.Smoothing)
            end
        end
    end
end

-- Функция переключения aimbot'а и обновления индикатора
local function toggleAimbot()
    aimbotEnabled = not aimbotEnabled
    -- Обновляем цвет индикатора: зелёный при включении, красный при выключении
    statusCircle.Color = aimbotEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
    
    if aimbotEnabled then
        FOVring = Drawing.new("Circle")
        FOVring.Visible = true
        FOVring.Thickness = 1.5
        FOVring.Radius = config.FOV
        FOVring.Transparency = 1
        FOVring.Color = Color3.fromRGB(255, 128, 128)
        FOVring.Position = workspace.CurrentCamera.ViewportSize / 2
        aimbotConnection = RunService.RenderStepped:Connect(updateAimbot)
    else
        if FOVring then
            FOVring:Remove()
            FOVring = nil
        end
        if aimbotConnection then
            aimbotConnection:Disconnect()
        end
    end
end

-- Переключение aimbot'а по нажатию клавиши F
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == config.KeyToToggle then
        toggleAimbot()
    end
end)
