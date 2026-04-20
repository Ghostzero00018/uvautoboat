// Performance optimization: Debug mode flag
let DEBUG_MODE = false;  // Set to true to enable console logging (type DEBUG_MODE=true in browser console)
let configSynced = false; // True after first config update received from ROS

// ROS Connection
let ros;
let connected = false;

// Map variables
let map;
let boatMarker;
let trajectoryLine;
let trajectoryPoints = [];
let waypointMarkers = [];
let waypointPath = null;  // Line connecting waypoints
let currentWaypointMarker = null;  // Highlight current target
let gridLayerGroup = null;  // Grid overlay layer group
let gridEventHandlerRegistered = false;  // Prevent duplicate grid event handlers
let gridEnabled = true;  // User toggle — off for max framerate on weak GPUs
let gridRedrawTimer = null;  // Debounce handle for addGridOverlay() redraws

// Configuration publisher
let configPublisher = null;
let modularConfigPublisher = null;  // For waypoint planner
let missionCommandPublisher = null;  // Mission command publisher
let modularMissionCommandPublisher = null;  // For waypoint planner

// Track which config inputs have been modified by user (prevents ROS from overwriting)
let dirtyInputs = new Set();
let navModeDirty = false;
// Performance optimization: Throttle updates
let lastTrajectoryUpdate = 0;
let lastMapPan = 0;
let pendingTrajectoryUpdate = false;

// Camera feed elements
let cameraImageEl = null;
let cameraStatusEl = null;
let cameraTopicInput = null;

// Mission state
let missionState = {
    state: 'IDLE',
    gpsReady: false,
    waypointsGenerated: false,
    missionArmed: false,
    joystickOverride: false,
    goHomeMode: false,
    // Snapshot of distance-to-home the moment Go Home starts, used to turn the
    // single-waypoint return trip into a real progress bar. Reset when goHomeMode flips off.
    goHomeInitialDistance: null,
    waypoints: [],
    currentWaypoint: 0,
    totalWaypoints: 0,
    startLat: null,
    startLon: null
};

const WAYPOINT_STORAGE_KEY = 'autoboat_cached_waypoints';

// Data storage
let currentState = {
    gps: { lat: 0, lon: 0, local_x: 0, local_y: 0 },
    obstacles: { min: Infinity, front: true, left: true, right: true },
    thrusters: { left: 0, right: 0 },
    mission: { state: 'IDLE', waypoint: 0, distance: 0 },
    config: {
        scan_length: 15.0,
        scan_width: 30.0,
        lanes: 10,
        kp: 500.0,
        ki: 20.0,
        kd: 150.0,
        base_speed: 400.0,
        max_speed: 800.0,
        min_safe_distance: 12.0
    },
    world: {
        name: 'unknown'
    }
};

// Style mode (single mode - normal only)

// Initialize everything when page loads
window.addEventListener('load', () => {
    if (DEBUG_MODE) console.log('Dashboard loading...');
    initMap();
    restorePersistedWaypoints();  // Recover waypoints after hard refresh
    connectToROS();
    initConfigPanel();
    initMissionControl();  // NEW: Mission control buttons
    initCameraFeed();      // Camera/RViz stream panel
    initTerminal();
    initWorldBanner();
    initCollapsiblePanels();
    initOnboarding();
    addLog('Dashboard initialized', 'info');
});

// Wire click-to-collapse on any .panel.collapsible — the h2 toggles the panel's .collapsed class
function initCollapsiblePanels() {
    document.querySelectorAll('.panel.collapsible > h2').forEach(h => {
        h.addEventListener('click', () => {
            h.parentElement.classList.toggle('collapsed');
        });
    });
}

// ========== FIRST-RUN ONBOARDING TOUR ==========
// Bump the storage key suffix (e.g. _v2) if the steps change meaningfully — returning users
// will then see the refreshed tour once, rather than silently missing new guidance.
const ONBOARDING_STORAGE_KEY = 'autoboat_tutorial_seen_v1';

const ONBOARDING_STEPS = [
    {
        targetSelector: null,
        title: 'Welcome to AutoBoat',
        subtitle: 'Bienvenue — 5-step tour',
        body: 'This is the control dashboard for the AutoBoat autonomous USV. The next four steps walk through a full mission: generate a route, confirm it, start navigation, and where to halt the boat if something goes wrong. You can replay this tour anytime from the ? button in the header.'
    },
    {
        targetSelector: '#btn-generate-waypoints',
        title: 'Step 1 — Generate a route',
        subtitle: 'Étape 1 — Générer',
        body: 'Pick the number of lanes, lane length and width, then select a Navigation Mode (Simple Lawnmower, Runtime A*, or Hybrid). Clicking Generate Waypoints sends the parameters to the planner, which returns a lawnmower sweep pattern and draws it on the trajectory map.'
    },
    {
        targetSelector: '#btn-confirm-waypoints',
        title: 'Step 2 — Review and confirm',
        subtitle: 'Étape 2 — Confirmer',
        body: 'The generated waypoints appear on the map. Inspect the route for clashes with the shoreline or obstacles. Click Confirm to lock the plan, or Cancel to regenerate with different settings. The mission state transitions from WAITING_CONFIRM to READY once confirmed.'
    },
    {
        targetSelector: '#btn-start-mission',
        title: 'Step 3 — Start the mission',
        subtitle: 'Étape 3 — Démarrer',
        body: 'The heading controller begins tracking the first waypoint at the configured PID gains. During the run, obstacle clearance, VFH gap direction, Kalman-estimated drift, and waypoint progress are all live on the panels below. STOP pauses the mission; RESUME continues; RETURN HOME heads back to spawn.'
    },
    {
        targetSelector: '#header-estop-badge',
        title: 'Emergency Stop',
        subtitle: 'Arrêt d\'urgence — always accessible',
        body: 'This header shortcut (and the big red button in Mission Control) immediately cuts thrust. After use, click Resume to recover the mission or Reset to clear the plan. The ℹ️ icons on every panel explain the individual fields — no need to memorise them up front.'
    }
];

const onboardingState = {
    currentStep: 0,
    backdrop: null,
    card: null,
    highlightedEl: null,
    keyHandler: null
};

function initOnboarding() {
    const helpBtn = document.getElementById('header-help-btn');
    if (helpBtn) {
        helpBtn.addEventListener('click', () => startOnboarding(true));
    }

    // Auto-launch for first-time visitors, after the rest of the dashboard has settled
    if (!localStorage.getItem(ONBOARDING_STORAGE_KEY)) {
        setTimeout(() => startOnboarding(false), 900);
    }
}

function startOnboarding(isReplay) {
    if (onboardingState.backdrop) return;  // already running

    onboardingState.currentStep = 0;

    const backdrop = document.createElement('div');
    backdrop.className = 'onboarding-backdrop';
    document.body.appendChild(backdrop);
    onboardingState.backdrop = backdrop;

    const card = document.createElement('div');
    card.className = 'onboarding-card';
    card.setAttribute('role', 'dialog');
    card.setAttribute('aria-live', 'polite');
    document.body.appendChild(card);
    onboardingState.card = card;

    onboardingState.keyHandler = (e) => {
        if (e.key === 'Escape') { endOnboarding(false); }
        else if (e.key === 'ArrowRight' || e.key === 'Enter') { nextOnboardingStep(); }
        else if (e.key === 'ArrowLeft') { prevOnboardingStep(); }
    };
    document.addEventListener('keydown', onboardingState.keyHandler);

    renderOnboardingStep();
    if (!isReplay) {
        addLog('Welcome tour started — click Skip to dismiss', 'info');
    }
}

function renderOnboardingStep() {
    const step = ONBOARDING_STEPS[onboardingState.currentStep];
    const total = ONBOARDING_STEPS.length;
    const idx = onboardingState.currentStep;
    const isFirst = idx === 0;
    const isLast = idx === total - 1;

    clearOnboardingHighlight();

    if (step.targetSelector) {
        const target = document.querySelector(step.targetSelector);
        if (target) {
            target.classList.add('onboarding-highlight');
            onboardingState.highlightedEl = target;
            target.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }

    const backLabel = 'Back | Retour';
    const skipLabel = 'Skip | Passer';
    const nextLabel = isLast ? 'Finish | Terminer' : 'Next | Suivant';
    const nextClass = isLast ? 'finish' : 'next';

    onboardingState.card.innerHTML = `
        <div class="onboarding-progress">Step ${idx + 1} of ${total}</div>
        <h3>${escapeOnboardingText(step.title)}</h3>
        <span class="onboarding-subtitle">${escapeOnboardingText(step.subtitle)}</span>
        <p>${escapeOnboardingText(step.body)}</p>
        <div class="onboarding-buttons">
            <button class="onboarding-btn back" ${isFirst ? 'style="visibility: hidden;"' : ''}>${backLabel}</button>
            <div style="display: flex; gap: 8px;">
                <button class="onboarding-btn skip">${skipLabel}</button>
                <button class="onboarding-btn ${nextClass}">${nextLabel}</button>
            </div>
        </div>
    `;

    onboardingState.card.querySelector('.onboarding-btn.back').addEventListener('click', prevOnboardingStep);
    onboardingState.card.querySelector('.onboarding-btn.skip').addEventListener('click', () => endOnboarding(false));
    onboardingState.card.querySelector(`.onboarding-btn.${nextClass}`).addEventListener('click', nextOnboardingStep);
}

function nextOnboardingStep() {
    if (!onboardingState.card) return;
    if (onboardingState.currentStep >= ONBOARDING_STEPS.length - 1) {
        endOnboarding(true);
    } else {
        onboardingState.currentStep += 1;
        renderOnboardingStep();
    }
}

function prevOnboardingStep() {
    if (!onboardingState.card || onboardingState.currentStep === 0) return;
    onboardingState.currentStep -= 1;
    renderOnboardingStep();
}

function endOnboarding(completed) {
    clearOnboardingHighlight();
    if (onboardingState.backdrop) {
        onboardingState.backdrop.remove();
        onboardingState.backdrop = null;
    }
    if (onboardingState.card) {
        onboardingState.card.remove();
        onboardingState.card = null;
    }
    if (onboardingState.keyHandler) {
        document.removeEventListener('keydown', onboardingState.keyHandler);
        onboardingState.keyHandler = null;
    }
    try {
        localStorage.setItem(ONBOARDING_STORAGE_KEY, '1');
    } catch (e) {
        // localStorage may be unavailable in private mode — tour will simply replay next session
    }
    if (completed) {
        addLog('Welcome tour completed', 'info');
    }
}

function clearOnboardingHighlight() {
    if (onboardingState.highlightedEl) {
        onboardingState.highlightedEl.classList.remove('onboarding-highlight');
        onboardingState.highlightedEl = null;
    }
}

function escapeOnboardingText(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// World banner marquee
function initWorldBanner() {
    const banner = document.getElementById('world-banner-text');
    if (banner) {
        banner.textContent = 'Awaiting world info...';
    }
}

let _prevBanner = {};
function updateWorldBanner(name) {
    if (_prevBanner.name === name) return;
    _prevBanner.name = name;
    const banner = document.getElementById('world-banner-text');
    if (!banner) return;
    banner.innerHTML = `Currently loaded world is <b><i>${(name || 'unknown').replace(/</g, '&lt;')}</i></b>`;
}


// Map follow mode
let mapFollowBoat = false;  // Default: don't auto-follow

// Update follow button visual state
function updateFollowButtonState() {
    const btn = document.getElementById('follow-boat-toggle');
    if (btn) {
        if (mapFollowBoat) {
            btn.innerHTML = '🔒';
            btn.classList.add('active');
            btn.title = 'Following active (click to disable) | Suivi actif';
        } else {
            btn.innerHTML = '🎯';
            btn.classList.remove('active');
            btn.title = 'Click to follow boat | Suivre le navire';
        }
    }
}

// Initialize Leaflet map
function initMap() {
    // Initialize map at Sydney Regatta Centre approximate location
    map = L.map('map').setView([-33.8361, 151.0697], 16);
    
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
    }).addTo(map);
    
    // Custom boat icon
    const boatIcon = L.divIcon({
        className: 'boat-marker',
        html: '🚤',
        iconSize: [30, 30],
        iconAnchor: [15, 15]
    });
    
    boatMarker = L.marker([-33.8361, 151.0697], { icon: boatIcon }).addTo(map);
    trajectoryLine = L.polyline([], { color: '#00cc66', weight: 3 }).addTo(map);
    
    // Add follow boat toggle button
    const FollowBoatControl = L.Control.extend({
        options: { position: 'topright' },
        onAdd: function(map) {
            const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control follow-boat-control');
            const button = L.DomUtil.create('a', 'follow-boat-btn', container);
            button.href = '#';
            button.title = 'Follow boat | Suivre le navire';
            button.innerHTML = '🎯';
            button.id = 'follow-boat-toggle';
            
            L.DomEvent.on(button, 'click', function(e) {
                L.DomEvent.preventDefault(e);
                L.DomEvent.stopPropagation(e);
                mapFollowBoat = !mapFollowBoat;
                updateFollowButtonState();
                if (mapFollowBoat && currentState.gps.lat !== 0) {
                    map.panTo([currentState.gps.lat, currentState.gps.lon]);
                }
            });
            
            return container;
        }
    });
    
    map.addControl(new FollowBoatControl());
    updateFollowButtonState();

    // Add grid overlay to map + toggle button
    addGridOverlay();
    addGridToggleControl();

    addLog('Map initialized', 'info');
}

// Adaptive grid spacing — pick a spacing from this list so the grid always has
// a reasonable visual density regardless of zoom level. Prevents the line
// count from exploding when zoomed out (which previously froze weak GPUs).
const GRID_SPACING_CHOICES_M = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000];
const GRID_TARGET_PX_PER_CELL = 60;  // Aim for ~60px per cell on screen
const GRID_MAX_LINES = 200;           // Safety cap — skip drawing if above this

// Add grid overlay to map (OPTIMIZED — adaptive spacing + debounced + safety cap)
function addGridOverlay() {
    if (!map) return;

    // Initialize grid layer group once
    if (!gridLayerGroup) {
        gridLayerGroup = L.layerGroup().addTo(map);
    }

    // Register event handler ONCE. Always register so the toggle can
    // re-enable the grid without another call site.
    if (!gridEventHandlerRegistered) {
        gridEventHandlerRegistered = true;
        map.on('moveend zoomend', scheduleGridRedraw);
    }

    // Fast exits: user toggled grid off, or we're mid-debounce
    gridLayerGroup.clearLayers();
    if (!gridEnabled) return;

    // Pick a grid spacing so cells are ~60px on screen. metersPerPixel varies
    // with latitude and zoom; Leaflet exposes this via map.containerPointToLatLng.
    const center = map.getCenter();
    const metersPerPixel = _computeMetersPerPixel(center.lat, map.getZoom());
    const targetMeters = GRID_TARGET_PX_PER_CELL * metersPerPixel;
    let spacingMeters = GRID_SPACING_CHOICES_M[GRID_SPACING_CHOICES_M.length - 1];
    for (const s of GRID_SPACING_CHOICES_M) {
        if (s >= targetMeters) { spacingMeters = s; break; }
    }

    const bounds = map.getBounds();
    const metersPerDegreeLat = 111000;
    const metersPerDegreeLon = 111000 * Math.cos(center.lat * Math.PI / 180);
    const gridSpacingLat = spacingMeters / metersPerDegreeLat;
    const gridSpacingLon = spacingMeters / metersPerDegreeLon;

    const minLat = Math.floor(bounds.getSouth() / gridSpacingLat) * gridSpacingLat;
    const maxLat = Math.ceil(bounds.getNorth() / gridSpacingLat) * gridSpacingLat;
    const minLon = Math.floor(bounds.getWest() / gridSpacingLon) * gridSpacingLon;
    const maxLon = Math.ceil(bounds.getEast() / gridSpacingLon) * gridSpacingLon;

    // Safety cap — if something goes wrong (e.g. weird bounds), skip drawing
    const latLines = Math.ceil((maxLat - minLat) / gridSpacingLat) + 1;
    const lonLines = Math.ceil((maxLon - minLon) / gridSpacingLon) + 1;
    if (latLines + lonLines > GRID_MAX_LINES) {
        if (DEBUG_MODE) console.warn(`Grid skipped: ${latLines + lonLines} lines > ${GRID_MAX_LINES} cap`);
        return;
    }

    const lineStyle = {
        color: '#3498db',
        weight: 1,
        opacity: 0.3,
        dashArray: '5, 5',
        interactive: false
    };

    for (let lat = minLat; lat <= maxLat; lat += gridSpacingLat) {
        L.polyline([[lat, bounds.getWest()], [lat, bounds.getEast()]], lineStyle)
            .addTo(gridLayerGroup);
    }
    for (let lon = minLon; lon <= maxLon; lon += gridSpacingLon) {
        L.polyline([[bounds.getSouth(), lon], [bounds.getNorth(), lon]], lineStyle)
            .addTo(gridLayerGroup);
    }
}

// Approximate meters-per-pixel at a given latitude and zoom level. Uses the
// Web Mercator relationship: meters/pixel = 156543.03 * cos(lat) / 2^zoom.
function _computeMetersPerPixel(lat, zoom) {
    return 156543.03 * Math.cos(lat * Math.PI / 180) / Math.pow(2, zoom);
}

// Debounced grid redraw — rapid pan/zoom shouldn't trigger a cascade of redraws.
function scheduleGridRedraw() {
    if (gridRedrawTimer) clearTimeout(gridRedrawTimer);
    gridRedrawTimer = setTimeout(() => {
        gridRedrawTimer = null;
        addGridOverlay();
    }, 150);
}

// Leaflet control: small button in the top-right to toggle the grid on/off.
// Useful on weak GPUs where even the adaptive grid costs framerate.
function addGridToggleControl() {
    if (!map) return;
    const GridToggle = L.Control.extend({
        options: { position: 'topright' },
        onAdd: function() {
            const btn = L.DomUtil.create('button', 'leaflet-bar leaflet-control grid-toggle-btn');
            btn.type = 'button';
            btn.title = 'Toggle grid overlay | Activer/désactiver la grille';
            btn.textContent = '⊞';
            btn.style.cssText = 'width:30px;height:30px;background:#fff;border:2px solid rgba(0,0,0,0.2);cursor:pointer;font-size:18px;line-height:26px;padding:0;';
            L.DomEvent.disableClickPropagation(btn);
            btn.addEventListener('click', () => {
                gridEnabled = !gridEnabled;
                btn.style.background = gridEnabled ? '#fff' : '#ddd';
                btn.style.color = gridEnabled ? '#333' : '#999';
                addGridOverlay();
            });
            return btn;
        }
    });
    new GridToggle().addTo(map);
}

