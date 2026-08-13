const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dashboardDir = path.join(__dirname, '..');
const appSource = fs.readFileSync(path.join(dashboardDir, 'app.js'), 'utf8');
const indexSource = fs.readFileSync(path.join(dashboardDir, 'index.html'), 'utf8');
const styleSource = fs.readFileSync(path.join(dashboardDir, 'style_merged.css'), 'utf8');

function sourceBetween(startMarker, endMarker) {
    const start = appSource.indexOf(startMarker);
    const end = appSource.indexOf(endMarker, start);
    assert.notEqual(start, -1, `Missing source marker: ${startMarker}`);
    assert.notEqual(end, -1, `Missing source marker: ${endMarker}`);
    return appSource.slice(start, end);
}

function createClassList(initial = []) {
    const classes = new Set(initial);
    return {
        add(...names) { names.forEach((name) => classes.add(name)); },
        remove(...names) { names.forEach((name) => classes.delete(name)); },
        contains(name) { return classes.has(name); },
        list() { return [...classes]; }
    };
}

function createHarness() {
    const elements = new Map();

    function createElement(id) {
        return {
            id,
            textContent: '',
            className: '',
            classList: createClassList(),
            style: {
                values: new Map(),
                setProperty(name, value) { this.values.set(name, String(value)); },
                getPropertyValue(name) { return this.values.get(name) || ''; }
            }
        };
    }

    for (const id of [
        'left-thrust', 'right-thrust',
        'left-thrust-bar', 'right-thrust-bar',
        'person-stop-status', 'stop-override'
    ]) {
        elements.set(id, createElement(id));
    }

    let clock = 1000000;
    const context = {
        document: {
            getElementById(id) { return elements.get(id) || null; }
        },
        currentState: { thrusters: { left: 0, right: 0 } },
        missionState: { stopOverride: false },
        Date: { now: () => clock },
        setInterval: () => 0,
        console
    };
    const advance = (ms) => { clock += ms; };

    vm.createContext(context);
    const thrusterSource = sourceBetween(
        '// Update thruster data',
        '// ========== DIGITAL TWIN HULL ENVELOPE =========='
    );
    const envelopeSource = sourceBetween(
        '// ========== DIGITAL TWIN HULL ENVELOPE ==========',
        '// ========== END DIGITAL TWIN HULL ENVELOPE =========='
    );
    vm.runInContext(
        `${envelopeSource}\n${thrusterSource}\n` +
        'globalThis.__twinApi = { updateThruster, hullThrustClass, ' +
        'applyPersonStopStatus, renderPersonStopBadge, resetPersonStopStatus, ' +
        'refreshPersonStopFreshness, personStatusIsCurrent, readPersonVerdict, ' +
        'applyControlStatus, isStatusObject, twinState };',
        context
    );

    // Reproduce the real subscription callback: JSON in, no guard of its own.
    // Anything the handler dereferences unsafely surfaces here, not in a
    // direct helper call with an already-shaped object.
    const deliver = (json) => {
        const data = JSON.parse(json);
        return context.__twinApi.applyControlStatus(data);
    };

    return { api: context.__twinApi, elements, advance, deliver, context };
}

// --- thrust envelope ---------------------------------------------------------

test('forward thrust renders without a direction flag', () => {
    const { api, elements } = createHarness();
    api.updateThruster('left', 420.0);
    const bar = elements.get('left-thrust-bar');
    assert.equal(elements.get('left-thrust').textContent, '420.0 N');
    assert.equal(bar.classList.contains('reverse'), false);
    assert.equal(bar.classList.contains('envelope-violation'), false);
});

test('negative thrust on a forward-only hull is flagged as an envelope breach', () => {
    const { api, elements } = createHarness();
    api.twinState.forwardOnly = true;
    api.updateThruster('left', -300.0);
    const bar = elements.get('left-thrust-bar');
    assert.equal(bar.classList.contains('envelope-violation'), true);
    assert.equal(bar.classList.contains('reverse'), false);
});

test('the breach reading is shown, never silently clamped to zero', () => {
    const { api, elements } = createHarness();
    api.twinState.forwardOnly = true;
    api.updateThruster('right', -250.0);
    assert.equal(elements.get('right-thrust').textContent, '-250.0 N');
    assert.equal(api.twinState.forwardOnly, true);
});

test('negative thrust is ordinary reverse when the hull allows it', () => {
    const { api, elements } = createHarness();
    api.twinState.forwardOnly = false;
    api.updateThruster('left', -300.0);
    const bar = elements.get('left-thrust-bar');
    assert.equal(bar.classList.contains('reverse'), true);
    assert.equal(bar.classList.contains('envelope-violation'), false);
});

