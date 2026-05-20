const express = require('express');
const { WebcastPushConnection } = require('tiktok-live-connector');
const fs = require('fs');
const path = require('path');
const { FamousRotator } = require('./famous_users');

// Load optional .env (TIKTOK_SIGN_API_KEY) — keeps secrets out of git
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
    for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
        const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
        if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
    }
}

const app = express();
app.use(express.json());

// Allow TikTok browser bridge (Tampermonkey) to POST chat → queue
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
});

// --- Configuration ---
const TIKTOK_USERNAME   = 'milkywizard'; // Your TikTok handle (no @)
const TIKTOK_SESSION_ID = 'eb7d91ce9fdcfe3e1d22804cd05fc1dc';
const TIKTOK_TARGET_IDC = 'useast5';
const TIKTOK_SIGN_API_KEY = process.env.TIKTOK_SIGN_API_KEY || ''; // free at eulerstream.com — fixes rate limits
const PORT = 3000;
const MAX_ON_SCREEN = 12;  // Safe for Studio 60 FPS. Raise to 20 when streaming Roblox client.
const FAMOUS_FILL_INTERVAL_MS = 6000;  // drip a new famous user when real queue is idle
const MAX_FAMOUS_QUEUE = 4;            // keep a small pipeline, not a flood

// --- State Memory ---
let regularQueue = [];   // Usernames waiting their turn (TikTok / manual)
let vipQueue = [];       // Gift senders — always go to the front
let famousQueue = [];    // Auto-filled famous Roblox accounts — lowest priority
const famousRotator = new FamousRotator();
let activeOnScreen = []; // Usernames currently spawned in Roblox
let lastHeartbeat = Date.now(); // Tracks when Roblox last checked in
let robloxWasOffline = false;
let tiktokConnected = false;
let tiktokRoomId = null;
let tiktokLastError = null;
let tiktokLastChat = null;
let tiktokReconnectMs = 15000;

// If Roblox stops polling (idle disconnect, crash), clear activeOnScreen after 15s
// so the floor doesn't stay permanently "full" and block new spawns.
setInterval(() => {
    const secondsSinceHeartbeat = (Date.now() - lastHeartbeat) / 1000;
    if (secondsSinceHeartbeat > 15) {
        if (activeOnScreen.length > 0) {
            console.warn(`[Heartbeat] No contact from Roblox for ${Math.round(secondsSinceHeartbeat)}s — clearing active list.`);
            activeOnScreen = [];
        }
        if (!robloxWasOffline) {
            console.warn('[Heartbeat] Roblox offline — waiting for game to reconnect...');
            robloxWasOffline = true;
        }
    }
}, 5000);

// --- Helpers ---

// Valid Roblox usernames: 3–20 chars, letters/numbers/underscores only
const isValidRobloxUsername = (username) => {
    const regex = /^[a-zA-Z0-9_]{3,20}$/;
    return regex.test(username);
};

// Common words to skip when scanning chat for usernames
const IGNORE_WORDS = new Set([
    'the','and','for','you','are','not','but','can','all','was','has',
    'had','his','her','its','our','out','one','get','got','new','now',
    'how','who','why','did','try','roblox','game','play','name','user',
    'floor','dance','hello','please','spawn','add','put','yes','lol',
    'omg','haha','wait','hey','bro','sis','nah','yep','nope','this',
    'that','with','from','they','them','just','like','want','mine',
    'here','come','lets','lmao','nice','cool','good','love','whoa',
    'type','world','dude','roblox','your','usernames',
    'fallout','wheres','vegas','newvegas','falloutnewvegas','wheresurpa',
]);

// Scan a chat message for the first word that looks like a Roblox username.
// Strips leading @ symbol. Case-insensitive matching via normalization.
const extractUsername = (message) => {
    const trimmed = message.trim();

    // Whole message is the username (most common: "Mcjbomb")
    const whole = trimmed.replace(/^@/, '').replace(/[^a-zA-Z0-9_]/g, '');
    if (isValidRobloxUsername(whole) && !IGNORE_WORDS.has(whole.toLowerCase())) {
        return whole;
    }

    // Explicit @mention anywhere in the message
    const atMatch = trimmed.match(/@([a-zA-Z0-9_]{3,20})/);
    if (atMatch && !IGNORE_WORDS.has(atMatch[1].toLowerCase())) {
        return atMatch[1];
    }

    // Fall back to first valid word
    const words = trimmed.split(/\s+/);
    for (const word of words) {
        const cleaned = word.replace(/^@/, '').replace(/[^a-zA-Z0-9_]/g, '');
        if (isValidRobloxUsername(cleaned) && !IGNORE_WORDS.has(cleaned.toLowerCase())) {
            return cleaned;
        }
    }
    return null;
};