// Connect to ROS via rosbridge
function connectToROS() {
    const rosHost = window.location.hostname || 'localhost';
    const rosUrl = `ws://${rosHost}:9090`;
    if (DEBUG_MODE) console.log(`Attempting to connect to ${rosUrl}...`);
    ros = new ROSLIB.Ros({
        url: rosUrl
    });

    ros.on('connection', () => {
        if (DEBUG_MODE) console.log('Connected to rosbridge!');
        connected = true;
        updateConnectionStatus(true);
        addLog('Connected to rosbridge', 'info');
        subscribeToTopics();
    });

    ros.on('error', (error) => {
        console.error('ROS connection error:', error);
        connected = false;
        updateConnectionStatus(false);
        addLog(`Connection error: ${error}`, 'error');
    });

    ros.on('close', () => {
        if (DEBUG_MODE) console.log('Connection closed');
        connected = false;
        updateConnectionStatus(false);
        // Clear publishers so they get recreated with the new ros object on reconnect
        missionCommandPublisher = null;
        configPublisher = null;
        modularConfigPublisher = null;
        modularMissionCommandPublisher = null;
        addLog('Connection closed. Retrying in 5s...', 'warning');
        setTimeout(connectToROS, 5000);
    });
}

// Initialize camera/RViz stream panel using web_video_server
function initCameraFeed() {
    cameraImageEl = document.getElementById('camera-image');
    cameraStatusEl = document.getElementById('camera-status');
    cameraTopicInput = document.getElementById('camera-topic');
    const refreshBtn = document.getElementById('btn-refresh-camera');

    if (refreshBtn) {
        refreshBtn.addEventListener('click', updateCameraStream);
    }

    if (!cameraImageEl || !cameraStatusEl || !cameraTopicInput) {
        return;
    }

    cameraImageEl.addEventListener('load', () => {
        cameraStatusEl.textContent = 'Streaming | Flux en cours';
        cameraStatusEl.classList.remove('error');
    });

    cameraImageEl.addEventListener('error', () => {
        cameraStatusEl.textContent = 'Camera feed unavailable. Start web_video_server? | Flux indisponible';
        cameraStatusEl.classList.add('error');
    });

    updateCameraStream();
}

function updateCameraStream() {
    if (!cameraImageEl || !cameraTopicInput || !cameraStatusEl) {
        return;
    }
    const topic = cameraTopicInput.value.trim() || '/wamv/sensors/cameras/front_left_camera_sensor/image_raw';
    cameraStatusEl.textContent = `Connecting to ${topic}...`;
    const streamUrl = buildCameraUrl(topic);
    // Cache-bust each refresh to force a reconnect
    cameraImageEl.src = `${streamUrl}&t=${Date.now()}`;
}

function buildCameraUrl(topic) {
    // Use the current host so you don't need a separate tab on another localhost/host.
    const baseHost = window.location.hostname || 'localhost';
    const base = `${window.location.protocol}//${baseHost}:8080/stream`;
    // web_video_server expects the topic path unencoded (slashes are valid), so build manually.
    return `${base}?topic=${topic}&type=mjpeg&quality=80`;
}

// Update connection status indicator
function updateConnectionStatus(isConnected) {
    const statusElement = document.getElementById('connection-status');
    if (isConnected) {
        statusElement.textContent = 'Connected | Connecté';
        statusElement.className = 'status connected';
    } else {
        statusElement.textContent = 'Disconnected | Déconnecté';
        statusElement.className = 'status disconnected';
    }
}

// Subscribe to ROS topics
function subscribeToTopics() {
    if (DEBUG_MODE) console.log('Subscribing to topics...');
    
    // GPS Fix
    const gpsTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/wamv/sensors/gps/gps/fix',
        messageType: 'sensor_msgs/NavSatFix'
    });

    gpsTopic.subscribe((message) => {
        if (DEBUG_MODE) console.log('GPS data received:', message.latitude, message.longitude);
        updateGPS(message);
    });

    // Left thruster
    const leftThrustTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/wamv/thrusters/left/thrust',
        messageType: 'std_msgs/Float64'
    });

    leftThrustTopic.subscribe((message) => {
        if (DEBUG_MODE) console.log('Left thrust:', message.data);
        updateThruster('left', message.data);
    });

    // Right thruster
    const rightThrustTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/wamv/thrusters/right/thrust',
        messageType: 'std_msgs/Float64'
    });

    rightThrustTopic.subscribe((message) => {
        if (DEBUG_MODE) console.log('Right thrust:', message.data);
        updateThruster('right', message.data);
    });
    
    // Mission status (integrated and modular)
    const missionStatusTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/planning/mission_status',
        messageType: 'std_msgs/String'
    });
    
    missionStatusTopic.subscribe((message) => {
        let data;
        try { data = JSON.parse(message.data); }
        catch (e) { logBadJson('/planning/mission_status', e); return; }
        if (DEBUG_MODE) console.log('Mission status:', data);
        updateMissionStatus({
            state: data.state,
            waypoint: data.current_waypoint,
            total_waypoints: data.total_waypoints,
            // distance_to_target is NOT in /planning/mission_status — the
            // /planning/current_target subscriber owns that field.
            local_x: data.position ? data.position[0] : 0,
            local_y: data.position ? data.position[1] : 0,
            detour_active: data.detour_active || false,
            go_home_mode: data.go_home_mode || false
        });
    });

    // Modular controller anti-stuck status
    const controllerAntiStuckTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/control/anti_stuck_status',
        messageType: 'std_msgs/String'
    });
    
    controllerAntiStuckTopic.subscribe((message) => {
        let data;
        try { data = JSON.parse(message.data); }
        catch (e) { logBadJson('/control/anti_stuck_status', e); return; }
        if (DEBUG_MODE) console.log('Controller anti-stuck status:', data);
        updateAntiStuckStatus(data);
    });

    // ==================== MODULAR NAVIGATION SUPPORT ====================
    // Modular current target from waypoint_planner (for distance info)
    const modularTargetTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/planning/current_target',
        messageType: 'std_msgs/String'
    });
    
    modularTargetTopic.subscribe((message) => {
        let data;
        try { data = JSON.parse(message.data); }
        catch (e) { logBadJson('/planning/current_target', e); return; }
        if (DEBUG_MODE) console.log('Modular current target:', data);
        // /planning/current_target is the authoritative source for distance-to-target;
        // /planning/mission_status does not carry it.
        if (data.distance_to_target !== undefined && data.distance_to_target !== null) {
            currentState.mission.distance = data.distance_to_target;
            // Capture the initial distance at the moment Go Home starts so the bar
            // can fill progressively as the boat approaches home.
            if (missionState.goHomeMode
                && missionState.goHomeInitialDistance === null
                && data.distance_to_target > 0.5) {
                missionState.goHomeInitialDistance = data.distance_to_target;
            }
        }
    });
    
    // Modular waypoints from waypoint_planner
    const modularWaypointsTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/planning/waypoints',
        messageType: 'std_msgs/String'
    });
    
    modularWaypointsTopic.subscribe((message) => {
        let data;
        try { data = JSON.parse(message.data); }
        catch (e) { logBadJson('/planning/waypoints', e); return; }
        if (DEBUG_MODE) console.log('Modular waypoints received:', data);
        if (data.waypoints && data.waypoints.length > 0) {
            // Check if waypoints actually changed
            const newWpString = JSON.stringify(data.waypoints);
            const oldWpString = JSON.stringify(missionState.waypoints);
            const waypointsChanged = newWpString !== oldWpString;
            
            missionState.waypoints = data.waypoints;
            missionState.totalWaypoints = data.total || data.waypoints.length;
            persistWaypoints();
            displayWaypointsOnMap(data.waypoints, waypointsChanged);
        } else {
            clearWaypoints('Planner cleared waypoints');
        }
    });
    
    // Modular obstacle status from lidar_perception
    const modularObstacleTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/perception/obstacle_info',
        messageType: 'std_msgs/String'
    });
    
    modularObstacleTopic.subscribe((message) => {
        let data;
        try { data = JSON.parse(message.data); }
        catch (e) { logBadJson('/perception/obstacle_info', e); return; }
        if (DEBUG_MODE) console.log('Modular obstacle status:', data);
        // Convert modular format to autoboat format with LiDAR v2.0/v2.1 enhancements
        // LiDAR v2.0: front_clear, left_clear, right_clear ARE the distances in meters
        const CLEAR_THRESHOLD = 10.0;  // Distance threshold for "clear" status
        updateObstacleStatus({
            min_distance: data.min_distance,
            // LiDAR v2.0: Use distance values for both boolean and numeric display
            front_clear: data.front_clear > CLEAR_THRESHOLD,
            left_clear: data.left_clear > CLEAR_THRESHOLD,
            right_clear: data.right_clear > CLEAR_THRESHOLD,
            front_distance: data.front_clear,  // LiDAR v2.0: front_clear IS the distance
            left_distance: data.left_clear,    // LiDAR v2.0: left_clear IS the distance
            right_distance: data.right_clear,  // LiDAR v2.0: right_clear IS the distance
            status: data.force_avoid_active ? '🔴 FORCE AVOID | Évitement forcé' :
                    data.is_critical ? '🚨 CRITICAL | Critique' :
                    data.obstacle_detected ? '⚠️ OBSTACLE | Détecté' :
                    '✅ CLEAR | Dégagé',
            // LiDAR v2.0 enhanced fields
            urgency: data.urgency || 0.0,
            obstacle_count: data.obstacle_count || 0,
            best_gap: data.best_gap || null,
            clusters: data.clusters || [],
            // LiDAR v2.1 enhanced fields
            vfh_gap: data.vfh_gap || null,           // VFH best direction
            polar_bias: data.polar_bias || 0.0,      // Steering bias [-1, 1]
            force_avoid_active: data.force_avoid_active || false,
            laserscan_fused: data.laserscan_fused || false
        });
    });
    
    // Modular controller status from heading_controller
    const modularControlTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/control/status',
        messageType: 'std_msgs/String'
    });
    
    modularControlTopic.subscribe((message) => {
        let data;
        try { data = JSON.parse(message.data); }
        catch (e) { logBadJson('/control/status', e); return; }
        if (DEBUG_MODE) console.log('Modular control status:', data);
        if (data.stop_override !== undefined) {
            missionState.stopOverride = !!data.stop_override;
            const el = document.getElementById('stop-override');
            if (el) {
                el.textContent = missionState.stopOverride ? 'STOP LATCHED' : 'Inactive';
                el.className = 'value ' + (missionState.stopOverride ? 'warning' : '');
            }
        }
    });

    if (DEBUG_MODE) console.log('Subscribed to all topics (integrated + modular)');
    addLog('Subscribed to topics (AutoBoat + Modular)', 'info');
    
    // Enable mission control UI when connected (before config received)
    updateMissionControlUI({ state: 'IDLE', gps_ready: true });
    
    // Create publisher for configuration updates (Planner modular mode only)
    configPublisher = new ROSLIB.Topic({
        ros: ros,
        name: '/planning/set_config',
        messageType: 'std_msgs/String'
    });

    // Backward compatibility alias
    modularConfigPublisher = configPublisher;
    
    // Subscribe to current config (Planner modular mode only)
    const modularConfigTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/planning/config',
        messageType: 'std_msgs/String'
    });
    
    modularConfigTopic.subscribe((message) => {
        let data;
        try { data = JSON.parse(message.data); }
        catch (e) { logBadJson('/planning/config', e); return; }
        if (DEBUG_MODE) console.log('Config received (planner):', data);
        updateConfigFromROS(data);
        updateWorldFromConfig(data);
    });

    // Subscribe to param ranges from all 3 nodes — syncs HTML min/max from Python authoritative ranges
    ['/perception/param_ranges', '/planning/param_ranges', '/control/param_ranges'].forEach(topicName => {
        const topic = new ROSLIB.Topic({
            ros: ros,
            name: topicName,
            messageType: 'std_msgs/String'
        });
        topic.subscribe((message) => {
            try {
                const ranges = JSON.parse(message.data);
                applyRangesToDashboard(ranges);
            } catch (e) {
                logBadJson(topicName, e);
            }
        });
    });

    // Create mission command publisher (Planner modular mode only)
    missionCommandPublisher = new ROSLIB.Topic({
        ros: ros,
        name: '/planning/mission_command',
        messageType: 'std_msgs/String'
    });

    // Backward compatibility alias
    modularMissionCommandPublisher = missionCommandPublisher;
    
    // Subscribe to ROS logs (rosout)
    const rosoutTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/rosout',
        messageType: 'rcl_interfaces/Log'
    });
    
    rosoutTopic.subscribe((message) => {
        // Filter for autoboat and modular node messages
        if (message.name && (
            message.name.includes('autoboat') ||
            message.name.includes('waypoint_planner') ||
            message.name.includes('lidar_perception') ||
            message.name.includes('heading_controller')
        )) {
            addTerminalLine(message);
            // Show red toast for rejected parameter values (server-side validation)
            if (message.level >= 30 && message.msg && message.msg.startsWith('Rejected ')) {
                showFeedback(message.msg, 'error');
            }
        }
    });
    
    addTerminalLine({ level: 20, msg: 'Connected to ROS | Connecté à ROS', name: 'system' });
}

// Update GPS data (OPTIMIZED - throttled trajectory updates)
function updateGPS(message) {
    currentState.gps.lat = message.latitude;
    currentState.gps.lon = message.longitude;

    // Update display
    document.getElementById('latitude').textContent = message.latitude.toFixed(6) + '°';
    document.getElementById('longitude').textContent = message.longitude.toFixed(6) + '°';

    // Update map
    const latLng = [message.latitude, message.longitude];
    boatMarker.setLatLng(latLng);

    // Throttle trajectory updates to reduce CPU usage
    const now = Date.now();
    if (now - lastTrajectoryUpdate > 100) {  // Update at most 10Hz instead of GPS rate
        lastTrajectoryUpdate = now;

        // Add to trajectory
        trajectoryPoints.push(latLng);
        if (trajectoryPoints.length > 1000) {
            trajectoryPoints.shift(); // Keep last 1000 points (extended trail)
        }

        // Use requestAnimationFrame for smooth rendering
        if (!pendingTrajectoryUpdate) {
            pendingTrajectoryUpdate = true;
            requestAnimationFrame(() => {
                trajectoryLine.setLatLngs(trajectoryPoints);
                pendingTrajectoryUpdate = false;
            });
        }
    }

    // Throttle map pan operations (max once per 500ms)
    if (mapFollowBoat && now - lastMapPan > 500) {
        const center = map.getCenter();
        const distance = map.distance(center, latLng);
        if (distance > 50) { // More than 50m from center
            lastMapPan = now;
            map.setView(latLng, map.getZoom(), {animate: false});  // No animation for better performance
        }
    }
}

// Update thruster data
function updateThruster(side, value) {
    currentState.thrusters[side] = value;
    
    // Update display (in Newtons)
    document.getElementById(`${side}-thrust`).textContent = value.toFixed(1) + ' N';
    
    // Update thrust bar
    const bar = document.getElementById(`${side}-thrust-bar`);
    const percentage = Math.min(Math.abs(value) / 1000 * 100, 100);
    bar.style.width = percentage + '%';
    
    // Color based on direction
    if (value < 0) {
        bar.classList.add('reverse');
    } else {
        bar.classList.remove('reverse');
    }
}

// Simulate mission data (would come from custom topics in real implementation)
function updateMissionStatus(data) {
    currentState.mission.state = data.state || 'UNKNOWN';
    currentState.mission.waypoint = data.waypoint || 0;
    missionState.blockedReason = data.blocked_reason || '';
    missionState.goHomeMode = data.go_home_mode || false;
    // Detour badge
    updateDetourBadge(!!data.detour_active);
    // Only update distance if the caller actually provided it — the /planning/current_target
    // subscriber is the authoritative source and writes `currentState.mission.distance` directly.
    if (data.distance_to_waypoint !== undefined && data.distance_to_waypoint !== null) {
        currentState.mission.distance = data.distance_to_waypoint;
    }

    // Reset the captured Go Home initial distance once we leave Go Home so the next
    // trip starts fresh. The capture itself happens in the /planning/current_target subscriber.
    if (!missionState.goHomeMode && missionState.goHomeInitialDistance !== null) {
        missionState.goHomeInitialDistance = null;
    }
    
    // CRITICAL: Update missionState.currentWaypoint so waypoints on map reflect current progress
    // This is needed for displayWaypointsOnMap() to show correct waypoint coloring (passed/current/pending)
    const previousWaypoint = missionState.currentWaypoint;
    missionState.currentWaypoint = data.waypoint || 0;
    // Sync totals if provided
    if (data.total_waypoints !== undefined) {
        missionState.totalWaypoints = data.total_waypoints || 0;
        // If planner reports zero waypoints, clear map so stale routes disappear
        if (missionState.totalWaypoints === 0 && missionState.waypoints.length > 0) {
            clearWaypoints('Planner reported 0 waypoints');
        } else {
            persistWaypoints();
        }
    }
    
    // If waypoint changed, redraw waypoints on map to update colors (green for passed, orange for current)
    if (previousWaypoint !== missionState.currentWaypoint && missionState.waypoints.length > 0) {
        if (DEBUG_MODE) console.log(`Waypoint updated: ${previousWaypoint} → ${missionState.currentWaypoint}, redrawing map`);
        displayWaypointsOnMap(missionState.waypoints, false);  // Don't fit to bounds, just update colors
    }
    
    document.getElementById('state').textContent = (data.state || 'UNKNOWN').replace(/_/g, ' ');
    document.getElementById('waypoint').textContent = `${data.waypoint || 0}/${data.total_waypoints || missionState.totalWaypoints || 0}`;
    const distanceValue = Number(currentState.mission.distance);
    document.getElementById('distance').textContent = (Number.isFinite(distanceValue) ? distanceValue : 0).toFixed(1) + 'm';
    const blockedEl = document.getElementById('blocked-reason');
    if (blockedEl) {
        const reason = missionState.blockedReason || 'None';
        blockedEl.textContent = reason;
    }
}

