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

### Stream / Anti-Ban
1. **No copyrighted music.** Use StreamBeats, Lofi Girl stream-safe, or any DMCA-free playlist only.
2. **Keep the overlay moving.** A scrolling "Type your Roblox username!" ticker or live clock must always be visible. This prevents TikTok from flagging the stream as frozen/static content.
3. **PC sleep = never.** Power settings must be set to Never Sleep before walking away.
4. **Remote access is your safety net.** Chrome Remote Desktop or AnyDesk on your phone lets you restart from anywhere.

---

## Monetization Model

| Action | Effect |
|---|---|
| Viewer types username in chat | Added to regular queue |
| Viewer sends any gift | Bumped to VIP priority queue (skips the line) |
| Large gift (future feature) | Triggers special visual effect on their character |

---

## File Map

| File | Purpose |
|---|---|
| `server.js` | The entire Node.js backend |
| `package.json` | npm project config |
| `node_modules/` | Installed libraries (never edit manually) |
| `MISSION.md` | This file — rules and reference |
| `README.md` | Public-facing project overview |

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
