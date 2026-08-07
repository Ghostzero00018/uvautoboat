const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const appSource = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const htmlSource = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const cssSource = fs.readFileSync(path.join(__dirname, '..', 'style_merged.css'), 'utf8');

function liveMavlinkSource() {
    const startMarker = '// ========== TEMPORARY LIVE MAVLINK VIEW ==========';
    const endMarker = '// ========== END TEMPORARY LIVE MAVLINK VIEW ==========';
    const start = appSource.indexOf(startMarker);
    const end = appSource.indexOf(endMarker, start);
    assert.notEqual(start, -1, `Missing source marker: ${startMarker}`);
    assert.notEqual(end, -1, `Missing source marker: ${endMarker}`);
    return appSource.slice(start, end);
}

function createHarness() {
    const elements = new Map();
    const subscriptions = [];
    const intervals = [];
    let gpsUpdates = 0;
    let publishes = 0;
    let serviceCalls = 0;
    let now = 1_000_000;

    class FakeDate extends Date {
        constructor(value) {
            super(value === undefined ? now : value);
        }

        static now() {
            return now;
        }
    }

    function createElement() {
        const classes = new Set();
        return {
            textContent: '',
            className: '',
            dataset: {},
            disabled: false,
            inert: false,
            attributes: new Map(),
            classList: {
                add(name) { classes.add(name); },
                contains(name) { return classes.has(name); }
            },
            setAttribute(name, value) { this.attributes.set(name, value); }
        };
    }

    const writeControls = Array.from({ length: 8 }, createElement);
    const panelContainers = Array.from({ length: 4 }, createElement);
    const diagnosticControlIds = [
        'btn-toggle-history',
        'btn-clear-history',
        'btn-export-history',
        'btn-clear-health-check',
        'health-auto-scroll'
    ];
    diagnosticControlIds.forEach((id) => elements.set(id, createElement()));

    class Topic {
        constructor(options) {
            this.options = options;
            subscriptions.push(this);
        }

        subscribe(callback) {
            this.callback = callback;
        }

        publish() {
            publishes += 1;
        }
    }

    const bodyClasses = new Set();
    const context = {
        ROSLIB: { Topic },
        ros: {},
        console: { warn() {} },
        addLog() {},
        showFeedback() {},
        updateGPS() { gpsUpdates += 1; },
        Date: FakeDate,
        setInterval(callback) {
            intervals.push(callback);
            return intervals.length;
        },
        document: {
            body: {
                classList: {
                    add(name) { bodyClasses.add(name); }
                }
            },
            querySelectorAll(selector) {
                return selector.includes('button') ? writeControls : panelContainers;
            },
            getElementById(id) {
                if (!elements.has(id)) {
                    elements.set(id, createElement());
                }
                return elements.get(id);
            }
        }
    };

    vm.createContext(context);
    vm.runInContext(
        `${liveMavlinkSource()}\n` +
        `globalThis.__mavlinkTestApi = {
            LIVE_MAVLINK_VIEW_ONLY,
            LIVE_MAVLINK_STALE_AFTER_MS,
            LIVE_MAVLINK_WRITE_CONTROL_SELECTOR:
                typeof LIVE_MAVLINK_WRITE_CONTROL_SELECTOR === 'undefined'
                    ? null
                    : LIVE_MAVLINK_WRITE_CONTROL_SELECTOR,
            LIVE_MAVLINK_TOPIC_SPECS,
            quaternionToEulerDegrees,
            markLiveMavlinkTopic,
            refreshLiveMavlinkFreshness,
            resetLiveMavlinkTelemetry,
            publishDashboardWrite,
            callDashboardWriteService,
            enableLiveMavlinkViewOnly,
            subscribeToLiveMavlinkTopics,
            updateLiveMavlinkState,
            updateLiveMavlinkImu,
            updateLiveMavlinkBattery,
            updateLiveMavlinkRc,
            updateLiveMavlinkThrust,
            updateLiveMavlinkGps
        };`,
        context
    );

    return {
        api: context.__mavlinkTestApi,
        bodyClasses,
        elements,
        intervals,
        subscriptions,
        diagnosticControlIds,
        panelContainers,
        writeControls,
        advance(ms) { now += ms; },
        getGpsUpdates: () => gpsUpdates,
        getPublishes: () => publishes,
        getServiceCalls: () => serviceCalls,
        service: {
            callService() { serviceCalls += 1; }
        }
    };
}