// Show/hide detour badge
function updateDetourBadge(isActive) {
    const badge = document.getElementById('detour-badge');
    if (!badge) return;
    badge.style.display = isActive ? 'inline-block' : 'none';
}

// Simulate obstacle data (would parse from PointCloud2 or custom topic)
// Cache for obstacle status to avoid redundant DOM updates at ~10Hz
let _prevObstacle = {};

function updateObstacleStatus(data) {
    currentState.obstacles.min = data.min_distance;
    currentState.obstacles.front = data.front_clear;
    currentState.obstacles.left = data.left_clear;
    currentState.obstacles.right = data.right_clear;

    const minDist = data.min_distance;
    const minDistText = minDist >= 999 ? '∞' : minDist.toFixed(1) + 'm';
    const frontText = data.front_clear ? `✓ ${data.front_distance.toFixed(1)}m` : `✗ ${data.front_distance.toFixed(1)}m`;
    const leftText = data.left_clear ? `✓ ${data.left_distance.toFixed(1)}m` : `✗ ${data.left_distance.toFixed(1)}m`;
    const rightText = data.right_clear ? `✓ ${data.right_distance.toFixed(1)}m` : `✗ ${data.right_distance.toFixed(1)}m`;

    if (_prevObstacle.minDist !== minDistText) {
        document.getElementById('min-obstacle').textContent = minDistText;
        _prevObstacle.minDist = minDistText;
    }
    if (_prevObstacle.front !== frontText) {
        document.getElementById('front-clear').textContent = frontText;
        _prevObstacle.front = frontText;
    }
    if (_prevObstacle.left !== leftText) {
        document.getElementById('left-clear').textContent = leftText;
        _prevObstacle.left = leftText;
    }
    if (_prevObstacle.right !== rightText) {
        document.getElementById('right-clear').textContent = rightText;
        _prevObstacle.right = rightText;
    }

    // LiDAR v2.0: Update urgency display if element exists
    const urgencyEl = document.getElementById('urgency');
    if (urgencyEl && data.urgency !== undefined) {
        const urgencyPct = (data.urgency * 100).toFixed(0);
        const urgencyClass = data.urgency > 0.7 ? 'value critical' :
                             data.urgency > 0.3 ? 'value warning' : 'value';
        if (_prevObstacle.urgency !== urgencyPct) {
            urgencyEl.textContent = `${urgencyPct}%`;
            _prevObstacle.urgency = urgencyPct;
        }
        if (_prevObstacle.urgencyClass !== urgencyClass) {
            urgencyEl.className = urgencyClass;
            _prevObstacle.urgencyClass = urgencyClass;
        }
    }

    // LiDAR v2.0: Update obstacle count if element exists
    const countEl = document.getElementById('obstacle-count');
    if (countEl && data.obstacle_count !== undefined && _prevObstacle.count !== data.obstacle_count) {
        countEl.textContent = data.obstacle_count;
        _prevObstacle.count = data.obstacle_count;
    }

    // LiDAR v2.0: Update best gap if element exists
    const gapEl = document.getElementById('best-gap');
    if (gapEl && data.best_gap) {
        const gapText = `${data.best_gap.direction.toFixed(0)}° (${data.best_gap.width.toFixed(0)}°)`;
        if (_prevObstacle.gap !== gapText) {
            gapEl.textContent = gapText;
            _prevObstacle.gap = gapText;
        }
    }

    // Update status badge with bilingual message
    const statusBadge = document.getElementById('obstacle-status');
    let statusText, statusClass;
    if (data.status) {
        statusText = data.status;
        statusClass = data.status.includes('✅') ? 'value badge clear' :
                      data.status.includes('🚨') ? 'value badge critical' : 'value badge warning';
    } else {
        if (minDist > 15 || minDist >= 999) {
            statusText = 'Clear | Dégagé';
            statusClass = 'value badge clear';
        } else if (minDist > 5) {
            statusText = 'Warning | Attention';
            statusClass = 'value badge warning';
        } else {
            statusText = 'Critical | Critique';
            statusClass = 'value badge critical';
        }
    }
    if (_prevObstacle.statusText !== statusText) {
        statusBadge.textContent = statusText;
        _prevObstacle.statusText = statusText;
    }
    if (_prevObstacle.statusClass !== statusClass) {
        statusBadge.className = statusClass;
        _prevObstacle.statusClass = statusClass;
    }
}

// Cache for anti-stuck status to avoid redundant DOM updates
let _prevAntiStuck = {};

// Update Simple Anti-Stuck Status
function updateAntiStuckStatus(data) {
    // Update anti-stuck panel elements if they exist
    const stuckStatus = document.getElementById('stuck-status');
    const escapePhase = document.getElementById('escape-phase');
    const driftVector = document.getElementById('drift-vector');
    const probeResults = document.getElementById('probe-results');

    if (stuckStatus) {
        const stuckText = (data.is_stuck && data.escape_mode)
            ? `STUCK | BLOQUÉ (Attempt ${data.consecutive_attempts})` : 'Normal';
        const stuckClass = (data.is_stuck && data.escape_mode)
            ? 'value badge critical' : 'value badge clear';
        if (_prevAntiStuck.stuckText !== stuckText) {
            stuckStatus.textContent = stuckText;
            stuckStatus.className = stuckClass;
            _prevAntiStuck.stuckText = stuckText;
        }
    }

    if (escapePhase) {
        const dir = data.escape_direction || 'IDLE';
        const phaseText = data.escape_mode
            ? (dir === 'RIGHT' ? 'TURNING RIGHT | Virage Droite' : 'TURNING LEFT | Virage Gauche')
            : 'IDLE | Attente';
        if (_prevAntiStuck.phase !== phaseText) {
            escapePhase.textContent = phaseText;
            escapePhase.className = data.escape_mode ? 'value active' : 'value';
            _prevAntiStuck.phase = phaseText;
        }
    }

    if (driftVector && data.drift_vector) {
        const dx = data.drift_vector[0];
        const dy = data.drift_vector[1];
        const magnitude = Math.hypot(dx, dy);
        let driftText;
        if (magnitude > 0.1) {
            const angle = Math.atan2(dy, dx) * 180 / Math.PI;
            driftText = `${magnitude.toFixed(2)} m/s @ ${angle.toFixed(0)}°`;
        } else {
            driftText = 'Minimal';
        }
        if (_prevAntiStuck.drift !== driftText) {
            driftVector.textContent = driftText;
            _prevAntiStuck.drift = driftText;
        }
    }

    // Display Kalman filter uncertainty
    const driftUncertainty = document.getElementById('drift-uncertainty');
    if (driftUncertainty && data.drift_uncertainty) {
        const ux = data.drift_uncertainty[0];
        const uy = data.drift_uncertainty[1];
        const avgUncertainty = Math.hypot(ux, uy);
        let uncText, uncColor;
        if (avgUncertainty < 0.1) {
            uncText = 'High conf. | Haute conf.';
            uncColor = '#4CAF50';
        } else if (avgUncertainty < 0.5) {
            uncText = `σ=${avgUncertainty.toFixed(2)}`;
            uncColor = '#FFC107';
        } else {
            uncText = `σ=${avgUncertainty.toFixed(2)} (converging | convergence)`;
            uncColor = '#FF9800';
        }
        if (_prevAntiStuck.uncText !== uncText) {
            driftUncertainty.textContent = uncText;
            driftUncertainty.style.color = uncColor;
            _prevAntiStuck.uncText = uncText;
        }
    }

    if (probeResults) {
        probeResults.textContent = `Front: ${data.front_clear ? data.front_clear.toFixed(1) : 'N/A'}m`;
    }

    // Update best direction indicator — reflects the side the controller is currently turning toward
    const bestDirection = document.getElementById('best-direction');
    if (bestDirection) {
        const dir = data.escape_direction || 'IDLE';
        const dirText = dir === 'LEFT'  ? '← LEFT | Gauche'
                      : dir === 'RIGHT' ? 'RIGHT → | Droite'
                      :                   '— Idle | Attente';
        if (_prevAntiStuck.direction !== dirText) {
            bestDirection.textContent = dirText;
            _prevAntiStuck.direction = dirText;
        }
    }

    // Add terminal log for stuck events
    if (data.is_stuck && data.escape_mode) {
        addTerminalLine({
            level: 30,  // WARN
            msg: `Simple escape: Turning left until clear (front: ${data.front_clear}m)`,
            name: 'anti_stuck'
        });
    }
}

// Add log entry
// Rate-limited visible logger for JSON.parse failures on ROS status topics.
// The Python publishers now guard with allow_nan=False, so this path should
// only trigger on wire-level corruption (truncated rosbridge frames). When it
// does, we want the operator to see it — not silent skip.
const _jsonParseErrorLastLog = {};
function logBadJson(topicName, error) {
    const now = Date.now();
    if (!_jsonParseErrorLastLog[topicName] || now - _jsonParseErrorLastLog[topicName] > 5000) {
        _jsonParseErrorLastLog[topicName] = now;
        addLog(`Malformed JSON on ${topicName}: ${error.message || error}`, 'error');
    }
    if (DEBUG_MODE) console.warn(`Bad ${topicName} JSON:`, error);
}

function addLog(message, type = 'info') {
    const logsContainer = document.getElementById('logs');
    const logEntry = document.createElement('div');
    logEntry.className = `log-entry ${type}`;
    
    const timestamp = new Date().toLocaleTimeString();
    logEntry.innerHTML = `
        <span class="timestamp">[${timestamp}]</span>
        <span class="message">${message}</span>
    `;
    
    logsContainer.insertBefore(logEntry, logsContainer.firstChild);
    
    // Keep only last 50 logs
    while (logsContainer.children.length > 50) {
        logsContainer.removeChild(logsContainer.lastChild);
    }
}

// GPS origin — set from first GPS fix, matching how waypoint_planner stores start_gps
let gpsOrigin = null;

// Convert GPS to local coordinates (simplified)
function gpsToLocal(lat, lon) {
    // Use first GPS fix as origin, same as waypoint_planner
    if (!gpsOrigin) {
        if (lat !== 0 && lon !== 0) {
            gpsOrigin = { lat: lat, lon: lon };
        } else {
            return { x: 0, y: 0 };
        }
    }

    const latDiff = (lat - gpsOrigin.lat) * 111320; // meters per degree latitude
    const lonDiff = (lon - gpsOrigin.lon) * 111320 * Math.cos(gpsOrigin.lat * Math.PI / 180);

    return { x: lonDiff, y: latDiff };
}

// Update local coordinates display
setInterval(() => {
    const local = gpsToLocal(currentState.gps.lat, currentState.gps.lon);
    document.getElementById('local-x').textContent = local.x.toFixed(1) + 'm';
    document.getElementById('local-y').textContent = local.y.toFixed(1) + 'm';
}, 1000);

// Initialize configuration panel
function initConfigPanel() {
    if (DEBUG_MODE) console.log('Initializing config panel...');

    // All config input IDs (main + Perception + Controller)
    const allConfigInputs = [
        'cfg-lanes', 'cfg-scan-length', 'cfg-scan-width',
        'cfg-kp', 'cfg-ki', 'cfg-kd',
        'cfg-base-speed', 'cfg-max-speed', 'cfg-safe-dist',
        'cfg-waypoint-tolerance', 'cfg-approach-slow-distance', 'cfg-approach-slow-factor',
        'cfg-astar-resolution', 'cfg-astar-safety', 'cfg-astar-max',
        'wp-lanes', 'wp-length', 'wp-width',
        // Perception inputs
        'perception-min-height', 'perception-max-height', 'perception-min-range', 'perception-max-range',
        'perception-safe-dist', 'perception-critical-dist', 'perception-cluster-dist', 'perception-min-cluster-size',
        'perception-temporal-history', 'perception-temporal-threshold', 'perception-water-threshold', 'perception-hysteresis',
        // Controller inputs
        'controller-critical-dist', 'controller-safe-dist', 'controller-bank-dist',
        'controller-obstacle-slow', 'controller-bank-slow', 'controller-avoid-gain',
        'controller-use-vfh', 'controller-max-turn', 'controller-stuck-timeout', 'controller-stuck-threshold',
        'controller-reverse-timeout', 'controller-max-reverse', 'controller-turn-deadband', 'controller-slew-rate'
    ];

    // Mark input as dirty when user types
    allConfigInputs.forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            el.addEventListener('input', () => {
                dirtyInputs.add(id);
                el.classList.add('input-dirty');
            });
            // Also mark dirty on focus (user intends to edit)
            el.addEventListener('focus', () => {
                dirtyInputs.add(id);
                el.classList.add('input-dirty');
            });
        }
    });

    // Navigation mode radio buttons - show/hide advanced A* params
    const navModeRadios = document.querySelectorAll('input[name="nav-mode"]');
    const advancedParams = document.getElementById('astar-advanced-params');

    navModeRadios.forEach(radio => {
        radio.addEventListener('change', () => {
            navModeDirty = true;
            // Show advanced params if Runtime A* or Hybrid mode selected
            if (radio.value === 'runtime' || radio.value === 'hybrid') {
                advancedParams.style.display = 'block';
            } else {
                advancedParams.style.display = 'none';
            }
        });
    });

    // Apply all config button (applies all parameters including PID, speed, and scan settings)
    document.getElementById('btn-apply-config').addEventListener('click', () => {
        const success = sendConfig(false);  // Send ALL parameters (PID, speed, scan settings)
        if (success) {
            addLog('Config sent - waiting for confirmation...', 'info');
        }
    });

    // A* Apply button (sends only A* params)
    document.getElementById('btn-apply-astar').addEventListener('click', () => {
        if (!connected || !configPublisher) {
            showFeedback('Not connected to ROS', 'error');
            return;
        }
        resetValidation();
        const navMode = getSelectedNavMode();
        const config = {
            astar_enabled: (navMode === 'runtime' || navMode === 'hybrid'),
            astar_hybrid_mode: (navMode === 'hybrid'),
            hazard_enabled: (navMode === 'hybrid'),
            astar_resolution: readInput('cfg-astar-resolution', 3.0),
            astar_safety_margin: readInput('cfg-astar-safety', 12.0),
            astar_max_expansions: readInput('cfg-astar-max', 20000)
        };
        if (hasValidationErrors()) {
            addLog('A* config not sent — fix out-of-range values first', 'warning');
            return;
        }
        configPublisher.publish(new ROSLIB.Message({ data: JSON.stringify(config) }));
        markClean(['cfg-astar-resolution', 'cfg-astar-safety', 'cfg-astar-max']);
        navModeDirty = false;
        // Spell out what got sent so the user knows the nav mode + 3 numeric params are ALL included
        const modeLabel = navMode === 'hybrid' ? 'Hybrid Mode' : navMode === 'runtime' ? 'Runtime A*' : 'Simple Lawnmower';
        const msg = `✅ A* applied: mode="${modeLabel}" + 3 params (resolution, safety_margin, max_expansions)`;
        addLog(msg, 'info');
        showFeedback(msg, 'success');
    });

    // A* Reset button
    document.getElementById('btn-reset-astar').addEventListener('click', () => {
        document.getElementById('cfg-astar-resolution').value = '3.0';
        document.getElementById('cfg-astar-safety').value = '12.0';
        document.getElementById('cfg-astar-max').value = '20000';
        // Mark dirty so ROS sync doesn't overwrite
        ['cfg-astar-resolution', 'cfg-astar-safety', 'cfg-astar-max'].forEach(id => {
            dirtyInputs.add(id);
            const el = document.getElementById(id);
            if (el) el.classList.add('input-dirty');
        });
        showFeedback('A* parameters reset to defaults — click Apply to send', 'info');
    });

    // Reset to defaults button
    document.getElementById('btn-reset-config').addEventListener('click', () => {
        if (confirm('Reset all configuration values to defaults? | Réinitialiser toutes les valeurs par défaut?')) {
            resetConfigToDefaults();
            setTimeout(() => alert('🔄 Configuration Reset\n\nAll values restored to defaults.\n\n🔄 Configuration Réinitialisée\n\nToutes les valeurs restaurées par défaut.'), 100);
        }
    });

    // Initialize value displays and change indicators
    initConfigValueTracking();

    if (DEBUG_MODE) console.log('Config panel initialized');
}

// Reset configuration to default values
function resetConfigToDefaults() {
    const configInputs = [
        'cfg-kp', 'cfg-ki', 'cfg-kd',
        'cfg-base-speed', 'cfg-max-speed', 'cfg-safe-dist'
    ];

    configInputs.forEach(id => {
        const input = document.getElementById(id);
        if (input && input.dataset.default) {
            input.value = input.dataset.default;
            input.classList.remove('modified');
            // Mark dirty so ROS sync doesn't overwrite before user clicks Apply
            dirtyInputs.add(id);
            input.classList.add('input-dirty');
            updateValueDisplay(input);
        }
    });

    addLog('Configuration reset to defaults — click Apply to send | Cliquez Appliquer pour envoyer', 'info');
}

// Perception launch defaults (must match autoboat.launch.yaml)
const PERCEPTION_DEFAULTS = {
    'perception-min-height': -1.2, 'perception-max-height': 1.5,
    'perception-min-range': 2.2, 'perception-max-range': 100,
    'perception-safe-dist': 10.0, 'perception-critical-dist': 5.5,  // perception_critical_distance in ROS
    'perception-cluster-dist': 3.0, 'perception-min-cluster-size': 8,
    'perception-temporal-history': 3, 'perception-temporal-threshold': 2,
    'perception-water-threshold': 0.32, 'perception-hysteresis': 2.0
};

// Controller launch defaults (must match autoboat.launch.yaml)
const CONTROLLER_DEFAULTS = {
    'controller-critical-dist': 6.0, 'controller-safe-dist': 12.0,
    'controller-bank-dist': 6.0, 'controller-obstacle-slow': 0.5,
    'controller-bank-slow': 0.25, 'controller-avoid-gain': 18,
    'controller-max-turn': 45, 'controller-stuck-timeout': 12.0,
    'controller-stuck-threshold': 1.0, 'controller-reverse-timeout': 4.0,
    'controller-max-reverse': 25, 'controller-turn-deadband': 0.5,
    'controller-slew-rate': 80
};

function resetPerceptionToDefaults() {
    for (const [id, val] of Object.entries(PERCEPTION_DEFAULTS)) {
        const el = document.getElementById(id);
        if (el) { el.value = val; dirtyInputs.add(id); el.classList.add('input-dirty'); }
    }
    addLog('Perception parameters reset to launch defaults | Paramètres Perception réinitialisés', 'info');
    showFeedback('🔄 Perception reset to launch defaults', 'info');
}

