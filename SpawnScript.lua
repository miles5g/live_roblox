-- ============================================================
-- SpawnScript  |  ServerScriptService > Script
-- Polls the Node.js backend and spawns viewer avatars.
-- ============================================================
-- WHERE TO PUT THIS:
--   Roblox Studio → Explorer → ServerScriptService
--   Right-click → Insert Object → Script → paste this in
-- ============================================================

local HttpService    = game:GetService("HttpService")
local Players        = game:GetService("Players")
local Debris         = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Config ────────────────────────────────────────────────
local SERVER_URL      = "http://localhost:3000"
local POLL_INTERVAL   = 2    -- seconds between queue checks
local DANCE_DURATION  = 60   -- seconds each character stays
local MAX_ON_SCREEN   = 20
local GRID_COLS       = 5    -- characters per row on the floor
local GRID_SPACING    = 5    -- studs between characters

-- R15 HumanoidRootPart sits ~3 studs above the character's feet.
-- We add this so characters land ON the floor rather than through it.
local CHAR_ROOT_HEIGHT = 3

-- Roblox built-in dance animation IDs (loopable emotes)
local DANCE_ANIMS = {
    "507771019",  -- Robot
    "507776043",  -- Dance 2
    "507770453",  -- Breakdance
    "507771955",  -- Shufflin'
    "507776543",  -- Gangnam Style
}

-- ── Setup ─────────────────────────────────────────────────

-- RemoteEvent tells the CameraScript which character to follow
local focusEvent = Instance.new("RemoteEvent")
focusEvent.Name  = "FocusOnCharacter"
focusEvent.Parent = ReplicatedStorage

-- Reference point — name this Part "SpawnLocation" in your map
local spawnAnchor = workspace:WaitForChild("SpawnLocation")

-- Fixed grid of 20 spawn positions around the anchor
local function buildSpawnSlots()
    local slots = {}
    for i = 0, MAX_ON_SCREEN - 1 do
        local col = i % GRID_COLS
        local row = math.floor(i / GRID_COLS)
        local offset = Vector3.new(
            (col - math.floor(GRID_COLS / 2)) * GRID_SPACING,
            spawnAnchor.Size.Y / 2 + CHAR_ROOT_HEIGHT,
            row * GRID_SPACING
        )
        slots[i + 1] = {
            position = spawnAnchor.Position + offset,
            occupied = false,
        }
    end
    return slots
end

local spawnSlots = buildSpawnSlots()

local function claimSlot()
    for _, slot in ipairs(spawnSlots) do
        if not slot.occupied then
            slot.occupied = true
            return slot
        end
    end
    return nil
end

local function releaseSlot(slot)
    if slot then slot.occupied = false end
end

-- ── Helpers ───────────────────────────────────────────────

local function playDance(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. DANCE_ANIMS[math.random(#DANCE_ANIMS)]

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if ok and track then
        track.Looped = true
        track:Play()
    end
end

local function hardDestroy(model, slot)
    pcall(function()
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum then hum:UnequipTools() end
        model.Parent = nil
        model:Destroy()
    end)
    releaseSlot(slot)
end

local function notifyDone(username)
    pcall(function()
        HttpService:PostAsync(
            SERVER_URL .. "/api/queue/done",
            HttpService:JSONEncode({ username = username }),
            Enum.HttpContentType.ApplicationJson
        )
    end)
end

-- ── Spawn ─────────────────────────────────────────────────

local function spawnCharacter(username)
    -- 1. Validate username exists on Roblox
    local ok1, userId = pcall(function()
        return Players:GetUserIdFromUsernameAsync(username)
    end)
    if not ok1 or not userId then
        warn("[Spawn] Unknown username: " .. username)
        notifyDone(username)
        return
    end

    -- 2. Fetch their avatar description
    local ok2, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if not ok2 or not desc then
        warn("[Spawn] Could not load avatar for: " .. username)
        notifyDone(username)
        return
    end

    -- 3. Build the 3D rig
    local ok3, model = pcall(function()
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if not ok3 or not model then
        warn("[Spawn] Could not create model for: " .. username)
        notifyDone(username)
        return
    end

    -- 4. Claim a slot and position the character
    local slot = claimSlot()
    if not slot then
        warn("[Spawn] No slots — should not happen if server is correct")
        model:Destroy()
        notifyDone(username)
        return
    end

    model.Name = username
    -- Ensure PrimaryPart is set (CreateHumanoidModelFromDescription should do this,
    -- but we guard against edge cases)
    if not model.PrimaryPart then
        model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
    end
    model.Parent = workspace
    model:SetPrimaryPartCFrame(CFrame.new(slot.position))

    -- 5. Dance!
    playDance(model)

    -- 6. Tell the camera to swing to this character
    focusEvent:FireAllClients(model.PrimaryPart)

    -- Safety fallback: Debris auto-removes if the task.delay ever hangs
    Debris:AddItem(model, DANCE_DURATION + 10)

    -- 7. Schedule clean removal after DANCE_DURATION seconds
    task.delay(DANCE_DURATION, function()
        hardDestroy(model, slot)
        notifyDone(username)
        print("[Done] " .. username .. " left the floor.")
    end)

    print("[Spawn] " .. username .. " on the floor! (" .. (slot.occupied and "slot OK" or "?") .. ")")
end

-- ── Main Poll Loop ─────────────────────────────────────────

print("[Server] SpawnScript running — polling " .. SERVER_URL)

while true do
    task.wait(POLL_INTERVAL)

    local ok, raw = pcall(function()
        return HttpService:GetAsync(SERVER_URL .. "/api/queue/next", true)
    end)

    if not ok or not raw then
        warn("[Poll] Cannot reach Node.js server. Is `node server.js` running?")
    else
        local parseOk, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if parseOk and data and data.status == "spawn" and data.username then
            print("[Poll] Spawning " .. data.username .. " [" .. (data.type or "Regular") .. "]")
            task.spawn(spawnCharacter, data.username)
        end
    end
end
