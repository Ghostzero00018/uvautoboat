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

function createHarness(search = '') {
    const elements = new Map();
    const subscriptions = [];
    const intervals = [];
    const published = [];
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
        const listeners = new Map();
        return {
            textContent: '',
            className: '',
            dataset: {},
            value: '0',
            checked: false,
            disabled: false,
            inert: false,
            attributes: new Map(),
            classList: {
                add(name) { classes.add(name); },
                remove(name) { classes.delete(name); },
                contains(name) { return classes.has(name); }
            },
            setAttribute(name, value) { this.attributes.set(name, value); },
            removeAttribute(name) { this.attributes.delete(name); },
            capturedPointers: [],
            setPointerCapture(pointerId) { this.capturedPointers.push(pointerId); },
            addEventListener(name, callback) {
                if (!listeners.has(name)) listeners.set(name, []);
                listeners.get(name).push(callback);
            },
            dispatch(name, event = {}) {
                for (const callback of listeners.get(name) || []) callback(event);
            }
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
    elements.set('btn-emergency-stop', createElement());
    elements.set('btn-camera-emergency-stop', createElement());

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
            published.push({ topic: this.options.name, message: arguments[0] });
        }
    }

    const bodyClasses = new Set();
    const windowListeners = new Map();
    const documentListeners = new Map();
    const context = {
        ROSLIB: { Topic, Message: class Message { constructor(value) { Object.assign(this, value); } } },
        ros: {},
        connected: true,
        console: { warn() {} },
        addLog() {},
        showFeedback() {},
        updateGPS() { gpsUpdates += 1; },
        Date: FakeDate,
        location: { search },
        setInterval(callback) {
            intervals.push({ callback, active: true });
            return intervals.length;
        },
        clearInterval(id) {
            if (intervals[id - 1]) intervals[id - 1].active = false;
        },
        clearTimeout() {},
        setTimeout(callback) {
            callback();
            return 1;
        },
        addEventListener(name, callback) {
            if (!windowListeners.has(name)) windowListeners.set(name, []);
            windowListeners.get(name).push(callback);
        },
        document: {
            hidden: false,
            body: {
                classList: {
                    add(name) { bodyClasses.add(name); }
                }
            },
            querySelectorAll(selector) {
                return selector.includes('button')
                    ? [...writeControls, elements.get('btn-emergency-stop')]
                    : panelContainers;
            },
            getElementById(id) {
                if (!elements.has(id)) {
                    elements.set(id, createElement());
                }
                return elements.get(id);
            },
            addEventListener(name, callback) {
                if (!documentListeners.has(name)) documentListeners.set(name, []);
                documentListeners.get(name).push(callback);
            }
        }
    };
    context.window = context;

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
            updateLiveMavlinkGps,
            LIVE_FCU_BENCH_REQUESTED,
            liveFcuBenchRequested,
            clampFcuBenchDemand,
            fcuBenchMessage,
            fcuBenchCanApply,
            railRelativePercent,
            updateLiveFcuBenchStatus,
            updateLiveFcuTwinTelemetry,
            refreshLiveFcuTwinTelemetry,
            resetLiveFcuTwinTelemetry,
            refreshFcuBenchControls,
            subscribeToLiveFcuBenchLoop,
            initFcuBenchLoop,
            startFcuBenchHold,
            stopFcuBenchHold,
            publishFcuBenchEmergencyStop,
            publishFcuBenchEmergencyReset,
            publishFcuBenchControlOwner,
            toggleFcuBenchControlOwner,
            fcuBenchAutoMoveProfile,
            readFcuBenchAutoMoveConfig,
            startFcuBenchAutoMove
        };`,
        context
    );

    return {
        api: context.__mavlinkTestApi,
        bodyClasses,
        elements,
        intervals,
        published,
        subscriptions,
        diagnosticControlIds,
        panelContainers,
        writeControls,
        advance(ms) { now += ms; },
        getGpsUpdates: () => gpsUpdates,
        getPublishes: () => publishes,
        getServiceCalls: () => serviceCalls,
        runInterval(index) {
            const interval = intervals[index];
            if (interval?.active) interval.callback();
        },
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

test('bench URL restores the real E-Stop while leaving other live writes blocked', () => {
    const normal = createHarness();
    normal.api.enableLiveMavlinkViewOnly();
    assert.equal(normal.elements.get('btn-emergency-stop').disabled, true);
    assert.equal(normal.elements.get('btn-camera-emergency-stop').disabled, true);

    const bench = createHarness('?enable_fcu_bench_control=1');
    bench.api.enableLiveMavlinkViewOnly();
    assert.equal(bench.elements.get('btn-emergency-stop').disabled, false);
    assert.equal(bench.elements.get('btn-camera-emergency-stop').disabled, false);
    assert.equal(bench.elements.get('btn-emergency-stop').inert, false);
    assert.equal(bench.writeControls.every((control) => control.disabled), true);
    assert.match(htmlSource, /id="btn-camera-emergency-stop"/);
});

test('direct-call syntax canary keeps known writes behind the temporary guard', () => {
    const publishCalls = appSource.match(/\.publish\s*\(/g) || [];
    const serviceCalls = appSource.match(/\.callService\s*\(/g) || [];
    assert.equal(publishCalls.length, 5);
    assert.equal(serviceCalls.length, 2);
    assert.match(appSource, /function publishDashboardWrite[\s\S]*?topic\.publish\(message\)/);
    assert.match(appSource, /function publishFcuBenchDemand[\s\S]*?liveFcuBenchCommandPublisher\.publish\(message\)/);
    assert.match(appSource, /function publishFcuBenchEmergencyStop[\s\S]*?liveFcuBenchEmergencyPublisher\.publish/);
    assert.match(appSource, /function publishFcuBenchEmergencyReset[\s\S]*?liveFcuBenchEmergencyResetPublisher\.publish/);
    assert.match(appSource, /function publishFcuBenchControlOwner[\s\S]*?liveFcuBenchControlOwnerPublisher\.publish/);
    assert.match(appSource, /enable_fcu_bench_control/);
    assert.match(htmlSource, /Hold to Apply RC Demand/);
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
        'mavlink-last-update',
        'fcu-loop-policy',
        'fcu-loop-state',
        'fcu-loop-owner',
        'fcu-loop-mapping',
        'fcu-loop-command',
        'fcu-loop-feedback',
        'fcu-loop-twin-status',
        'fcu-loop-twin-pose',
        'fcu-loop-twin-thrust',
        'fcu-loop-steering',
        'fcu-loop-throttle',
        'fcu-loop-physical-confirmation',
        'btn-fcu-loop-neutral',
        'btn-fcu-loop-hold',
        'btn-fcu-loop-reset-estop',
        'btn-fcu-loop-control-owner',
        'btn-fcu-loop-auto-move',
        'fcu-loop-auto-throttle',
        'fcu-loop-auto-steering',
        'fcu-loop-auto-side',
        'fcu-loop-auto-straight-seconds',
        'fcu-loop-auto-turn-seconds',
        'fcu-loop-auto-status'
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

test('validated W2 twin telemetry renders actual VRX pose and thrust then expires', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    assert.equal(harness.subscriptions.find(
        (topic) => topic.options.name === '/command_ingress/emergency_reset'
    ).options.messageType, 'std_msgs/String');
    assert.equal(harness.subscriptions.find(
        (topic) => topic.options.name === '/command_ingress/control_owner'
    ).options.messageType, 'std_msgs/String');
    const topic = harness.subscriptions.find(
        (entry) => entry.options.name === '/fcu_to_vrx/twin_telemetry'
    );
    assert.ok(topic, 'Expected the validated twin telemetry subscription');
    topic.callback({ data: JSON.stringify({
        schema: 'uvautoboat.fcu_to_vrx.twin_telemetry.v1',
        source: 'fcu_to_vrx_domain77_bridge',
        sequence: 7,
        sent_unix_ns: 1788290000000000000,
        sent_monotonic_ns: 1234567890,
        pose: {
            frame_id: 'sydney_regatta',
            child_frame_id: 'wamv/base_link',
            position: { x: 12.345, y: -6.789, z: 0.25 },
            orientation: { x: 0, y: 0, z: 0, w: 1 }
        },
        thrust: { left_newtons: 320.5, right_newtons: 280.25 }
    }) });

    assert.equal(harness.elements.get('fcu-loop-twin-status').textContent, 'Live');
    assert.equal(
        harness.elements.get('fcu-loop-twin-pose').textContent,
        'sydney_regatta | X 12.35 m | Y -6.79 m | Z 0.25 m'
    );
    assert.equal(
        harness.elements.get('fcu-loop-twin-thrust').textContent,
        'Left 320.5 N | Right 280.3 N'
    );

    harness.advance(2501);
    harness.api.refreshLiveFcuTwinTelemetry();
    assert.match(harness.elements.get('fcu-loop-twin-status').textContent, /^Stale \(/);
    assert.match(harness.elements.get('fcu-loop-twin-status').className, /critical/);
});

test('malformed twin telemetry cannot replace or refresh the last valid sample', () => {
    const harness = createHarness();
    const valid = {
        schema: 'uvautoboat.fcu_to_vrx.twin_telemetry.v1',
        source: 'fcu_to_vrx_domain77_bridge',
        sequence: 1,
        sent_unix_ns: 1,
        sent_monotonic_ns: 1,
        pose: {
            frame_id: 'sydney_regatta', child_frame_id: 'wamv/base_link',
            position: { x: 1, y: 2, z: 3 },
            orientation: { x: 0, y: 0, z: 0, w: 1 }
        },
        thrust: { left_newtons: 10, right_newtons: 20 }
    };
    assert.equal(
        harness.api.updateLiveFcuTwinTelemetry({ data: JSON.stringify(valid) }),
        true
    );
    harness.advance(1000);
    assert.equal(
        harness.api.updateLiveFcuTwinTelemetry({
            data: JSON.stringify({ ...valid, thrust: { left_newtons: '10' } })
        }),
        false
    );
    assert.equal(
        harness.elements.get('fcu-loop-twin-thrust').textContent,
        'Left 10.0 N | Right 20.0 N'
    );
    harness.advance(1501);
    harness.api.refreshLiveFcuTwinTelemetry();
    assert.match(harness.elements.get('fcu-loop-twin-status').textContent, /^Stale \(/);
});

test('bench command path is opt-in, bounded, paired, and strictly stamped', () => {
    const inhibited = createHarness();
    assert.equal(inhibited.api.LIVE_FCU_BENCH_REQUESTED, false);
    assert.equal(inhibited.api.liveFcuBenchRequested('enable_fcu_bench_control=1'), true);
    assert.equal(inhibited.api.liveFcuBenchRequested('?enable_fcu_bench_control=true'), false);

    const harness = createHarness('?enable_fcu_bench_control=1');
    assert.equal(harness.api.LIVE_FCU_BENCH_REQUESTED, true);
    const first = harness.api.fcuBenchMessage(0.1, 0.05, 1, 1000);
    const second = harness.api.fcuBenchMessage(0.1, 0.05, 1, 1000);
    assert.deepEqual(Array.from(first.axes), [0.1, 0.05]);
    assert.deepEqual(Array.from(first.buttons), [1]);
    assert.equal(first.header.frame_id, 'uvautoboat/rc_axes/v1');
    assert.ok(second.header.stamp.nanosec > first.header.stamp.nanosec);

    const clamped = harness.api.clampFcuBenchDemand(9, 9);
    assert.equal(clamped.steering, 0.2);
    assert.equal(clamped.throttle, 0.2);
    assert.equal(harness.api.fcuBenchMessage(0, 0, 2), null);
});

test('bench status keeps requested and measured outputs in separate fields', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'ARMED_NEUTRAL',
            fault: 'ARMED_NEUTRAL',
            ready: true,
            connected: true,
            armed: true,
            mode: 'MANUAL',
            feedback_fresh: true,
            rc_in_age_ms: 20,
            rc_out_age_ms: 25,
            resolved: {
                steering_rc: 1,
                throttle_rc: 3,
                left_servo: 3,
                right_servo: 1
            },
            command: { steering: 0.1, throttle: 0.05 },
            servo_rails: {
                left: {
                    channel: 3, function: 73, minimum: 800, trim: 800,
                    maximum: 2200, reversed: 0
                },
                right: {
                    channel: 1, function: 74, minimum: 800, trim: 800,
                    maximum: 2200, reversed: 0
                }
            },
            measured: {
                rc_steering_pwm: 1550,
                rc_throttle_pwm: 1525,
                left_servo_pwm: 860,
                right_servo_pwm: 820
            }
        })
    });
    assert.equal(harness.elements.get('fcu-loop-state').textContent, 'ARMED_NEUTRAL');
    assert.match(harness.elements.get('fcu-loop-mapping').textContent, /Left SERVO3/);
    assert.equal(
        harness.elements.get('fcu-loop-command').textContent,
        'Steering 0.10 | Throttle 0.05'
    );
    assert.equal(
        harness.elements.get('fcu-loop-feedback').textContent,
        'RC 1550 / 1525 us | Left 860 us (+4.3% PWM rail) | Right 820 us (+1.4% PWM rail)'
    );
    assert.match(harness.elements.get('fcu-loop-feedback').className, /clear/);
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    assert.equal(harness.api.fcuBenchCanApply(), true);
    harness.advance(501);
    assert.equal(harness.api.fcuBenchCanApply(), false);
});

test('bench feedback never invents rail-relative output before rails arrive', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'READY_DISARMED', fault: 'READY_DISARMED', ready: true,
            connected: true, armed: false, mode: 'MANUAL', feedback_fresh: true,
            command: {},
            measured: {
                rc_steering_pwm: 1500, rc_throttle_pwm: 1500,
                left_servo_pwm: 1500, right_servo_pwm: 1500
            }
        })
    });
    assert.equal(
        harness.elements.get('fcu-loop-feedback').textContent,
        'RC 1500 / 1500 us | Left 1500 us | Right 1500 us | Rails not received'
    );
    assert.match(harness.elements.get('fcu-loop-feedback').className, /critical/);
});

test('bench rail percentage keeps reversed midscale output in raw PWM direction', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    assert.equal(
        harness.api.railRelativePercent(1585, {
            minimum: 1000, trim: 1500, maximum: 2000, reversed: 1
        }),
        17
    );
});

test('bench rail percentage keeps reversed endpoint output in raw PWM direction', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    assert.ok(
        Math.abs(harness.api.railRelativePercent(860, {
            minimum: 800, trim: 800, maximum: 2200, reversed: 1
        }) - (60 / 1400 * 100)) < 1e-12
    );
});

test('bench feedback normalizes simulator output around its live midscale trim', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'ACTIVE', fault: 'ACTIVE', ready: true,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            command: { steering: 0.1, throttle: 0.08 },
            servo_rails: {
                left: {
                    channel: 1, function: 73, minimum: 1000, trim: 1500,
                    maximum: 2000, reversed: 0
                },
                right: {
                    channel: 3, function: 74, minimum: 1000, trim: 1500,
                    maximum: 2000, reversed: 0
                }
            },
            measured: {
                rc_steering_pwm: 1577, rc_throttle_pwm: 1567,
                left_servo_pwm: 1585, right_servo_pwm: 1485
            }
        })
    });
    assert.equal(
        harness.elements.get('fcu-loop-feedback').textContent,
        'RC 1577 / 1567 us | Left 1585 us (+17.0% PWM rail) | Right 1485 us (-3.0% PWM rail)'
    );
});

test('bench hold stops and emits disabled frames when readiness disappears', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    const ready = {
        state: 'ARMED_NEUTRAL',
        fault: 'ARMED_NEUTRAL',
        ready: true,
        connected: true,
        armed: true,
        mode: 'MANUAL',
        feedback_fresh: true,
        resolved: { steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1 },
        command: { steering: 0, throttle: 0 },
        measured: {}
    };
    harness.api.updateLiveFcuBenchStatus({ data: JSON.stringify(ready) });
    assert.equal(harness.api.startFcuBenchHold(), true);
    assert.equal(harness.intervals.some((entry) => entry.active), true);

    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({ ...ready, ready: false, state: 'FEEDBACK_INVALID' })
    });
    assert.equal(harness.intervals.some((entry) => entry.active), false);
    const commands = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    );
    assert.deepEqual(Array.from(commands.at(-1).message.buttons), [0]);
});

test('bench emergency stop stops hold and publishes a latched stop topic', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'ARMED_NEUTRAL', fault: 'ARMED_NEUTRAL', ready: true,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            resolved: { steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1 },
            command: {}, measured: {}
        })
    });
    assert.equal(harness.api.startFcuBenchHold(), true);
    assert.equal(harness.api.publishFcuBenchEmergencyStop(), true);
    assert.equal(harness.intervals.some((entry) => entry.active), false);
    const estops = harness.published.filter(
        (entry) => entry.topic === '/planning/emergency_stop'
    );
    assert.equal(estops.at(-1).message.data, true);
    const commands = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    );
    assert.deepEqual(Array.from(commands.at(-1).message.buttons), [0]);
});

test('bench reset is fail-closed and only publishes when bridge reports eligibility', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    const status = {
        state: 'EMERGENCY_STOP', fault: 'EMERGENCY_STOP', ready: false,
        connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
        control_owner: 'DASHBOARD', emergency_stop_latched: true,
        emergency_reset_allowed: false,
        emergency_reset_block_reason: 'PERSON_HOLD_ACTIVE',
        resolved: {
            steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1
        },
        command: {}, measured: {}
    };
    harness.api.updateLiveFcuBenchStatus({ data: JSON.stringify(status) });
    assert.equal(harness.api.publishFcuBenchEmergencyReset(), false);
    assert.equal(harness.elements.get('btn-fcu-loop-reset-estop').disabled, true);

    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            ...status,
            emergency_reset_allowed: true,
            emergency_reset_block_reason: ''
        })
    });
    assert.equal(harness.elements.get('btn-fcu-loop-reset-estop').disabled, false);
    const beforeResetCommands = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    ).length;
    assert.equal(harness.api.publishFcuBenchEmergencyReset(), true);
    const resets = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/emergency_reset'
    );
    assert.equal(resets.length, 1);
    assert.equal(resets[0].message.data, 'DASHBOARD_COMMAND_NEUTRAL');
    assert.equal(harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    ).length, beforeResetCommands);
    const beforeClear = harness.published.length;
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            ...status,
            state: 'ARMED_NEUTRAL', fault: 'DASHBOARD_PRIME_REQUIRED',
            ready: true,
            emergency_stop_latched: false,
            emergency_reset_allowed: false,
            emergency_reset_block_reason: 'NOT_LATCHED'
        })
    });
    const primeFrames = harness.published.slice(beforeClear).filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    );
    assert.equal(primeFrames.length, 0);
});

test('stale bridge status disables and blocks reset and owner publications', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    const resolved = {
        steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1
    };
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'EMERGENCY_STOP', fault: 'EMERGENCY_STOP', ready: false,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            control_owner: 'DASHBOARD', emergency_stop_latched: true,
            emergency_reset_allowed: true, emergency_reset_block_reason: '',
            resolved, command: {}, measured: {}
        })
    });
    assert.equal(harness.elements.get('btn-fcu-loop-reset-estop').disabled, false);

    harness.advance(5000);
    harness.api.refreshLiveMavlinkFreshness();
    assert.equal(harness.elements.get('btn-fcu-loop-reset-estop').disabled, true);
    assert.equal(harness.api.publishFcuBenchEmergencyReset(), false);
    assert.equal(harness.published.filter(
        (entry) => entry.topic === '/command_ingress/emergency_reset'
    ).length, 0);

    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'ARMED_NEUTRAL', fault: 'ARMED_NEUTRAL', ready: true,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            control_owner: 'DASHBOARD', emergency_stop_latched: false,
            emergency_reset_allowed: false,
            emergency_reset_block_reason: 'NOT_LATCHED',
            resolved, command: {}, measured: {}
        })
    });
    assert.equal(harness.elements.get('btn-fcu-loop-control-owner').disabled, false);

    harness.advance(5000);
    harness.api.refreshLiveMavlinkFreshness();
    assert.equal(harness.elements.get('btn-fcu-loop-control-owner').disabled, true);
    assert.equal(harness.api.publishFcuBenchControlOwner('HERELINK'), false);
    assert.equal(harness.published.filter(
        (entry) => entry.topic === '/command_ingress/control_owner'
    ).length, 0);
});

test('bench control-owner toggle hands off to Herelink and inhibits dashboard demand', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    const ready = {
        state: 'ARMED_NEUTRAL', fault: 'ARMED_NEUTRAL', ready: true,
        connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
        control_owner: 'DASHBOARD', emergency_stop_latched: false,
        emergency_reset_allowed: false,
        emergency_reset_block_reason: 'NOT_LATCHED',
        resolved: {
            steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1
        },
        command: {}, measured: {}
    };
    harness.api.updateLiveFcuBenchStatus({ data: JSON.stringify(ready) });
    assert.equal(harness.api.fcuBenchCanApply(), true);
    assert.equal(
        harness.elements.get('btn-fcu-loop-control-owner').textContent,
        'Confirm Herelink Sticks Neutral & Take Control'
    );
    const commandsBeforeHerelink = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    ).length;
    assert.equal(harness.api.toggleFcuBenchControlOwner(), true);
    const owners = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/control_owner'
    );
    assert.equal(owners.at(-1).message.data, 'HERELINK_STICKS_NEUTRAL');
    assert.ok(harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    ).length > commandsBeforeHerelink);

    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            ...ready, state: 'HERELINK_CONTROL', control_owner: 'HERELINK'
        })
    });
    assert.equal(harness.api.fcuBenchCanApply(), false);
    assert.equal(harness.elements.get('fcu-loop-owner').textContent, 'HERELINK');
    assert.equal(
        harness.elements.get('btn-fcu-loop-control-owner').textContent,
        'Switch to Dashboard Control (Neutral Now Required)'
    );
    const commandsBeforeDashboard = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    ).length;
    assert.equal(harness.api.toggleFcuBenchControlOwner(), true);
    assert.equal(
        harness.published.filter(
            (entry) => entry.topic === '/command_ingress/control_owner'
        ).at(-1).message.data,
        'DASHBOARD'
    );
    harness.api.updateLiveFcuBenchStatus({ data: JSON.stringify(ready) });
    assert.equal(harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    ).length, commandsBeforeDashboard);

    harness.api.stopFcuBenchHold();
    const explicitPrime = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    ).slice(commandsBeforeDashboard);
    assert.ok(explicitPrime.length > 0);
    assert.ok(explicitPrime.every(
        (entry) => Array.from(entry.message.buttons)[0] === 0
    ));
    assert.equal(harness.api.toggleFcuBenchControlOwner(), true);
    assert.equal(
        harness.published.filter(
            (entry) => entry.topic === '/command_ingress/control_owner'
        ).at(-1).message.data,
        'HERELINK_STICKS_NEUTRAL'
    );
});

test('Herelink E-stop reset carries an explicit physical-stick confirmation', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'EMERGENCY_STOP', fault: 'EMERGENCY_STOP', ready: false,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            control_owner: 'HERELINK', emergency_stop_latched: true,
            emergency_reset_allowed: true, emergency_reset_block_reason: '',
            resolved: {
                steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1
            },
            command: {}, measured: {}
        })
    });
    assert.equal(
        harness.elements.get('btn-fcu-loop-reset-estop').textContent,
        'Confirm Herelink Sticks Neutral & Reset E-Stop'
    );
    assert.equal(harness.api.publishFcuBenchEmergencyReset(), true);
    const resets = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/emergency_reset'
    );
    assert.equal(resets.length, 1);
    assert.equal(resets[0].message.data, 'HERELINK_STICKS_NEUTRAL');
});

test('returning from Herelink to dashboard does not auto-prime', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    const base = {
        state: 'HERELINK_CONTROL', fault: 'HERELINK_CONTROL', ready: true,
        connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
        control_owner: 'HERELINK', emergency_stop_latched: false,
        emergency_reset_allowed: false,
        emergency_reset_block_reason: 'NOT_LATCHED',
        resolved: {
            steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1
        },
        command: {}, measured: {}
    };
    harness.api.updateLiveFcuBenchStatus({ data: JSON.stringify(base) });
    const before = harness.published.length;
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            ...base, state: 'ARMED_NEUTRAL', fault: 'ARMED_NEUTRAL',
            control_owner: 'DASHBOARD'
        })
    });
    const commands = harness.published.slice(before).filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    );
    assert.equal(commands.length, 0);
});

test('bench keyboard hold stops when Tab moves focus off the button', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'ARMED_NEUTRAL', fault: 'ARMED_NEUTRAL', ready: true,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            resolved: { steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1 },
            command: {}, measured: {}
        })
    });
    harness.api.initFcuBenchLoop();
    const hold = harness.elements.get('btn-fcu-loop-hold');
    hold.dispatch('keydown', {
        key: ' ', repeat: false, preventDefault() {}
    });
    assert.equal(harness.intervals.some((entry) => entry.active), true);

    hold.dispatch('blur');
    assert.equal(harness.intervals.some((entry) => entry.active), false);
    const commands = harness.published.filter(
        (entry) => entry.topic === '/command_ingress/rc_axes'
    );
    assert.deepEqual(Array.from(commands.at(-1).message.buttons), [0]);
});

test('onboarding backdrop cannot intercept emergency-stop clicks', () => {
    assert.match(
        cssSource,
        /\.onboarding-backdrop\s*\{[^}]*pointer-events:\s*none;/s
    );
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

test('thrust output labels follow the live-selected servo function channels', () => {
    const harness = createHarness('?thrust_left_servo=1&thrust_right_servo=3');

    harness.api.updateLiveMavlinkThrust({ channels: [1644, 0, 1496, 0] });

    assert.equal(
        harness.elements.get('mavlink-thrust-output').textContent,
        'L SERVO1 1644 us | R SERVO3 1496 us | delta +148'
    );
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
    harness.runInterval(0);

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

test('hardware safety badge reads ENGAGED and RELEASED from fresh bridge status', () => {
    const harness = createHarness();
    const badge = () => harness.elements.get('fcu-loop-hardware-safety').textContent;

    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({ state: 'READY_DISARMED', hardware_safety: 'ENGAGED' })
    });
    assert.match(badge(), /^ENGAGED /);

    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({ state: 'READY_DISARMED', hardware_safety: 'RELEASED' })
    });
    assert.match(badge(), /^RELEASED /);
});

test('hardware safety badge never claims outputs are live', () => {
    const harness = createHarness();
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({ state: 'READY_DISARMED', hardware_safety: 'RELEASED' })
    });
    // The switch reports suppression state only; it does not establish that
    // propulsion is powered or that any output is actually being produced.
    assert.doesNotMatch(harness.elements.get('fcu-loop-hardware-safety').textContent,
        /outputs live|powered|propulsion/i);
});

test('bridge silence ages the hardware safety badge to Unknown', () => {
    const harness = createHarness();
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({ state: 'READY_DISARMED', hardware_safety: 'RELEASED' })
    });
    assert.match(harness.elements.get('fcu-loop-hardware-safety').textContent, /^RELEASED /);

    harness.advance(60_000);
    harness.api.refreshFcuBenchControls();
    assert.equal(harness.elements.get('fcu-loop-hardware-safety').textContent,
        'Unknown (stale)');
});

test('malformed bridge status clears the hardware safety badge', () => {
    const harness = createHarness();
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({ state: 'READY_DISARMED', hardware_safety: 'ENGAGED' })
    });
    assert.match(harness.elements.get('fcu-loop-hardware-safety').textContent, /^ENGAGED /);

    harness.api.updateLiveFcuBenchStatus({ data: '{not json' });
    assert.equal(harness.elements.get('fcu-loop-hardware-safety').textContent,
        'Unknown (stale)');
});

test('a status without hardware_safety does not leave a stale safety claim', () => {
    const harness = createHarness();
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({ state: 'READY_DISARMED', hardware_safety: 'ENGAGED' })
    });
    harness.api.updateLiveFcuBenchStatus({ data: JSON.stringify({ state: 'READY_DISARMED' }) });
    assert.equal(harness.elements.get('fcu-loop-hardware-safety').textContent,
        'Unknown (stale)');
});

// ---------------------------------------------------------------------------
// Auto-move: a bounded scripted maneuver on the same hold path as the sliders.

function readyBenchHarness() {
    const harness = createHarness('?enable_fcu_bench_control=1');
    harness.api.subscribeToLiveFcuBenchLoop();
    harness.api.initFcuBenchLoop();
    harness.elements.get('fcu-loop-physical-confirmation').checked = true;
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'ARMED_NEUTRAL', fault: 'ARMED_NEUTRAL', ready: true,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            resolved: { steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1 },
            command: {}, measured: {}
        })
    });
    harness.elements.get('fcu-loop-auto-throttle').value = '0.17';
    harness.elements.get('fcu-loop-auto-steering').value = '0.10';
    harness.elements.get('fcu-loop-auto-side').value = 'right';
    harness.elements.get('fcu-loop-auto-straight-seconds').value = '5';
    harness.elements.get('fcu-loop-auto-turn-seconds').value = '5';
    // The bridge publishes status at about 20 Hz in a real run; the dashboard
    // treats a status older than 500 ms as stale and stops applying demand.
    // Tests that advance the clock must feed a fresh status, as the bridge would.
    harness.refreshStatus = () => harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'ACTIVE', fault: 'ACTIVE', ready: true,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: true,
            resolved: { steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1 },
            command: {}, measured: {}
        })
    });
    return harness;
}

// Objects created inside the vm context carry that realm's prototypes, which
// deepStrictEqual treats as a difference; a JSON round-trip flattens them.
function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

function commandFrames(harness) {
    return harness.published
        .filter((entry) => entry.topic === '/command_ingress/rc_axes')
        .map((entry) => plain({ axes: Array.from(entry.message.axes), enable: entry.message.buttons[0] }));
}

function activeTick(harness) {
    const entry = harness.intervals.find((item) => item.active);
    assert.ok(entry, 'expected an active hold interval');
    entry.callback();
}

test('auto-move profile is straight, then turn, then over', () => {
    const harness = createHarness('?enable_fcu_bench_control=1');
    const config = { throttle: 0.17, steering: 0.10, straightMs: 5000, turnMs: 5000 };
    const profile = (ms) => plain(harness.api.fcuBenchAutoMoveProfile(config, ms));
    assert.deepEqual(profile(0), { steering: 0, throttle: 0.17, phase: 'straight' });
    assert.deepEqual(profile(4999), { steering: 0, throttle: 0.17, phase: 'straight' });
    assert.deepEqual(profile(5000), { steering: 0.10, throttle: 0.17, phase: 'turn' });
    assert.deepEqual(profile(9999), { steering: 0.10, throttle: 0.17, phase: 'turn' });
    assert.equal(harness.api.fcuBenchAutoMoveProfile(config, 10000), null);
    assert.equal(harness.api.fcuBenchAutoMoveProfile(config, -1), null);
    assert.equal(harness.api.fcuBenchAutoMoveProfile(null, 0), null);
});

test('auto-move publishes straight then turn frames and ends itself with disabled frames', () => {
    const harness = readyBenchHarness();
    assert.equal(harness.api.startFcuBenchAutoMove(), true);
    let frames = commandFrames(harness);
    assert.deepEqual(frames.at(-1), { axes: [0, 0.17], enable: 1 });

    harness.advance(5001);
    harness.refreshStatus();
    activeTick(harness);
    frames = commandFrames(harness);
    assert.deepEqual(frames.at(-1), { axes: [0.10, 0.17], enable: 1 });

    harness.advance(5000);
    harness.refreshStatus();
    activeTick(harness);
    frames = commandFrames(harness);
    assert.equal(frames.at(-1).enable, 0, 'the maneuver must end in a disabled frame');
    assert.deepEqual(frames.at(-1).axes, [0, 0]);
    assert.equal(harness.intervals.some((entry) => entry.active), false, 'the hold interval must be stopped');
    assert.equal(harness.elements.get('fcu-loop-auto-status').textContent, 'Idle');
});

test('releasing mid-maneuver is neutral at once and the profile is forgotten', () => {
    const harness = readyBenchHarness();
    assert.equal(harness.api.startFcuBenchAutoMove(), true);
    harness.advance(2000);
    harness.refreshStatus();
    activeTick(harness);
    assert.equal(commandFrames(harness).at(-1).enable, 1);
    harness.api.stopFcuBenchHold();
    const frames = commandFrames(harness);
    assert.equal(frames.at(-1).enable, 0);
    assert.deepEqual(frames.at(-1).axes, [0, 0]);
    assert.equal(harness.intervals.some((entry) => entry.active), false);
    // A plain hold afterwards uses the sliders, not the leftover profile.
    harness.elements.get('fcu-loop-steering').value = '0.03';
    harness.elements.get('fcu-loop-throttle').value = '0.05';
    harness.refreshStatus();
    assert.equal(harness.api.startFcuBenchHold(), true);
    assert.deepEqual(commandFrames(harness).at(-1), { axes: [0.03, 0.05], enable: 1 });
    harness.api.stopFcuBenchHold();
});

test('auto-move keeps the same gating as the hold: not ready, no frames', () => {
    const harness = readyBenchHarness();
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'READY_DISARMED', fault: 'READY_DISARMED', ready: true,
            connected: true, armed: false, mode: 'MANUAL', feedback_fresh: true,
            resolved: { steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1 },
            command: {}, measured: {}
        })
    });
    const before = commandFrames(harness).length;
    assert.equal(harness.api.startFcuBenchAutoMove(), false);
    assert.equal(commandFrames(harness).length, before);
    assert.equal(harness.elements.get('btn-fcu-loop-auto-move').disabled, true);
});

test('auto-move refuses a throttle below the measured break-away', () => {
    const harness = readyBenchHarness();
    harness.elements.get('fcu-loop-auto-throttle').value = '0.10';
    const before = commandFrames(harness).length;
    assert.equal(harness.api.startFcuBenchAutoMove(), false);
    assert.equal(commandFrames(harness).length, before);
    assert.match(harness.elements.get('fcu-loop-auto-status').textContent, /Rejected/);
    assert.equal(harness.api.readFcuBenchAutoMoveConfig(), null);
    harness.elements.get('fcu-loop-auto-throttle').value = '0.25';
    assert.equal(harness.api.readFcuBenchAutoMoveConfig(), null);
    harness.elements.get('fcu-loop-auto-throttle').value = '0.17';
    harness.elements.get('fcu-loop-auto-turn-seconds').value = '11';
    assert.equal(harness.api.readFcuBenchAutoMoveConfig(), null);
});

test('auto-move side maps onto the FCU mixer sign', () => {
    const harness = readyBenchHarness();
    harness.elements.get('fcu-loop-auto-side').value = 'left';
    const config = harness.api.readFcuBenchAutoMoveConfig();
    assert.equal(config.steering, -0.10);
    harness.elements.get('fcu-loop-auto-side').value = 'right';
    assert.equal(harness.api.readFcuBenchAutoMoveConfig().steering, 0.10);
    harness.elements.get('fcu-loop-auto-side').value = 'sideways';
    assert.equal(harness.api.readFcuBenchAutoMoveConfig(), null);
});

test('emergency stop during an auto-move ends it and later ticks publish nothing enabled', () => {
    const harness = readyBenchHarness();
    assert.equal(harness.api.startFcuBenchAutoMove(), true);
    harness.advance(1000);
    assert.equal(harness.api.publishFcuBenchEmergencyStop(), true);
    const frames = commandFrames(harness);
    assert.equal(frames.at(-1).enable, 0);
    assert.equal(harness.intervals.some((entry) => entry.active), false);
    const before = commandFrames(harness).length;
    assert.equal(harness.api.startFcuBenchAutoMove(), false, 'latched: nothing may start');
    assert.equal(commandFrames(harness).length, before);
});

test('readiness lost during an auto-move stops it like the plain hold', () => {
    const harness = readyBenchHarness();
    assert.equal(harness.api.startFcuBenchAutoMove(), true);
    harness.advance(1000);
    harness.api.updateLiveFcuBenchStatus({
        data: JSON.stringify({
            state: 'FEEDBACK_INVALID', fault: 'FEEDBACK_INVALID', ready: false,
            connected: true, armed: true, mode: 'MANUAL', feedback_fresh: false,
            resolved: { steering_rc: 1, throttle_rc: 3, left_servo: 3, right_servo: 1 },
            command: {}, measured: {}
        })
    });
    assert.equal(harness.intervals.some((entry) => entry.active), false);
    assert.equal(commandFrames(harness).at(-1).enable, 0);
});

test('a bridge status that goes stale mid-maneuver ends the auto-move within the freshness limit', () => {
    const harness = readyBenchHarness();
    assert.equal(harness.api.startFcuBenchAutoMove(), true);
    // No refreshStatus(): the bridge has gone quiet.
    harness.advance(600);
    activeTick(harness);
    const frames = commandFrames(harness);
    assert.equal(frames.at(-1).enable, 0, 'a stale bridge status must end the maneuver in a disabled frame');
    assert.equal(harness.intervals.some((entry) => entry.active), false);
});

// On 04/09/2026 every mouse press of the auto-move button sent exactly one
// frame: the status line written on that frame reflowed the panel, the button
// slid out from under the stationary pointer, and pointerleave released the
// hold. Capturing the pointer on press keeps its events on the button wherever
// the layout puts it. The harness has no layout, so the contract under test is
// the capture call itself; the browser measurement is in the runbook.
['btn-fcu-loop-hold', 'btn-fcu-loop-auto-move'].forEach((id) => {
    test(`${id} captures the pointer on press so a layout shift cannot release the hold`, () => {
        const harness = readyBenchHarness();
        const button = harness.elements.get(id);
        button.dispatch('pointerdown', {
            pointerId: 7, currentTarget: button, preventDefault() {}
        });
        assert.deepEqual(button.capturedPointers, [7]);
        assert.equal(harness.intervals.some((entry) => entry.active), true, 'hold started');
        button.dispatch('pointerup', { pointerId: 7 });
        assert.equal(harness.intervals.some((entry) => entry.active), false, 'pointerup still releases');
        assert.deepEqual(Array.from(harness.published.at(-1).message.buttons), [0]);
    });
});

test('a press still starts the hold when the element cannot capture the pointer', () => {
    const harness = readyBenchHarness();
    const button = harness.elements.get('btn-fcu-loop-auto-move');
    button.setPointerCapture = () => { throw new Error('capture refused'); };
    button.dispatch('pointerdown', {
        pointerId: 3, currentTarget: button, preventDefault() {}
    });
    assert.equal(harness.intervals.some((entry) => entry.active), true, 'hold started without capture');
    button.dispatch('pointerup', { pointerId: 3 });
    assert.equal(harness.intervals.some((entry) => entry.active), false);
});

test('keyboard activation skips pointer capture for both hold buttons', () => {
    for (const id of ['btn-fcu-loop-hold', 'btn-fcu-loop-auto-move']) {
        const harness = readyBenchHarness();
        const button = harness.elements.get(id);
        button.dispatch('keydown', {
            key: ' ', repeat: false, currentTarget: button, preventDefault() {}
        });
        assert.deepEqual(button.capturedPointers, [], `${id} must not capture a keyboard event`);
        assert.equal(harness.intervals.some((entry) => entry.active), true, `${id} hold started`);
        button.dispatch('keyup', { key: ' ' });
        assert.equal(harness.intervals.some((entry) => entry.active), false, `${id} keyup released`);
        assert.deepEqual(Array.from(harness.published.at(-1).message.buttons), [0]);
    }
});