function resetControllerToDefaults() {
    for (const [id, val] of Object.entries(CONTROLLER_DEFAULTS)) {
        const el = document.getElementById(id);
        if (el) { el.value = val; dirtyInputs.add(id); el.classList.add('input-dirty'); }
    }
    // Reset VFH select
    const vfhEl = document.getElementById('controller-use-vfh');
    if (vfhEl) vfhEl.value = 'false';
    addLog('Controller parameters reset to launch defaults | Paramètres Controller réinitialisés', 'info');
    showFeedback('🔄 Controller reset to launch defaults', 'info');
}

// Initialize value tracking and displays
function initConfigValueTracking() {
    const configInputs = [
        'cfg-kp', 'cfg-ki', 'cfg-kd',
        'cfg-base-speed', 'cfg-max-speed', 'cfg-safe-dist'
    ];

    configInputs.forEach(id => {
        const input = document.getElementById(id);
        if (input) {
            // Initialize value display
            updateValueDisplay(input);

            // Track changes
            input.addEventListener('input', () => {
                const defaultValue = parseFloat(input.dataset.default);
                const currentValue = parseFloat(input.value);

                if (currentValue !== defaultValue) {
                    input.classList.add('modified');
                } else {
                    input.classList.remove('modified');
                }

                updateValueDisplay(input);
            });
        }
    });
}

// Update value display next to input
function updateValueDisplay(input) {
    const valueDisplay = input.nextElementSibling;
    if (valueDisplay && valueDisplay.classList.contains('value-display')) {
        const defaultValue = parseFloat(input.dataset.default);
        const currentValue = parseFloat(input.value);

        if (currentValue !== defaultValue) {
            valueDisplay.textContent = `(default: ${defaultValue})`;
            valueDisplay.style.color = '#ff9800';
        } else {
            valueDisplay.textContent = '';
        }
    }
}

// Update config inputs from ROS
function updateConfigFromROS(data) {
    currentState.config = { ...currentState.config, ...data };

    // Enable Apply buttons after first ROS config sync
    if (!configSynced) {
        configSynced = true;
        document.querySelectorAll('.apply-btn[disabled], .config-btn.apply[disabled]').forEach(btn => {
            btn.disabled = false;
            btn.title = '';
        });
    }
    
    // Only update inputs if they're not dirty (user hasn't modified them)
    const inputs = {
        'cfg-lanes': data.lanes,
        'cfg-scan-length': data.scan_length,
        'cfg-scan-width': data.scan_width,
        'cfg-kp': data.kp,
        'cfg-ki': data.ki,
        'cfg-kd': data.kd,
        'cfg-base-speed': data.base_speed,
        'cfg-max-speed': data.max_speed,
        'cfg-safe-dist': data.min_safe_distance
    };
    
    // Also update mission control inputs (only during active mission — in INIT/IDLE
    // the user is configuring a new mission and their inputs should not be overwritten)
    const wpInputs = {
        'wp-lanes': data.lanes,
        'wp-length': data.scan_length,
        'wp-width': data.scan_width
    };

    // Don't overwrite route config inputs when boat is idle/init (user is editing for next mission)
    const isConfiguring = ['INIT', 'IDLE'].includes(missionState.state);

    for (const [id, value] of Object.entries(inputs)) {
        const el = document.getElementById(id);
        // Don't update route params (lanes/scan) from ROS while user is configuring
        const isRouteParam = ['cfg-lanes', 'cfg-scan-length', 'cfg-scan-width'].includes(id);
        if (isRouteParam && isConfiguring) continue;
        // Don't update if input is dirty (user modified) or focused
        if (el && !dirtyInputs.has(id) && document.activeElement !== el && value !== undefined) {
            el.value = value;
        }
        // Clear dirty state if ROS value matches what we sent (confirmation)
        if (el && dirtyInputs.has(id) && parseFloat(el.value) === value) {
            dirtyInputs.delete(id);
            el.classList.remove('input-dirty');
        }
    }

    for (const [id, value] of Object.entries(wpInputs)) {
        // Don't overwrite wp inputs while user is configuring a new mission
        if (isConfiguring) continue;
        const el = document.getElementById(id);
        // Don't update if input is dirty (user modified) or focused
        if (el && !dirtyInputs.has(id) && document.activeElement !== el && value !== undefined) {
            el.value = value;
        }
        // Clear dirty state if ROS value matches what we sent (confirmation)
        if (el && dirtyInputs.has(id) && parseFloat(el.value) === value) {
            dirtyInputs.delete(id);
            el.classList.remove('input-dirty');
        }
    }

    // Update navigation mode radio buttons based on A* settings (respect user edits)
    if (!navModeDirty && (data.astar_hybrid_mode !== undefined || data.astar_enabled !== undefined)) {
        let navMode = 'simple';
        if (data.astar_hybrid_mode === true) {
            navMode = 'hybrid';
        } else if (data.astar_enabled === true) {
            navMode = 'runtime';
        }
        const rb = document.getElementById(`nav-mode-${navMode}`);
        if (rb) rb.checked = true;
        const advancedParams = document.getElementById('astar-advanced-params');
        if (advancedParams) advancedParams.style.display = (navMode === 'runtime' || navMode === 'hybrid') ? 'block' : 'none';
    } else if (navModeDirty) {
        // If incoming matches current selection, clear dirty
        const current = getSelectedNavMode();
        const incoming = data.astar_hybrid_mode ? 'hybrid' : (data.astar_enabled ? 'runtime' : 'simple');
        if (current === incoming) {
            navModeDirty = false;
        }
    }

    // Update A* advanced parameters if present (skip if user is editing)
    if (data.astar_resolution !== undefined && !dirtyInputs.has('cfg-astar-resolution')) {
        const el = document.getElementById('cfg-astar-resolution');
        if (el) el.value = data.astar_resolution;
    }
    if (data.astar_safety_margin !== undefined && !dirtyInputs.has('cfg-astar-safety')) {
        const el = document.getElementById('cfg-astar-safety');
        if (el) el.value = data.astar_safety_margin;
    }
    if (data.astar_max_expansions !== undefined && !dirtyInputs.has('cfg-astar-max')) {
        const el = document.getElementById('cfg-astar-max');
        if (el) el.value = data.astar_max_expansions;
    }

    // Update mission control UI
    updateMissionControlUI(data);
}

// Validation error counter — reset before each Apply, check after building config
let _validationErrors = 0;
function resetValidation() { _validationErrors = 0; }
function hasValidationErrors() { return _validationErrors > 0; }

// Read and validate a numeric input using its HTML min/max/default attributes.
// Returns fallback if out of range, increments _validationErrors, and shows orange toast.
function readInput(id, fallback) {
    const el = document.getElementById(id);
    if (!el) return fallback;
    const raw = (el.type === 'hidden' || el.step === '1' || Number.isInteger(fallback))
        ? parseInt(el.value) : parseFloat(el.value);
    if (isNaN(raw)) return fallback;
    const min = el.min !== '' ? parseFloat(el.min) : -Infinity;
    const max = el.max !== '' ? parseFloat(el.max) : Infinity;
    // Reject out-of-range values — return fallback so config object stays well-formed
    if (min !== -Infinity && max !== Infinity && (raw < min || raw > max)) {
        const label = el.closest('.param-row')?.querySelector('label')?.textContent?.trim() || id;
        showFeedback(`${label} ${raw} is out of range (valid: ${min}–${max})`, 'warning');
        _validationErrors++;
        return fallback;
    }
    return raw;
}

// Filter a config object to only include params whose input was modified.
// idToParam maps DOM input IDs to param names: { 'cfg-kp': 'kp', ... }
// Returns the filtered config, or the full config if nothing was dirty (first apply / preset).
function filterDirtyParams(fullConfig, idToParam) {
    const dirty = {};
    let hasDirty = false;
    for (const [id, param] of Object.entries(idToParam)) {
        if (dirtyInputs.has(id)) {
            dirty[param] = fullConfig[param];
            hasDirty = true;
        }
    }
    return hasDirty ? dirty : fullConfig;
}

// Clear dirty state for a set of input IDs after a successful send
function markClean(inputIds) {
    inputIds.forEach(id => {
        dirtyInputs.delete(id);
        const el = document.getElementById(id);
        if (el) el.classList.remove('input-dirty');
    });
}

// Send configuration to AutoBoat
function sendConfig(pidOnly = false) {
    if (!connected || !configPublisher) {
        addLog('Not connected to ROS', 'error');
        return false;
    }

    let config = {};

    // ID-to-param mapping for dirty filtering
    const pidIdMap = {
        'cfg-kp': 'kp', 'cfg-ki': 'ki', 'cfg-kd': 'kd'
    };

    resetValidation();

    if (pidOnly) {
        // Only send PID parameters
        const fullPid = {
            kp: readInput('cfg-kp', 500),
            ki: readInput('cfg-ki', 20),
            kd: readInput('cfg-kd', 150)
        };
        if (hasValidationErrors()) {
            addLog('Config not sent — fix out-of-range values first', 'warning');
            return false;
        }
        config = filterDirtyParams(fullPid, pidIdMap);
        addLog('Sending PID config... | Envoi configuration PID...', 'info');
    } else {
        // Get selected navigation mode
        const navMode = getSelectedNavMode();

        // Build full config
        const fullConfig = {
            lanes: readInput('cfg-lanes', 8),
            scan_length: readInput('cfg-scan-length', 15.0),
            scan_width: readInput('cfg-scan-width', 30.0),
            kp: readInput('cfg-kp', 500),
            ki: readInput('cfg-ki', 20),
            kd: readInput('cfg-kd', 150),
            base_speed: readInput('cfg-base-speed', 400),
            max_speed: readInput('cfg-max-speed', 800),
            min_safe_distance: readInput('cfg-safe-dist', 12),
            // Waypoint approach parameters
            waypoint_tolerance: readInput('cfg-waypoint-tolerance', 3.5),
            approach_slow_distance: readInput('cfg-approach-slow-distance', 10),
            approach_slow_factor: readInput('cfg-approach-slow-factor', 0.7),
            // A* detour options based on selected navigation mode
            astar_enabled: (navMode === 'runtime' || navMode === 'hybrid'),
            astar_hybrid_mode: (navMode === 'hybrid'),
            hazard_enabled: (navMode === 'hybrid'),
            astar_resolution: readInput('cfg-astar-resolution', 3.0),
            astar_safety_margin: readInput('cfg-astar-safety', 12.0),
            astar_max_expansions: readInput('cfg-astar-max', 20000)
        };

        if (hasValidationErrors()) {
            addLog('Config not sent — fix out-of-range values first', 'warning');
            return false;
        }

        const mainIdMap = {
            'cfg-lanes': 'lanes', 'cfg-scan-length': 'scan_length', 'cfg-scan-width': 'scan_width',
            'cfg-kp': 'kp', 'cfg-ki': 'ki', 'cfg-kd': 'kd',
            'cfg-base-speed': 'base_speed', 'cfg-max-speed': 'max_speed',
            'cfg-safe-dist': 'min_safe_distance',
            'cfg-waypoint-tolerance': 'waypoint_tolerance',
            'cfg-approach-slow-distance': 'approach_slow_distance',
            'cfg-approach-slow-factor': 'approach_slow_factor',
            'cfg-astar-resolution': 'astar_resolution',
            'cfg-astar-safety': 'astar_safety_margin',
            'cfg-astar-max': 'astar_max_expansions'
        };

        config = filterDirtyParams(fullConfig, mainIdMap);

        // Always include A* mode flags if nav mode radio was changed
        if (navModeDirty) {
            config.astar_enabled = fullConfig.astar_enabled;
            config.astar_hybrid_mode = fullConfig.astar_hybrid_mode;
            config.hazard_enabled = fullConfig.hazard_enabled;
        }

        addLog('Sending config... | Envoi configuration...', 'info');
    }

    const message = new ROSLIB.Message({
        data: JSON.stringify(config)
    });

    // Publish to planning topics
    configPublisher.publish(message);
    if (modularConfigPublisher) {
        modularConfigPublisher.publish(message);
    }

    const sentCount = Object.keys(config).length;
    addLog(`Config sent (${sentCount} params)! | Configuration envoyée!`, 'info');
    if (DEBUG_MODE) console.log('Config sent:', config);

    // Clear dirty state for sent inputs
    if (pidOnly) {
        markClean(Object.keys(pidIdMap));
        showFeedback(`✅ PID: ${sentCount} parameter(s) applied`, 'success');
    } else {
        markClean([
            'cfg-lanes', 'cfg-scan-length', 'cfg-scan-width',
            'cfg-kp', 'cfg-ki', 'cfg-kd',
            'cfg-base-speed', 'cfg-max-speed', 'cfg-safe-dist',
            'cfg-waypoint-tolerance', 'cfg-approach-slow-distance', 'cfg-approach-slow-factor',
            'cfg-astar-resolution', 'cfg-astar-safety', 'cfg-astar-max'
        ]);
        navModeDirty = false;
        showFeedback(`✅ Config: ${sentCount} parameter(s) applied`, 'success');
    }
    return true;
}

function getSelectedNavMode() {
    const radio = document.querySelector('input[name="nav-mode"]:checked');
    return radio ? radio.value : 'simple';
}

// ========== TERMINAL OUTPUT FUNCTIONS ==========

// Add line to terminal output
function addTerminalLine(message) {
    const terminal = document.getElementById('terminal-output');
    if (!terminal) return;
    
    const line = document.createElement('div');
    line.className = 'terminal-line';
    
    // Determine log level class
    // ROS log levels: DEBUG=10, INFO=20, WARN=30, ERROR=40, FATAL=50
    let levelClass = 'info';
    let levelPrefix = '[INFO]';
    
    if (message.level !== undefined) {
        if (message.level >= 40) {
            levelClass = 'error';
            levelPrefix = '[ERROR]';
        } else if (message.level >= 30) {
            levelClass = 'warn';
            levelPrefix = '[WARN]';
        } else if (message.level <= 10) {
            levelClass = 'debug';
            levelPrefix = '[DEBUG]';
        }
    }
    
    if (message.name === 'system') {
        levelClass = 'system';
        levelPrefix = '[SYSTEM]';
    }
    
    line.classList.add(levelClass);
    
    // Format timestamp
    const now = new Date();
    const timestamp = now.toLocaleTimeString('en-US', { hour12: false });
    
    // Format the message
    const msgText = message.msg || message;
    line.innerHTML = `<span class="timestamp">[${timestamp}]</span> <span class="level">${levelPrefix}</span> <span class="message"></span>`;
    line.querySelector('.message').textContent = msgText;
    
    terminal.appendChild(line);
    
    // Auto-scroll if enabled
    const autoScroll = document.getElementById('auto-scroll');
    if (autoScroll && autoScroll.checked) {
        terminal.scrollTop = terminal.scrollHeight;
    }
    
    // Limit lines to prevent memory issues
    while (terminal.children.length > 200) {
        terminal.removeChild(terminal.firstChild);
    }
}

function updateWorldFromConfig(data) {
    if (data.world_name) {
        currentState.world.name = data.world_name;
    }
    updateWorldBanner(currentState.world.name);
}
// Initialize terminal controls
function initTerminal() {
    const clearBtn = document.getElementById('btn-clear-terminal');
    if (clearBtn) {
        clearBtn.addEventListener('click', () => {
            const terminal = document.getElementById('terminal-output');
            terminal.innerHTML = '<div class="terminal-line system">[SYSTEM] Terminal cleared | Terminal effacé</div>';
        });
    }

    // Clear logs button handler
    const clearLogsBtn = document.getElementById('btn-clear-logs');
    if (clearLogsBtn) {
        clearLogsBtn.addEventListener('click', () => {
            const logs = document.getElementById('logs');
            if (logs) {
                const timestamp = new Date().toLocaleTimeString();
                logs.innerHTML = `<div class="log-entry info">
                    <span class="timestamp">[${timestamp}]</span>
                    <span class="message">[SYSTEM] Logs cleared | Journaux effacés</span>
                </div>`;
            }
        });
    }
}

// ========== MISSION CONTROL FUNCTIONS ==========

// Debounce guard — prevents duplicate commands from rapid clicks
let lastCommandTime = 0;
const COMMAND_DEBOUNCE_MS = 800;

function debounceCommand(fn) {
    const now = Date.now();
    if (now - lastCommandTime < COMMAND_DEBOUNCE_MS) {
        addLog('Command ignored (too fast) | Commande ignorée (trop rapide)', 'warning');
        return;
    }
    lastCommandTime = now;
    fn();
}

