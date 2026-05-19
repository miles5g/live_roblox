-- ============================================================
-- CameraScript  |  StarterPlayerScripts > LocalScript
-- Portrait-optimized (9:16) cinematic camera for TikTok Live.
-- Swings to newest spawn; crowd visible below in frame.
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

-- ── Portrait Framing Config (optimized for TikTok 9:16) ───
--
-- TikTok is viewed almost entirely on mobile in portrait.
-- The key difference vs. landscape:
--   - LESS side offset (portrait is narrow — side room is wasted)
--   - MORE height (we have vertical space, use it to show the crowd below)
--   - Camera pulls back further so the grid fills the lower frame
--   - Focus point aims slightly above chest so head isn't cropped
--
local CAM_DISTANCE  = 28   -- studs behind target (pulls back = more crowd visible)
local CAM_HEIGHT    = 14   -- studs above floor (tall portrait = show crowd below)
local CAM_SIDE      = 2    -- minimal side offset (portrait frame is narrow)
local FOCUS_HEIGHT  = 3    -- studs above target root to aim at (keeps head in frame)

-- How fast the camera swings to a new character (seconds)
local TWEEN_DURATION = 2.2

-- Gentle follow drift after tween lands (0 = instant, higher = slower)
local FOLLOW_ALPHA  = 0.04

-- ── State ─────────────────────────────────────────────────

local currentTarget = nil
local isTweening    = false

-- ── Camera Position Calculator ────────────────────────────
--
-- Camera sits high and far back so:
--   - Newest character: upper-center of frame (hero position)
--   - Crowd grid: visible in lower portion of the tall portrait frame
--   - Slight side offset: gives a natural 3/4 angle, not a dead-on shot
--
local function getTargetCFrame(rootPart)
    local pos   = rootPart.Position
    local focus = pos + Vector3.new(0, FOCUS_HEIGHT, 0)

    local camPos = pos + Vector3.new(
        CAM_SIDE,
        CAM_HEIGHT,
        CAM_DISTANCE
    )

    return CFrame.lookAt(camPos, focus)
end

-- ── Event: new character spawned ──────────────────────────

local focusEvent = ReplicatedStorage:WaitForChild("FocusOnCharacter", 30)

focusEvent.OnClientEvent:Connect(function(rootPart)
    if not rootPart or not rootPart.Parent then return end

    currentTarget = rootPart
    isTweening    = true

    local goal = getTargetCFrame(rootPart)
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

-- ── RenderStepped: smooth follow drift ────────────────────
-- After the tween settles, the camera gently tracks the target
-- so it stays locked even if the character bobs or slides.

RunService.RenderStepped:Connect(function()
    if isTweening then return end
    if not currentTarget or not currentTarget.Parent then return end

    local desired = getTargetCFrame(currentTarget)
    camera.CFrame  = camera.CFrame:Lerp(desired, FOLLOW_ALPHA)
end)

-- ── Roblox Studio Setup Reminder (printed on Play) ────────
-- In Studio: set the game window to approximately 9:16 ratio
-- (e.g. 405 × 720 px) before streaming so what you see in
-- Studio matches what TikTok viewers see on mobile.
print("[Camera] Portrait mode active — optimized for TikTok 9:16")
