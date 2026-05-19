# Project Mission & Rules
## TikTok Live → Roblox Dance Floor (@milkywizard)

---

## What This Project Is

An autonomous, self-sustaining TikTok Live stream where viewers type their Roblox username in chat to have their 3D character spawned onto a neon dance floor inside Roblox Studio. The stream runs 24/7, processes a live queue, rewards gift-senders with VIP priority, and is engineered to survive unattended for hours.

**Stack:** Node.js + Express + tiktok-live-connector + Roblox Studio (Luau)

---

## The Pipeline (Always Keep This in Mind)

```
TikTok Chat
     │
     ▼
Node.js server.js        ← listens, filters, queues
     │
     ▼  (HTTP polling every 2s)
Roblox Studio Script     ← spawns avatar, plays dance, destroys after 60s
     │
     ▼  (HTTP POST when done)
Node.js server.js        ← frees the slot, next user spawns
```

---

## Ground Rules for Development

### Node.js / server.js
1. **Never break the auto-reconnect loop.** TikTok will drop connections. The reconnect must always be in place.
2. **Always validate before queuing.** Roblox usernames = 3–20 chars, alphanumeric + underscores only. Regex: `/^[a-zA-Z0-9_]{3,20}$/`
3. **No duplicates anywhere.** A username can only exist in ONE place: regularQueue, vipQueue, or activeOnScreen — never two.
4. **VIP always goes first.** Gift senders skip the regular queue entirely and go to vipQueue. Pull them out of regularQueue if they were already there.
5. **Max 20 on screen.** `MAX_ON_SCREEN = 20`. Never spawn beyond this. Return `status: 'full'` if at capacity.
6. **The `/api/status` endpoint is your dashboard.** Open `http://localhost:3000/api/status` in a browser any time to see the live state.

### Roblox / Luau Script
1. **All API calls go inside `pcall`.** `GetUserIdFromUsernameAsync` talks to Roblox servers and can fail. Never call it raw.
2. **Always destroy, never just hide.** When a character's 60s is up: `UnequipTools()` → `model.Parent = nil` → `model:Destroy()`. Use `Debris:AddItem()` as a fallback.
3. **POST `/api/queue/done` after every despawn.** This is what frees the slot. If this call fails, the floor fills up and never clears.
4. **HTTP Requests must be ON.** Game Settings → Security → Allow HTTP Requests. Without this, nothing works.
5. **Camera must be locked.** No free-cam during stream. Position it once in Studio, then lock it before going live.

### Stream / Anti-Ban (TOP PRIORITY — Never Compromise These)
TikTok's moderation AI looks for three things: static video, no audio reaction to chat, and no human presence. Every rule below defeats one of those signals.

**Video signals (must always be moving):**
1. **Camera swings to every new spawn.** Every time a character appears, the camera does a 2-second cinematic tween directly to them. This is constant, chat-driven motion — TikTok's AI reads it as a human reacting to the audience.
2. **Keep the overlay moving.** A scrolling "Type your Roblox username to join the dance floor!" ticker in TikTok Live Studio must always be visible. A live digital clock in the corner is a strong secondary signal.
3. **Never leave a static frame.** The grid of dancing characters + camera swings + scrolling overlay = three independent moving elements at all times.

**Audio signals (stream must never be silent):**
4. **No copyrighted music.** Use StreamBeats, Lofi Girl stream-safe, or any DMCA-free synthwave playlist only. Run through TikTok Live Studio's audio mixer, not through Roblox.
5. **Future: add TTS announcements.** When a character spawns, Node.js should speak "Welcome to the dance floor, [username]!" out loud via the `say` npm package. This is the strongest anti-ban signal (active audio commentary).

**Uptime / crash protection:**
6. **PC sleep = never.** Windows Power Settings → Sleep → Never. Screen can turn off; GPU must keep rendering.
7. **Remote access is your safety net.** Chrome Remote Desktop or AnyDesk on your phone. Check it every few hours if unattended.
8. **Test before sleeping.** Run the stream for 1 hour unattended before leaving it overnight. Watch it from your phone remotely to confirm no crash.

---

## Monetization Model

| Action | Effect |
|---|---|
| Viewer types username in chat | Added to regular queue |
| Viewer sends any gift | Bumped to VIP priority queue (skips the line) |
| Large gift (future feature) | Triggers special visual effect on their character |

---

## File Map

| File | Where it goes | Purpose |
|---|---|---|
| `server.js` | Run in terminal | Node.js backend — TikTok listener + queue |
| `SpawnScript.lua` | Roblox → ServerScriptService → Script | Spawns avatars, manages grid, cleans up |
| `CameraScript.lua` | Roblox → StarterPlayerScripts → LocalScript | Cinematic camera follows newest spawn |
| `package.json` | (project root) | npm config |
| `node_modules/` | (project root) | Libraries — never edit |
| `MISSION.md` | (project root) | This file — rules and reference |
| `README.md` | (project root) | Public GitHub overview |

## Camera Behavior Rules

- On every new spawn, camera **tweens** (2.2 seconds, Sine ease) to a position behind + above + slightly right of the new character
- After the tween, camera **softly drifts** (Lerp α=0.04) to stay locked on target
- `CAM_DISTANCE = 22` studs pulls back far enough that the full crowd is visible in the background
- `CAM_SIDE = 6` studs gives a cinematic 3/4 angle instead of a dead-on shot
- Never set `camera.CameraType` to anything except `Scriptable` while the stream is running

---

## Quick-Start Checklist (Every Session)

- [ ] Open Cursor in this folder
- [ ] Run `node server.js` in the terminal
- [ ] Confirm you see `[Server] Running` and `[TikTok] Connected!`
- [ ] Open Roblox Studio → press Play
- [ ] Open TikTok Live Studio → set scene to Window Capture (Roblox Studio)
- [ ] Verify overlay/clock is visible
- [ ] Hit Go Live

---

*Built for @milkywizard — keep it running, keep it clean.*
