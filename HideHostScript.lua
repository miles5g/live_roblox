-- ============================================================
-- HideHostScript  |  StarterCharacterScripts > LocalScript
-- Makes YOUR character invisible and frozen during the stream.
-- Viewers only see the TikTok-spawned characters, not you.
-- ============================================================
-- WHERE TO PUT THIS:
--   Roblox Studio → Explorer → StarterPlayer → StarterCharacterScripts
--   Right-click → Insert Object → LocalScript → paste this in
-- ============================================================

local char = script.Parent
local hum  = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

-- Make every visible part of the host character invisible
for _, obj in ipairs(char:GetDescendants()) do
    if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("SpecialMesh") then
        obj.Transparency = 1
        obj.CanCollide   = false
    end
    if obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = 1
    end
end

-- Hide the name tag above the character
local billboard = char:FindFirstChildOfClass("BillboardGui")
if billboard then billboard.Enabled = false end

-- Lock the host in place so they don't wander onto the dance floor
root.Anchored  = true
hum.WalkSpeed  = 0
hum.JumpHeight = 0

-- Move the host far below the map so they don't block spawns
root.CFrame = CFrame.new(0, -500, 0)
