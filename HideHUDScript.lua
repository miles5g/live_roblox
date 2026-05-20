-- ============================================================
-- HideHUDScript  |  StarterPlayerScripts > LocalScript
-- Removes every default Roblox HUD element so the TikTok
-- stream shows a clean dance floor with no UI clutter.
-- ============================================================
-- WHERE TO PUT THIS:
--   Roblox Studio → Explorer → StarterPlayer → StarterPlayerScripts
--   Right-click → Insert Object → LocalScript → paste this in
-- ============================================================

local StarterGui  = game:GetService("StarterGui")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Kill CoreGui elements (health bar, backpack, chat, leaderboard, player list)
local function hideCoreGui()
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
end

-- Kill the virtual joystick / touch controls
local function hideTouchGui()
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, name in ipairs({ "TouchGui", "ControlGui" }) do
                local g = playerGui:FindFirstChild(name)
                if g then g.Enabled = false end
            end
        end
    end)
end

-- SetCore("TopbarEnabled") throws if called before CoreGui is ready.
-- Retry in a tight loop until it stops erroring, then we know it worked.
local function hideTopbar()
    task.spawn(function()
        for _ = 1, 30 do
            local ok = pcall(function()
                StarterGui:SetCore("TopbarEnabled", false)
            end)
            if ok then
                break   -- confirmed hidden, stop retrying
            end
            task.wait(0.2)
        end
    end)
end

hideCoreGui()
hideTopbar()
hideTouchGui()

-- Re-apply after a short delay in case Roblox re-enables anything on load
task.delay(1, function()
    hideCoreGui()
    hideTopbar()
    hideTouchGui()
end)
task.delay(3, function()
    hideCoreGui()
    hideTopbar()
    hideTouchGui()
end)
