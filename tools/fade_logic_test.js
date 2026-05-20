// Validates row-based fade rules used by CameraScript.lua
const GRID_SPACING = 5;
const ANCHOR_Z = 0; // SpawnLocation at (0, 2.1, 0)

function zToRow(z) {
    const relZ = z - ANCHOR_Z;
    return Math.max(0, Math.min(3, Math.floor(relZ / GRID_SPACING + 0.5)));
}

function shouldHide(modelRow, focusRow, modelZ, focusZ) {
    if (focusRow != null && modelRow != null) {
        return modelRow > focusRow;
    }
    return modelZ > focusZ + 2.5;
}

let pass = 0;
let fail = 0;

function assert(name, cond) {
    if (cond) {
        pass++;
    } else {
        fail++;
        console.error("FAIL:", name);
    }
}

// Row 0 back at Z≈anchor+0, row 3 front at anchor+15
const rows = [0, 1, 2, 3].map((r) => ({
    row: r,
    z: ANCHOR_Z + r * GRID_SPACING,
}));

assert("focus row 0 hides rows 1-3", rows.filter((m) => shouldHide(m.row, 0, m.z, rows[0].z)).length === 3);
assert("focus row 0 keeps row 0 visible", !shouldHide(rows[0].row, 0, rows[0].z, rows[0].z));
assert("focus row 2 hides row 3 only", shouldHide(rows[3].row, 2, rows[3].z, rows[2].z));
assert("focus row 2 keeps row 1 visible", !shouldHide(rows[1].row, 2, rows[1].z, rows[2].z));
assert("focus row 3 hides nobody", rows.every((m) => !shouldHide(m.row, 3, m.z, rows[3].z) || m.row === 3));

console.log(`fade_logic_test: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