test('temporary live view wires exactly six read-only MAVROS topics', () => {
    const harness = createHarness();
    assert.equal(harness.api.LIVE_MAVLINK_VIEW_ONLY, true);
    // Every entry must be a subscription. /mavros/rc/out is servo OUTPUT
    // telemetry from the allowlisted rc_io plugin and is not one of the Pi
    // helper's COMMAND_TOPICS, so subscribing to it cannot abort a live run.
    assert.deepEqual(
        Array.from(harness.api.LIVE_MAVLINK_TOPIC_SPECS, (spec) => [spec.name, spec.messageType]),
        [
            ['/mavros/state', 'mavros_msgs/State'],
            ['/mavros/global_position/raw/fix', 'sensor_msgs/NavSatFix'],
            ['/mavros/imu/data', 'sensor_msgs/Imu'],
            ['/mavros/battery', 'sensor_msgs/BatteryState'],
            ['/mavros/rc/in', 'mavros_msgs/RCIn'],
            ['/mavros/rc/out', 'mavros_msgs/RCOut']
        ]
    );

    harness.api.subscribeToLiveMavlinkTopics();
    assert.equal(harness.subscriptions.length, 6);
    assert.equal(harness.subscriptions.find((topic) => topic.options.name === '/mavros/imu/data').options.throttle_rate, 200);
});

test('temporary view blocks writes while preserving diagnostic controls', () => {
    const harness = createHarness();
    const topic = { publish() { throw new Error('publish must stay blocked'); } };

    assert.equal(harness.api.publishDashboardWrite(topic, {}, 'test publish'), false);
    assert.equal(
        harness.api.callDashboardWriteService(harness.service, {}, () => {}, () => {}, 'test service'),
        false
    );
    assert.equal(harness.getPublishes(), 0);
    assert.equal(harness.getServiceCalls(), 0);

    harness.api.enableLiveMavlinkViewOnly();
    assert.equal(harness.bodyClasses.has('live-mavlink-view-only'), true);
    assert.equal(harness.panelContainers.every((panel) => !panel.inert), true);
    assert.equal(harness.writeControls.every((control) => control.inert), true);
    assert.equal(harness.writeControls.every((control) => control.disabled), true);
    assert.equal(
        harness.writeControls.every((control) => control.attributes.get('aria-disabled') === 'true'),
        true
    );
    assert.equal(harness.writeControls.every((control) => control.attributes.get('inert') === ''), true);
    assert.equal(
        harness.writeControls.every((control) => control.classList.contains('live-mavlink-write-disabled')),
        true
    );
    for (const id of harness.diagnosticControlIds) {
        const control = harness.elements.get(id);
        assert.equal(control.inert, false, `#${id} must remain interactive`);
        assert.equal(control.disabled, false, `#${id} must remain enabled`);
    }
    assert.equal(harness.elements.get('header-estop-badge').disabled, true);
    assert.equal(harness.elements.get('footer-estop-badge').disabled, true);
    const selectorFragments = harness.api.LIVE_MAVLINK_WRITE_CONTROL_SELECTOR
        .split(',')
        .map((fragment) => fragment.trim());
    assert.equal(selectorFragments.length, 16);
    for (const fragment of selectorFragments) {
        assert.match(fragment, /\.(?:mission-control|config|tuning|health-check)-panel/);
        assert.match(fragment, /\b(?:button|input|select|textarea):not\(\.view-only-diagnostic-control\)$/);
        assert.doesNotMatch(fragment, /^\.(?:mission-control|config|tuning|health-check)-panel$/);
    }
    harness.api.enableLiveMavlinkViewOnly();
    assert.equal(harness.intervals.length, 1);
});