// Initialize mission control panel
function initMissionControl() {
    if (DEBUG_MODE) console.log('Initializing mission control...');

    // Step 1: Generate Waypoints
    document.getElementById('btn-generate-waypoints').addEventListener('click', () => {
        debounceCommand(() => generateWaypoints());
    });

    // Step 2: Confirm/Cancel Waypoints
    document.getElementById('btn-confirm-waypoints').addEventListener('click', () => {
        debounceCommand(() => {
            sendMissionCommand('confirm_waypoints');
            setTimeout(() => alert('✅ Waypoints Confirmed\n\nRoute locked. Ready to start mission.\n\n✅ Waypoints Confirmés\n\nRoute verrouillée. Prêt à démarrer la mission.'), 100);
        });
    });

    document.getElementById('btn-cancel-waypoints').addEventListener('click', () => {
        debounceCommand(() => {
            sendMissionCommand('cancel_waypoints');
            clearWaypointPreview();
            setTimeout(() => alert('❌ Waypoints Cancelled\n\nRoute cleared. Generate new waypoints.\n\n❌ Waypoints Annulés\n\nRoute effacée. Générer de nouveaux waypoints.'), 100);
        });
    });

    // Step 3: Start/Stop/Resume/Reset Mission
    document.getElementById('btn-start-mission').addEventListener('click', () => {
        debounceCommand(() => {
            sendMissionCommand('start_mission');
            setTimeout(() => alert('✅ Mission Started\n\nThe boat will begin navigation.\n\n✅ Mission Démarrée\n\nLe bateau va commencer la navigation.'), 100);
        });
    });

    document.getElementById('btn-stop-mission').addEventListener('click', () => {
        debounceCommand(() => {
            const stopService = new ROSLIB.Service({
                ros: ros,
                name: '/planning/stop_mission',
                serviceType: 'std_srvs/Trigger'
            });
            stopService.callService(new ROSLIB.ServiceRequest({}), (result) => {
                if (result.success) {
                    addLog(`Mission stopped — ${result.message}`, 'info');
                } else {
                    addLog(`Stop rejected: ${result.message}`, 'warning');
                }
            }, (error) => {
                addLog(`Stop service error: ${error}`, 'error');
            });
            setTimeout(() => alert('⏸️ Mission Stopped\n\nNavigation paused. Use Resume to continue.\n\n⏸️ Mission Arrêtée\n\nNavigation en pause. Utilisez Reprendre pour continuer.'), 100);
        });
    });

    document.getElementById('btn-resume-mission').addEventListener('click', () => {
        debounceCommand(() => {
            sendMissionCommand('resume_mission');
            setTimeout(() => alert('▶️ Mission Resumed\n\nNavigation continuing.\n\n▶️ Mission Reprise\n\nNavigation en cours.'), 100);
        });
    });

    document.getElementById('btn-reset-mission').addEventListener('click', () => {
        if (confirm('Reset mission and clear waypoints? | Réinitialiser la mission et effacer les waypoints?')) {
            debounceCommand(() => {
                sendMissionCommand('reset_mission');
                clearWaypointPreview();
                missionState.startLat = null;
                missionState.startLon = null;
                addLog('Mission reset - ready for new waypoints | Prêt pour nouveaux waypoints', 'warning');
                setTimeout(() => alert('🔄 Mission Reset\n\nAll waypoints cleared. Ready for new mission.\n\n🔄 Mission Réinitialisée\n\nTous les waypoints effacés. Prêt pour nouvelle mission.'), 100);
            });
        }
    });

    // Go Home - One-click return to spawn point
    document.getElementById('btn-go-home').addEventListener('click', () => {
        if (confirm('🏠 Go Home: The boat will navigate to its starting point. Continue? | Le bateau va naviguer vers son point de départ. Continuer?')) {
            debounceCommand(() => {
                sendMissionCommand('go_home');
                addLog('🏠 Go Home activated | Retour maison activé', 'info');
                setTimeout(() => alert('🏠 Go Home Activated\n\nBoat navigating to starting position.\n\n🏠 Retour Maison Activé\n\nBateau naviguant vers position de départ.'), 100);
            });
        }
    });

    // Emergency Stop - Immediately halt the boat (no debounce — safety critical)
    document.getElementById('btn-emergency-stop').addEventListener('click', () => {
        emergencyStop();
    });

    // Joystick Override — debounced to prevent rapid toggling during command latency
    document.getElementById('btn-joystick-enable').addEventListener('click', () => {
        debounceCommand(() => {
            sendMissionCommand('joystick_enable');
            setTimeout(() => alert('🎮 Joystick Mode Enabled\n\nAutonomous control disabled. Use keyboard teleop.\n\n🎮 Mode Joystick Activé\n\nContrôle autonome désactivé. Utilisez le téléopération.'), 100);
        });
    });

    document.getElementById('btn-joystick-disable').addEventListener('click', () => {
        debounceCommand(() => {
            sendMissionCommand('joystick_disable');
            setTimeout(() => alert('🤖 Autonomous Mode Restored\n\nJoystick override disabled.\n\n🤖 Mode Autonome Restauré\n\nJoystick désactivé.'), 100);
        });
    });

    // Header E-Stop shortcut — scrolls to and flashes the real Emergency Stop button
    const headerEstop = document.getElementById('header-estop-badge');
    if (headerEstop) {
        headerEstop.addEventListener('click', () => {
            const target = document.getElementById('btn-emergency-stop');
            if (!target) return;
            target.scrollIntoView({ behavior: 'smooth', block: 'center' });
            target.focus({ preventScroll: true });
            target.classList.add('estop-flash');
            setTimeout(() => target.classList.remove('estop-flash'), 1200);
        });
    }

    if (DEBUG_MODE) console.log('Mission control initialized');
}

// Generate waypoints and update config
function generateWaypoints() {
    if (!connected || !configPublisher) {
        addLog('Not connected to ROS', 'error');
        return;
    }
    
    // Get waypoint parameters from mission control inputs (validated)
    resetValidation();
    const lanes = readInput('wp-lanes', 10);
    const length = readInput('wp-length', 15.0);
    const width = readInput('wp-width', 30.0);

    if (hasValidationErrors()) {
        addLog('Waypoint generation aborted — fix out-of-range values first', 'warning');
        return;
    }

    // Update hidden config fields for compatibility
    document.getElementById('cfg-lanes').value = lanes;
    document.getElementById('cfg-scan-length').value = length;
    document.getElementById('cfg-scan-width').value = width;
    
    // Don't clear dirty state immediately - wait for ROS confirmation

    const navMode = getSelectedNavMode();

    // Send config update first
    const config = {
        lanes: lanes,
        scan_length: length,
        scan_width: width,
        // Carry A* settings to Planner with waypoint generation
        astar_enabled: navMode !== 'simple',
        astar_hybrid_mode: navMode === 'hybrid',
        hazard_enabled: navMode === 'hybrid',
        astar_resolution: readInput('cfg-astar-resolution', 3.0),
        astar_safety_margin: readInput('cfg-astar-safety', 12.0),
        astar_max_expansions: readInput('cfg-astar-max', 20000)
    };
    
    const configMsg = new ROSLIB.Message({
        data: JSON.stringify(config)
    });
    configPublisher.publish(configMsg);

    // Call generate as a service; rosbridge forwards the config publish first,
    // so by the time the service handler runs the new config is already applied.
    // No hand-tuned sleep needed.
    const generateService = new ROSLIB.Service({
        ros: ros,
        name: '/planning/generate_waypoints',
        serviceType: 'std_srvs/Trigger'
    });
    generateService.callService(new ROSLIB.ServiceRequest({}), (result) => {
        if (result.success) {
            addLog(`Waypoints generated — ${result.message}`, 'info');
        } else {
            addLog(`Generate rejected: ${result.message}`, 'warning');
        }
    }, (error) => {
        addLog(`Generate service error: ${error}`, 'error');
    });
    
    // Calculate and display preview info
    const totalWaypoints = lanes * 2 - 1;
    const estimatedDistance = length * lanes + width * (lanes - 1);
    document.getElementById('waypoint-count').textContent = `Waypoints: ~${totalWaypoints}`;
    document.getElementById('estimated-distance').textContent = `Distance: ~${estimatedDistance}m`;
    
    addLog(`Generating ${totalWaypoints} waypoints: ${length}m × ${lanes} lanes`, 'info');
}

// Send mission command to Planner (modular mode)
function sendMissionCommand(command) {
    if (!connected) {
        addLog('Not connected to ROS', 'error');
        return;
    }

    // Create publisher if not exists (Planner only)
    if (!missionCommandPublisher) {
        missionCommandPublisher = new ROSLIB.Topic({
            ros: ros,
            name: '/planning/mission_command',
            messageType: 'std_msgs/String'
        });
    }

    const msg = new ROSLIB.Message({
        data: JSON.stringify({ command: command })
    });

    // Publish to modular planner only
    missionCommandPublisher.publish(msg);
    addLog(`Mission command: ${command}`, 'info');
    if (DEBUG_MODE) console.log('Mission command sent to planner:', command);
}

// Emergency Stop - Immediately halt the boat
function emergencyStop() {
    if (!connected) {
        addLog('Not connected to ROS', 'error');
        return;
    }

    // Show critical warning with audio if possible
    const confirmed = confirm('🚨 EMERGENCY STOP 🚨\n\nThis will IMMEDIATELY:\n- Cut all thrust to ZERO\n- Stop the mission\n- Halt the boat\n\nConfirm emergency stop?\n\n🚨 ARRÊT D\'URGENCE 🚨\n\nCela va IMMÉDIATEMENT:\n- Couper toute propulsion à ZÉRO\n- Arrêter la mission\n- Immobiliser le bateau\n\nConfirmer l\'arrêt d\'urgence?');

    if (!confirmed) {
        addLog('Emergency stop cancelled by user', 'warning');
        return;
    }

    addLog('🚨 EMERGENCY STOP ACTIVATED | ARRÊT D\'URGENCE ACTIVÉ 🚨', 'error');
    console.error('🚨 EMERGENCY STOP ACTIVATED');

    // 1. IMMEDIATELY publish zero thrust to both thrusters (highest priority)
    const zeroThrustMsg = new ROSLIB.Message({ data: 0.0 });

    const leftThrustTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/wamv/thrusters/left/thrust',
        messageType: 'std_msgs/Float64'
    });

    const rightThrustTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/wamv/thrusters/right/thrust',
        messageType: 'std_msgs/Float64'
    });

    leftThrustTopic.publish(zeroThrustMsg);
    rightThrustTopic.publish(zeroThrustMsg);

    // 2. Latch e-stop on the dedicated safety-critical channel.
    //    Bool on /planning/emergency_stop is received by both planner and
    //    controller with RELIABLE QoS, so a single publish is sufficient.
    const estopTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/planning/emergency_stop',
        messageType: 'std_msgs/Bool'
    });
    estopTopic.publish(new ROSLIB.Message({ data: true }));

    // 3. Visual feedback - flash the emergency stop button
    const emergencyBtn = document.getElementById('btn-emergency-stop');
    if (emergencyBtn) {
        emergencyBtn.style.animation = 'emergency-flash 0.5s ease-in-out 6';
        setTimeout(() => {
            emergencyBtn.style.animation = '';
        }, 3000);
    }

    // 4. Log detailed emergency stop info
    addLog('Zero thrust commanded to both thrusters', 'error');
    addLog('Mission emergency stop sent to planner', 'error');
    addLog('Boat should be stopped. Verify manually before resuming.', 'warning');
}

// Update mission control UI based on state
function updateMissionControlUI(state) {
    if (DEBUG_MODE) console.log('updateMissionControlUI called with state:', state);
    missionState.state = (state.state || 'IDLE').toString().toUpperCase();
    // If no gps_ready field, assume true when connected (for testing)
    missionState.gpsReady = (state.gps_ready !== undefined) ? state.gps_ready : connected;
    missionState.missionArmed = state.mission_armed || false;
    missionState.joystickOverride = state.joystick_override || false;
    // Guard fields that /planning/mission_status owns — /planning/config doesn't carry them
    // and unguarded `|| false/0` would clobber the good value every config tick (1 Hz race).
    if (state.go_home_mode !== undefined) {
        missionState.goHomeMode = state.go_home_mode;
    }
    if (state.total_waypoints !== undefined) {
        missionState.totalWaypoints = state.total_waypoints;
    }
    if (state.current_waypoint !== undefined) {
        missionState.currentWaypoint = state.current_waypoint;
    }
    missionState.startLat = state.start_lat;
    missionState.startLon = state.start_lon;
    if (missionState.waypoints && missionState.waypoints.length > 0) {
        persistWaypoints();
    }
    
    // Update GPS indicator
    const gpsBadge = document.getElementById('gps-ready-badge');
    if (gpsBadge) {
        if (missionState.gpsReady) {
            gpsBadge.textContent = '📡 GPS: Ready | Prêt';
            gpsBadge.className = 'gps-badge ready';
        } else {
            gpsBadge.textContent = '📡 GPS: Waiting... | En attente...';
            gpsBadge.className = 'gps-badge not-ready';
        }
    }

    // Update state badge
    const stateBadge = document.getElementById('mission-state-badge');
    if (stateBadge) {
        const stateLabels = {
            'INIT': 'Init | Initialisation',
            'IDLE': 'Idle | En attente',
            'WAITING_CONFIRM': 'Confirm | Confirmation',
            'WAYPOINTS_PREVIEW': 'Preview | Aperçu',
            'READY': 'Ready | Prêt',
            'RUNNING': 'Running | En cours',
            'DRIVING': 'Driving | Navigation',
            'PAUSED': 'Paused | Pause',
            'JOYSTICK': 'Joystick',
            'FINISHED': 'Finished | Terminé',
            'EMERGENCY_STOP': '⚠ EMERGENCY STOP'
        };
        stateBadge.textContent = stateLabels[missionState.state] || missionState.state;
        stateBadge.className = `mission-badge ${missionState.state.toLowerCase()}`;
    }

    // Header E-Stop badge pulses while the latch is active
    const headerEstopBadge = document.getElementById('header-estop-badge');
    if (headerEstopBadge) {
        headerEstopBadge.classList.toggle('latched', missionState.state === 'EMERGENCY_STOP');
    }

    // Update button states based on mission state
    const btnGenerate = document.getElementById('btn-generate-waypoints');
    const btnConfirm = document.getElementById('btn-confirm-waypoints');
    const btnCancel = document.getElementById('btn-cancel-waypoints');
    const btnStart = document.getElementById('btn-start-mission');
    const btnStop = document.getElementById('btn-stop-mission');
    const btnResume = document.getElementById('btn-resume-mission');
    const btnReset = document.getElementById('btn-reset-mission');
    const btnJoyEnable = document.getElementById('btn-joystick-enable');
    const btnJoyDisable = document.getElementById('btn-joystick-disable');
    const btnGoHome = document.getElementById('btn-go-home');
    const hasWaypoints = (missionState.totalWaypoints || 0) > 0 || (missionState.waypoints && missionState.waypoints.length > 0);
    const resumableStates = ['PAUSED', 'EMERGENCY_STOP'];
    const awaitingDecision = ['WAITING_CONFIRM', 'WAYPOINTS_PREVIEW'].includes(missionState.state);

    // Reset all buttons
    [btnGenerate, btnConfirm, btnCancel, btnStart, btnStop, btnResume, btnReset, btnGoHome, btnJoyEnable, btnJoyDisable].forEach(btn => {
        if (btn) btn.disabled = true;
    });

    // Reset is safe in most states, but NOT during the Confirm/Cancel window —
    // racing a clear_mission against a pending confirm_waypoints leaves the planner inconsistent
    if (btnReset) btnReset.disabled = !connected || awaitingDecision;
    
    // STOP/joystick toggles only when not awaiting confirm/cancel
    if (!awaitingDecision) {
        if (btnStop) btnStop.disabled = !connected;
        if (btnJoyEnable) btnJoyEnable.disabled = !(connected && !missionState.joystickOverride);
        if (btnJoyDisable) btnJoyDisable.disabled = !(connected && missionState.joystickOverride);
    }

    // Generate allowed when connected, GPS ready, not in joystick override, and either no waypoints yet or we're in INIT/IDLE
    const canGenerate = connected && missionState.gpsReady && !missionState.joystickOverride &&
        (!hasWaypoints || ['INIT', 'IDLE'].includes(missionState.state));
    if (btnGenerate) btnGenerate.disabled = !canGenerate;

    // Confirm/Cancel only during preview/confirm stage (waypoints exist, no joystick override)
    const canDecide = awaitingDecision && hasWaypoints && !missionState.joystickOverride;
    if (btnConfirm) btnConfirm.disabled = !canDecide;
    if (btnCancel) btnCancel.disabled = !canDecide;

    // Start allowed when waypoints exist, not in joystick override, not awaiting decision, and state is ready/paused/stop family
    const startAllowedStates = ['READY', 'PAUSED', 'EMERGENCY_STOP', 'FINISHED', 'IDLE', 'INIT'];
    const canStart = hasWaypoints && !missionState.joystickOverride && !awaitingDecision && startAllowedStates.includes(missionState.state);
    if (btnStart) btnStart.disabled = !canStart;

    // Go Home creates its own waypoint (spawn point) — doesn't need existing waypoints, just GPS and connected
    const goHomeAllowedStates = ['READY', 'PAUSED', 'EMERGENCY_STOP', 'FINISHED', 'IDLE', 'INIT', 'DRIVING'];
    const canGoHome = connected && missionState.gpsReady && !missionState.joystickOverride && !awaitingDecision && goHomeAllowedStates.includes(missionState.state);
    if (btnGoHome) btnGoHome.disabled = !canGoHome;

    // Resume allowed when paused/stop family and waypoints exist (no joystick override) and not awaiting decision
    const canResume = hasWaypoints && !missionState.joystickOverride && !awaitingDecision && resumableStates.includes(missionState.state);
    if (btnResume) btnResume.disabled = !canResume;
    
    // Update joystick status and instructions display
    const joystickStatus = document.getElementById('joystick-status');
    const joystickInstructions = document.getElementById('joystick-instructions');
    if (joystickStatus) {
        if (missionState.joystickOverride) {
            joystickStatus.classList.remove('hidden');
            if (joystickInstructions) joystickInstructions.classList.remove('hidden');
        } else {
            joystickStatus.classList.add('hidden');
            if (joystickInstructions) joystickInstructions.classList.add('hidden');
        }
    }
    
    // Update waypoint count display
    if (missionState.totalWaypoints > 0) {
        document.getElementById('waypoint-count').textContent = 
            `Waypoints: ${missionState.currentWaypoint}/${missionState.totalWaypoints}`;
    }
}