const norm = (username) => username.toLowerCase();

const isAlreadyOnScreen = (username) =>
    activeOnScreen.some(u => norm(u) === norm(username));

const isInAnyQueue = (username) => {
    const n = norm(username);
    return regularQueue.some(u => norm(u) === n)
        || vipQueue.some(u => norm(u) === n)
        || famousQueue.some(u => norm(u) === n);
};

// Drop names already dancing and collapse duplicate wait-list entries.
function scrubQueues() {
    const scrub = (queue, label) => {
        const seen = new Set();
        const before = queue.length;
        for (let i = queue.length - 1; i >= 0; i--) {
            const u = queue[i];
            const n = norm(u);
            if (isAlreadyOnScreen(u) || seen.has(n)) {
                queue.splice(i, 1);
            } else {
                seen.add(n);
            }
        }
        if (queue.length !== before) {
            console.log(`[Queue] Scrubbed ${label}: ${before} → ${queue.length}`);
        }
    };
    scrub(regularQueue, 'regular');
    scrub(vipQueue, 'vip');
    scrub(famousQueue, 'famous');
}

function addToQueue(username, source = 'manual') {
    if (!isValidRobloxUsername(username)) {
        return { ok: false, error: 'Invalid Roblox username (3–20 letters, numbers, underscore)' };
    }
    if (isAlreadyOnScreen(username)) {
        console.log(`[Queue] Skip ${username} via ${source} — already on floor`);
        return { ok: false, error: 'Already on the dance floor', skipped: true };
    }
    if (isInAnyQueue(username)) {
        console.log(`[Queue] Skip ${username} via ${source} — already waiting`);
        return { ok: false, error: 'Already in queue', skipped: true };
    }
    regularQueue.push(username);
    console.log(`[Queue] +${username} via ${source} (queue: ${regularQueue.length})`);
    return { ok: true, username, queueLength: regularQueue.length };
}

function allQueuedUsernames() {
    return [...regularQueue, ...vipQueue, ...famousQueue];
}

function isRobloxOnline() {
    return (Date.now() - lastHeartbeat) < 15000;
}

function queueNextFamousUser() {
    if (regularQueue.length > 0 || vipQueue.length > 0) return false;
    if (famousQueue.length >= MAX_FAMOUS_QUEUE) return false;
    if (!isRobloxOnline()) return false;

    const name = famousRotator.next({
        onScreen: activeOnScreen,
        inQueues: allQueuedUsernames(),
    });
    if (!name) return false;

    famousQueue.push(name);
    const stats = famousRotator.stats();
    console.log(`[Famous] Auto-queued ${name} (${famousQueue.length} waiting, ${stats.remainingThisCycle} fresh left this cycle)`);
    return true;
}

function primeFamousQueue(count = 3) {
    for (let i = 0; i < count; i++) {
        if (!queueNextFamousUser()) break;
    }
}

// --- TikTok Connection ---
const tiktokOptions = {
    ...(TIKTOK_SESSION_ID && TIKTOK_TARGET_IDC
        ? { sessionId: TIKTOK_SESSION_ID, ttTargetIdc: TIKTOK_TARGET_IDC }
        : {}),
    ...(TIKTOK_SIGN_API_KEY ? { signApiKey: TIKTOK_SIGN_API_KEY } : {}),
};
let tiktokConnection = new WebcastPushConnection(TIKTOK_USERNAME, tiktokOptions);

