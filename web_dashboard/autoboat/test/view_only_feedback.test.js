const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const appSource = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');

function sourceBetween(startMarker, endMarker) {
    const start = appSource.indexOf(startMarker);
    const end = appSource.indexOf(endMarker, start);
    assert.notEqual(start, -1, `Missing source marker: ${startMarker}`);
    assert.notEqual(end, -1, `Missing source marker: ${endMarker}`);
    return appSource.slice(start, end);
}

function liveMavlinkSource() {
    return sourceBetween(
        '// ========== TEMPORARY LIVE MAVLINK VIEW ==========',
        '// ========== END TEMPORARY LIVE MAVLINK VIEW =========='
    );
}

test('blocked preset exits before confirmation, local mutation, or success feedback', () => {
    const elements = new Map([
        ['preset-input', { value: 'before', scrollIntoView() {} }],
        ['preset-status', {
            textContent: '',
            classList: { add() {}, remove() {} }
        }]
    ]);
    const logs = [];
    let confirmations = 0;
    let mutations = 0;
    let sends = 0;
    const context = {
        ROSLIB: { Topic: class {} },
        ros: {},
        console: { warn() {} },
        addLog(message, level) { logs.push([message, level]); },
        showFeedback() {},
        updateGPS() {},
        confirm() { confirmations += 1; return true; },
        setTimeout(callback) { callback(); },
        document: {
            body: { classList: { add() {} } },
            querySelectorAll() { return []; },
            getElementById(id) { return elements.get(id) || null; }
        },
        updatePerceptionInputs() { mutations += 1; elements.get('preset-input').value = 'after'; },
        updateControllerInputs() { mutations += 1; },
        applyPerceptionParameters() { sends += 1; return true; },
        applyControllerParameters() { sends += 1; return true; },
        expandTuningSection() {},
        flashChangedInputs() {}
    };

    vm.createContext(context);
    vm.runInContext(
        `${liveMavlinkSource()}\n` +
        `const TUNING_PRESETS = { universal: {
            name: 'Universal', perception: { min_height: -1 }, controller: { critical_distance: 5 }
        } };\n` +
        `const PRESET_INPUT_IDS = ['preset-input'];\n` +
        `${sourceBetween('function applyPreset(presetName) {', '// Update Perception input fields from preset')}\n` +
        'globalThis.__presetApi = { applyPreset };',
        context
    );

    assert.equal(context.__presetApi.applyPreset('universal'), false);
    assert.equal(confirmations, 0);
    assert.equal(mutations, 0);
    assert.equal(sends, 0);
    assert.equal(elements.get('preset-input').value, 'before');
    assert.equal(elements.get('preset-status').textContent, '');
    assert.equal(logs.some(([message]) => /preset applied/i.test(message)), false);
});

test('mission command helper returns a real dispatch boolean', () => {
    const context = {
        connected: true,
        missionCommandPublisher: null,
        ROSLIB: {
            Topic: class {
                publish() {}
            },
            Message: class {
                constructor(value) { Object.assign(this, value); }
            }
        },
        ros: {},
        DEBUG_MODE: false,
        addLog() {},
        publishDashboardWrite() { return true; },
        console: { log() {} }
    };

    vm.createContext(context);
    vm.runInContext(
        `${sourceBetween('// Send mission command to Planner (modular mode)', '// Emergency Stop - Immediately halt the boat')}\n` +
        'globalThis.__missionApi = { sendMissionCommand };',
        context
    );

    assert.equal(context.__missionApi.sendMissionCommand('start_mission'), true);
    context.publishDashboardWrite = () => false;
    assert.equal(context.__missionApi.sendMissionCommand('stop_mission'), false);
});

function createBlockedMissionHandlerHarness() {
    const handlers = new Map();
    const scheduledAlerts = [];
    const elements = new Map();
    const logs = [];
    const sentCommands = [];
    let previewClears = 0;
    let serviceCalls = 0;
    const context = {
        DEBUG_MODE: false,
        ros: {},
        missionState: { state: 'UNKNOWN', startLat: 48, startLon: 2 },
        gpsOrigin: null,
        currentState: { gps: { lat: 0, lon: 0 }, config: {} },
        ROSLIB: {
            Service: class {},
            ServiceRequest: class {}
        },
        document: {
            getElementById(id) {
                if (!elements.has(id)) {
                    elements.set(id, {
                        addEventListener(type, callback) {
                            if (type === 'click') handlers.set(id, callback);
                        },
                        classList: { add() {}, remove() {} },
                        scrollIntoView() {},
                        focus() {}
                    });
                }
                return elements.get(id);
            }
        },
        debounceCommand(callback) { callback(); },
        debounceGroup(_name, _ms, callback) { callback(); },
        callDashboardWriteService() { serviceCalls += 1; return false; },
        sendMissionCommand(command) { sentCommands.push(command); return false; },
        setTimeout(callback) { scheduledAlerts.push(callback); },
        alert(message) { scheduledAlerts.push(message); },
        confirm() { return true; },
        clearWaypointPreview() { previewClears += 1; },
        emergencyStop() { return false; },
        showFeedback() {},
        addLog(message) { logs.push(message); },
        gpsToLocal() { return { x: 0, y: 0 }; },
        readInput() { return 3.5; }
    };

    vm.createContext(context);
    vm.runInContext(
        `${sourceBetween('function initMissionControl() {', '// Generate waypoints and update config')}\n` +
        'globalThis.__missionHandlersApi = { initMissionControl };',
        context
    );
    context.__missionHandlersApi.initMissionControl();

    return {
        context,
        handlers,
        logs,
        scheduledAlerts,
        sentCommands,
        getPreviewClears: () => previewClears,
        getServiceCalls: () => serviceCalls
    };
}