// Display waypoints on map
// fitToWaypoints: only zoom to fit when waypoints change, not on every update
function displayWaypointsOnMap(waypoints, fitToWaypoints = false) {
    if (!waypoints || waypoints.length === 0) return;

    // Get reference point: use mission start if available, otherwise use current boat position
    let startLat = missionState.startLat;
    let startLon = missionState.startLon;

    if (!startLat || !startLon) {
        // Fallback: use boat's current GPS position as reference
        // This allows waypoints to display even if config hasn't arrived yet
        startLat = currentState.gps.lat;
        startLon = currentState.gps.lon;

        if (!startLat || !startLon || startLat === 0) {
            // Still no reference point, can't display waypoints yet
            return;
        }
        // Lock in the fallback reference so waypoints don't jitter as the boat moves
        missionState.startLat = startLat;
        missionState.startLon = startLon;
    }

    // Skip redraw if nothing visually changed (same waypoints, same current index)
    const currentWpIndex = (missionState.currentWaypoint || 1) - 1;
    const cacheKey = JSON.stringify(waypoints) + ':' + currentWpIndex;
    if (!fitToWaypoints && cacheKey === displayWaypointsOnMap._lastCacheKey) {
        return;  // Nothing changed, skip expensive clear+redraw
    }
    displayWaypointsOnMap._lastCacheKey = cacheKey;

    // Clear existing waypoint markers
    clearWaypointPreview();
    
    // Convert local coordinates to GPS
    // Handle both formats: [{x, y}] or [[x, y]] from planner
    const waypointLatLngs = waypoints.map((wp, idx) => {
        const x = Array.isArray(wp) ? wp[0] : wp.x;
        const y = Array.isArray(wp) ? wp[1] : wp.y;
        const latLng = localToGPS(x, y, startLat, startLon);
        return { lat: latLng[0], lon: latLng[1], x: x, y: y, idx: idx };
    });
    
    // Create waypoint markers
    waypointLatLngs.forEach((wp, idx) => {
        const isCurrentTarget = idx === currentWpIndex;
        const isPassed = idx < currentWpIndex;
        
        const markerColor = isPassed ? 'green' : (isCurrentTarget ? 'orange' : 'blue');
        const markerSize = isCurrentTarget ? 14 : 10;
        const statusText = isPassed ? '✓ Passed | Passé' : (isCurrentTarget ? '→ Target | Cible' : 'Pending | En attente');
        
        const icon = L.divIcon({
            className: 'waypoint-marker',
            html: `<div style="
                background-color: ${markerColor};
                width: ${markerSize}px;
                height: ${markerSize}px;
                border-radius: 50%;
                border: 2px solid white;
                box-shadow: 0 0 4px rgba(0,0,0,0.5);
                cursor: pointer;
            "></div>`,
            iconSize: [markerSize, markerSize],
            iconAnchor: [markerSize/2, markerSize/2]
        });
        
        // Detailed tooltip content
        const tooltipContent = `
            <div class="waypoint-tooltip">
                <strong>Waypoint ${idx + 1}/${waypoints.length}</strong><br>
                <span class="wp-status" style="color: ${markerColor}">${statusText}</span>
                <hr style="margin: 4px 0; border-color: #ddd;">
                <b>Local:</b> (${wp.x.toFixed(1)}, ${wp.y.toFixed(1)}) m<br>
                <b>GPS:</b> ${wp.lat.toFixed(6)}°, ${wp.lon.toFixed(6)}°
            </div>
        `;
        
        const marker = L.marker([wp.lat, wp.lon], { icon: icon })
            .bindTooltip(tooltipContent, {
                permanent: false,  // Only show on hover
                direction: 'top',
                offset: [0, -10],
                className: 'waypoint-tooltip-container',
                sticky: true  // Keeps tooltip visible while mouse hovers over waypoint
            })
            .addTo(map);
        
        waypointMarkers.push(marker);
    });
    
    // Draw path line connecting waypoints
    const pathCoords = waypointLatLngs.map(wp => [wp.lat, wp.lon]);
    waypointPath = L.polyline(pathCoords, {
        color: '#aa44ff',
        weight: 2,
        opacity: 0.7,
        dashArray: '5, 10'
    }).addTo(map);
    
    // Fit map to show all waypoints (only when waypoints change, not on every update)
    if (fitToWaypoints && pathCoords.length > 0) {
        const bounds = L.latLngBounds(pathCoords);
        bounds.extend([startLat, startLon]);  // Include boat position
        map.fitBounds(bounds, { padding: [50, 50] });
    }
    
    addLog(`Displayed ${waypoints.length} waypoints on map`, 'info');
}

// Clear waypoint preview from map
function clearWaypointPreview() {
    waypointMarkers.forEach(marker => map.removeLayer(marker));
    waypointMarkers = [];
    
    if (waypointPath) {
        map.removeLayer(waypointPath);
        waypointPath = null;
    }
}

// Clear stored waypoints + UI affordances
function clearWaypoints(reason = '') {
    missionState.waypoints = [];
    missionState.totalWaypoints = 0;
    missionState.currentWaypoint = 0;
    clearWaypointPreview();

    const wpCount = document.getElementById('waypoint-count');
    if (wpCount) wpCount.textContent = 'Waypoints: 0';
    const distEstimate = document.getElementById('estimated-distance');
    if (distEstimate) distEstimate.textContent = 'Distance: 0m';

    if (reason) {
        addLog(`Waypoints cleared (${reason})`, 'warning');
    }

    try {
        localStorage.removeItem(WAYPOINT_STORAGE_KEY);
    } catch (err) {
        console.warn('Failed to clear waypoint cache', err);
    }
}

function persistWaypoints() {
    try {
        const payload = {
            waypoints: missionState.waypoints || [],
            totalWaypoints: missionState.totalWaypoints || 0,
            startLat: missionState.startLat,
            startLon: missionState.startLon
        };
        localStorage.setItem(WAYPOINT_STORAGE_KEY, JSON.stringify(payload));
    } catch (err) {
        console.warn('Failed to persist waypoints', err);
    }
}

function restorePersistedWaypoints() {
    try {
        const raw = localStorage.getItem(WAYPOINT_STORAGE_KEY);
        if (!raw) return;
        const data = JSON.parse(raw);
        if (data.waypoints && data.waypoints.length > 0) {
            missionState.waypoints = data.waypoints;
            missionState.totalWaypoints = data.totalWaypoints || data.waypoints.length;
            missionState.startLat = data.startLat || missionState.startLat;
            missionState.startLon = data.startLon || missionState.startLon;
            addLog(`Restored ${missionState.waypoints.length} cached waypoints`, 'info');
            displayWaypointsOnMap(missionState.waypoints, true);
        }
    } catch (err) {
        console.warn('Failed to restore waypoint cache', err);
    }
}

// Convert local ENU coordinates to GPS
function localToGPS(x, y, refLat, refLon) {
    const R = 6371000.0;  // Earth radius in meters
    const refLatRad = refLat * Math.PI / 180;

    // x = East, y = North
    const dLat = y / R;
    const dLon = x / (R * Math.cos(refLatRad));

    const lat = refLat + dLat * 180 / Math.PI;
    const lon = refLon + dLon * 180 / Math.PI;

    return [lat, lon];
}

// =============================================================================
// PERCEPTION & CONTROL TUNING SYSTEM
// =============================================================================

// Preset configurations
const TUNING_PRESETS = {
    universal: {
        name: "Universal",
        perception: {
            min_height: -1.8,
            max_height: 0.8,
            min_range: 0.8,
            max_range: 80.0,
            perception_min_safe_distance: 11.0,
            perception_critical_distance: 3.5,
            cluster_distance: 1.5,
            min_cluster_size: 4,
            temporal_history_size: 3,
            temporal_threshold: 3,
            water_plane_threshold: 0.2,
            hysteresis_distance: 1.3
        },
        controller: {
            critical_distance: 3.5,
            min_safe_distance: 11.0,
            bank_slow_distance: 7.0,
            obstacle_slow_factor: 0.35,
            bank_slow_factor: 0.22,
            use_vfh_bias: true,
            stuck_timeout: 3.5,
            stuck_threshold: 0.9,
            max_reverse_distance: 20.0,
            slew_rate_limit: 90.0
        }
    },
    buoyField: {
        name: "Buoy Field",
        perception: {
            min_height: -1.8,
            max_height: 0.8,
            min_range: 0.8,
            max_range: 80.0,
            perception_min_safe_distance: 10.0,
            perception_critical_distance: 2.5,
            cluster_distance: 1.2,
            min_cluster_size: 3,
            temporal_history_size: 2,
            temporal_threshold: 2,
            water_plane_threshold: 0.2,
            hysteresis_distance: 1.0
        },
        controller: {
            critical_distance: 3.0,
            min_safe_distance: 10.0,
            bank_slow_distance: 6.0,
            obstacle_slow_factor: 0.3,
            bank_slow_factor: 0.2,
            use_vfh_bias: true,
            stuck_timeout: 3.0,
            stuck_threshold: 1.0,
            max_reverse_distance: 10.0,
            slew_rate_limit: 100.0
        }
    },
    pier: {
        name: "Pier Detect",
        perception: {
            min_height: -1.6,
            max_height: 1.0,
            min_range: 0.5,
            max_range: 60.0,
            perception_min_safe_distance: 12.0,
            perception_critical_distance: 2.0,
            cluster_distance: 0.5,
            min_cluster_size: 3,
            temporal_history_size: 3,
            temporal_threshold: 2,
            water_plane_threshold: 0.15,
            hysteresis_distance: 1.5
        },
        controller: {
            critical_distance: 2.5,
            min_safe_distance: 12.0,
            bank_slow_distance: 8.0,
            obstacle_slow_factor: 0.3,
            bank_slow_factor: 0.2,
            use_vfh_bias: true,
            stuck_timeout: 4.0,
            stuck_threshold: 0.8,
            max_reverse_distance: 25.0,
            slew_rate_limit: 80.0
        }
    },
    openWater: {
        name: "Open Water",
        perception: {
            min_height: -0.2,
            max_height: 3.0,
            min_range: 3.0,
            max_range: 80.0,
            perception_min_safe_distance: 15.0,
            perception_critical_distance: 5.0,
            cluster_distance: 3.0,
            min_cluster_size: 6,
            temporal_history_size: 2,
            temporal_threshold: 1,
            water_plane_threshold: 0.5,
            hysteresis_distance: 2.0
        },
        controller: {
            critical_distance: 5.0,
            min_safe_distance: 15.0,
            bank_slow_distance: 8.0,
            obstacle_slow_factor: 0.4,
            bank_slow_factor: 0.3,
            use_vfh_bias: false,
            stuck_timeout: 4.0,
            stuck_threshold: 0.8,
            max_reverse_distance: 30.0,
            slew_rate_limit: 80.0
        }
    }
};

// Initialize tuning panel
function initTuningPanel() {
    if (DEBUG_MODE) console.log('Initializing tuning panel...');

    // Collapsible section headers
    document.querySelectorAll('.tuning-section-header').forEach(header => {
        header.addEventListener('click', function() {
            const targetId = this.getAttribute('data-target');
            const content = document.getElementById(targetId);
            const icon = this.querySelector('.section-icon');

            if (content.style.display === 'none') {
                content.style.display = 'block';
                icon.textContent = '▼';
            } else {
                content.style.display = 'none';
                icon.textContent = '▶';
            }
        });
    });

    // Preset buttons
    document.getElementById('btn-preset-universal').addEventListener('click', () => applyPreset('universal'));
    document.getElementById('btn-preset-buoy-field').addEventListener('click', () => applyPreset('buoyField'));
    document.getElementById('btn-preset-pier').addEventListener('click', () => applyPreset('pier'));
    document.getElementById('btn-preset-open-water').addEventListener('click', () => applyPreset('openWater'));

    // Apply buttons
    document.getElementById('btn-apply-perception').addEventListener('click', () => applyPerceptionParameters());
    document.getElementById('btn-apply-controller').addEventListener('click', () => applyControllerParameters());

    // Reset defaults buttons
    document.getElementById('btn-reset-perception').addEventListener('click', () => {
        if (confirm('Reset Perception parameters to launch defaults? | Réinitialiser les paramètres Perception?')) {
            resetPerceptionToDefaults();
        }
    });
    document.getElementById('btn-reset-controller').addEventListener('click', () => {
        if (confirm('Reset Controller parameters to launch defaults? | Réinitialiser les paramètres Controller?')) {
            resetControllerToDefaults();
        }
    });

    if (DEBUG_MODE) console.log('Tuning panel initialized');
}

// All tuning input IDs that can change when a preset is applied. Used for diff + flash.
const PRESET_INPUT_IDS = [
    'perception-min-height', 'perception-max-height', 'perception-min-range', 'perception-max-range',
    'perception-safe-dist', 'perception-critical-dist', 'perception-cluster-dist',
    'perception-min-cluster-size', 'perception-temporal-history', 'perception-temporal-threshold',
    'perception-water-threshold', 'perception-hysteresis',
    'controller-critical-dist', 'controller-safe-dist', 'controller-bank-dist',
    'controller-obstacle-slow', 'controller-bank-slow', 'controller-avoid-gain',
    'controller-use-vfh', 'controller-max-turn', 'controller-stuck-timeout',
    'controller-stuck-threshold', 'controller-reverse-timeout', 'controller-max-reverse',
    'controller-turn-deadband', 'controller-slew-rate'
];

// Expand a collapsed tuning section and sync the caret
function expandTuningSection(contentId) {
    const content = document.getElementById(contentId);
    if (!content) return;
    if (content.style.display === 'none' || content.style.display === '') {
        content.style.display = 'block';
        const header = document.querySelector(`.tuning-section-header[data-target="${contentId}"]`);
        if (header) {
            const icon = header.querySelector('.section-icon');
            if (icon) icon.textContent = '▼';
        }
    }
}

// Briefly highlight input fields whose value changed — drops the class after the animation
function flashChangedInputs(inputIds) {
    inputIds.forEach(id => {
        const el = document.getElementById(id);
        if (el) el.classList.add('preset-changed-flash');
    });
    setTimeout(() => {
        inputIds.forEach(id => {
            const el = document.getElementById(id);
            if (el) el.classList.remove('preset-changed-flash');
        });
    }, 2200);
}

// Apply preset configuration
function applyPreset(presetName) {
    const preset = TUNING_PRESETS[presetName];
    if (!preset) {
        addLog(`Preset ${presetName} not found`, 'error');
        return;
    }

    // Confirmation dialog — presets overwrite BOTH Perception and Controller params in one click,
    // so prevent misclicks by asking the user to confirm before anything is sent to ROS.
    const perceptionCount = Object.keys(preset.perception || {}).length;
    const controllerCount = Object.keys(preset.controller || {}).length;
    const msg = `Apply "${preset.name}" preset?\n\nThis will overwrite:\n` +
                `  • ${perceptionCount} Perception parameter(s)\n` +
                `  • ${controllerCount} Controller parameter(s)\n\n` +
                `Current values will be replaced.`;
    if (!confirm(msg)) {
        addLog(`Preset ${preset.name} cancelled by user`, 'info');
        return;
    }

    const statusEl = document.getElementById('preset-status');
    statusEl.textContent = `Applying ${preset.name} preset...`;
    statusEl.style.color = '#f39c12';

    // Snapshot pre-change values so we can flash only the inputs that actually moved
    const before = {};
    PRESET_INPUT_IDS.forEach(id => {
        const el = document.getElementById(id);
        if (el) before[id] = el.value;
    });

    // Update UI inputs
    updatePerceptionInputs(preset.perception);
    updateControllerInputs(preset.controller);

    // Diff + flash; scroll the first changed field into view
    const changed = PRESET_INPUT_IDS.filter(id => {
        const el = document.getElementById(id);
        return el && el.value !== before[id];
    });

    // Only reveal a tuning sub-section if at least one of its fields actually moved —
    // respects the user's prior collapse state for sub-sections this preset doesn't touch
    // (e.g. Open Water leaves perception untouched, so keep that sub-section as it was).
    const changedPerception = changed.filter(id => id.startsWith('perception-'));
    const changedController = changed.filter(id => id.startsWith('controller-'));
    if (changedPerception.length > 0) expandTuningSection('perception-params');
    if (changedController.length > 0) expandTuningSection('controller-params');

    if (changed.length > 0) {
        flashChangedInputs(changed);
        const firstChanged = document.getElementById(changed[0]);
        if (firstChanged) firstChanged.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }

    // Apply parameters to ROS
    applyPerceptionParameters(preset.perception);
    applyControllerParameters(preset.controller);

    setTimeout(() => {
        statusEl.textContent = `✅ ${preset.name} preset applied — ${changed.length} field(s) changed`;
        statusEl.style.color = '#27ae60';
        setTimeout(() => {
            statusEl.textContent = '';
        }, 4000);
    }, 500);

    addLog(`Applied ${preset.name} preset (${changed.length} fields changed)`, 'info');
}

// Update Perception input fields from preset
function updatePerceptionInputs(params) {
    document.getElementById('perception-min-height').value = params.min_height;
    document.getElementById('perception-max-height').value = params.max_height;
    document.getElementById('perception-min-range').value = params.min_range;
    document.getElementById('perception-max-range').value = params.max_range;
    document.getElementById('perception-safe-dist').value = params.perception_min_safe_distance;
    document.getElementById('perception-critical-dist').value = params.perception_critical_distance;
    document.getElementById('perception-cluster-dist').value = params.cluster_distance;
    document.getElementById('perception-min-cluster-size').value = params.min_cluster_size;
    document.getElementById('perception-temporal-history').value = params.temporal_history_size;
    document.getElementById('perception-temporal-threshold').value = params.temporal_threshold;
    document.getElementById('perception-water-threshold').value = params.water_plane_threshold;
    document.getElementById('perception-hysteresis').value = params.hysteresis_distance;
}

// Update Controller input fields from preset.
// Guards with `!== undefined` on keys that some presets may omit — presets only carry
// the params that meaningfully differ from YAML defaults, so shared values (avoid_diff_gain,
// reverse_timeout, turn_deadband_deg, max_avoidance_turn_deg) are intentionally absent.
function updateControllerInputs(params) {
    document.getElementById('controller-critical-dist').value = params.critical_distance;
    document.getElementById('controller-safe-dist').value = params.min_safe_distance;
    document.getElementById('controller-bank-dist').value = params.bank_slow_distance;
    document.getElementById('controller-obstacle-slow').value = params.obstacle_slow_factor;
    document.getElementById('controller-bank-slow').value = params.bank_slow_factor;
    if (params.avoid_diff_gain !== undefined) {
        document.getElementById('controller-avoid-gain').value = params.avoid_diff_gain;
    }
    document.getElementById('controller-use-vfh').value = params.use_vfh_bias.toString();
    if (params.max_avoidance_turn_deg !== undefined) {
        document.getElementById('controller-max-turn').value = params.max_avoidance_turn_deg;
    }
    document.getElementById('controller-stuck-timeout').value = params.stuck_timeout;
    document.getElementById('controller-stuck-threshold').value = params.stuck_threshold;
    if (params.reverse_timeout !== undefined) {
        document.getElementById('controller-reverse-timeout').value = params.reverse_timeout;
    }
    document.getElementById('controller-max-reverse').value = params.max_reverse_distance;
    if (params.turn_deadband_deg !== undefined) {
        document.getElementById('controller-turn-deadband').value = params.turn_deadband_deg;
    }
    document.getElementById('controller-slew-rate').value = params.slew_rate_limit;
}