test('a direction flag does not survive the next forward reading', () => {
    const { api, elements } = createHarness();
    api.updateThruster('left', -300.0);
    api.updateThruster('left', 300.0);
    assert.deepEqual(elements.get('left-thrust-bar').classList.list(), []);
});

// --- person hold -------------------------------------------------------------

const EVIDENCED_CLEAR = {
    person_stop: false,
    person_verdict_known: true,
    person_feed_fresh: true
};

const HELD = {
    person_stop: true,
    person_verdict_known: true,
    person_feed_fresh: true
};

test('a person hold is rendered as a critical badge', () => {
    const { api, elements } = createHarness();
    const held = api.applyPersonStopStatus({ ...HELD, forward_only: true });
    assert.equal(held, true);
    const el = elements.get('person-stop-status');
    assert.equal(el.textContent, 'PERSON — HOLD');
    assert.match(el.className, /critical/);
});

test('a hold is shown even when nothing corroborates it', () => {
    // The safe direction never waits for evidence.
    const { api, elements } = createHarness();
    api.applyPersonStopStatus({
        person_stop: true, person_verdict_known: false, person_feed_fresh: false
    });
    assert.equal(elements.get('person-stop-status').textContent, 'PERSON — HOLD');
});

test('clearing the hold restores the clear badge when evidenced', () => {
    const { api, elements } = createHarness();
    api.applyPersonStopStatus(HELD);
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    const el = elements.get('person-stop-status');
    assert.equal(el.textContent, 'Clear');
    assert.match(el.className, /clear/);
});

test('a controller that has never heard an alert does not read Clear', () => {
    // The controller publishes person_stop:false from boot, and the idle loop
    // starts emitting status immediately — long before any camera reports.
    const { api, elements } = createHarness();
    api.applyPersonStopStatus({
        mode: 'IDLE',
        person_stop: false,
        person_verdict_known: false,
        person_feed_fresh: false
    });
    const el = elements.get('person-stop-status');
    assert.equal(el.textContent, 'Waiting');
    assert.equal(/\bclear\b/.test(el.className), false);
});

test('a stale detector feed cannot claim the water is clear', () => {
    // Simulation runs with no camera at all; the row must stay honest.
    const { api, elements } = createHarness();
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    assert.equal(elements.get('person-stop-status').textContent, 'Clear');
    api.applyPersonStopStatus({ ...EVIDENCED_CLEAR, person_feed_fresh: false });
    assert.equal(elements.get('person-stop-status').textContent, 'Waiting');
});

test('a controller that goes quiet stops counting as an all-clear', () => {
    // Nothing arrives to correct a stale Clear, so it has to age out on its
    // own — the controller dying looks identical to a calm waterway otherwise.
    const { api, elements, advance } = createHarness();
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    assert.equal(elements.get('person-stop-status').textContent, 'Clear');

    advance(4000);
    api.refreshPersonStopFreshness();
    assert.equal(elements.get('person-stop-status').textContent, 'Clear');

    advance(2000);
    api.refreshPersonStopFreshness();
    assert.equal(elements.get('person-stop-status').textContent, 'Waiting');
});

test('a quiet controller cannot hide an active hold', () => {
    // Ageing out must never downgrade a hold to something less alarming.
    const { api, elements, advance } = createHarness();
    api.applyPersonStopStatus({
        person_stop: true, person_verdict_known: true, person_feed_fresh: true
    });
    advance(60000);
    api.refreshPersonStopFreshness();
    assert.equal(elements.get('person-stop-status').textContent, 'PERSON — HOLD');
});

test('a fresh status message revives the reading', () => {
    const { api, elements, advance } = createHarness();
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    advance(9000);
    api.refreshPersonStopFreshness();
    assert.equal(elements.get('person-stop-status').textContent, 'Waiting');
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    assert.equal(elements.get('person-stop-status').textContent, 'Clear');
});

test('coerced verdict fields are rejected, not rendered as Clear', () => {
    // The string "false" is truthy, so `!!` would paint a confident green
    // badge out of a malformed status message.
    const coerced = [
        { person_stop: 'false', person_verdict_known: 'false', person_feed_fresh: 'false' },
        { person_stop: 0, person_verdict_known: 1, person_feed_fresh: 1 },
        { person_stop: false, person_verdict_known: 'true', person_feed_fresh: true },
        { person_stop: null, person_verdict_known: true, person_feed_fresh: true }
    ];
    for (const data of coerced) {
        const { api, elements } = createHarness();
        api.applyPersonStopStatus(data);
        assert.equal(api.readPersonVerdict(data), null, JSON.stringify(data));
        assert.equal(elements.get('person-stop-status').textContent, 'Waiting',
            JSON.stringify(data));
    }
});

