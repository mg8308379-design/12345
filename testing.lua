for _, Value in next, getgc() do
    if type(Value) == "function" and islclosure(Value) then
        local Constants = getconstants(Value)

        if type(Constants) == "table" then
            for _, Constant in next, Constants do
                if Constant == "X-16" then
                    local OldHook

                    OldHook = hookfunction(Value, function(...)
                        local Stack = debug.getstack(1)

                        for Index, Value in next, Stack do
                            if Value == "X-16" then
                                debug.setstack(1, Index, nil)
                            end
                        end

                        return OldHook(...)
                    end)

                    break
                end
            end
        end
    end
end


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local function fireAskDoff()
    local success, packages = pcall(function() return ReplicatedStorage:WaitForChild("Packages", 2) end)
    if not success or not packages then return end

    local networking = packages:WaitForChild("Networking", 2)
    if not networking then return end

    local askDoff = networking:WaitForChild("RF/Treadmill/AskDoff", 2)
    if askDoff then
        pcall(function()
            askDoff:InvokeServer()
        end)
    end
end

local function replaceHumanoid(character)
    local oldHumanoid = character:FindFirstChildOfClass("Humanoid")
    if not oldHumanoid then
        return
    end

    local camera = workspace.CurrentCamera
    local animateScript = character:FindFirstChild("Animate")

    local savedWalkSpeed = oldHumanoid.WalkSpeed
    local savedJumpPower = oldHumanoid.JumpPower
    local savedJumpHeight = oldHumanoid.JumpHeight
    local savedHealth = oldHumanoid.Health
    local savedMaxHealth = oldHumanoid.MaxHealth

    if animateScript and animateScript:IsA("LocalScript") then
        animateScript.Disabled = true
    end

    local animator = oldHumanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
    end

    oldHumanoid.Archivable = true

    local newHumanoid = oldHumanoid:Clone()
    newHumanoid.Name = "Humanoid"

    local clonedAnimator = newHumanoid:FindFirstChildOfClass("Animator")
    if clonedAnimator then
        clonedAnimator:Destroy()
    end

    -- LAG FIX: Instantly remove the old humanoid from the character hierarchy 
    -- exactly as the new one is added so game scripts don't error out.
    oldHumanoid.Name = "_OldHumanoid"
    oldHumanoid.Parent = nil 
    
    newHumanoid.Parent = character
    Instance.new("Animator", newHumanoid)

    newHumanoid.WalkSpeed = savedWalkSpeed
    newHumanoid.JumpPower = savedJumpPower
    newHumanoid.JumpHeight = savedJumpHeight
    newHumanoid.MaxHealth = savedMaxHealth
    newHumanoid.Health = math.min(savedHealth, savedMaxHealth)

    newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    newHumanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)

    -- CUSTOM RESPAWN HOOK:
    newHumanoid.Died:Connect(function()
        pcall(function()
            local networking = ReplicatedStorage:FindFirstChild("Packages"):FindFirstChild("Networking")
            if networking then
                local askRigWipe = networking:FindFirstChild("RE/RigSync/AskRigWipe")
                if askRigWipe then
                    askRigWipe:FireServer(character)
                end
            end
        end)
    end)

    newHumanoid.Jumping:Connect(function(isJumping)
        if isJumping then
            fireAskDoff()
        end
    end)

    local jumpConnection
    jumpConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Space or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonA) then
            if newHumanoid and newHumanoid.Parent and newHumanoid.Health > 0 then
                if newHumanoid:GetState() == Enum.HumanoidStateType.Running or newHumanoid:GetState() == Enum.HumanoidStateType.Landed then
                    newHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    fireAskDoff()
                end
            else
                jumpConnection:Disconnect()
            end
        end
    end)

    if camera then
        camera.CameraSubject = newHumanoid
    end

    -- Completely destroy the old one now that the swap is cleanly finished
    oldHumanoid:Destroy()

    if animateScript and animateScript:IsA("LocalScript") then
        task.wait()
        animateScript.Disabled = false

        task.defer(function()
            if animateScript.Parent then
                animateScript.Disabled = true
                task.wait()
                animateScript.Disabled = false
            end
        end)
    end

    task.defer(function()
        if newHumanoid.Parent then
            newHumanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)

    return newHumanoid
end

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then return end

    -- Prevents the infinite death loop on initial spawn
    if not character.Parent then
        character.AncestryChanged:Wait()
    end
    
    character:WaitForChild("HumanoidRootPart", 10)
    character:WaitForChild("Head", 10)
    
    task.wait(0.25)

    if not character.Parent or humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
        return
    end

    replaceHumanoid(character)
end

if player.Character then
    task.spawn(setupCharacter, player.Character)
end

player.CharacterAdded:Connect(function(character)
    task.spawn(setupCharacter, character)
end)
loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/634d681114e7443e2b3cab03232f29eb.lua"))()
