-- ============================================================
-- CameraScript  |  StarterPlayerScripts > LocalScript
-- Portrait-optimized cinematic camera for TikTok 9:16.
-- Cycles through spawned characters (oldest → newest → loop).
-- Interval scales with player count: 5s (full) to 20s (1 player).
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

-- ── Config ────────────────────────────────────────────────

local CAM_DISTANCE   = 10    -- studs behind target (body shot distance)
local CAM_HEIGHT     = 1     -- studs above root (waist level → hero angle)
local CAM_SIDE       = 2     -- slight 3/4 offset
local FOCUS_HEIGHT   = 4     -- aim at chest/neck
local TWEEN_DURATION = 2.2   -- seconds per camera swing
local FOLLOW_ALPHA   = 0.04  -- drift smoothness (the natural shake feel)
local MIN_INTERVAL   = 5     -- min seconds per character (full floor)
local MAX_INTERVAL   = 20    -- max seconds per character (1 player alone)

-- ── State (declared before any function that references them) ──

local activeParts   = {}     -- [1]=oldest ... [n]=newest
local cycleIndex    = 1
local currentTarget = nil
local isTweening    = false
local lastCycleTime = 0

-- ── Helpers ───────────────────────────────────────────────

-- Dynamic interval: fewer players → longer feature time
local function getCycleInterval()
    local count = math.max(1, #activeParts)
    return math.clamp(MAX_INTERVAL / count, MIN_INTERVAL, MAX_INTERVAL)
end

-- Level CFrame via explicit axis math — no roll from side offset
local function getTargetCFrame(rootPart)
    local pos    = rootPart.Position
    local focus  = pos + Vector3.new(0, FOCUS_HEIGHT, 0)
    local camPos = pos + Vector3.new(CAM_SIDE, CAM_HEIGHT, CAM_DISTANCE)
    local forward = (focus - camPos).Unit
    local right   = forward:Cross(Vector3.new(0, 1, 0)).Unit
    local up      = right:Cross(forward).Unit
    return CFrame.fromMatrix(camPos, right, up, -forward)
end

local function tweenTo(rootPart)
    if not rootPart or not rootPart.Parent then return end
    currentTarget = rootPart
    isTweening    = true
    local tween = TweenService:Create(
        camera,
        TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { CFrame = getTargetCFrame(rootPart) }
    )
    tween.Completed:Connect(function() isTweening = false end)
    tween:Play()
end

local function removePart(target)
    for i, p in ipairs(activeParts) do
        if p == target then
            table.remove(activeParts, i)
            cycleIndex = math.clamp(cycleIndex, 1, math.max(1, #activeParts))
            break
        end
    end
end

-- ── Enforce Scriptable camera type ────────────────────────
-- Roblox's default PlayerModule can override this on startup

RunService.RenderStepped:Connect(function()
    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end
end)

-- ── Event: new character spawned ──────────────────────────

local focusEvent = ReplicatedStorage:WaitForChild("FocusOnCharacter", 30)

focusEvent.OnClientEvent:Connect(function(model)
    if not model or not model.Parent then return end

    local rootPart = model:WaitForChild("HumanoidRootPart", 5)
    if not rootPart then return end

    -- Avoid duplicates
    for _, p in ipairs(activeParts) do
        if p == rootPart then return end
    end

    table.insert(activeParts, rootPart)
    cycleIndex = #activeParts  -- feature this new arrival first

    -- Clean up when character despawns
    rootPart.AncestryChanged:Connect(function()
        if not rootPart.Parent then
            removePart(rootPart)
            if currentTarget == rootPart and #activeParts > 0 then
                tweenTo(activeParts[math.clamp(cycleIndex, 1, #activeParts)])
                lastCycleTime = tick()
            end
        end
    end)

    tweenTo(rootPart)
    lastCycleTime = tick()
    print("[Camera] Now featuring: " .. model.Name .. " (" .. #activeParts .. " on floor)")
end)

-- ── Cycle loop (task.spawn — not Heartbeat) ───────────────
-- Using task.wait(1) so errors don't spam 60x per second

task.spawn(function()
    while true do
        task.wait(1)

        -- Prune destroyed parts
        for i = #activeParts, 1, -1 do
            if not activeParts[i] or not activeParts[i].Parent then
                table.remove(activeParts, i)
            end
        end

        if #activeParts == 0 then continue end

        cycleIndex = math.clamp(cycleIndex, 1, #activeParts)

        if not isTweening and (tick() - lastCycleTime) >= getCycleInterval() then
            cycleIndex = (cycleIndex % #activeParts) + 1
            local target = activeParts[cycleIndex]
            if target and target.Parent then
                tweenTo(target)
                lastCycleTime = tick()
                print("[Camera] Cycle → " .. (target.Parent and target.Parent.Name or "?")
                    .. " [" .. cycleIndex .. "/" .. #activeParts .. "] "
                    .. math.floor(getCycleInterval()) .. "s interval")
            end
        end
    end
end)

-- ── Drift follow (RenderStepped — keeps the natural shake) ──

RunService.RenderStepped:Connect(function()
    if isTweening then return end
    if not currentTarget or not currentTarget.Parent then return end
    camera.CFrame = camera.CFrame:Lerp(getTargetCFrame(currentTarget), FOLLOW_ALPHA)
end)

-- ── Default idle position (empty floor) ───────────────────

local STAGE_CENTER = Vector3.new(0, 5, 7.5)
camera.CFrame = CFrame.lookAt(
    STAGE_CENTER + Vector3.new(4, 14, 28),
    STAGE_CENTER
)

print("[Camera] Ready — " .. MIN_INTERVAL .. "s-" .. MAX_INTERVAL .. "s dynamic cycle")
