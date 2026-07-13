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

function createGpsUpdateHarness() {
    const elements = new Map();
    const markerPositions = [];
    let now = 0;

    const context = {
        currentState: {
            gps: { lat: 0, lon: 0, x: 0, y: 0, speed: 0, hasFix: false }
        },
        gpsToLocal(latitude, longitude) {
            return { x: longitude * 100, y: latitude * 100 };
        },
        document: {
            getElementById(id) {
                if (!elements.has(id)) elements.set(id, { textContent: '' });
                return elements.get(id);
            }
        },
        boatMarker: {
            setLatLng(position) {
                markerPositions.push([...position]);
            }
        },
        trajectoryPoints: [],
        trajectoryLine: { setLatLngs() {} },
        lastTrajectoryUpdate: 0,
        pendingTrajectoryUpdate: false,
        requestAnimationFrame(callback) { callback(); },
        mapFollowBoat: false,
        lastMapPan: 0,
        map: {
            getCenter() { return [0, 0]; },
            distance() { return 0; },
            getZoom() { return 16; },
            setView() {}
        },
        Date: { now: () => (now += 1000) },
        progressState: {
            lastPosition: null,
            distanceTraveled: 0
        },
        missionState: { state: 'IDLE' },
        updateMissionProgress() {}
    };

    vm.createContext(context);
    const gpsUpdateSource = sourceBetween(
        '// A NavSatFix coordinate',
        '// Update thruster data'
    );
    const speedWrapperSource = sourceBetween(
        '// Hook into GPS updates for speed tracking',
        '// Hook into waypoint generation'
    );
    vm.runInContext(
        `${gpsUpdateSource}\n${speedWrapperSource}\n` +
        'globalThis.__gpsTestApi = { updateGPS };',
        context
    );

    return {
        context,
        elements,
        markerPositions,
        updateGPS: context.__gpsTestApi.updateGPS
    };
}

test('invalid NavSatFix samples show no fix without moving the last valid position', async (t) => {
    const invalidSamples = [
        ['unknown status', { status: { status: -2 }, latitude: 0, longitude: 0 }],
        ['no-fix status', { status: { status: -1 }, latitude: 0, longitude: 0 }],
        ['missing status', { latitude: 48.1, longitude: 2.3 }],
        ['non-finite latitude', { status: { status: 0 }, latitude: NaN, longitude: 2.3 }],
        ['non-finite longitude', { status: { status: 0 }, latitude: 48.1, longitude: Infinity }]
    ];

    for (const [name, sample] of invalidSamples) {
        await t.test(name, () => {
            const harness = createGpsUpdateHarness();
            const accepted = harness.updateGPS({
                status: { status: 0 },
                latitude: 48.123456,
                longitude: 2.654321
            });
            assert.equal(accepted, true);

            const coordinatesBefore = {
                lat: harness.context.currentState.gps.lat,
                lon: harness.context.currentState.gps.lon,
                x: harness.context.currentState.gps.x,
                y: harness.context.currentState.gps.y
            };
            const markerCountBefore = harness.markerPositions.length;
            const trajectoryBefore = harness.context.trajectoryPoints.map((point) => [...point]);

            assert.equal(harness.updateGPS(sample), false);
            assert.deepEqual(
                {
                    lat: harness.context.currentState.gps.lat,
                    lon: harness.context.currentState.gps.lon,
                    x: harness.context.currentState.gps.x,
                    y: harness.context.currentState.gps.y
                },
                coordinatesBefore
            );
            assert.equal(harness.context.currentState.gps.speed, 0);
            assert.equal(harness.context.progressState.lastPosition, null);
            assert.equal(harness.markerPositions.length, markerCountBefore);
            assert.deepEqual(
                harness.context.trajectoryPoints.map((point) => Array.from(point)),
                trajectoryBefore
            );
            assert.equal(harness.context.currentState.gps.hasFix, false);
            assert.equal(harness.elements.get('latitude').textContent, 'No fix | Pas de position');
            assert.equal(harness.elements.get('longitude').textContent, 'No fix | Pas de position');
            assert.equal(harness.elements.get('local-x').textContent, 'N/A');
            assert.equal(harness.elements.get('local-y').textContent, 'N/A');
        });
    }
});

test('status zero with coordinates at 0,0 is a valid GPS fix', () => {
    const harness = createGpsUpdateHarness();

    assert.equal(harness.updateGPS({
        status: { status: 0 },
        latitude: 0,
        longitude: 0
    }), true);
    assert.equal(harness.context.currentState.gps.hasFix, true);
    assert.deepEqual(harness.markerPositions, [[0, 0]]);
    assert.equal(harness.elements.get('latitude').textContent, '0.000000°');
    assert.equal(harness.elements.get('longitude').textContent, '0.000000°');
});

test('first valid fix after an outage establishes a fresh speed baseline', () => {
    const harness = createGpsUpdateHarness();
    harness.updateGPS({
        status: { status: 0 },
        latitude: 48.1,
        longitude: 2.3
    });
    harness.updateGPS({
        status: { status: -1 },
        latitude: 0,
        longitude: 0
    });
    harness.context.progressState.distanceTraveled = 12;
    harness.context.missionState.state = 'PAUSED';

    assert.equal(harness.updateGPS({
        status: { status: 0 },
        latitude: 49.1,
        longitude: 3.3
    }), true);
    assert.equal(harness.context.currentState.gps.hasFix, true);
    assert.equal(harness.context.currentState.gps.speed, 0);
    assert.equal(harness.context.progressState.distanceTraveled, 12);
    assert.equal(harness.context.progressState.lastPosition.x, 330);
    assert.equal(harness.context.progressState.lastPosition.y, 4910);
    assert.equal(harness.elements.get('latitude').textContent, '49.100000°');
});

test('0,0 can become the local-coordinate origin after a valid fix', () => {
    const gpsOriginSource = sourceBetween(
        '// GPS origin',
        '// Update local coordinates display'
    );
    const context = {};
    vm.createContext(context);
    vm.runInContext(
        `${gpsOriginSource}\n` +
        'globalThis.__originApi = { gpsToLocal };',
        context
    );

    assert.deepEqual({ ...context.__originApi.gpsToLocal(0, 0) }, { x: 0, y: 0 });
    const moved = context.__originApi.gpsToLocal(0.001, 0.001);
    assert.ok(moved.x > 100 && moved.x < 120);
    assert.ok(moved.y > 100 && moved.y < 120);
});

test('local-coordinate display stays unavailable while GPS has no fix', () => {
    const elements = new Map();
    let intervalCallback;
    const context = {
        currentState: {
            gps: { lat: 48.1, lon: 2.3, hasFix: false }
        },
        gpsToLocal() { return { x: 123.4, y: 567.8 }; },
        document: {
            getElementById(id) {
                if (!elements.has(id)) elements.set(id, { textContent: '' });
                return elements.get(id);
            }
        },
        setInterval(callback) { intervalCallback = callback; }
    };
    const localDisplaySource = sourceBetween(
        '// Update local coordinates display',
        'const MAIN_CONFIG_RESET_INPUTS'
    );
    vm.createContext(context);
    vm.runInContext(localDisplaySource, context);

    intervalCallback();
    assert.equal(elements.get('local-x').textContent, 'N/A');
    assert.equal(elements.get('local-y').textContent, 'N/A');
});
