const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dashboardDir = path.join(__dirname, '..');
const appSource = fs.readFileSync(path.join(dashboardDir, 'app.js'), 'utf8');
const htmlSource = fs.readFileSync(path.join(dashboardDir, 'index.html'), 'utf8');
const cssSource = fs.readFileSync(path.join(dashboardDir, 'style_merged.css'), 'utf8');

function sourceBetween(startMarker, endMarker) {
    const start = appSource.indexOf(startMarker);
    const end = appSource.indexOf(endMarker, start);
    assert.notEqual(start, -1, `Missing source marker: ${startMarker}`);
    assert.notEqual(end, -1, `Missing source marker: ${endMarker}`);
    return appSource.slice(start, end);
}

function cameraViewerSource() {
    return sourceBetween(
        '// ========== CAMERA VIEWER PRESENTATION ==========',
        '// ========== END CAMERA VIEWER PRESENTATION =========='
    );
}

function createClassList(initial = []) {
    const classes = new Set(initial);
    return {
        add(...names) { names.forEach((name) => classes.add(name)); },
        remove(...names) { names.forEach((name) => classes.delete(name)); },
        contains(name) { return classes.has(name); },
        toggle(name, force) {
            if (force === undefined) {
                if (classes.has(name)) classes.delete(name);
                else classes.add(name);
            } else if (force) classes.add(name);
            else classes.delete(name);
            return classes.has(name);
        }
    };
}

function createHarness() {
    const elements = new Map();
    const documentListeners = new Map();
    let srcAssignments = 0;
    let srcRemovals = 0;

    const document = {
        activeElement: null,
        body: { classList: createClassList() },
        getElementById(id) { return elements.get(id) || null; },
        addEventListener(type, listener, options) {
            if (!documentListeners.has(type)) documentListeners.set(type, []);
            documentListeners.get(type).push({ listener, options });
        }
    };

    function createElement(id, options = {}) {
        const listeners = new Map();
        const attributes = new Map();
        const styleValues = new Map();
        let srcValue = options.src || '';
        const element = {
            id,
            textContent: options.textContent || '',
            hidden: options.hidden || false,
            disabled: options.disabled || false,
            isConnected: true,
            scrollLeft: 0,
            scrollTop: 0,
            parentNode: options.parentNode || null,
            classList: createClassList(options.classes || []),
            style: {
                setProperty(name, value) { styleValues.set(name, String(value)); },
                getPropertyValue(name) { return styleValues.get(name) || ''; },
                removeProperty(name) { styleValues.delete(name); }
            },
            addEventListener(type, listener) {
                if (!listeners.has(type)) listeners.set(type, []);
                listeners.get(type).push(listener);
            },
            dispatch(type, event = {}) {
                event.target ||= element;
                event.currentTarget = element;
                for (const listener of listeners.get(type) || []) listener(event);
            },
            setAttribute(name, value) {
                if (name === 'src') {
                    srcAssignments += 1;
                    srcValue = String(value);
                }
                attributes.set(name, String(value));
            },
            getAttribute(name) { return attributes.has(name) ? attributes.get(name) : null; },
            hasAttribute(name) { return attributes.has(name); },
            removeAttribute(name) {
                if (name === 'src') {
                    srcRemovals += 1;
                    srcValue = '';
                }
                attributes.delete(name);
            },
            focus(optionsArg) {
                document.activeElement = element;
                element.lastFocusOptions = optionsArg;
            },
            querySelectorAll() { return element.focusables || []; }
        };
        Object.defineProperty(element, 'src', {
            get() { return srcValue; },
            set(value) { srcAssignments += 1; srcValue = value; }
        });
        for (const [name, value] of Object.entries(options.attributes || {})) {
            element.setAttribute(name, value);
        }
        elements.set(id, element);
        return element;
    }

    const viewer = createElement('camera-viewer', { classes: ['camera-container'] });
    const toolbar = createElement('camera-viewer-controls', { hidden: true });
    const feed = createElement('camera-feed', { parentNode: viewer });
    const image = createElement('camera-image', {
        parentNode: feed,
        src: 'http://localhost:8080/stream?topic=/hailo/overlay/image_raw',
        attributes: {
            role: 'button',
            tabindex: '0',
            'aria-haspopup': 'dialog',
            'aria-controls': 'camera-viewer',
            'aria-expanded': 'false'
        }
    });
    const enlarge = createElement('btn-enlarge-camera', {
        attributes: {
            'aria-haspopup': 'dialog',
            'aria-controls': 'camera-viewer',
            'aria-expanded': 'false'
        }
    });
    const zoomOut = createElement('btn-camera-zoom-out');
    const readout = createElement('camera-zoom-level', { textContent: '1.0×' });
    const zoomIn = createElement('btn-camera-zoom-in');
    const reset = createElement('btn-camera-zoom-reset');
    const close = createElement('btn-camera-viewer-close');
    viewer.focusables = [zoomOut, zoomIn, reset, close, feed];
    document.activeElement = enlarge;

    const context = { document, console, onboardingState: { backdrop: null } };
    vm.createContext(context);
    vm.runInContext(
        `let cameraImageEl = document.getElementById('camera-image');\n` +
        `${cameraViewerSource()}\n` +
        `globalThis.__cameraViewerApi = {
            CAMERA_VIEWER_MIN_ZOOM,
            CAMERA_VIEWER_MAX_ZOOM,
            CAMERA_VIEWER_ZOOM_STEP,
            initCameraViewer,
            openCameraViewer,
            closeCameraViewer,
            adjustCameraViewerZoom,
            resetCameraViewerZoom,
            setCameraViewerImageAvailable,
            getState: () => ({
                open: cameraViewerOpen,
                zoom: cameraViewerZoom,
                imageAvailable: cameraViewerImageAvailable,
                opener: cameraViewerOpener
            })
        };`,
        context
    );
    context.__cameraViewerApi.initCameraViewer();

    function keyEvent(key, options = {}) {
        return {
            key,
            shiftKey: options.shiftKey || false,
            defaultPrevented: false,
            propagationStopped: false,
            preventDefault() { this.defaultPrevented = true; },
            stopImmediatePropagation() { this.propagationStopped = true; }
        };
    }

    function dispatchDocumentKeydown(event) {
        for (const { listener } of documentListeners.get('keydown') || []) listener(event);
    }

    return {
        api: context.__cameraViewerApi,
        document,
        documentListeners,
        elements: { viewer, toolbar, feed, image, enlarge, zoomOut, readout, zoomIn, reset, close },
        keyEvent,
        dispatchDocumentKeydown,
        getSrcAssignments: () => srcAssignments,
        getSrcRemovals: () => srcRemovals
    };
}