function connectToTikTok() {
    if (tiktokConnected) return;

    console.log(`[TikTok] Connecting to @${TIKTOK_USERNAME}...`);

    tiktokConnection.connect()
        .then(state => {
            tiktokConnected = true;
            tiktokRoomId = state.roomId;
            tiktokLastError = null;
            tiktokReconnectMs = 15000;
            console.log(`[TikTok] Connected! Room ID: ${state.roomId}`);
        })
        .catch(err => {
            tiktokConnected = false;
            tiktokLastError = err.message || String(err);
            const isRateLimit = tiktokLastError.includes('rate_limit');
            if (isRateLimit && !TIKTOK_SIGN_API_KEY) {
                tiktokReconnectMs = 55 * 60 * 1000;
                console.error('[TikTok] Rate limited & no API key.');
                console.error('[TikTok] → Add names manually: http://localhost:3000/queue');
                console.error(`[TikTok] → Will retry automatically in ${Math.round(tiktokReconnectMs / 60000)} min`);
            } else if (isRateLimit) {
                tiktokReconnectMs = Math.min(tiktokReconnectMs * 2, 3600000);
                console.error(`[TikTok] Rate limited — waiting ${Math.round(tiktokReconnectMs / 60000)} min before retry`);
            } else {
                tiktokReconnectMs = Math.min(tiktokReconnectMs * 1.5, 120000);
                console.error(`[TikTok] Connection failed — retry in ${Math.round(tiktokReconnectMs / 1000)}s:`, tiktokLastError);
            }
            setTimeout(connectToTikTok, tiktokReconnectMs);
        });
}

// --- TikTok Event Listeners ---

// Chat message → scan for a Roblox username anywhere in the message
tiktokConnection.on('chat', (data) => {
    console.log(`[Chat] ${data.uniqueId}: "${data.comment}"`);
    tiktokLastChat = { from: data.uniqueId, text: data.comment, at: new Date().toISOString() };

    const username = extractUsername(data.comment);
    if (!username) {
        console.log(`[Skip] No Roblox username found in: "${data.comment.trim()}"`);
        return;
    }

    addToQueue(username, 'tiktok');
});

// Gift received → bump sender to VIP queue
tiktokConnection.on('gift', (data) => {
    const username = data.uniqueId;
    console.log(`[Gift] ${username} sent gift ID: ${data.giftId}`);

    if (isValidRobloxUsername(username)) {
        // Pull out of regular queue if they were already waiting
        regularQueue = regularQueue.filter(u => u.toLowerCase() !== username.toLowerCase());

        // Add to VIP if not currently on the floor
        if (!activeOnScreen.some(u => u.toLowerCase() === username.toLowerCase())) {
            vipQueue.push(username);
            console.log(`[VIP] ${username} upgraded to priority queue!`);
        }
    }
});

// Auto-reconnect on disconnect
tiktokConnection.on('disconnected', () => {
    tiktokConnected = false;
    tiktokRoomId = null;
    console.warn('[TikTok] Disconnected. Auto-reconnecting...');
    setTimeout(connectToTikTok, tiktokReconnectMs);
});

tiktokConnection.on('error', (err) => {
    tiktokLastError = err.message || String(err);
    console.error('[TikTok] Stream error:', tiktokLastError);
});

// --- REST Endpoints for Roblox ---

// GET /api/queue/next — Roblox asks "who do I spawn next?"
// Also serves as the heartbeat — every poll resets the timer.
//
// Responses:
//   { status: 'spawn', username, type }        — floor has room, spawn normally
//   { status: 'bump',  evict, username, type } — floor full, evict oldest first
//   { status: 'empty' }                        — nothing queued right now
// Pull next eligible user; drop stale entries (already on floor) instead of blocking forever.
function pullNextFromQueue(queue) {
    while (queue.length > 0) {
        const candidate = queue.shift();
        if (!isAlreadyOnScreen(candidate)) {
            return candidate;
        }
        console.log(`[Queue] Dropped ${candidate} — already on floor`);
    }
    return null;
}

