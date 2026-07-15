const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const appSource = fs.readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
const htmlSource = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');

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
    let gpsUpdates = 0;
    let publishes = 0;
    let serviceCalls = 0;

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
        document: {
            body: {
                classList: {
                    add(name) { bodyClasses.add(name); }
                }
            },
            getElementById(id) {
                if (!elements.has(id)) {
                    elements.set(id, { textContent: '', className: '', dataset: {} });
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
            LIVE_MAVLINK_TOPIC_SPECS,
            quaternionToEulerDegrees,
            publishDashboardWrite,
            callDashboardWriteService,
            enableLiveMavlinkViewOnly,
            subscribeToLiveMavlinkTopics,
            updateLiveMavlinkState,
            updateLiveMavlinkImu,
            updateLiveMavlinkBattery,
            updateLiveMavlinkRc,
            updateLiveMavlinkGps
        };`,
        context
    );

    return {
        api: context.__mavlinkTestApi,
        bodyClasses,
        elements,
        subscriptions,
        getGpsUpdates: () => gpsUpdates,
        getPublishes: () => publishes,
        getServiceCalls: () => serviceCalls,
        service: {
            callService() { serviceCalls += 1; }
        }
    };
}

test('temporary live view wires exactly five read-only MAVROS topics', () => {
    const harness = createHarness();
    assert.equal(harness.api.LIVE_MAVLINK_VIEW_ONLY, true);
    assert.deepEqual(
        Array.from(harness.api.LIVE_MAVLINK_TOPIC_SPECS, (spec) => [spec.name, spec.messageType]),
        [
            ['/mavros/state', 'mavros_msgs/State'],
            ['/mavros/global_position/raw/fix', 'sensor_msgs/NavSatFix'],
            ['/mavros/imu/data', 'sensor_msgs/Imu'],
            ['/mavros/battery', 'sensor_msgs/BatteryState'],
            ['/mavros/rc/in', 'mavros_msgs/RCIn']
        ]
    );

    harness.api.subscribeToLiveMavlinkTopics();
    assert.equal(harness.subscriptions.length, 5);
    assert.equal(harness.subscriptions.find((topic) => topic.options.name === '/mavros/imu/data').options.throttle_rate, 200);
});

test('temporary view blocks dashboard writes and enables the visible safety state', () => {
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
});

test('all dashboard publishes pass through the temporary write guard', () => {
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
        'mavlink-connected',
        'mavlink-armed',
        'mavlink-mode',
        'mavlink-system-status',
        'mavlink-manual-input',
        'mavlink-gps-fix',
        'mavlink-gps-altitude',
        'mavlink-attitude',
        'mavlink-gyro',
        'mavlink-accel',
        'mavlink-battery',
        'mavlink-battery-current',
        'mavlink-rc-rssi',
        'mavlink-rc-channels',
        'mavlink-last-update'
    ];
    for (const id of ids) {
        const matches = htmlSource.match(new RegExp(`id=["']${id}["']`, 'g')) || [];
        assert.equal(matches.length, 1, `Expected exactly one #${id}`);
    }
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
    assert.equal(harness.elements.get('mavlink-system-status').textContent, '5');

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

    harness.api.updateLiveMavlinkGps({
        status: { status: -1, service: 1 },
        altitude: 17.16,
        latitude: 0,
        longitude: 0
    });
    assert.equal(harness.elements.get('mavlink-gps-fix').textContent, 'No fix (-1)');
    assert.equal(harness.getGpsUpdates(), 1);
});