test('camera viewer keeps one image and leaves stream ownership unchanged', () => {
    assert.equal((htmlSource.match(/id="camera-image"/g) || []).length, 1);
    const viewerMarkupStart = htmlSource.indexOf('id="camera-viewer"');
    const viewerMarkupEnd = htmlSource.indexOf('<div class="camera-controls">', viewerMarkupStart);
    assert.notEqual(viewerMarkupStart, -1);
    assert.notEqual(viewerMarkupEnd, -1);
    assert.equal((htmlSource.slice(viewerMarkupStart, viewerMarkupEnd).match(/<img\b/g) || []).length, 1);
    assert.match(htmlSource, /id="camera-image"[^>]*alt="Live front camera feed \| Flux caméra avant"/);
    for (const id of [
        'camera-viewer',
        'camera-viewer-controls',
        'btn-enlarge-camera',
        'btn-camera-zoom-out',
        'camera-zoom-level',
        'btn-camera-zoom-in',
        'btn-camera-zoom-reset',
        'btn-camera-viewer-close'
    ]) {
        assert.match(htmlSource, new RegExp(`id="${id}"`), `Missing #${id}`);
    }

    const viewerSource = cameraViewerSource();
    assert.doesNotMatch(viewerSource, /\.src\s*=/);
    assert.doesNotMatch(viewerSource, /setAttribute\(\s*['"]src['"]/);
    assert.doesNotMatch(viewerSource, /removeAttribute\(\s*['"]src['"]\s*\)/);
    assert.doesNotMatch(viewerSource, /\b(?:buildCameraUrl|updateCameraStream)\s*\(/);
    assert.doesNotMatch(viewerSource, /\b(?:cloneNode|replaceWith|replaceChild|appendChild|append|prepend)\s*\(/);

    const streamOwner = sourceBetween('function updateCameraStream() {', 'function buildCameraUrl(topic) {');
    assert.equal((streamOwner.match(/removeAttribute\(\s*['"]src['"]\s*\)/g) || []).length, 1);
    assert.equal((streamOwner.match(/cameraImageEl\.src\s*=/g) || []).length, 1);
    assert.equal((appSource.match(/cameraImageEl\.setAttribute\(\s*['"]src['"]/g) || []).length, 0);
    assert.equal((appSource.match(/cameraImageEl\.removeAttribute\(\s*['"]src['"]\s*\)/g) || []).length, 1);
    assert.equal((appSource.match(/cameraImageEl\.src\s*=/g) || []).length, 1);
    assert.match(cssSource, /\.camera-container\.camera-viewer-open[\s\S]*?position:\s*fixed/);
    assert.match(cssSource, /\.camera-container\.camera-viewer-open[\s\S]*?--camera-viewer-scale/);
    assert.match(
        cssSource,
        /\.camera-container\.camera-viewer-open #camera-image\s*\{[\s\S]*?zoom:\s*var\(--camera-viewer-scale,\s*1\)/
    );
});

test('open and close are idempotent and preserve the image node and URL', () => {
    const harness = createHarness();
    const { api, elements, document } = harness;
    const originalParent = elements.image.parentNode;
    const originalSrc = elements.image.src;

    elements.enlarge.dispatch('click');
    assert.equal(api.getState().open, true);
    assert.equal(api.getState().opener, elements.enlarge);
    assert.equal(elements.viewer.classList.contains('camera-viewer-open'), true);
    assert.equal(document.body.classList.contains('camera-viewer-active'), true);
    assert.equal(elements.viewer.getAttribute('role'), 'dialog');
    assert.equal(elements.viewer.getAttribute('aria-modal'), 'true');
    assert.equal(elements.viewer.getAttribute('aria-labelledby'), 'camera-viewer-title');
    assert.equal(elements.toolbar.hidden, false);
    assert.equal(document.activeElement, elements.close);
    assert.equal(elements.feed.getAttribute('role'), 'region');
    assert.equal(elements.feed.getAttribute('tabindex'), '0');
    assert.equal(elements.image.getAttribute('tabindex'), '-1');
    assert.equal(elements.image.hasAttribute('role'), false);
    assert.equal(elements.image.hasAttribute('aria-controls'), false);
    assert.equal(elements.enlarge.getAttribute('aria-expanded'), 'true');
    assert.equal(elements.image.hasAttribute('aria-expanded'), false);

    assert.equal(api.openCameraViewer(elements.image), false);
    assert.equal(api.getState().opener, elements.enlarge);

    api.adjustCameraViewerZoom(1.5);
    elements.feed.scrollLeft = 25;
    elements.feed.scrollTop = 40;
    assert.equal(api.closeCameraViewer(), true);
    assert.equal(api.closeCameraViewer(), false);
    assert.equal(api.getState().open, false);
    assert.equal(api.getState().zoom, 1);
    assert.equal(elements.feed.scrollLeft, 0);
    assert.equal(elements.feed.scrollTop, 0);
    assert.equal(elements.viewer.classList.contains('camera-viewer-open'), false);
    assert.equal(document.body.classList.contains('camera-viewer-active'), false);
    assert.equal(elements.toolbar.hidden, true);
    assert.equal(elements.viewer.hasAttribute('role'), false);
    assert.equal(elements.feed.hasAttribute('tabindex'), false);
    assert.equal(elements.image.getAttribute('role'), 'button');
    assert.equal(elements.image.getAttribute('tabindex'), '0');
    assert.equal(elements.image.getAttribute('aria-controls'), 'camera-viewer');
    assert.equal(elements.image.getAttribute('aria-expanded'), 'false');
    assert.equal(document.activeElement, elements.enlarge);
    assert.equal(elements.image.parentNode, originalParent);
    assert.equal(elements.image.src, originalSrc);
    assert.equal(harness.getSrcAssignments(), 0);
    assert.equal(harness.getSrcRemovals(), 0);

    elements.image.dispatch('click');
    assert.equal(api.getState().open, true);
    elements.close.dispatch('click');
    assert.equal(api.getState().open, false);
    assert.equal(document.activeElement, elements.image);
    assert.equal(elements.image.parentNode, originalParent);
    assert.equal(elements.image.src, originalSrc);
    assert.equal(harness.getSrcAssignments(), 0);
    assert.equal(harness.getSrcRemovals(), 0);
});

test('zoom uses half-step bounded state and reset clears the viewport', () => {
    const harness = createHarness();
    const { api, elements } = harness;
    api.openCameraViewer(elements.enlarge);

    assert.equal(elements.readout.textContent, '1.0×');
    assert.equal(elements.zoomOut.disabled, true);
    assert.equal(elements.reset.disabled, false);
    assert.equal(elements.zoomIn.disabled, false);

    elements.zoomIn.dispatch('click');
    assert.equal(api.getState().zoom, 1.5);
    elements.zoomOut.dispatch('click');
    assert.equal(api.getState().zoom, 1);

    elements.feed.scrollLeft = 15;
    elements.feed.scrollTop = 20;
    elements.reset.dispatch('click');
    assert.equal(elements.feed.scrollLeft, 0);
    assert.equal(elements.feed.scrollTop, 0);

    for (let i = 0; i < 12; i += 1) api.adjustCameraViewerZoom(0.5);
    assert.equal(api.getState().zoom, 4);
    assert.equal(elements.readout.textContent, '4.0×');
    assert.equal(elements.zoomIn.disabled, true);
    assert.equal(elements.zoomOut.disabled, false);
    assert.equal(elements.image.style.getPropertyValue('--camera-viewer-scale'), '4');

    for (let i = 0; i < 12; i += 1) api.adjustCameraViewerZoom(-0.5);
    assert.equal(api.getState().zoom, 1);
    assert.equal(elements.zoomOut.disabled, true);

    api.adjustCameraViewerZoom(1.5);
    elements.feed.scrollLeft = 70;
    elements.feed.scrollTop = 90;
    elements.reset.dispatch('click');
    assert.equal(api.getState().zoom, 1);
    assert.equal(elements.readout.textContent, '1.0×');
    assert.equal(elements.feed.scrollLeft, 0);
    assert.equal(elements.feed.scrollTop, 0);
    assert.equal(harness.getSrcAssignments(), 0);
    assert.equal(harness.getSrcRemovals(), 0);
});

test('Escape and Tab are contained only while the viewer is open', () => {
    const harness = createHarness();
    const { api, elements, document } = harness;
    const closedEscape = harness.keyEvent('Escape');
    harness.dispatchDocumentKeydown(closedEscape);
    assert.equal(closedEscape.defaultPrevented, false);
    assert.equal(closedEscape.propagationStopped, false);

    const openKey = harness.keyEvent('Enter');
    elements.image.dispatch('keydown', openKey);
    assert.equal(openKey.defaultPrevented, true);
    assert.equal(api.getState().open, true);

    document.activeElement = elements.feed;
    const forwardTab = harness.keyEvent('Tab');
    harness.dispatchDocumentKeydown(forwardTab);
    assert.equal(forwardTab.defaultPrevented, true);
    assert.equal(document.activeElement, elements.zoomIn);

    const reverseTab = harness.keyEvent('Tab', { shiftKey: true });
    harness.dispatchDocumentKeydown(reverseTab);
    assert.equal(reverseTab.defaultPrevented, true);
    assert.equal(document.activeElement, elements.feed);

    const openEscape = harness.keyEvent('Escape');
    harness.dispatchDocumentKeydown(openEscape);
    assert.equal(openEscape.defaultPrevented, true);
    assert.equal(openEscape.propagationStopped, true);
    assert.equal(api.getState().open, false);
    assert.equal(document.activeElement, elements.image);

    const listenerRecords = harness.documentListeners.get('keydown') || [];
    assert.equal(listenerRecords.length, 1);
    assert.equal(listenerRecords[0].options.capture, true);
});

test('image error disables zoom and a later load restores controls without stream churn', () => {
    const harness = createHarness();
    const { api, elements } = harness;
    api.openCameraViewer(elements.enlarge);
    api.adjustCameraViewerZoom(1.5);
    assert.equal(api.getState().zoom, 2.5);

    api.setCameraViewerImageAvailable(false);
    assert.equal(api.getState().imageAvailable, false);
    assert.equal(elements.zoomOut.disabled, true);
    assert.equal(elements.zoomIn.disabled, true);
    assert.equal(elements.reset.disabled, true);
    assert.equal(elements.close.disabled, false);
    assert.equal(api.getState().zoom, 2.5);

    const documentActiveBefore = harness.document.activeElement;
    api.setCameraViewerImageAvailable(true);
    assert.equal(api.getState().imageAvailable, true);
    assert.equal(elements.zoomOut.disabled, false);
    assert.equal(elements.zoomIn.disabled, false);
    assert.equal(elements.reset.disabled, false);
    assert.equal(api.getState().zoom, 2.5);
    assert.equal(harness.document.activeElement, documentActiveBefore);
    assert.equal(harness.getSrcAssignments(), 0);
    assert.equal(harness.getSrcRemovals(), 0);

    const cameraInit = sourceBetween('function initCameraFeed() {', '// ROS topic name pattern:');
    assert.match(cameraInit, /initCameraViewer\(\)/);
    assert.match(cameraInit, /addEventListener\(['"]load['"][\s\S]*?setCameraViewerImageAvailable\(true\)[\s\S]*?dataset\.userError/);
    assert.match(cameraInit, /addEventListener\(['"]error['"][\s\S]*?setCameraViewerImageAvailable\(false\)/);

    const rosClose = sourceBetween("ros.on('close',", '// Initialize camera/RViz stream panel');
    assert.doesNotMatch(rosClose, /\b(?:openCameraViewer|closeCameraViewer|updateCameraStream)\s*\(/);
    assert.doesNotMatch(rosClose, /camera(?:Image|Status|Viewer|Topic|Feed)|camera-|#camera/i);
});
