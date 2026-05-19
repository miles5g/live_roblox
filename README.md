# TikTok Live → Roblox Dance Floor

> **@milkywizard's autonomous live stream engine.**  
> Viewers type their Roblox username in TikTok chat → their 3D character spawns on a neon dance floor → they dance for 60 seconds → the next person loads in. Endless loop. 24/7. Gift-senders skip the line.

---

## How It Works

```
TikTok Live Chat  →  Node.js Queue  →  Roblox Studio  →  TikTok Live Studio
```

1. **Node.js** (`server.js`) listens to your TikTok live chat in real-time using `tiktok-live-connector`.
2. Valid Roblox usernames get added to a queue (max 20 on screen, no duplicates).
3. **Roblox Studio** polls the server every 2 seconds and spawns the next character.
4. After 60 seconds, the character is destroyed and the slot is freed.
5. Gift-senders are automatically bumped to a **VIP priority queue**.

---

## Stack

- **Node.js** — runtime
- **Express** — local HTTP server (talks to Roblox)
- **tiktok-live-connector** — reads your TikTok live chat & gifts
- **Roblox Studio + Luau** — renders the 3D avatars and animations

---

## Project Structure

```
live_roblox/
├── server.js        ← Node.js backend (run this first)
├── package.json
├── MISSION.md       ← Dev rules and architecture reference
└── README.md
```

---

## Setup

### Prerequisites
- Node.js v24+ installed
- A TikTok account with Live access
- Roblox Studio installed

### 1. Install dependencies
```bash
npm install
```

### 2. Start the server
```bash
node server.js
```

You should see:
```
[Server] Running at http://localhost:3000
[TikTok] Connected! Room ID: ...
```

### 3. Roblox Studio
- Create a new Baseplate project
- Go to **Home → Game Settings → Security** and enable **Allow HTTP Requests**
- Add a `Script` under `ServerScriptService` (see `MISSION.md` for the Luau code prompt)
- Name your spawn area part `SpawnLocation`
- Lock your camera angle, then hit Play

### 4. TikTok Live Studio
- Add a **Window Capture** source pointing at Roblox Studio
- Add a scrolling text overlay: *"Type your Roblox username to join the dance floor!"*
- Hit **Go Live**

---

## API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/api/queue/next` | GET | Returns the next username to spawn |
| `/api/queue/done` | POST | Marks a user as done (frees their slot) |
| `/api/status` | GET | Live dashboard — queue lengths, active users |

---

## Monetization

- **Regular viewers** type their username → join the queue
- **Gift senders** → automatically skip to the front (VIP queue)
- Future: large gifts trigger special visual effects on their character

---

## Anti-Ban (Unattended Streams)

- Always include a **moving overlay** (scrolling text or live clock) so TikTok's AI doesn't flag a static screen
- Use **DMCA-free music only** (StreamBeats, Lofi Girl stream-safe catalog)
- Set Windows **Power Settings → Never Sleep**
- Install **Chrome Remote Desktop** or **AnyDesk** to monitor/restart from your phone

---

## License

MIT — do whatever you want with it.