app.get('/api/queue/next', (req, res) => {
    if (robloxWasOffline) {
        console.log('[Heartbeat] Roblox reconnected — resuming spawns');
        robloxWasOffline = false;
    }
    lastHeartbeat = Date.now();
    scrubQueues();

    let nextUser = pullNextFromQueue(vipQueue);
    let nextType = nextUser ? 'VIP' : null;

    if (!nextUser) {
        nextUser = pullNextFromQueue(regularQueue);
        nextType = nextUser ? 'Regular' : null;
    }

    if (!nextUser) {
        nextUser = pullNextFromQueue(famousQueue);
        nextType = nextUser ? 'Featured' : null;
    }

    if (!nextUser) return res.json({ status: 'empty' });

    // Floor has room — spawn normally
    if (activeOnScreen.length < MAX_ON_SCREEN) {
        activeOnScreen.push(nextUser);
        console.log(`[Spawn] ${nextType}: ${nextUser} (${activeOnScreen.length}/${MAX_ON_SCREEN})`);
        return res.json({ status: 'spawn', username: nextUser, type: nextType });
    }

    // Floor is full — bump oldest to make room for next person
    const evict = activeOnScreen.shift();
    activeOnScreen.push(nextUser);
    console.log(`[Bump] Evicting ${evict} → Spawning ${nextUser} [${nextType}] (${activeOnScreen.length}/${MAX_ON_SCREEN})`);
    return res.json({ status: 'bump', evict, username: nextUser, type: nextType });
});

// POST /api/queue/done — Roblox signals a character finished their 60s dance
app.post('/api/queue/done', (req, res) => {
    const { username } = req.body;
    if (!username) return res.status(400).json({ error: 'Missing username' });

    activeOnScreen = activeOnScreen.filter(u => u.toLowerCase() !== username.toLowerCase());
    console.log(`[Done] ${username} left the floor. Open slots: ${MAX_ON_SCREEN - activeOnScreen.length}`);

    return res.json({ status: 'success' });
});

// POST /api/reset — called by SpawnScript on startup to wipe stale session state
app.post('/api/reset', (req, res) => {
    const prev = activeOnScreen.length;
    activeOnScreen = [];
    famousQueue = [];
    famousRotator.reset();
    primeFamousQueue(3);
    console.log(`[Reset] Roblox session started — cleared ${prev} stale active user(s), primed famous queue.`);
    return res.json({ status: 'ok' });
});

// POST /api/test/inject — manually push a username into the queue (testing only)
app.post('/api/test/inject', (req, res) => {
    const { username, message } = req.body;
    const name = username || extractUsername(message || '');
    if (!name) return res.status(400).json({ error: 'Missing username or message' });

    const result = addToQueue(name, 'inject');
    if (!result.ok) return res.status(400).json({ error: result.error });
    return res.json({ status: 'injected', username: name, queueLength: result.queueLength });
});

// POST /api/queue/add — same as inject, used by the manual queue page
app.post('/api/queue/add', (req, res) => {
    const { username, message } = req.body;
    const name = username || extractUsername(message || '');
    if (!name) return res.status(400).json({ error: 'Type a Roblox username or paste a chat message' });

    const result = addToQueue(name, 'manual');
    if (!result.ok) return res.status(400).json({ error: result.error });
    return res.json({ status: 'queued', username: name, queueLength: result.queueLength });
});

// Manual queue page — use when TikTok/Euler signup is broken
app.get('/queue', (req, res) => {
    res.type('html').send(`<!DOCTYPE html>
<html><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Spawn Queue</title>
<style>
  body{font-family:system-ui,sans-serif;max-width:480px;margin:40px auto;padding:0 16px;background:#111;color:#eee}
  h1{font-size:1.4rem} input,button{font-size:1.1rem;padding:10px;border-radius:8px;border:none;width:100%;box-sizing:border-box}
  input{background:#222;color:#fff;margin:8px 0} button{background:#0af;color:#000;font-weight:bold;cursor:pointer;margin-top:8px}
  .stat{background:#222;padding:12px;border-radius:8px;margin:16px 0;font-size:.95rem;line-height:1.6}
  .ok{color:#6f6}.err{color:#f66}.hint{color:#888;font-size:.85rem}
</style></head><body>
<h1>Spawn Queue</h1>
<p class="hint">Euler/TikTok auto-chat down? Use the <a href="/bridge" style="color:#0af">browser bridge</a> or type names below.</p>
<div class="stat" id="stat">Loading...</div>
<input id="name" placeholder="Roblox username e.g. Mcjbomb" autocomplete="off">
<input id="msg" placeholder="Or paste full chat message" autocomplete="off">
<button onclick="add()">Add to queue</button>
<p id="result"></p>
<script>
async function refresh(){
  const r=await fetch('/api/status'); const d=await r.json();
  document.getElementById('stat').innerHTML=
    'TikTok: '+(d.tiktokConnected?'<span class="ok">connected</span>':'<span class="err">offline</span>')+
    '<br>Roblox: '+(d.robloxOnline?'<span class="ok">polling</span>':'<span class="err">offline</span>')+
    '<br>Queue: '+d.regularQueueLength+' waiting — '+JSON.stringify(d.regularQueue)+
    '<br>On floor: '+d.activeCount+' — '+JSON.stringify(d.activeOnScreen);
}
async function add(){
  const username=document.getElementById('name').value.trim();
  const message=document.getElementById('msg').value.trim();
  const r=await fetch('/api/queue/add',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({username,message})});
  const d=await r.json();
  document.getElementById('result').innerHTML=r.ok
    ? '<span class="ok">Queued '+d.username+' (#'+d.queueLength+')</span>'
    : '<span class="err">'+(d.error||'Failed')+'</span>';
  document.getElementById('name').value=''; document.getElementById('msg').value='';
  refresh();
}
refresh(); setInterval(refresh,3000);
document.getElementById('name').addEventListener('keydown',e=>{if(e.key==='Enter')add()});
</script></body></html>`);
});

