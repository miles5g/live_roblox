-- ============================================================
-- HideHUDScript  |  StarterPlayerScripts > LocalScript
-- Removes every default Roblox HUD element so the TikTok
-- stream shows a clean dance floor with no UI clutter.
-- Also shows the "type your username" prompt at the top.
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

-- ── "Type your username" prompt ────────────────────────────
-- Displayed at the top of the screen for TikTok viewers.

local function createPrompt()
    local Players     = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local playerGui   = LocalPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name            = "SpawnPrompt"
    screenGui.ResetOnSpawn    = false
    screenGui.IgnoreGuiInset  = false  -- respect the topbar safe area
    screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    screenGui.Parent          = playerGui

    -- Semi-transparent dark pill behind the text
    local bg = Instance.new("Frame")
    bg.Name                = "Background"
    bg.AnchorPoint         = Vector2.new(0.5, 0)
    bg.Position            = UDim2.new(0.5, 0, 0, 8)
    bg.Size                = UDim2.new(0.85, 0, 0, 46)
    bg.BackgroundColor3    = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.45
    bg.BorderSizePixel     = 0
    bg.Parent              = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 26)
    corner.Parent       = bg

    local label = Instance.new("TextLabel")
    label.Name                 = "PromptText"
    label.AnchorPoint          = Vector2.new(0.5, 0.5)
    label.Position             = UDim2.new(0.5, 0, 0.5, 0)
    label.Size                 = UDim2.new(1, -20, 1, 0)
    label.BackgroundTransparency = 1
    label.Text                 = "💬  Type your username to spawn!"
    label.TextColor3           = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3     = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.4
    label.Font                 = Enum.Font.GothamBold
    label.TextSize             = 20
    label.TextScaled           = true
    label.TextXAlignment       = Enum.TextXAlignment.Center
    label.Parent               = bg
end

createPrompt()

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