test('a partial verdict is no verdict', () => {
    const partial = [
        { person_stop: false },
        { person_stop: false, person_verdict_known: true },
        { person_stop: false, person_feed_fresh: true },
        { mode: 'IDLE' }
    ];
    for (const data of partial) {
        assert.equal(api_readsNull(data), true, JSON.stringify(data));
    }
});

function api_readsNull(data) {
    const { api } = createHarness();
    return api.readPersonVerdict(data) === null;
}

test('field-less status messages cannot keep an old all-clear alive', () => {
    // A controller emitting status without the person fields is not
    // confirming anything; only a complete verdict restarts the clock.
    const { api, elements, advance } = createHarness();
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    assert.equal(elements.get('person-stop-status').textContent, 'Clear');

    for (let i = 0; i < 3; i += 1) {
        advance(4000);
        api.applyPersonStopStatus({ mode: 'IDLE' });
    }
    assert.equal(elements.get('person-stop-status').textContent, 'Waiting');
});

test('a non-object status payload does not throw', () => {
    for (const data of [null, undefined, 42, 'status', [], [1, 2]]) {
        const { api, elements } = createHarness();
        assert.doesNotThrow(() => api.applyPersonStopStatus(data), String(data));
        assert.equal(elements.get('person-stop-status').textContent, 'Waiting');
    }
});

test('a malformed status message can never release an active hold', () => {
    const malformed = [
        null, undefined, 42, 'status', [],
        { mode: 'IDLE' },
        { person_stop: false },
        { person_stop: 'false', person_verdict_known: true, person_feed_fresh: true },
        { person_stop: 0, person_verdict_known: true, person_feed_fresh: true }
    ];
    for (const data of malformed) {
        const { api, elements } = createHarness();
        api.applyPersonStopStatus(HELD);
        assert.equal(api.applyPersonStopStatus(data), true, String(data));
        assert.equal(elements.get('person-stop-status').textContent, 'PERSON — HOLD',
            String(data));
    }
});

test('forward_only is only believed as a real boolean', () => {
    const { api } = createHarness();
    api.applyPersonStopStatus({ ...EVIDENCED_CLEAR, forward_only: 'false' });
    assert.equal(api.twinState.forwardOnly, true);
    api.applyPersonStopStatus({ ...EVIDENCED_CLEAR, forward_only: false });
    assert.equal(api.twinState.forwardOnly, false);
});

// --- the real callback path, not just the helper -----------------------------

test('well-formed JSON that is not an object does not crash the handler', () => {
    // JSON.parse returns these happily; the old handler then dereferenced them.
    for (const json of ['null', '42', '[]', '"status"', 'true', '[1,2,3]']) {
        const { deliver } = createHarness();
        assert.doesNotThrow(() => deliver(json), json);
        assert.equal(deliver(json), false, json);
    }
});

test('a non-object status message cannot release an active hold', () => {
    for (const json of ['null', '42', '[]', '"status"', 'true']) {
        const { api, elements, deliver } = createHarness();
        api.applyPersonStopStatus(HELD);
        assert.doesNotThrow(() => deliver(json), json);
        assert.equal(api.twinState.personStop, true, json);
        assert.equal(elements.get('person-stop-status').textContent,
            'PERSON — HOLD', json);
    }
});

test('a non-object status message does not refresh the staleness clock', () => {
    const { api, elements, advance, deliver } = createHarness();
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    assert.equal(elements.get('person-stop-status').textContent, 'Clear');
    for (let i = 0; i < 3; i += 1) {
        advance(4000);
        deliver('null');
    }
    assert.equal(elements.get('person-stop-status').textContent, 'Waiting');
});

test('the stop latch indicator is driven through the same callback', () => {
    const { elements, deliver, context } = createHarness();
    deliver(JSON.stringify({ ...EVIDENCED_CLEAR, stop_override: true }));
    assert.equal(context.missionState.stopOverride, true);
    assert.equal(elements.get('stop-override').textContent, 'STOP LATCHED');

    deliver(JSON.stringify({ ...EVIDENCED_CLEAR, stop_override: false }));
    assert.equal(context.missionState.stopOverride, false);
    assert.equal(elements.get('stop-override').textContent, 'Inactive');
});

// Coercion is wrong in both directions, so both are pinned. A falsy
// non-boolean (0, null, "") would clear a latch that is still set; any
// non-empty string — "false" included, since it is truthy — would raise one
// that was never set. The only correct behaviour is to change nothing.
const NON_BOOLEANS = ['"false"', '"true"', '""', '0', '1', 'null', '[]', '{}'];

test('a non-boolean stop_override cannot clear a set latch indicator', () => {
    for (const bad of NON_BOOLEANS) {
        const { elements, deliver, context } = createHarness();
        deliver(JSON.stringify({ ...EVIDENCED_CLEAR, stop_override: true }));
        assert.equal(elements.get('stop-override').textContent, 'STOP LATCHED');

        deliver(`{"stop_override": ${bad}}`);
        assert.equal(context.missionState.stopOverride, true, bad);
        assert.equal(elements.get('stop-override').textContent, 'STOP LATCHED', bad);
    }
});