test('direct-call syntax canary keeps known writes behind the temporary guard', () => {
    const publishCalls = appSource.match(/\.publish\s*\(/g) || [];
    const serviceCalls = appSource.match(/\.callService\s*\(/g) || [];
    assert.equal(publishCalls.length, 1);
    assert.equal(serviceCalls.length, 2);
    assert.match(appSource, /function publishDashboardWrite[\s\S]*?topic\.publish\(message\)/);
    assert.match(appSource, /function callDashboardWriteService[\s\S]*?service\.callService\(request/);
    assert.match(appSource, /name: '\/rosapi\/topics_for_type'[\s\S]*?svc\.callService\(/);
    assert.equal(appSource.includes('const LIVE_MAVLINK_VIEW_ONLY = true;'), true);
});

test('temporary panel DOM contract is complete and camera defaults to Hailo', () => {
    const ids = [
        'live-mavlink-safety-banner',
        'mavlink-topic-state',
        'mavlink-topic-gps',
        'mavlink-topic-imu',
        'mavlink-topic-battery',
        'mavlink-topic-rc',
        'mavlink-topic-thrust',
        'mavlink-connected',
        'mavlink-armed',
        'mavlink-mode',
        'mavlink-system-status',
        'mavlink-manual-input',
        'mavlink-gps-fix',
        'mavlink-gps-position',
        'mavlink-gps-accuracy',
        'mavlink-gps-altitude',
        'mavlink-attitude',
        'mavlink-gyro',
        'mavlink-accel',
        'mavlink-battery',
        'mavlink-battery-current',
        'mavlink-rc-rssi',
        'mavlink-rc-channels',
        'mavlink-thrust-output',
        'mavlink-last-update'
    ];
    for (const id of ids) {
        const matches = htmlSource.match(new RegExp(`id=["']${id}["']`, 'g')) || [];
        assert.equal(matches.length, 1, `Expected exactly one #${id}`);
    }
    for (const panelClass of [
        'mission-control-panel',
        'config-panel',
        'tuning-panel',
        'health-check-panel'
    ]) {
        const matches = htmlSource.match(
            new RegExp(`class=["'][^"']*\\b${panelClass}\\b[^"']*["']`, 'g')
        ) || [];
        assert.equal(matches.length, 1, `Expected exactly one .${panelClass}`);
    }
    for (const id of [
        'btn-toggle-history',
        'btn-clear-history',
        'btn-export-history',
        'btn-clear-health-check',
        'health-auto-scroll'
    ]) {
        const tag = htmlSource.match(new RegExp(`<[^>]*\\bid=["']${id}["'][^>]*>`));
        assert.ok(tag, `Missing diagnostic control #${id}`);
        assert.match(tag[0], /class=["'][^"']*\bview-only-diagnostic-control\b/);
    }
    for (const target of ['perception-params', 'controller-params']) {
        const tag = htmlSource.match(
            new RegExp(`<button[^>]*\\bdata-target=["']${target}["'][^>]*>`)
        );
        assert.ok(tag, `Missing tuning expander for #${target}`);
        assert.match(tag[0], /class=["'][^"']*\btuning-section-header\b/);
        assert.match(tag[0], /class=["'][^"']*\bview-only-diagnostic-control\b/);
    }
    assert.match(cssSource, /\.live-mavlink-write-disabled\s*\{/);
    assert.doesNotMatch(cssSource, /live-mavlink-view-only \.health-check-panel (?:button|input)/);
    assert.match(htmlSource, /id="camera-topic" value="\/hailo\/overlay\/image_raw"/);
});

test('state, IMU, battery, RC, and GPS samples render bounded diagnostics', () => {
    const harness = createHarness();

    harness.api.updateLiveMavlinkState({
        connected: true,
        armed: false,
        mode: 'HOLD',
        system_status: 5,
        manual_input: true
    });
    assert.equal(harness.elements.get('mavlink-connected').textContent, 'Connected');
    assert.equal(harness.elements.get('mavlink-armed').textContent, 'Disarmed');
    assert.equal(harness.elements.get('mavlink-mode').textContent, 'HOLD');
    // MAV_STATE 5 is CRITICAL; it renders by name so the state is legible at a glance.
    assert.equal(harness.elements.get('mavlink-system-status').textContent, 'Critical (5)');

    const yaw90 = Math.sqrt(0.5);
    const euler = harness.api.quaternionToEulerDegrees({ x: 0, y: 0, z: yaw90, w: yaw90 });
    assert.ok(Math.abs(euler.yaw - 90) < 0.001);

    harness.api.updateLiveMavlinkImu({
        orientation: { x: 0, y: 0, z: yaw90, w: yaw90 },
        orientation_covariance: [0, 0, 0, 0, 0, 0, 0, 0, 0],
        angular_velocity: { x: 0.1, y: 0.2, z: 0.3 },
        linear_acceleration: { x: 1, y: 2, z: 9.8 }
    });
    assert.match(harness.elements.get('mavlink-attitude').textContent, /Y 90\.0°/);
    assert.equal(harness.elements.get('mavlink-gyro').textContent, '0.10, 0.20, 0.30 rad/s');

    harness.api.updateLiveMavlinkBattery({ voltage: 16.24, current: NaN, percentage: 1, present: true });
    assert.equal(harness.elements.get('mavlink-battery').textContent, '16.24 V | 100% | Present');
    assert.equal(harness.elements.get('mavlink-battery-current').textContent, 'N/A');

    harness.api.updateLiveMavlinkRc({ rssi: 255, channels: [] });
    assert.equal(harness.elements.get('mavlink-rc-rssi').textContent, '255 raw');
    assert.equal(harness.elements.get('mavlink-rc-channels').textContent, '0 channels');

    // This vehicle carries ThrottleLeft on SERVO3 and ThrottleRight on SERVO1,
    // so index 2 is LEFT and index 0 is RIGHT. Raw PWM only; no rail assumed.
    harness.api.updateLiveMavlinkThrust({ channels: [1496, 0, 1644, 0, 0, 0, 0, 0] });
    assert.equal(
        harness.elements.get('mavlink-thrust-output').textContent,
        'L SERVO3 1644 us | R SERVO1 1496 us | delta +148'
    );
    harness.api.updateLiveMavlinkThrust({ channels: [] });
    assert.equal(harness.elements.get('mavlink-thrust-output').textContent, 'N/A');

    harness.api.updateLiveMavlinkGps({
        status: { status: -1, service: 1 },
        altitude: 17.16,
        latitude: 0,
        longitude: 0
    });
    assert.equal(harness.elements.get('mavlink-gps-fix').textContent, 'No fix (-1)');
    assert.equal(harness.elements.get('mavlink-gps-position').textContent, '0.0000000, 0.0000000');
    // No covariance supplied, so accuracy must report unknown rather than invent a figure.
    assert.equal(harness.elements.get('mavlink-gps-accuracy').textContent, 'N/A');
    assert.equal(harness.getGpsUpdates(), 1);

    harness.api.updateLiveMavlinkGps({
        status: { status: 0, service: 1 },
        altitude: 17.16,
        latitude: 50.5187654,
        longitude: 3.1234567,
        position_covariance: [1.44, 0, 0, 0, 2.56, 0, 0, 0, 4],
        position_covariance_type: 2
    });
    assert.equal(harness.elements.get('mavlink-gps-fix').textContent, 'Fix (standard) (0)');
    assert.equal(harness.elements.get('mavlink-gps-position').textContent, '50.5187654, 3.1234567');
    assert.equal(harness.elements.get('mavlink-gps-accuracy').textContent, '+/-1.41 m horizontal');
    assert.equal(harness.getGpsUpdates(), 2);
});

test('topic freshness expires independently and invalidates only stale telemetry', () => {
    const harness = createHarness();

    harness.api.updateLiveMavlinkState({
        connected: true,
        armed: false,
        mode: 'HOLD',
        system_status: 5,
        manual_input: true
    });
    harness.api.updateLiveMavlinkGps({
        status: { status: -1, service: 1 },
        altitude: 17.16,
        latitude: 0,
        longitude: 0
    });
    harness.api.updateLiveMavlinkImu({
        orientation: { x: 0, y: 0, z: 0, w: 1 },
        orientation_covariance: [0, 0, 0, 0, 0, 0, 0, 0, 0],
        angular_velocity: { x: 0.1, y: 0.2, z: 0.3 },
        linear_acceleration: { x: 1, y: 2, z: 9.8 }
    });
    harness.api.updateLiveMavlinkBattery({ voltage: 16.24, current: 1.2, percentage: 0.8, present: true });
    harness.api.updateLiveMavlinkRc({ rssi: 200, channels: [1500, 1501] });

    harness.advance(harness.api.LIVE_MAVLINK_STALE_AFTER_MS + 1);
    harness.api.updateLiveMavlinkImu({
        orientation: { x: 0, y: 0, z: 0, w: 1 },
        orientation_covariance: [0, 0, 0, 0, 0, 0, 0, 0, 0],
        angular_velocity: { x: 0.4, y: 0.5, z: 0.6 },
        linear_acceleration: { x: 3, y: 4, z: 9.7 }
    });
    harness.api.refreshLiveMavlinkFreshness();

    assert.match(harness.elements.get('mavlink-topic-imu').textContent, /^IMU: Live /);
    for (const key of ['state', 'gps', 'battery', 'rc']) {
        assert.match(harness.elements.get(`mavlink-topic-${key}`).textContent, /: Stale /);
    }
    assert.equal(harness.elements.get('mavlink-armed').textContent, 'Unknown (stale)');
    assert.equal(harness.elements.get('mavlink-battery').textContent, '-');
    assert.equal(harness.elements.get('mavlink-gyro').textContent, '0.40, 0.50, 0.60 rad/s');
    assert.match(harness.elements.get('mavlink-last-update').textContent, /State: stale/);
    assert.match(harness.elements.get('mavlink-last-update').textContent, /IMU: 0\.0 s/);
});

test('freshness watchdog expires an all-topic freeze without another message', () => {
    const harness = createHarness();
    harness.api.enableLiveMavlinkViewOnly();

    harness.api.updateLiveMavlinkState({
        connected: true,
        armed: true,
        mode: 'AUTO',
        system_status: 4,
        manual_input: true
    });
    harness.api.updateLiveMavlinkGps({
        status: { status: 0, service: 1 },
        altitude: 12,
        latitude: 48,
        longitude: 2
    });
    harness.api.updateLiveMavlinkImu({
        orientation: { x: 0, y: 0, z: 0, w: 1 },
        orientation_covariance: [0, 0, 0, 0, 0, 0, 0, 0, 0],
        angular_velocity: { x: 1, y: 2, z: 3 },
        linear_acceleration: { x: 4, y: 5, z: 6 }
    });
    harness.api.updateLiveMavlinkBattery({ voltage: 15, current: 2, percentage: 0.5, present: true });
    harness.api.updateLiveMavlinkRc({ rssi: 123, channels: [1400] });

    assert.equal(harness.intervals.length, 1);
    harness.advance(harness.api.LIVE_MAVLINK_STALE_AFTER_MS + 1);
    harness.intervals[0]();

    for (const key of ['state', 'gps', 'imu', 'battery', 'rc']) {
        assert.match(harness.elements.get(`mavlink-topic-${key}`).textContent, /: Stale /);
    }
    assert.equal(harness.elements.get('mavlink-armed').textContent, 'Unknown (stale)');
    assert.equal(harness.elements.get('mavlink-gps-fix').textContent, '-');
    assert.equal(harness.elements.get('mavlink-attitude').textContent, '-');
    assert.equal(harness.elements.get('mavlink-battery').textContent, '-');
    assert.equal(harness.elements.get('mavlink-rc-rssi').textContent, '-');
});

test('rosbridge reset clears every live MAVLink value and timestamp', () => {
    const harness = createHarness();

    harness.api.updateLiveMavlinkState({ connected: true, armed: true, mode: 'AUTO', system_status: 4, manual_input: true });
    harness.api.updateLiveMavlinkGps({ status: { status: 0 }, altitude: 12, latitude: 48, longitude: 2 });
    harness.api.updateLiveMavlinkImu({
        orientation: { x: 0, y: 0, z: 0, w: 1 },
        orientation_covariance: [0, 0, 0, 0, 0, 0, 0, 0, 0],
        angular_velocity: { x: 1, y: 2, z: 3 },
        linear_acceleration: { x: 4, y: 5, z: 6 }
    });
    harness.api.updateLiveMavlinkBattery({ voltage: 15, current: 2, percentage: 0.5, present: true });
    harness.api.updateLiveMavlinkRc({ rssi: 123, channels: [1400] });

    harness.api.resetLiveMavlinkTelemetry();

    assert.equal(harness.elements.get('mavlink-connected').textContent, 'Disconnected');
    assert.equal(harness.elements.get('mavlink-armed').textContent, 'Unavailable');
    for (const id of [
        'mavlink-mode', 'mavlink-system-status', 'mavlink-manual-input',
        'mavlink-gps-fix', 'mavlink-gps-altitude', 'mavlink-attitude',
        'mavlink-gyro', 'mavlink-accel', 'mavlink-battery',
        'mavlink-battery-current', 'mavlink-rc-rssi', 'mavlink-rc-channels'
    ]) {
        assert.equal(harness.elements.get(id).textContent, '-', `Expected #${id} to be cleared`);
    }
    for (const label of ['State', 'GPS', 'IMU', 'Battery', 'RC']) {
        assert.match(harness.elements.get(`mavlink-topic-${label.toLowerCase()}`).textContent, new RegExp(`^${label}: Waiting$`));
    }
    assert.match(harness.elements.get('mavlink-last-update').textContent, /State: waiting/);
    assert.doesNotMatch(harness.elements.get('mavlink-last-update').textContent, /\d+\.\d s/);
    assert.match(appSource, /ros\.on\('close',[\s\S]*?resetLiveMavlinkTelemetry\(\)/);
});

test('a fresh MAVROS state sample cannot present stale FCU state as current', () => {
    const harness = createHarness();

    harness.api.updateLiveMavlinkState({
        connected: false,
        armed: false,
        mode: 'HOLD',
        system_status: 5,
        manual_input: true
    });

    assert.equal(harness.elements.get('mavlink-connected').textContent, 'Disconnected');
    assert.equal(harness.elements.get('mavlink-armed').textContent, 'Unavailable');
    assert.equal(harness.elements.get('mavlink-mode').textContent, '-');
    assert.match(harness.elements.get('mavlink-topic-state').textContent, /^State: Live /);
});