test('every blocked mission handler avoids success feedback and local mutation', () => {
    const cases = [
        ['btn-confirm-waypoints', 'confirm_waypoints'],
        ['btn-cancel-waypoints', 'cancel_waypoints'],
        ['btn-start-mission', 'start_mission'],
        ['btn-stop-mission', null],
        ['btn-resume-mission', 'resume_mission'],
        ['btn-reset-mission', 'reset_mission'],
        ['btn-go-home', 'go_home'],
        ['btn-joystick-enable', 'joystick_enable'],
        ['btn-joystick-disable', 'joystick_disable']
    ];

    for (const [buttonId, expectedCommand] of cases) {
        const harness = createBlockedMissionHandlerHarness();
        const handler = harness.handlers.get(buttonId);
        assert.equal(typeof handler, 'function', `Missing click handler for #${buttonId}`);

        handler();

        assert.deepEqual(harness.scheduledAlerts, [], `${buttonId} scheduled success feedback`);
        assert.equal(harness.getPreviewClears(), 0, `${buttonId} cleared the waypoint preview`);
        assert.equal(harness.context.missionState.startLat, 48, `${buttonId} changed startLat`);
        assert.equal(harness.context.missionState.startLon, 2, `${buttonId} changed startLon`);
        assert.deepEqual(harness.logs, [], `${buttonId} logged a local success state`);
        if (expectedCommand === null) {
            assert.equal(harness.getServiceCalls(), 1, `${buttonId} did not attempt the guarded service`);
            assert.deepEqual(harness.sentCommands, []);
        } else {
            assert.equal(harness.getServiceCalls(), 0);
            assert.deepEqual(harness.sentCommands, [expectedCommand]);
        }
    }
});

test('stop handler has no dead dispatch branch after the guarded call', () => {
    const stopHandler = sourceBetween(
        "document.getElementById('btn-stop-mission')",
        "document.getElementById('btn-resume-mission')"
    );
    assert.doesNotMatch(stopHandler, /const dispatched\s*=/);
    assert.doesNotMatch(stopHandler, /if \(!dispatched\) return/);
});

test('blocked health check leaves the panel usable and reports no start state', () => {
    const button = { disabled: false };
    const statuses = [];
    const lines = [];
    let subscriptions = 0;
    const context = {
        ros: { isConnected: true },
        healthCheckStartTime: null,
        ROSLIB: {
            Service: class {},
            ServiceRequest: class {}
        },
        document: {
            getElementById(id) { return id === 'btn-run-health-check' ? button : null; }
        },
        dashboardWriteAllowed() { return false; },
        subscribeHealthTopics() { subscriptions += 1; },
        setHealthStatus(state, text) { statuses.push([state, text]); },
        clearHealthOutput() {},
        appendHealthLine(line) { lines.push(line); },
        callDashboardWriteService() { throw new Error('blocked health check must not reach service dispatch'); }
    };

    vm.createContext(context);
    vm.runInContext(
        `${sourceBetween('function runHealthCheck() {', "window.addEventListener('load', () => {")}\n` +
        'globalThis.__healthApi = { runHealthCheck };',
        context
    );

    assert.equal(context.__healthApi.runHealthCheck(), false);
    assert.equal(button.disabled, false);
    assert.equal(subscriptions, 0);
    assert.deepEqual(statuses, []);
    assert.deepEqual(lines, []);
});

test('missing GPS readiness remains fail-closed while connected', () => {
    const missionSource = sourceBetween(
        'function updateMissionControlUI(state) {',
        '// Display waypoints on map'
    );
    assert.match(missionSource, /gpsReady\s*=\s*\(state\.gps_ready !== undefined\)\s*\?\s*state\.gps_ready\s*:\s*false/);
    assert.match(appSource, /updateMissionControlUI\(\{ state: 'UNKNOWN', gps_ready: false \}\)/);
});

test('injected export and copy buttons remain view-only diagnostic controls', () => {
    const appended = [];
    const makeContainer = () => ({
        classList: { add() {} },
        appendChild(child) { appended.push(child); }
    });
    const containers = new Map([
        ['.mission-control-panel h2', makeContainer()],
        ['.health-check-panel .terminal-controls', makeContainer()]
    ]);
    const context = {
        document: {
            querySelector(selector) { return containers.get(selector) || null; },
            createElement() {
                return {
                    className: '',
                    textContent: '',
                    title: '',
                    addEventListener() {}
                };
            }
        }
    };

    vm.createContext(context);
    vm.runInContext(
        `${sourceBetween('function addExportButton(', "window.addEventListener('load', () => {")}\n` +
        'globalThis.__exportApi = { addExportButton, addExportButtonToControls, addCopyButton };',
        context
    );

    context.__exportApi.addExportButton('.mission-control-panel h2', 'system', 'Export Snapshot');
    context.__exportApi.addExportButtonToControls('.health-check-panel .terminal-controls', 'health', 'Export JSON');
    context.__exportApi.addCopyButton('.health-check-panel .terminal-controls', '#health-check-output', 'Copy');

    assert.equal(appended.length, 3);
    for (const button of appended) {
        assert.match(button.className, /\bview-only-diagnostic-control\b/);
    }
});