test('a non-boolean stop_override cannot raise an unset latch indicator', () => {
    for (const bad of NON_BOOLEANS) {
        const { elements, deliver, context } = createHarness();
        deliver(JSON.stringify({ ...EVIDENCED_CLEAR, stop_override: false }));
        assert.equal(elements.get('stop-override').textContent, 'Inactive');

        deliver(`{"stop_override": ${bad}}`);
        assert.equal(context.missionState.stopOverride, false, bad);
        assert.equal(elements.get('stop-override').textContent, 'Inactive', bad);
    }
});

test('a non-boolean person_stop cannot raise an unset hold', () => {
    // The mirror of the release case: a truthy non-boolean must not invent a
    // hold either, or the badge stops meaning anything.
    for (const bad of NON_BOOLEANS) {
        const { api, elements, deliver } = createHarness();
        deliver(JSON.stringify(EVIDENCED_CLEAR));
        assert.equal(elements.get('person-stop-status').textContent, 'Clear');

        deliver(`{"person_stop": ${bad}, "person_verdict_known": true, ` +
            '"person_feed_fresh": true}');
        assert.equal(api.twinState.personStop, false, bad);
        assert.equal(elements.get('person-stop-status').textContent, 'Clear', bad);
    }
});

test('a status message without the field leaves the hold untouched', () => {
    const { api } = createHarness();
    api.applyPersonStopStatus(HELD);
    assert.equal(api.applyPersonStopStatus({ mode: 'NAVIGATION' }), true);
});

test('resetting also forgets the evidence flags', () => {
    const { api } = createHarness();
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    api.resetPersonStopStatus();
    assert.equal(api.twinState.personVerdictKnown, false);
    assert.equal(api.twinState.personFeedFresh, false);
});

test('the hull envelope flag tracks the controller', () => {
    const { api } = createHarness();
    api.applyPersonStopStatus({ forward_only: false });
    assert.equal(api.twinState.forwardOnly, false);
    assert.equal(api.hullThrustClass(-1.0), 'reverse');
    api.applyPersonStopStatus({ forward_only: true });
    assert.equal(api.hullThrustClass(-1.0), 'envelope-violation');
});

test('a fresh page defaults to the forward-only envelope', () => {
    const { api } = createHarness();
    assert.equal(api.twinState.forwardOnly, true);
    assert.equal(api.hullThrustClass(-1), 'envelope-violation');
});

test('the hold reads unknown until a controller status arrives', () => {
    const { api, elements } = createHarness();
    assert.equal(api.twinState.personStop, null);
    api.renderPersonStopBadge();
    const el = elements.get('person-stop-status');
    assert.equal(el.textContent, 'Waiting');
    assert.equal(/\bclear\b/.test(el.className), false);
});

test('a dropped link forgets the last verdict instead of asserting all-clear', () => {
    const { api, elements } = createHarness();
    api.applyPersonStopStatus(EVIDENCED_CLEAR);
    assert.equal(elements.get('person-stop-status').textContent, 'Clear');
    api.resetPersonStopStatus();
    assert.equal(api.twinState.personStop, null);
    assert.equal(elements.get('person-stop-status').textContent, 'Waiting');
});

// --- markup and styling contract ---------------------------------------------

test('the person hold has exactly one element in the markup', () => {
    const matches = indexSource.match(/id="person-stop-status"/g) || [];
    assert.equal(matches.length, 1);
});

test('the shipped markup does not claim the water is clear', () => {
    const row = indexSource
        .split('\n')
        .find((line) => line.includes('id="person-stop-status"'));
    assert.ok(row, 'person-stop-status row missing');
    assert.equal(/badge clear/.test(row), false, row.trim());
    assert.match(row, />Waiting</);
});

test('the disconnect path clears the person verdict', () => {
    assert.match(appSource, /resetPersonStopStatus\(\);/);
    const closeBlock = appSource.slice(
        appSource.indexOf("ros.on('close'"),
        appSource.indexOf("addLog('Connection closed")
    );
    assert.match(closeBlock, /resetPersonStopStatus\(\)/);
});

test('the envelope-violation style is defined', () => {
    assert.match(styleSource, /\.thrust-fill\.envelope-violation\s*\{/);
});

test('no thruster tooltip still advertises reverse as a direction', () => {
    const thrusterTooltips = indexSource
        .split('\n')
        .filter((line) => /id="(left|right)-thrust"/.test(line) || /thruster command/.test(line));
    for (const line of thrusterTooltips) {
        assert.equal(/negative = reverse/.test(line), false, line.trim());
    }
});
