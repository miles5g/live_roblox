// Curated famous Roblox accounts — devs, staff, richest players, big creators.
// Roblox has no public "most friends" API, so we rotate this hand-picked pool.
// Names are shuffled each cycle so viewers rarely see repeats in one stream.

function shuffle(arr) {
    const a = [...arr];
    for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
}

const FAMOUS_USERS = [
    // Staff & OG legends
    'builderman', 'Roblox', 'Stickmasterluke', 'Shedletsky', 'Merely', 'Seranok',
    'SonOfSevenless', 'Brighteyes', 'Asimo3089', 'Litozinnamon', 'Diddleshot',
    // Richest / most-followed personalities
    'Linkmon99', 'KreekCraft', 'Flamingo', 'DenisDaily', 'Poke', 'Tofuu', 'Hyper',
    'PrestonPlayz', 'TanqR', 'ItsFunneh', 'InquisitorMaster', 'Thinknoodles',
    'Bandites', 'Sub2ZeroYT', 'AntAntixx', 'Speedy2662', 'Blizzei', 'KonekoKitten',
    // Major game devs
    'BadccVoid', 'CloneTrooper1019', 'Berezaa', 'Quenty', 'ScriptOn', 'Defaultio',
    'Explode1', 'OrbitalOwen', 'Nolan', 'Coeptus', 'Rukiryo', 'Creeperslayer100',
    'Nikilis', 'Alexnewtron', 'loleris', 'NewFissy', 'Bethink', 'ROLVe',
    'jandel', 'Wistful', 'Prexi', 'Vesterius', 'Lilly_S', 'OFish', 'Kikuxz',
    'xSuperMarioFan', 'Digiitaal', 'BlockZone', 'SonarSystems', 'MyUsernamesThis',
    'TanishF', 'Parloxx', 'UpliftGames', 'PlayBlox', 'Remindful', 'GamingMermaid',
    'Sketch', 'Corl', 'SubRoblox', 'Temprist', 'RussoPlays', 'Slogo', 'Jelly',
    'TypicalGamer', 'AliA', 'DanTDM', 'UnspeakableGaming', 'MooseCraft',
    // More creators & community figures
    'ZephPlayz', 'AshleyTheUnicorn', 'LaurelCraft', 'MeganPlays', 'ShanePlays',
    'Funneh', 'DraconiteDragon', 'GoldenGlare', 'PaintingRainbows', 'LunarEclipse',
    'BloxyDev', 'MaximumADHD', 'Bobys1371', 'Jaredvaldez4', 'PlaceRebuilder',
];

// Dedupe and drop invalid Roblox username patterns
const VALID = /^[a-zA-Z0-9_]{3,20}$/;
const UNIQUE_FAMOUS = [...new Set(FAMOUS_USERS.filter(n => VALID.test(n)))];

class FamousRotator {
    constructor(users = UNIQUE_FAMOUS) {
        this.allUsers = users;
        this.pool = shuffle(users);
        this.index = 0;
        this.usedThisCycle = new Set();
        this.cycleCount = 0;
    }

    _newCycle() {
        this.cycleCount++;
        this.pool = shuffle(this.allUsers);
        this.index = 0;
        this.usedThisCycle.clear();
        console.log(`[Famous] Cycle ${this.cycleCount} — shuffled ${this.pool.length} accounts`);
    }

    /** Pick next famous user not on screen and not already used this cycle. */
    next({ onScreen = [], inQueues = [] } = {}) {
        const blocked = new Set([
            ...onScreen.map(u => u.toLowerCase()),
            ...inQueues.map(u => u.toLowerCase()),
        ]);

        for (let tries = 0; tries < this.allUsers.length * 2; tries++) {
            if (this.index >= this.pool.length) this._newCycle();

            const name = this.pool[this.index++];
            const lower = name.toLowerCase();
            if (this.usedThisCycle.has(lower)) continue;
            if (blocked.has(lower)) continue;

            this.usedThisCycle.add(lower);
            return name;
        }
        return null;
    }

    stats() {
        return {
            poolSize: this.allUsers.length,
            usedThisCycle: this.usedThisCycle.size,
            remainingThisCycle: this.allUsers.length - this.usedThisCycle.size,
            cycleCount: this.cycleCount,
        };
    }

    reset() {
        this.pool = shuffle(this.allUsers);
        this.index = 0;
        this.usedThisCycle.clear();
        this.cycleCount = 0;
    }
}

module.exports = { FAMOUS_USERS: UNIQUE_FAMOUS, FamousRotator, shuffle };