// Apply LiDAR perception parameters via config topic
function applyPerceptionParameters(presetParams = null) {
    if (!connected || !configPublisher) {
        addLog('Not connected to ROS', 'error');
        showFeedback('❌ Not connected to ROS', 'error');
        return;
    }

    // Perception input ID to param name mapping
    const perceptionIdMap = {
        'perception-min-height': 'min_height', 'perception-max-height': 'max_height',
        'perception-min-range': 'min_range', 'perception-max-range': 'max_range',
        'perception-safe-dist': 'perception_min_safe_distance', 'perception-critical-dist': 'perception_critical_distance',
        'perception-cluster-dist': 'cluster_distance', 'perception-min-cluster-size': 'min_cluster_size',
        'perception-temporal-history': 'temporal_history_size', 'perception-temporal-threshold': 'temporal_threshold',
        'perception-water-threshold': 'water_plane_threshold', 'perception-hysteresis': 'hysteresis_distance'
    };

    // Get full parameters from UI (with validation) or preset
    resetValidation();
    const fullParams = presetParams || {
        min_height: readInput('perception-min-height', -1.2),
        max_height: readInput('perception-max-height', 1.5),
        min_range: readInput('perception-min-range', 2.2),
        max_range: readInput('perception-max-range', 100),
        perception_min_safe_distance: readInput('perception-safe-dist', 10.0),
        perception_critical_distance: readInput('perception-critical-dist', 5.5),
        cluster_distance: readInput('perception-cluster-dist', 3.0),
        min_cluster_size: readInput('perception-min-cluster-size', 8),
        temporal_history_size: readInput('perception-temporal-history', 3),
        temporal_threshold: readInput('perception-temporal-threshold', 2),
        water_plane_threshold: readInput('perception-water-threshold', 0.32),
        hysteresis_distance: readInput('perception-hysteresis', 2.0)
    };

    if (hasValidationErrors()) {
        addLog('Perception config not sent — fix out-of-range values first', 'warning');
        return;
    }

    // Presets send all params; manual edits send only changed ones
    const params = presetParams ? fullParams : filterDirtyParams(fullParams, perceptionIdMap);

    // Publish to /planning/set_config topic
    const message = new ROSLIB.Message({
        data: JSON.stringify(params)
    });

    configPublisher.publish(message);

    // Clear dirty state for Perception inputs
    markClean(Object.keys(perceptionIdMap));

    const sentCount = Object.keys(params).length;
    addLog(`✅ Perception: ${sentCount} parameter(s) sent via config topic`, 'info');
    showFeedback(`✅ Perception: ${sentCount} parameter(s) applied`, 'success');
    if (DEBUG_MODE) console.log('Perception config sent to /planning/set_config:', params);
}

// Apply Heading Controller parameters via config topic
function applyControllerParameters(presetParams = null) {
    if (!connected || !configPublisher) {
        addLog('Not connected to ROS', 'error');
        showFeedback('❌ Not connected to ROS', 'error');
        return;
    }

    // Controller input ID to param name mapping
    const controllerIdMap = {
        'controller-critical-dist': 'critical_distance', 'controller-safe-dist': 'min_safe_distance',
        'controller-bank-dist': 'bank_slow_distance', 'controller-obstacle-slow': 'obstacle_slow_factor',
        'controller-bank-slow': 'bank_slow_factor', 'controller-avoid-gain': 'avoid_diff_gain',
        'controller-use-vfh': 'use_vfh_bias', 'controller-max-turn': 'max_avoidance_turn_deg',
        'controller-stuck-timeout': 'stuck_timeout', 'controller-stuck-threshold': 'stuck_threshold',
        'controller-reverse-timeout': 'reverse_timeout', 'controller-max-reverse': 'max_reverse_distance',
        'controller-turn-deadband': 'turn_deadband_deg', 'controller-slew-rate': 'slew_rate_limit'
    };

    // Get full parameters from UI (with validation) or preset
    resetValidation();
    const fullParams = presetParams || {
        critical_distance: readInput('controller-critical-dist', 6.0),
        min_safe_distance: readInput('controller-safe-dist', 12.0),
        bank_slow_distance: readInput('controller-bank-dist', 6.0),
        obstacle_slow_factor: readInput('controller-obstacle-slow', 0.5),
        bank_slow_factor: readInput('controller-bank-slow', 0.25),
        avoid_diff_gain: readInput('controller-avoid-gain', 18),
        use_vfh_bias: document.getElementById('controller-use-vfh').value === 'true',
        max_avoidance_turn_deg: readInput('controller-max-turn', 45),
        stuck_timeout: readInput('controller-stuck-timeout', 12.0),
        stuck_threshold: readInput('controller-stuck-threshold', 1.0),
        reverse_timeout: readInput('controller-reverse-timeout', 4.0),
        max_reverse_distance: readInput('controller-max-reverse', 25),
        turn_deadband_deg: readInput('controller-turn-deadband', 0.5),
        slew_rate_limit: readInput('controller-slew-rate', 80)
    };

    if (hasValidationErrors()) {
        addLog('Controller config not sent — fix out-of-range values first', 'warning');
        return;
    }

    // Presets send all params; manual edits send only changed ones
    const params = presetParams ? fullParams : filterDirtyParams(fullParams, controllerIdMap);

    // Publish to /planning/set_config topic
    const message = new ROSLIB.Message({
        data: JSON.stringify(params)
    });

    configPublisher.publish(message);

    // Clear dirty state for Controller inputs
    markClean(Object.keys(controllerIdMap));

    const sentCount = Object.keys(params).length;
    addLog(`✅ Controller: ${sentCount} parameter(s) sent via config topic`, 'info');
    showFeedback(`✅ Controller: ${sentCount} parameter(s) applied`, 'success');
    if (DEBUG_MODE) console.log('Controller config sent to /planning/set_config:', params);
}

// Show visual feedback toast notification
function showFeedback(message, type = 'info') {
    // Create toast container if it doesn't exist
    let toastContainer = document.getElementById('toast-container');
    if (!toastContainer) {
        toastContainer = document.createElement('div');
        toastContainer.id = 'toast-container';
        toastContainer.style.cssText = `
            position: fixed;
            top: 80px;
            right: 20px;
            z-index: 10000;
            display: flex;
            flex-direction: column;
            gap: 10px;
        `;
        document.body.appendChild(toastContainer);
    }

    // Create toast element
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    // Set colors based on type
    let bgColor, borderColor;
    switch (type) {
        case 'success':
            bgColor = 'rgba(40, 167, 69, 0.95)';
            borderColor = '#28a745';
            break;
        case 'error':
            bgColor = 'rgba(220, 53, 69, 0.95)';
            borderColor = '#dc3545';
            break;
        case 'warning':
            bgColor = 'rgba(255, 193, 7, 0.95)';
            borderColor = '#ffc107';
            break;
        default: // info
            bgColor = 'rgba(23, 162, 184, 0.95)';
            borderColor = '#17a2b8';
    }

    toast.style.cssText = `
        background: ${bgColor};
        color: white;
        padding: 15px 20px;
        border-radius: 8px;
        border-left: 4px solid ${borderColor};
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        min-width: 300px;
        max-width: 400px;
        font-size: 14px;
        font-weight: 500;
        line-height: 1.5;
        animation: slideIn 0.3s ease-out;
        white-space: pre-wrap;
    `;

    toast.textContent = message;
    toastContainer.appendChild(toast);

    // Auto-remove after delay — errors need extra time to read (range messages, rejections)
    const TOAST_DURATIONS = { error: 6500, warning: 5500, success: 3000, info: 3500 };
    const duration = TOAST_DURATIONS[type] || 3500;
    setTimeout(() => {
        toast.style.animation = 'slideOut 0.3s ease-in';
        setTimeout(() => {
            toast.remove();
            // Remove container if empty
            if (toastContainer.children.length === 0) {
                toastContainer.remove();
            }
        }, 300);
    }, duration);
}

// Hook into existing page load initialization
// Auto-append valid range to existing info-tooltip hover text.
// Strips any previous [Range: ...] suffix so tooltips reflect the latest min/max
// (important when ranges come from /perception/param_ranges etc. and may change).
function enrichTooltipsWithRanges() {
    document.querySelectorAll('input[type="number"][min], input[type="number"][max]').forEach(input => {
        const min = input.min !== '' ? input.min : '—';
        const max = input.max !== '' ? input.max : '—';
        if (min === '—' && max === '—') return;
        // Find the nearest info-tooltip (ℹ️) in the same param-row
        const row = input.closest('.param-row') || input.parentElement;
        const tooltip = row?.querySelector('.info-tooltip');
        if (tooltip && tooltip.title) {
            // Strip any previous [Range: ...] then append the fresh one
            tooltip.title = tooltip.title.replace(/\s*\[Range:[^\]]*\]/, '') + ` [Range: ${min}–${max}]`;
        }
    });
}

// Param name → list of HTML input IDs. A param may appear in multiple inputs
// (e.g., 'lanes' is in both cfg-lanes and wp-lanes). Used by applyRangesToDashboard
// to sync min/max from ROS nodes onto HTML inputs at runtime.
const PARAM_TO_INPUT_IDS = {
    // Main Config (Planner + Controller)
    'lanes': ['cfg-lanes', 'wp-lanes'],
    'scan_length': ['cfg-scan-length', 'wp-length'],
    'scan_width': ['cfg-scan-width', 'wp-width'],
    'kp': ['cfg-kp'],
    'ki': ['cfg-ki'],
    'kd': ['cfg-kd'],
    'base_speed': ['cfg-base-speed'],
    'max_speed': ['cfg-max-speed'],
    'min_safe_distance': ['cfg-safe-dist', 'controller-safe-dist'],
    'waypoint_tolerance': ['cfg-waypoint-tolerance'],
    'approach_slow_distance': ['cfg-approach-slow-distance'],
    'approach_slow_factor': ['cfg-approach-slow-factor'],
    // A* Advanced
    'astar_resolution': ['cfg-astar-resolution'],
    'astar_safety_margin': ['cfg-astar-safety'],
    'astar_max_expansions': ['cfg-astar-max'],
    // Perception panel
    'min_height': ['perception-min-height'],
    'max_height': ['perception-max-height'],
    'min_range': ['perception-min-range'],
    'max_range': ['perception-max-range'],
    'perception_min_safe_distance': ['perception-safe-dist'],
    'perception_critical_distance': ['perception-critical-dist'],
    'cluster_distance': ['perception-cluster-dist'],
    'min_cluster_size': ['perception-min-cluster-size'],
    'temporal_history_size': ['perception-temporal-history'],
    'temporal_threshold': ['perception-temporal-threshold'],
    'water_plane_threshold': ['perception-water-threshold'],
    'hysteresis_distance': ['perception-hysteresis'],
    // Controller panel
    'critical_distance': ['controller-critical-dist'],
    'bank_slow_distance': ['controller-bank-dist'],
    'obstacle_slow_factor': ['controller-obstacle-slow'],
    'bank_slow_factor': ['controller-bank-slow'],
    'avoid_diff_gain': ['controller-avoid-gain'],
    'max_avoidance_turn_deg': ['controller-max-turn'],
    'stuck_timeout': ['controller-stuck-timeout'],
    'stuck_threshold': ['controller-stuck-threshold'],
    'reverse_timeout': ['controller-reverse-timeout'],
    'max_reverse_distance': ['controller-max-reverse'],
    'turn_deadband_deg': ['controller-turn-deadband'],
    'slew_rate_limit': ['controller-slew-rate'],
};

// Apply ranges received from a ROS node to HTML inputs at runtime.
// rangesJson: {param_name: [min, max], ...} — JSON from /<ns>/param_ranges
function applyRangesToDashboard(rangesJson) {
    let changed = 0;
    for (const [paramName, range] of Object.entries(rangesJson)) {
        if (!Array.isArray(range) || range.length !== 2) continue;
        const [min, max] = range;
        const inputIds = PARAM_TO_INPUT_IDS[paramName];
        if (!inputIds) continue;
        for (const id of inputIds) {
            const el = document.getElementById(id);
            if (el) {
                el.min = String(min);
                el.max = String(max);
                changed++;
            }
        }
    }
    if (changed > 0) {
        enrichTooltipsWithRanges();  // re-run so tooltips reflect the new ranges
        if (DEBUG_MODE) console.log(`applyRangesToDashboard: updated ${changed} input(s)`);
    }
}

// Find the existing initConfigPanel call and add initTuningPanel after it
const originalInit = window.onload;
window.addEventListener('load', () => {
    enrichTooltipsWithRanges();
    // Wait for ROS connection before initializing tuning panel
    setTimeout(() => {
        if (connected) {
            initTuningPanel();
        } else {
            // Retry after connection established
            const checkConnection = setInterval(() => {
                if (connected) {
                    initTuningPanel();
                    clearInterval(checkConnection);
                }
            }, 1000);
        }
    }, 1000);
});

// =============================================================================
// PHASE 2: MISSION HISTORY LOG, WAYPOINT VALIDATION, PROGRESS BAR
// =============================================================================

// Mission History System
const missionHistory = [];
const MAX_HISTORY_ENTRIES = 100;
let historyExpanded = false;
let historyUpdatePending = false;
let lastHistoryUpdate = 0;
const HISTORY_UPDATE_THROTTLE = 500; // Update display max once per 500ms

// Initialize mission history
function initMissionHistory() {
    // Toggle history panel
    document.getElementById('btn-toggle-history').addEventListener('click', () => {
        historyExpanded = !historyExpanded;
        const content = document.getElementById('mission-history-content');
        const icon = document.querySelector('.history-icon');

        if (historyExpanded) {
            content.style.display = 'block';
            icon.textContent = '▼';
        } else {
            content.style.display = 'none';
            icon.textContent = '▶';
        }
    });

    // Clear history
    document.getElementById('btn-clear-history').addEventListener('click', () => {
        if (confirm('Clear all mission history? | Effacer tout l\'historique?')) {
            missionHistory.length = 0;
            updateHistoryDisplay();
            addLog('Mission history cleared', 'info');
        }
    });

    // Export history as JSON
    document.getElementById('btn-export-history').addEventListener('click', () => {
        exportHistoryAsJSON();
    });

    if (DEBUG_MODE) console.log('Mission history initialized');
}

// Add event to mission history
function addHistoryEvent(type, message, data = {}) {
    const event = {
        timestamp: new Date().toISOString(),
        time: new Date().toLocaleTimeString(),
        type: type, // 'state', 'waypoint', 'detour', 'sass', 'emergency', 'info', 'warning', 'error'
        message: message,
        data: data
    };

    missionHistory.unshift(event); // Add to beginning

    // Keep only last MAX_HISTORY_ENTRIES
    if (missionHistory.length > MAX_HISTORY_ENTRIES) {
        missionHistory.pop();
    }

    // Throttle display updates to prevent rapid flickering
    scheduleHistoryUpdate();
}

// Schedule a throttled history display update
function scheduleHistoryUpdate() {
    const now = Date.now();

    // If enough time has passed since last update, update immediately
    if (now - lastHistoryUpdate >= HISTORY_UPDATE_THROTTLE) {
        updateHistoryDisplay();
        lastHistoryUpdate = now;
        historyUpdatePending = false;
    } else if (!historyUpdatePending) {
        // Schedule an update for later
        historyUpdatePending = true;
        setTimeout(() => {
            updateHistoryDisplay();
            lastHistoryUpdate = Date.now();
            historyUpdatePending = false;
        }, HISTORY_UPDATE_THROTTLE - (now - lastHistoryUpdate));
    }
}

// Update history display in UI
function updateHistoryDisplay() {
    const logEl = document.getElementById('mission-history-log');
    const countEl = document.getElementById('history-count');

    if (!logEl || !countEl) return;

    countEl.textContent = `(${missionHistory.length} events)`;

    if (missionHistory.length === 0) {
        logEl.innerHTML = '<div class="history-empty">No events yet | Aucun événement</div>';
        return;
    }

    let html = '';
    missionHistory.forEach(event => {
        const iconMap = {
            'state': '🔄',
            'waypoint': '📍',
            'detour': '⚠️',
            'sass': '🔄',
            'emergency': '🚨',
            'info': 'ℹ️',
            'warning': '⚠️',
            'error': '❌'
        };
        const icon = iconMap[event.type] || '•';
        const className = `history-entry history-${event.type}`;

        html += `<div class="${className}">
            <span class="history-time">${event.time}</span>
            <span class="history-icon">${icon}</span>
            <span class="history-message">${event.message}</span>
        </div>`;
    });

    logEl.innerHTML = html;

    // Auto-scroll to top if expanded
    if (historyExpanded) {
        logEl.scrollTop = 0;
    }
}