// Setup guide for TikTok → queue browser bridge (no Euler)
app.get('/bridge', (req, res) => {
    res.type('html').send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>TikTok Chat Bridge</title>
<style>body{font-family:system-ui;max-width:560px;margin:40px auto;padding:0 20px;background:#111;color:#eee;line-height:1.6}
h1{color:#0af} code,pre{background:#222;padding:2px 6px;border-radius:4px} ol{padding-left:1.2rem}
a{color:#0af}</style></head><body>
<h1>TikTok → Roblox Queue Bridge</h1>
<p>Routes live chat into your spawn queue <strong>without Euler Stream</strong>.</p>
<ol>
<li>Install <a href="https://www.tampermonkey.net/" target="_blank">Tampermonkey</a> in Chrome</li>
<li>Open the script file in your project:<br><code>tiktok_chat_bridge.user.js</code></li>
<li>Tampermonkey → Create new script → paste the file → Save</li>
<li>Make sure <code>node server.js</code> is running</li>
<li>Open your live in Chrome:<br><code>https://www.tiktok.com/@milkywizard/live</code></li>
<li>Chat messages auto-forward to the queue — look for blue "Roblox queue bridge ON" toast</li>
</ol>
<p>Manual fallback: <a href="/queue">/queue</a> · Status: <a href="/api/status">/api/status</a></p>
</body></html>`);
});

// GET /api/status — quick health check you can open in a browser
app.get('/api/status', (req, res) => {
    scrubQueues();
    res.json({
        activeOnScreen,
        activeCount: activeOnScreen.length,
        regularQueueLength: regularQueue.length,
        vipQueueLength: vipQueue.length,
        famousQueueLength: famousQueue.length,
        famousPoolStats: famousRotator.stats(),
        regularQueue: regularQueue.slice(0, 10),
        vipQueue: vipQueue.slice(0, 10),
        famousQueue: famousQueue.slice(0, 10),
        capacity: MAX_ON_SCREEN,
        tiktokConnected,
        tiktokRoomId,
        tiktokLastError,
        tiktokLastChat,
        robloxOnline: (Date.now() - lastHeartbeat) < 15000,
        secondsSinceRoblox: Math.round((Date.now() - lastHeartbeat) / 1000),
    });
});

// --- Start ---
app.listen(PORT, () => {
    console.log(`[Server] Running at http://localhost:${PORT}`);
    console.log(`[Server] Health check: http://localhost:${PORT}/api/status`);
    if (TIKTOK_SIGN_API_KEY) {
        console.log('[TikTok] Euler API key loaded from .env');
    } else {
        console.warn('[TikTok] No TIKTOK_SIGN_API_KEY — chat may rate-limit. Manual queue: http://localhost:3000/queue');
    }
    connectToTikTok();
    primeFamousQueue(3);
    setInterval(queueNextFamousUser, FAMOUS_FILL_INTERVAL_MS);
    console.log(`[Famous] Auto-queue enabled — ${famousRotator.stats().poolSize} accounts, new one every ${FAMOUS_FILL_INTERVAL_MS / 1000}s when chat is idle`);
});
