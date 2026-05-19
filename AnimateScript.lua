-- ============================================================
-- AnimateScript  |  StarterPlayerScripts > LocalScript
-- Receives AnimateCharacter events from the server and plays
-- dance animations client-side (avoids serverplaceid=0 error).
-- ============================================================
-- WHERE TO PUT THIS:
--   Roblox Studio → Explorer → StarterPlayer → StarterPlayerScripts
--   Right-click → Insert Object → LocalScript → paste this in
--   (Separate from CameraScript — give it a clear name)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local animateEvent = ReplicatedStorage:WaitForChild("AnimateCharacter", 30)

if not animateEvent then
    warn("[AnimateScript] AnimateCharacter RemoteEvent not found — is SpawnScript running?")
    return
end

animateEvent.OnClientEvent:Connect(function(model, animId)
    if not model or not model.Parent then return end

    -- Wait briefly for the model to fully replicate to the client
    task.wait(0.2)

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("[AnimateScript] No Humanoid found on model: " .. tostring(model.Name))
        return
    end

    -- Ensure Animator exists
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    -- Load and play the animation
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(animId)

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)

    if ok and track then
        track.Looped = true
        track:Play()
        print("[AnimateScript] Playing dance " .. animId .. " on " .. model.Name)
    else
        warn("[AnimateScript] Failed to load animation " .. animId .. " on " .. model.Name .. ": " .. tostring(track))
    end
end)

print("[AnimateScript] Ready — listening for dance events")
