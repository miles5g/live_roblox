-- ============================================================
-- CameraScript  |  StarterPlayerScripts > LocalScript
-- Smoothly swings the camera to focus on the newest spawned
-- character. The rest of the crowd stays visible behind them.
-- ============================================================
-- WHERE TO PUT THIS:
--   Roblox Studio → Explorer → StarterPlayer → StarterPlayerScripts
--   Right-click → Insert Object → LocalScript → paste this in
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

-- ── Camera Config ─────────────────────────────────────────

-- Distance behind + above the focused character.
-- Pulling back far enough means the crowd is visible in the bg.
local CAM_DISTANCE  = 22   -- studs behind the character
local CAM_HEIGHT    = 9    -- studs above the floor
local CAM_SIDE      = 6    -- studs to the right (slight 3/4 angle)

-- How fast the camera snaps to a new character (seconds)
local TWEEN_DURATION = 2.2

-- How smoothly it drifts while following (0 = instant, 1 = no follow)
-- 0.04 = very smooth cinematic drift
local FOLLOW_ALPHA  = 0.04

-- ── State ─────────────────────────────────────────────────

local currentTarget = nil   -- The PrimaryPart of the newest character
local isTweening    = false

-- ── Helpers ───────────────────────────────────────────────

-- Given a character's root part, return the ideal camera CFrame.
-- Camera sits behind, above, and slightly to the side so the
-- grid of dancers fills the background of the shot.
local function getTargetCFrame(rootPart)
    local pos   = rootPart.Position
    local focus = pos + Vector3.new(0, 1.5, 0)   -- aim at chest height

    local camPos = pos + Vector3.new(
        CAM_SIDE,
        CAM_HEIGHT,
        CAM_DISTANCE   -- positive Z = behind the character
    )

    return CFrame.lookAt(camPos, focus)
end

-- ── Event: new character spawned ──────────────────────────

local focusEvent = ReplicatedStorage:WaitForChild("FocusOnCharacter", 30)

focusEvent.OnClientEvent:Connect(function(rootPart)
    if not rootPart or not rootPart.Parent then return end

    currentTarget = rootPart
    isTweening    = true

    -- Smooth tween swing to the new character
    local goal     = getTargetCFrame(rootPart)
    local tweenInf = TweenInfo.new(
        TWEEN_DURATION,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut
    )
    local tween = TweenService:Create(camera, tweenInf, { CFrame = goal })

    tween.Completed:Connect(function()
        isTweening = false
    end)

    tween:Play()
end)

-- ── RenderStepped: gentle follow drift ────────────────────
-- After the tween finishes, the camera softly drifts to stay
-- locked on the target even if they slide or bob slightly.

RunService.RenderStepped:Connect(function()
    -- Don't fight the tween while it's running
    if isTweening then return end
    if not currentTarget or not currentTarget.Parent then return end

    local desired = getTargetCFrame(currentTarget)
    camera.CFrame  = camera.CFrame:Lerp(desired, FOLLOW_ALPHA)
end)