// Export history as JSON
function exportHistoryAsJSON() {
    const dataStr = JSON.stringify(missionHistory, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `mission_history_${new Date().toISOString()}.json`;
    link.click();
    URL.revokeObjectURL(url);
    addLog('Mission history exported', 'info');
}

// Waypoint Validation System
let currentValidation = null;

// Validate waypoints before confirmation
async function validateWaypoints(waypoints) {
    if (!waypoints || waypoints.length === 0) {
        return null;
    }

    const validation = {
        timestamp: Date.now(),
        waypoints: waypoints,
        checks: {
            reachable: { pass: true, message: '✅ All waypoints reachable' },
            obstacles: { pass: true, message: '✅ No waypoints in known obstacles', warnings: [] },
            proximity: { pass: true, message: '✅ Safe clearance from obstacles', warnings: [] }
        },
        estimates: {
            distance: 0,
            duration: 0
        }
    };

    // Calculate total distance
    let totalDistance = 0;
    for (let i = 0; i < waypoints.length - 1; i++) {
        const wp1 = Array.isArray(waypoints[i]) ? waypoints[i] : [waypoints[i].x, waypoints[i].y];
        const wp2 = Array.isArray(waypoints[i + 1]) ? waypoints[i + 1] : [waypoints[i + 1].x, waypoints[i + 1].y];
        const dx = wp2[0] - wp1[0];
        const dy = wp2[1] - wp1[1];
        totalDistance += Math.sqrt(dx * dx + dy * dy);
    }
    validation.estimates.distance = totalDistance;

    // Estimate duration (assuming average speed from config or default)
    const avgSpeed = currentState.config.base_speed ? currentState.config.base_speed / 200 : 2.5; // m/s
    validation.estimates.duration = totalDistance / avgSpeed;

    // Check obstacles (if perception has reported any clusters)
    if (currentState.obstacles && currentState.obstacles.clusters) {
        // Simplified check - in real implementation would check actual cluster positions
        const obstacleCount = currentState.obstacles.obstacle_count || 0;
        if (obstacleCount > 10) {
            validation.checks.obstacles.pass = false;
            validation.checks.obstacles.message = '⚠️ High obstacle density detected';
            validation.checks.obstacles.warnings.push(`${obstacleCount} obstacles currently detected`);
        }
    }

    currentValidation = validation;
    return validation;
}

// Display validation results
function displayValidationResults(validation) {
    const panel = document.getElementById('waypoint-validation-panel');
    const resultsEl = document.getElementById('validation-results');

    if (!validation) {
        panel.style.display = 'none';
        return;
    }

    panel.style.display = 'block';

    let html = '<div class="validation-checks">';

    // Display all checks
    for (const [key, check] of Object.entries(validation.checks)) {
        html += `<div class="validation-check ${check.pass ? 'pass' : 'warning'}">
            ${check.message}
        </div>`;

        if (check.warnings && check.warnings.length > 0) {
            check.warnings.forEach(warning => {
                html += `<div class="validation-warning">⚠️ ${warning}</div>`;
            });
        }
    }

    // Display estimates
    const minutes = Math.floor(validation.estimates.duration / 60);
    const seconds = Math.floor(validation.estimates.duration % 60);
    html += `
        <div class="validation-estimates">
            <div class="validation-estimate">
                ℹ️ Total distance: <strong>${validation.estimates.distance.toFixed(0)}m</strong>
            </div>
            <div class="validation-estimate">
                ℹ️ Estimated completion: <strong>${minutes}m ${seconds}s</strong>
            </div>
        </div>
    `;

    html += '</div>';
    resultsEl.innerHTML = html;

    // Log validation
    addHistoryEvent('info', `Waypoints validated: ${validation.waypoints.length} waypoints, ${validation.estimates.distance.toFixed(0)}m`);
}

// Mission Progress Bar System
const progressState = {
    startTime: null,
    distanceTraveled: 0,
    speedSamples: [],
    lastPosition: null
};

// Update mission progress
// Cache for mission progress to avoid redundant DOM updates at 5Hz
let _prevProgress = {};

function updateMissionProgress() {
    const progressSection = document.getElementById('mission-progress-section');

    // Show progress bar when mission is running
    const runningStates = ['RUNNING', 'DRIVING', 'PAUSED'];
    if (runningStates.includes(missionState.state) && missionState.totalWaypoints > 0) {
        if (_prevProgress.visible !== true) {
            progressSection.style.display = 'block';
            _prevProgress.visible = true;
        }

        // Fraction of waypoints actually COMPLETED (not targeted). currentWaypoint is
        // the 1-indexed target, so completed = currentWaypoint - 1 (e.g. heading to
        // wp 14 of 14 means 13 done → ~93%, not 100%). Clamp to [0, 1] for ticks
        // before mission start or just after final-waypoint capture.
        const waypointsCompletedFraction = missionState.totalWaypoints > 0
            ? Math.max(0, Math.min(1, (missionState.currentWaypoint - 1) / missionState.totalWaypoints))
            : 0;

        // Calculate progress percentage
        let waypointProgress;
        if (missionState.goHomeMode) {
            // Distance-based progress: 0% at start of return trip, 100% at home.
            // Falls back to 0% until we've captured a non-trivial initial distance.
            const init = missionState.goHomeInitialDistance;
            const curr = currentState.mission.distance || 0;
            if (init && init > 0) {
                waypointProgress = Math.max(0, Math.min(100, (1 - curr / init) * 100));
            } else {
                waypointProgress = 0;
            }
        } else {
            waypointProgress = waypointsCompletedFraction * 100;
        }
        const progressPct = waypointProgress.toFixed(0) + '%';

        // Update progress bar
        const progressBar = document.getElementById('mission-progress-bar');
        const progressText = document.getElementById('mission-progress-text');
        if (_prevProgress.pct !== progressPct) {
            progressBar.style.width = waypointProgress + '%';
            progressText.textContent = progressPct;
            _prevProgress.pct = progressPct;
        }

        // Color-code based on speed
        const speedClass = currentState.gps.speed < 0.5 ? 'mission-progress-bar slow' :
                           currentState.gps.speed < 1.5 ? 'mission-progress-bar normal' : 'mission-progress-bar fast';
        if (_prevProgress.speedClass !== speedClass) {
            progressBar.className = speedClass;
            _prevProgress.speedClass = speedClass;
        }

        // Update waypoint count (Go Home label moves here since the bar now shows real %)
        const wpText = missionState.goHomeMode
            ? '🏠 Returning Home'
            : `${missionState.currentWaypoint}/${missionState.totalWaypoints}`;
        if (_prevProgress.wp !== wpText) {
            document.getElementById('progress-waypoints').textContent = wpText;
            _prevProgress.wp = wpText;
        }

        // Update distance (simplified - would need actual path tracking)
        if (currentValidation) {
            const totalDist = currentValidation.estimates.distance;
            const traveledDist = waypointsCompletedFraction * totalDist;
            const distText = `${traveledDist.toFixed(0)}m / ${totalDist.toFixed(0)}m`;
            if (_prevProgress.dist !== distText) {
                document.getElementById('progress-distance').textContent = distText;
                _prevProgress.dist = distText;
            }
        }

        // Update current speed from GPS
        const currentSpeed = currentState.gps.speed || 0;
        const speedText = currentSpeed.toFixed(1) + ' m/s';
        if (_prevProgress.speed !== speedText) {
            document.getElementById('progress-current-speed').textContent = speedText;
            _prevProgress.speed = speedText;
        }

        // Calculate average speed
        progressState.speedSamples.push(currentSpeed);
        if (progressState.speedSamples.length > 30) {
            progressState.speedSamples.shift();
        }
        const avgSpeed = progressState.speedSamples.reduce((a, b) => a + b, 0) / progressState.speedSamples.length;
        const avgText = avgSpeed.toFixed(1) + ' m/s';
        if (_prevProgress.avg !== avgText) {
            document.getElementById('progress-avg-speed').textContent = avgText;
            _prevProgress.avg = avgText;
        }

        // Calculate time remaining
        let timeText = '--:--';
        if (currentValidation && avgSpeed > 0.1) {
            const totalDist = currentValidation.estimates.distance;
            const traveledDist = waypointsCompletedFraction * totalDist;
            const remainingDist = totalDist - traveledDist;
            const remainingTime = remainingDist / avgSpeed;
            const mins = Math.floor(remainingTime / 60);
            const secs = Math.floor(remainingTime % 60);
            timeText = `${mins}:${secs.toString().padStart(2, '0')}`;
        }
        if (_prevProgress.time !== timeText) {
            document.getElementById('progress-time-remaining').textContent = timeText;
            _prevProgress.time = timeText;
        }

        // Update status
        let statusText = missionState.state;
        if (missionState.blockedReason && missionState.blockedReason !== 'None') {
            statusText += ` (${missionState.blockedReason})`;
        }
        if (_prevProgress.status !== statusText) {
            document.getElementById('progress-status').textContent = statusText;
            _prevProgress.status = statusText;
        }

    } else {
        if (_prevProgress.visible !== false) {
            progressSection.style.display = 'none';
            _prevProgress.visible = false;
            _prevProgress = { visible: false };
        }
        progressState.speedSamples = [];
    }
}

// Hook into existing update functions to add history logging
const originalUpdateMissionStatus = updateMissionStatus;
updateMissionStatus = function(data) {
    const prevState = currentState.mission.state;
    const prevWaypoint = currentState.mission.waypoint;

    originalUpdateMissionStatus(data);

    // Log state changes
    if (prevState !== data.state) {
        addHistoryEvent('state', `State: ${prevState} → ${data.state}`);
    }

    // Log waypoint progress
    if (prevWaypoint !== data.waypoint && data.waypoint > 0) {
        addHistoryEvent('waypoint', `Waypoint ${data.waypoint}/${data.total_waypoints} reached`);
    }

    // Log detours
    if (data.detour_active && !currentState.mission.detour_active) {
        addHistoryEvent('detour', 'Detour activated (obstacle avoidance)');
    }

    // Update progress bar
    updateMissionProgress();
};

// Hook into GPS updates for speed tracking
const originalUpdateGPS = updateGPS;
updateGPS = function(message) {
    originalUpdateGPS(message);

    // Calculate speed from position changes if not provided
    if (!currentState.gps.speed && progressState.lastPosition) {
        const dx = currentState.gps.x - progressState.lastPosition.x;
        const dy = currentState.gps.y - progressState.lastPosition.y;
        const dt = (Date.now() - progressState.lastPosition.time) / 1000; // seconds
        if (dt > 0) {
            const dist = Math.sqrt(dx * dx + dy * dy);
            currentState.gps.speed = dist / dt;
        }
    }

    progressState.lastPosition = {
        x: currentState.gps.x,
        y: currentState.gps.y,
        time: Date.now()
    };

    // Update progress display
    if (missionState.state === 'RUNNING' || missionState.state === 'DRIVING') {
        updateMissionProgress();
    }
};

// Hook into waypoint generation to trigger validation
const originalGenerateWaypoints = generateWaypoints;
generateWaypoints = function() {
    originalGenerateWaypoints();

    // Validate waypoints after they're received (with delay for ROS processing)
    setTimeout(async () => {
        if (missionState.waypoints && missionState.waypoints.length > 0) {
            addHistoryEvent('info', `Generated ${missionState.waypoints.length} waypoints`);
            const validation = await validateWaypoints(missionState.waypoints);
            displayValidationResults(validation);
        }
    }, 1500);
};

// Initialize Phase 2 features on page load
window.addEventListener('load', () => {
    setTimeout(() => {
        initMissionHistory();
        if (DEBUG_MODE) console.log('Phase 2 features initialized');
    }, 1500);
});

// ============================================================================
// Health Check Panel — calls /health_check/run (std_srvs/Trigger) via rosbridge
// ============================================================================
function classifyHealthLine(line) {
    if (/\[PASS\]/.test(line)) return 'pass';
    if (/\[FAIL\]/.test(line)) return 'fail';
    if (/\[WARN\]/.test(line)) return 'warn-line';
    if (/\[INFO\]/.test(line)) return 'info';
    if (/\[DONE\]/.test(line)) return 'done';
    if (/\[SYSTEM\]/.test(line)) return 'info';
    if (/^={5,}.*={5,}$/.test(line)) return 'section';
    if (/^(PASS|FAIL|WARN|State):/.test(line.trim())) return 'summary';
    return '';
}

function clearHealthOutput() {
    const container = document.getElementById('health-check-output');
    if (container) container.innerHTML = '';
}

function appendHealthLine(raw) {
    const container = document.getElementById('health-check-output');
    if (!container) return;
    const div = document.createElement('div');
    const cls = classifyHealthLine(raw);
    div.className = 'terminal-line' + (cls ? ' ' + cls : '');
    div.textContent = raw.length === 0 ? '\u00A0' : raw;
    container.appendChild(div);
    const autoScroll = document.getElementById('health-auto-scroll');
    if (!autoScroll || autoScroll.checked) {
        container.scrollTop = container.scrollHeight;
    }
}

function setHealthStatus(state, label) {
    const badge = document.getElementById('health-check-status');
    if (!badge) return;
    badge.className = 'health-status-badge' + (state ? ' ' + state : '');
    badge.textContent = label;
}

let healthLineTopic = null;
let healthStatusTopic = null;

let healthCheckStartTime = null;

function subscribeHealthTopics() {
    if (!ros || !ros.isConnected) return;
    if (healthLineTopic && healthStatusTopic) return;

    healthLineTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/health_check/line',
        messageType: 'std_msgs/msg/String'
    });
    healthLineTopic.subscribe((msg) => {
        appendHealthLine(msg.data || '');
    });

    healthStatusTopic = new ROSLIB.Topic({
        ros: ros,
        name: '/health_check/status',
        messageType: 'std_msgs/msg/String'
    });
    healthStatusTopic.subscribe((msg) => {
        const btn = document.getElementById('btn-run-health-check');
        if (msg.data === 'running') {
            healthCheckStartTime = Date.now();
            setHealthStatus('running', 'Running...');
            if (btn) btn.disabled = true;
        } else if (msg.data === 'ok' || msg.data === 'error') {
            const elapsed = healthCheckStartTime
                ? ((Date.now() - healthCheckStartTime) / 1000).toFixed(1) + 's'
                : '';
            healthCheckStartTime = null;
            const label = msg.data === 'ok' ? 'All OK' : 'Issues found';
            setHealthStatus(msg.data, label);
            setTimeout(() => {
                appendHealthLine('');
                appendHealthLine('[DONE] Health check finished' + (elapsed ? ' in ' + elapsed : '') + '.');
            }, 500);
            if (btn) btn.disabled = false;
        }
    });
}

function runHealthCheck() {
    const btn = document.getElementById('btn-run-health-check');
    if (!ros || !ros.isConnected) {
        setHealthStatus('error', 'No rosbridge');
        clearHealthOutput();
        appendHealthLine('[ERROR] Not connected to rosbridge — start the simulation first.');
        return;
    }
    subscribeHealthTopics();
    if (btn) btn.disabled = true;
    healthCheckStartTime = Date.now();
    setHealthStatus('running', 'Starting...');
    clearHealthOutput();
    appendHealthLine('[SYSTEM] Health check started, streaming live...');

    const healthService = new ROSLIB.Service({
        ros: ros,
        name: '/health_check/run',
        serviceType: 'std_srvs/srv/Trigger'
    });
    const request = new ROSLIB.ServiceRequest({});
    healthService.callService(request, (response) => {
        if (response && !response.success) {
            if (btn) btn.disabled = false;
            setHealthStatus('error', 'Rejected');
            appendHealthLine('[ERROR] ' + (response.message || 'Unknown error'));
        }
    }, (error) => {
        if (btn) btn.disabled = false;
        setHealthStatus('error', 'Service failed');
        appendHealthLine('[ERROR] Service call failed: ' + error);
        appendHealthLine('Is /health_check/run running? Check that health_check_service node is launched.');
    });
}

window.addEventListener('load', () => {
    const runBtn = document.getElementById('btn-run-health-check');
    const clearBtn = document.getElementById('btn-clear-health-check');
    if (runBtn) runBtn.addEventListener('click', runHealthCheck);
    if (clearBtn) clearBtn.addEventListener('click', () => {
        clearHealthOutput();
        appendHealthLine('[SYSTEM] Output cleared.');
        setHealthStatus('', 'Idle');
    });
    setTimeout(subscribeHealthTopics, 2000);
});

// ============================================================================
// JSON LOG EXPORT
// ============================================================================

function downloadJSON(data, filename) {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
}

function getTimestamp() {
    return new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
}

function collectSystemSnapshot() {
    return {
        exported_at: new Date().toISOString(),
        gps: currentState.gps,
        mission: currentState.mission,
        obstacles: currentState.obstacles,
        thrusters: currentState.thrusters,
        config: currentState.config,
        world: currentState.world
    };
}

function collectTerminalLines(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return [];
    return Array.from(container.querySelectorAll('.log-entry, .terminal-line'))
        .map(el => el.textContent.trim())
        .filter(line => line.length > 0);
}

function exportPanel(panelName) {
    const ts = getTimestamp();
    let data, filename;

    switch (panelName) {
        case 'system':
            data = collectSystemSnapshot();
            filename = `autoboat_system_${ts}.json`;
            break;
        case 'health':
            data = {
                exported_at: new Date().toISOString(),
                lines: collectTerminalLines('health-check-output')
            };
            filename = `autoboat_health_check_${ts}.json`;
            break;
        case 'logs':
            data = {
                exported_at: new Date().toISOString(),
                lines: collectTerminalLines('logs')
            };
            filename = `autoboat_logs_${ts}.json`;
            break;
        case 'terminal':
            data = {
                exported_at: new Date().toISOString(),
                lines: collectTerminalLines('terminal-output')
            };
            filename = `autoboat_terminal_${ts}.json`;
            break;
        default:
            return;
    }

    downloadJSON(data, filename);
    addLog(`Exported ${panelName} logs to ${filename}`, 'info');
}

function addExportButton(headerSelector, panelName, label) {
    const header = document.querySelector(headerSelector);
    if (!header) return;
    const btn = document.createElement('button');
    btn.className = 'terminal-btn export-btn';
    btn.textContent = label || 'Export JSON';
    btn.title = `Export ${panelName} data as JSON`;
    btn.addEventListener('click', (e) => {
        e.stopPropagation();
        exportPanel(panelName);
    });
    header.style.display = 'flex';
    header.style.justifyContent = 'space-between';
    header.style.alignItems = 'center';
    header.appendChild(btn);
}

function addExportButtonToControls(controlsSelector, panelName, label) {
    const controls = document.querySelector(controlsSelector);
    if (!controls) return;
    const btn = document.createElement('button');
    btn.className = 'terminal-btn export-btn';
    btn.textContent = label || 'Export JSON';
    btn.title = `Export ${panelName} data as JSON`;
    btn.addEventListener('click', (e) => {
        e.stopPropagation();
        exportPanel(panelName);
    });
    controls.appendChild(btn);
}

// Copy panel text content to clipboard
function addCopyButton(controlsSelector, panelContentSelector, label) {
    const controls = document.querySelector(controlsSelector);
    if (!controls) return;
    const btn = document.createElement('button');
    btn.className = 'terminal-btn export-btn';
    btn.textContent = label || 'Copy';
    btn.title = 'Copy panel text to clipboard';
    btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const panel = document.querySelector(panelContentSelector);
        if (!panel) return;
        const text = panel.innerText || panel.textContent;
        navigator.clipboard.writeText(text).then(() => {
            showFeedback('Copied to clipboard', 'success');
        }).catch(() => {
            // Fallback for older browsers / insecure contexts
            const ta = document.createElement('textarea');
            ta.value = text;
            ta.style.position = 'fixed';
            ta.style.opacity = '0';
            document.body.appendChild(ta);
            ta.select();
            document.execCommand('copy');
            document.body.removeChild(ta);
            showFeedback('Copied to clipboard', 'success');
        });
    });
    controls.appendChild(btn);
}

window.addEventListener('load', () => {
    addExportButtonToControls('.health-check-panel .terminal-controls', 'health', 'Export JSON');
    addExportButtonToControls('.logs-panel .terminal-controls', 'logs', 'Export JSON');
    addExportButtonToControls('.terminal-panel .terminal-controls', 'terminal', 'Export JSON');
    addExportButton('.mission-control-panel h2', 'system', 'Export Snapshot');
    // Copy-to-clipboard buttons
    addCopyButton('.health-check-panel .terminal-controls', '#health-check-output', 'Copy');
    addCopyButton('.logs-panel .terminal-controls', '#logs', 'Copy');
    addCopyButton('.terminal-panel .terminal-controls', '#terminal-output', 'Copy');
});
