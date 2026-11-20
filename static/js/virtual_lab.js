/**
 * Learnix AI — Virtual Lab Layout & Interactive Circuit Controller
 * 
 * Features:
 *  - Drag & drop components from tray onto breadboard canvas (or click +)
 *  - Interactive pins on Arduino Uno, breadboard rails, and placed components
 *  - Click pin 1 then pin 2 to draw a natural drooping jumper wire
 *  - Click any wire to delete it (with hitbox and hover feedback)
 *  - Drag placed components to reposition (all attached wires dynamically follow!)
 *  - Real-time Circuit JSON synchronization: list of { from: "LED1.anode", to: "D13" }
 *  - Sleek debug panel with live JSON view, Copy to Clipboard, and Clear Wires
 *  - JavaScript Arduino Simulator: pinMode, digitalWrite, digitalRead, delay, if/else, setup(), loop()
 *  - Circuit graph analysis: LED glows when pin is HIGH and correctly wired to GND through resistor
 *  - AI Lab Partner Chat Bubble: If LED doesn't light as expected, calls /api/lab/check & shows praise + Socratic hint
 *  - Web Audio tone/noTone synthesizer for Buzzer + Push Button experiment
 *  - readDistance() with interactive slider for Distance Alarm experiment
 */

// Global State
let allExperiments = [];
let currentExperiment = null;
let currentExperimentId = 1;

// Circuit & Wiring State
const circuitState = {
  components: [], // [{ id, type, x, y, name }]
  wires: [],      // [{ from, to, color }]
  counters: {
    LED: 0,
    Resistor: 0,
    Button: 0,
    Buzzer: 0,
    HCSR04: 0,
  }
};

// Wire Drawing Interaction State
const wireDraw = {
  isDrawing: false,
  startPin: null, // { id, x, y, el }
};

// Component Dragging State (on canvas)
const compDrag = {
  isDragging: false,
  comp: null,
  dragOffset: { x: 0, y: 0 },
};

// Interactive Hardware State (Exp 2 Button & Exp 3 Sensor)
const hardwareState = {
  isButtonPressed: false,
  sensorDistance: 15, // cm
};

// Web Audio API Context & State
let audioCtx = null;
let activeOscillator = null;
let activeGainNode = null;

// DOM Elements
const expSelect = document.getElementById("exp-select");
const expGoalText = document.getElementById("exp-goal-text");
const codeEditor = document.getElementById("code-editor");
const btnRun = document.getElementById("btn-run");
const btnReset = document.getElementById("btn-reset");
const consoleOutput = document.getElementById("console-output");
const activeCompCount = document.getElementById("active-comp-count");
const wireCountBadge = document.getElementById("wire-count");
const canvasHintText = document.getElementById("canvas-hint-text");
const wireDrawingStatus = document.getElementById("wire-drawing-status");

// Interactive Hardware Bar Elements
const interactiveHardwareBar = document.getElementById("interactive-hardware-bar");
const distanceControlGroup = document.getElementById("distance-control-group");
const distanceSlider = document.getElementById("distance-slider");
const distanceValDisplay = document.getElementById("distance-val-display");
const distanceStatusPill = document.getElementById("distance-status-pill");
const buttonControlGroup = document.getElementById("button-control-group");
const btnPressVirtual = document.getElementById("btn-press-virtual");
const buttonStatePill = document.getElementById("button-state-pill");

// AI Lab Partner Chat Bubble Elements
const aiLabPartnerBubble = document.getElementById("ai-lab-partner-bubble");
const partnerExpTitle = document.getElementById("partner-exp-title");
const partnerPraiseText = document.getElementById("partner-praise-text");
const partnerHintText = document.getElementById("partner-hint-text");
const partnerFix = document.getElementById("partner-fix");
const partnerFixText = document.getElementById("partner-fix-text");
const btnClosePartnerBubble = document.getElementById("btn-close-partner-bubble");
const btnAskDirectFix = document.getElementById("btn-ask-direct-fix");
const btnGotIt = document.getElementById("btn-got-it");

// SVG Canvas & Layers
const breadboardSvg = document.getElementById("breadboard-svg");
const placedCompsLayer = document.getElementById("placed-components-layer");
const wiresLayer = document.getElementById("wires-layer");
const tempWire = document.getElementById("temp-wire");
const pinMarkersLayer = document.getElementById("pin-markers-layer");

// Debug Panel Elements
const circuitDebugPanel = document.getElementById("circuit-debug-panel");
const circuitJsonView = document.getElementById("circuit-json-view");
const debugWireCount = document.getElementById("debug-wire-count");
const btnCopyCircuit = document.getElementById("btn-copy-circuit");
const btnClearCircuit = document.getElementById("btn-clear-circuit");
const btnToggleDebug = document.getElementById("btn-toggle-debug");
const btnToggleDebugTop = document.getElementById("btn-toggle-debug-top");

// ============================================================================
// 1. INITIALIZATION
// ============================================================================
async function initVirtualLab() {
  logConsole("Initializing Learnix Virtual Lab engine...", "ready");
  setupTrayDragAndDrop();
  setupCanvasEvents();
  setupArduinoPins();
  setupDebugPanelEvents();
  setupPartnerBubbleEvents();
  setupHardwareControls();
  setupAppEvents();
  updateCircuitDebugView();

  await loadExperiments();
}

// ============================================================================
// 2. COORDINATE TRANSFORM HELPER
// ============================================================================
function getSvgCoords(evt) {
  if (!breadboardSvg) return { x: 0, y: 0 };
  const pt = breadboardSvg.createSVGPoint();
  pt.x = evt.clientX;
  pt.y = evt.clientY;
  const svgP = pt.matrixTransform(breadboardSvg.getScreenCTM().inverse());
  return {
    x: Math.round(Math.max(10, Math.min(750, svgP.x))),
    y: Math.round(Math.max(10, Math.min(470, svgP.y))),
  };
}

// ============================================================================
// 3. COMPONENT DEFINITIONS & GENERATION
// ============================================================================
const COMPONENT_DEFS = {
  "LED": {
    type: "LED",
    prefix: "LED",
    label: "LED (Red)",
    width: 60,
    height: 70,
    pins: [
      { idSuffix: "anode", name: "Anode (+)", offsetX: 18, offsetY: 62, role: "pos" },
      { idSuffix: "cathode", name: "Cathode (-)", offsetX: 38, offsetY: 62, role: "neg" },
    ],
    render(comp) {
      return `
        <g class="placed-comp" id="comp-${comp.id}" data-id="${comp.id}" transform="translate(${comp.x}, ${comp.y})">
          <rect x="0" y="0" width="56" height="70" rx="8" fill="rgba(239, 68, 68, 0.04)" stroke="rgba(239, 68, 68, 0.2)" stroke-dasharray="3 2" />
          
          <!-- Outer Radiance Glow (Active when HIGH & complete circuit) -->
          <circle id="led-radiance-${comp.id}" cx="28" cy="30" r="32" fill="url(#led-radiance)" opacity="0" pointer-events="none" style="transition: opacity 0.15s ease;" />

          <!-- LED Bulb -->
          <path id="led-bulb-${comp.id}" d="M 16 35 A 12 12 0 1 1 40 35 L 40 42 L 16 42 Z" fill="#991b1b" stroke="#7f1d1d" stroke-width="1.5" style="transition: fill 0.15s, stroke 0.15s;" />
          <path id="led-shine-${comp.id}" d="M 20 26 A 7 7 0 0 1 32 18" stroke="#fca5a5" stroke-width="2" fill="none" stroke-linecap="round" opacity="0.4" />
          <rect x="14" y="42" width="28" height="3" rx="1" fill="#7f1d1d" />
          
          <!-- Anode Leg (+) -->
          <line x1="22" y1="45" x2="18" y2="62" stroke="#94a3b8" stroke-width="2.5" stroke-linecap="round" />
          <!-- Cathode Leg (-) -->
          <line x1="34" y1="45" x2="38" y2="62" stroke="#94a3b8" stroke-width="2.5" stroke-linecap="round" />

          <!-- Terminal Pins -->
          <circle cx="18" cy="62" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.anode" data-pin-name="${comp.id} Anode (+)" />
          <text x="18" y="55" font-size="7" font-weight="bold" fill="#ef4444" text-anchor="middle">+</text>

          <circle cx="38" cy="62" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.cathode" data-pin-name="${comp.id} Cathode (-)" />
          <text x="38" y="55" font-size="7" font-weight="bold" fill="#3b82f6" text-anchor="middle">-</text>

          <text x="28" y="10" font-size="9" font-weight="bold" fill="#0f172a" text-anchor="middle">${comp.id}</text>

          <g class="comp-del-btn" data-id="${comp.id}" transform="translate(44, 4)">
            <circle cx="6" cy="6" r="6" fill="#ef4444" />
            <text x="6" y="9" font-size="9" fill="white" font-weight="bold" text-anchor="middle">×</text>
          </g>
        </g>
      `;
    }
  },

  "220 ohm Resistor": {
    type: "Resistor",
    prefix: "R",
    label: "220Ω Resistor",
    width: 85,
    height: 38,
    pins: [
      { idSuffix: "pin1", name: "Pin 1", offsetX: 6, offsetY: 18, role: "signal" },
      { idSuffix: "pin2", name: "Pin 2", offsetX: 78, offsetY: 18, role: "signal" },
    ],
    render(comp) {
      return `
        <g class="placed-comp" id="comp-${comp.id}" data-id="${comp.id}" transform="translate(${comp.x}, ${comp.y})">
          <rect x="0" y="0" width="84" height="36" rx="6" fill="rgba(217, 119, 6, 0.05)" stroke="rgba(217, 119, 6, 0.2)" stroke-dasharray="3 2" />
          
          <line x1="6" y1="18" x2="24" y2="18" stroke="#94a3b8" stroke-width="2.5" />
          <line x1="60" y1="18" x2="78" y2="18" stroke="#94a3b8" stroke-width="2.5" />

          <rect x="24" y="9" width="36" height="18" rx="4" fill="#fde68a" stroke="#d97706" stroke-width="1.5" />
          
          <!-- Color Bands: 220Ω (Red, Red, Brown, Gold) -->
          <rect x="31" y="9" width="3.5" height="18" fill="#dc2626" />
          <rect x="38" y="9" width="3.5" height="18" fill="#dc2626" />
          <rect x="45" y="9" width="3.5" height="18" fill="#78350f" />
          <rect x="52" y="9" width="2.5" height="18" fill="#eab308" />

          <circle cx="6" cy="18" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.pin1" data-pin-name="${comp.id} Pin 1" />
          <circle cx="78" cy="18" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.pin2" data-pin-name="${comp.id} Pin 2" />

          <text x="42" y="32" font-size="7.5" font-weight="bold" fill="#475569" text-anchor="middle">220Ω (${comp.id})</text>

          <g class="comp-del-btn" data-id="${comp.id}" transform="translate(72, 2)">
            <circle cx="6" cy="6" r="6" fill="#ef4444" />
            <text x="6" y="9" font-size="9" fill="white" font-weight="bold" text-anchor="middle">×</text>
          </g>
        </g>
      `;
    }
  },

  "Push Button": {
    type: "Button",
    prefix: "Button",
    label: "Push Button",
    width: 65,
    height: 55,
    pins: [
      { idSuffix: "pin1", name: "Pin 1", offsetX: 6, offsetY: 26, role: "signal" },
      { idSuffix: "pin2", name: "Pin 2", offsetX: 58, offsetY: 26, role: "signal" },
    ],
    render(comp) {
      return `
        <g class="placed-comp" id="comp-${comp.id}" data-id="${comp.id}" transform="translate(${comp.x}, ${comp.y})">
          <rect x="0" y="0" width="64" height="52" rx="6" fill="rgba(15, 23, 42, 0.05)" stroke="rgba(15, 23, 42, 0.2)" stroke-dasharray="3 2" />
          
          <!-- Button Body -->
          <rect x="14" y="8" width="36" height="36" rx="4" fill="#1e293b" stroke="#0f172a" stroke-width="1.5" />
          
          <!-- Interactive Tactile Plunger -->
          <circle id="btn-plunger-${comp.id}" cx="32" cy="26" r="11" fill="#ef4444" stroke="#b91c1c" stroke-width="2" class="interactive-btn-plunger" style="cursor: pointer; transition: transform 0.08s, fill 0.08s;" />
          <circle cx="30" cy="24" r="3" fill="#fca5a5" opacity="0.6" pointer-events="none" />

          <line x1="6" y1="26" x2="14" y2="26" stroke="#94a3b8" stroke-width="2.5" />
          <line x1="50" y1="26" x2="58" y2="26" stroke="#94a3b8" stroke-width="2.5" />

          <circle cx="6" cy="26" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.pin1" data-pin-name="${comp.id} Pin 1" />
          <circle cx="58" cy="26" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.pin2" data-pin-name="${comp.id} Pin 2" />

          <text x="32" y="49" font-size="7.5" font-weight="bold" fill="#64748b" text-anchor="middle">${comp.id}</text>

          <g class="comp-del-btn" data-id="${comp.id}" transform="translate(52, 2)">
            <circle cx="6" cy="6" r="6" fill="#ef4444" />
            <text x="6" y="9" font-size="9" fill="white" font-weight="bold" text-anchor="middle">×</text>
          </g>
        </g>
      `;
    }
  },

  "Buzzer": {
    type: "Buzzer",
    prefix: "Buzzer",
    label: "Buzzer",
    width: 65,
    height: 70,
    pins: [
      { idSuffix: "positive", name: "Positive (+)", offsetX: 18, offsetY: 62, role: "pos" },
      { idSuffix: "negative", name: "Negative (-)", offsetX: 46, offsetY: 62, role: "neg" },
    ],
    render(comp) {
      return `
        <g class="placed-comp" id="comp-${comp.id}" data-id="${comp.id}" transform="translate(${comp.x}, ${comp.y})">
          <rect x="0" y="0" width="64" height="68" rx="8" fill="rgba(15, 23, 42, 0.05)" stroke="rgba(15, 23, 42, 0.2)" stroke-dasharray="3 2" />
          
          <!-- Sound Wave Ripples (Visible during tone) -->
          <g id="buzzer-waves-${comp.id}" style="display: none;">
            <path d="M 6 22 A 18 18 0 0 0 6 38" stroke="#38bdf8" stroke-width="2" fill="none" class="buzzer-sound-wave" />
            <path d="M 58 22 A 18 18 0 0 1 58 38" stroke="#38bdf8" stroke-width="2" fill="none" class="buzzer-sound-wave" />
          </g>

          <!-- Piezo Body -->
          <circle id="buzzer-body-${comp.id}" cx="32" cy="30" r="22" fill="#0f172a" stroke="#334155" stroke-width="2" style="transition: stroke 0.15s;" />
          <circle cx="32" cy="30" r="13" fill="#1e293b" />
          <circle cx="32" cy="30" r="4" fill="#020617" />
          <text x="21" y="24" fill="#ef4444" font-size="11" font-weight="bold">+</text>

          <line x1="18" y1="50" x2="18" y2="62" stroke="#94a3b8" stroke-width="2.5" />
          <line x1="46" y1="50" x2="46" y2="62" stroke="#94a3b8" stroke-width="2.5" />

          <circle cx="18" cy="62" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.positive" data-pin-name="${comp.id} Positive (+)" />
          <circle cx="46" cy="62" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.negative" data-pin-name="${comp.id} Negative (-)" />

          <text x="32" y="10" font-size="8" font-weight="bold" fill="#0f172a" text-anchor="middle">${comp.id}</text>

          <g class="comp-del-btn" data-id="${comp.id}" transform="translate(50, 2)">
            <circle cx="6" cy="6" r="6" fill="#ef4444" />
            <text x="6" y="9" font-size="9" fill="white" font-weight="bold" text-anchor="middle">×</text>
          </g>
        </g>
      `;
    }
  },

  "HC-SR04 Ultrasonic Sensor": {
    type: "HCSR04",
    prefix: "HCSR04_",
    label: "HC-SR04 Ultrasonic Sensor",
    width: 95,
    height: 72,
    pins: [
      { idSuffix: "VCC", name: "VCC", offsetX: 20, offsetY: 64, role: "pos" },
      { idSuffix: "TRIG", name: "TRIG", offsetX: 38, offsetY: 64, role: "signal" },
      { idSuffix: "ECHO", name: "ECHO", offsetX: 57, offsetY: 64, role: "signal" },
      { idSuffix: "GND", name: "GND", offsetX: 76, offsetY: 64, role: "neg" },
    ],
    render(comp) {
      return `
        <g class="placed-comp" id="comp-${comp.id}" data-id="${comp.id}" transform="translate(${comp.x}, ${comp.y})">
          <rect x="0" y="0" width="96" height="72" rx="6" fill="rgba(2, 132, 199, 0.05)" stroke="rgba(2, 132, 199, 0.2)" stroke-dasharray="3 2" />
          
          <rect x="8" y="8" width="80" height="42" rx="4" fill="#0284c7" stroke="#0369a1" stroke-width="1.5" />
          <rect x="43" y="16" width="10" height="18" rx="2" fill="#cbd5e1" stroke="#94a3b8" />
          
          <circle cx="26" cy="28" r="13" fill="#cbd5e1" stroke="#475569" stroke-width="1.5" />
          <circle cx="26" cy="28" r="7" fill="#64748b" />
          <text x="26" y="24" font-size="7" font-weight="bold" fill="#0f172a" text-anchor="middle">T</text>
          
          <circle cx="70" cy="28" r="13" fill="#cbd5e1" stroke="#475569" stroke-width="1.5" />
          <circle cx="70" cy="28" r="7" fill="#64748b" />
          <text x="70" y="24" font-size="7" font-weight="bold" fill="#0f172a" text-anchor="middle">R</text>

          <line x1="20" y1="50" x2="20" y2="64" stroke="#94a3b8" stroke-width="2" />
          <line x1="38" y1="50" x2="38" y2="64" stroke="#94a3b8" stroke-width="2" />
          <line x1="57" y1="50" x2="57" y2="64" stroke="#94a3b8" stroke-width="2" />
          <line x1="76" y1="50" x2="76" y2="64" stroke="#94a3b8" stroke-width="2" />

          <circle cx="20" cy="64" r="5" fill="#38bdf8" stroke="#0284c7" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.VCC" data-pin-name="${comp.id} VCC" />
          <text x="20" y="47" font-size="6" fill="#f8fafc" text-anchor="middle">VCC</text>

          <circle cx="38" cy="64" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.TRIG" data-pin-name="${comp.id} TRIG" />
          <text x="38" y="47" font-size="6" fill="#f8fafc" text-anchor="middle">TRIG</text>

          <circle cx="57" cy="64" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.ECHO" data-pin-name="${comp.id} ECHO" />
          <text x="57" y="47" font-size="6" fill="#f8fafc" text-anchor="middle">ECHO</text>

          <circle cx="76" cy="64" r="5" fill="#facc15" stroke="#ca8a04" stroke-width="1.5" class="pin-terminal comp-pin" data-pin-id="${comp.id}.GND" data-pin-name="${comp.id} GND" />
          <text x="76" y="47" font-size="6" fill="#f8fafc" text-anchor="middle">GND</text>

          <text x="48" y="8" font-size="8" font-weight="bold" fill="#0f172a" text-anchor="middle">${comp.id}</text>

          <g class="comp-del-btn" data-id="${comp.id}" transform="translate(82, 2)">
            <circle cx="6" cy="6" r="6" fill="#ef4444" />
            <text x="6" y="9" font-size="9" fill="white" font-weight="bold" text-anchor="middle">×</text>
          </g>
        </g>
      `;
    }
  }
};

COMPONENT_DEFS["Resistor"] = COMPONENT_DEFS["220 ohm Resistor"];
COMPONENT_DEFS["HC-SR04"] = COMPONENT_DEFS["HC-SR04 Ultrasonic Sensor"];
COMPONENT_DEFS["HCSR04"] = COMPONENT_DEFS["HC-SR04 Ultrasonic Sensor"];

// ============================================================================
// 4. ADD & REMOVE COMPONENTS
// ============================================================================
function addComponent(nameOrType, customX = null, customY = null) {
  const defKey = Object.keys(COMPONENT_DEFS).find(
    k => k.toLowerCase() === (nameOrType || "").trim().toLowerCase()
  );
  if (!defKey) {
    if (nameOrType === "Arduino Uno") {
      logConsole("ℹ️ Arduino Uno is already mounted on the board.", "ready");
      return null;
    }
    if (nameOrType === "Jumper Wire") {
      logConsole("💡 Click any pin on the Arduino or a placed component to start drawing a wire.");
      return null;
    }
    logConsole(`Unknown component: ${nameOrType}`, "error");
    return null;
  }

  const def = COMPONENT_DEFS[defKey];
  const typeKey = def.type;
  circuitState.counters[typeKey] = (circuitState.counters[typeKey] || 0) + 1;
  const count = circuitState.counters[typeKey];
  const compId = `${def.prefix}${count}`;

  const defaultPositions = [
    { x: 180, y: 270 },
    { x: 300, y: 270 },
    { x: 420, y: 270 },
    { x: 530, y: 270 },
    { x: 240, y: 340 },
    { x: 360, y: 340 },
  ];
  const fallback = defaultPositions[(circuitState.components.length) % defaultPositions.length];
  
  const comp = {
    id: compId,
    type: def.type,
    defKey: defKey,
    x: customX !== null ? Math.max(70, Math.min(640, customX - def.width / 2)) : fallback.x,
    y: customY !== null ? Math.max(215, Math.min(410, customY - def.height / 2)) : fallback.y,
  };

  circuitState.components.push(comp);
  renderPlacedComponents();
  updateComponentCount();
  logConsole(`Placed ${def.label} as [${comp.id}] on breadboard.`);
  return comp;
}

function removeComponent(compId) {
  const compIndex = circuitState.components.findIndex(c => c.id === compId);
  if (compIndex === -1) return;

  circuitState.components.splice(compIndex, 1);

  const prefix = `${compId}.`;
  const initialWireCount = circuitState.wires.length;
  circuitState.wires = circuitState.wires.filter(
    w => !w.from.startsWith(prefix) && !w.to.startsWith(prefix)
  );
  const removedWires = initialWireCount - circuitState.wires.length;

  renderPlacedComponents();
  renderWires();
  updateComponentCount();
  updateCircuitDebugView();

  if (arduinoSim && arduinoSim.running) {
    arduinoSim.updateVisuals();
  }

  logConsole(`Removed component [${compId}]${removedWires > 0 ? ` and ${removedWires} attached wire(s)` : ""}.`);
}

function renderPlacedComponents() {
  if (!placedCompsLayer) return;

  const html = circuitState.components.map(comp => {
    const def = COMPONENT_DEFS[comp.defKey] || COMPONENT_DEFS[comp.type];
    return def ? def.render(comp) : "";
  }).join("\n");

  placedCompsLayer.innerHTML = html;
  bindComponentDOMEvents();
}

function updateComponentCount() {
  const count = circuitState.components.length;
  if (activeCompCount) {
    activeCompCount.textContent = `${count} placed`;
  }
}

// LED Visual Glow Handler
function setLEDGlow(compId, isGlowing) {
  const radianceEl = document.getElementById(`led-radiance-${compId}`);
  const bulbEl = document.getElementById(`led-bulb-${compId}`);
  const shineEl = document.getElementById(`led-shine-${compId}`);

  if (radianceEl) {
    radianceEl.style.opacity = isGlowing ? "0.9" : "0";
  }
  if (bulbEl) {
    if (isGlowing) {
      bulbEl.setAttribute("fill", "#ff1e1e");
      bulbEl.setAttribute("stroke", "#fee2e2");
      bulbEl.style.filter = "url(#led-glow)";
    } else {
      bulbEl.setAttribute("fill", "#991b1b");
      bulbEl.setAttribute("stroke", "#7f1d1d");
      bulbEl.style.filter = "none";
    }
  }
  if (shineEl) {
    shineEl.setAttribute("opacity", isGlowing ? "0.9" : "0.4");
  }
}

// Buzzer Sound Ripples Handler
function setBuzzerBeeping(isBeeping) {
  const buzzers = circuitState.components.filter(c => c.type === "Buzzer");
  buzzers.forEach(b => {
    const waveEl = document.getElementById(`buzzer-waves-${b.id}`);
    const bodyEl = document.getElementById(`buzzer-body-${b.id}`);
    if (waveEl) waveEl.style.display = isBeeping ? "block" : "none";
    if (bodyEl) {
      bodyEl.setAttribute("stroke", isBeeping ? "#38bdf8" : "#334155");
    }
  });
}

// ============================================================================
// 5. PINS POSITION RESOLUTION
// ============================================================================
const BOARD_PINS = {
  "GND": { x: 320, y: 137, role: "neg" },
  "D13": { x: 360, y: 137, role: "signal" },
  "D10": { x: 400, y: 137, role: "signal" },
  "D9":  { x: 440, y: 137, role: "signal" },
  "D8":  { x: 480, y: 137, role: "signal" },
  "D2":  { x: 520, y: 137, role: "signal" },
  "5V":  { x: 570, y: 137, role: "pos" },
  "GND2": { x: 610, y: 137, role: "neg" },
  "RAIL_5V_TOP": { x: 95, y: 230, role: "pos" },
  "RAIL_GND_TOP": { x: 95, y: 250, role: "neg" },
};

function getPinCoordinates(pinId) {
  if (BOARD_PINS[pinId]) {
    return { ...BOARD_PINS[pinId], id: pinId };
  }

  if (pinId.includes(".")) {
    const [compId, pinSuffix] = pinId.split(".");
    const comp = circuitState.components.find(c => c.id === compId);
    if (comp) {
      const def = COMPONENT_DEFS[comp.defKey] || COMPONENT_DEFS[comp.type];
      if (def) {
        const pinDef = def.pins.find(p => p.idSuffix === pinSuffix);
        if (pinDef) {
          return {
            x: comp.x + pinDef.offsetX,
            y: comp.y + pinDef.offsetY,
            role: pinDef.role,
            id: pinId,
          };
        }
      }
    }
  }

  const el = breadboardSvg ? breadboardSvg.querySelector(`[data-pin-id="${pinId}"]`) : null;
  if (el) {
    const bbox = el.getBoundingClientRect();
    const pt = breadboardSvg.createSVGPoint();
    pt.x = bbox.left + bbox.width / 2;
    pt.y = bbox.top + bbox.height / 2;
    const svgP = pt.matrixTransform(breadboardSvg.getScreenCTM().inverse());
    return { x: Math.round(svgP.x), y: Math.round(svgP.y), id: pinId, role: "signal" };
  }

  return null;
}

// ============================================================================
// 6. WIRE DRAWING & CURVES ENGINE
// ============================================================================
function chooseWireColor(pinA, pinB) {
  const pA = pinA.toLowerCase();
  const pB = pinB.toLowerCase();

  if (pA.includes("gnd") || pB.includes("gnd") || pA.includes("cathode") || pB.includes("cathode") || pA.includes("neg") || pB.includes("neg")) {
    return "#1e293b";
  }
  if (pA.includes("5v") || pB.includes("5v") || pA.includes("vcc") || pB.includes("vcc") || pA.includes("anode") || pB.includes("anode")) {
    return "#ef4444";
  }
  if (pA.includes("d13") || pB.includes("d13")) {
    return "#2563eb";
  }
  if (pA.includes("d8") || pB.includes("d8") || pA.includes("trig") || pB.includes("trig")) {
    return "#eab308";
  }
  if (pA.includes("d10") || pB.includes("d10") || pA.includes("echo") || pB.includes("echo")) {
    return "#10b981";
  }
  if (pA.includes("d2") || pB.includes("d2")) {
    return "#f97316";
  }

  return "#8b5cf6";
}

function calculateSagCurve(x1, y1, x2, y2) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const dist = Math.sqrt(dx * dx + dy * dy);
  const sag = Math.max(30, Math.min(120, dist * 0.35));

  const cp1x = x1;
  const cp1y = y1 + sag;
  const cp2x = x2;
  const cp2y = y2 + sag;

  return `M ${x1} ${y1} C ${cp1x} ${cp1y} ${cp2x} ${cp2y} ${x2} ${y2}`;
}

function handlePinClick(pinId, evt) {
  if (evt) evt.stopPropagation();

  const pinCoords = getPinCoordinates(pinId);
  if (!pinCoords) {
    logConsole(`⚠️ Pin ${pinId} position could not be resolved.`, "error");
    return;
  }

  if (!wireDraw.isDrawing || !wireDraw.startPin) {
    wireDraw.isDrawing = true;
    wireDraw.startPin = pinCoords;

    highlightPin(pinId, true);
    if (tempWire) {
      tempWire.style.display = "block";
      tempWire.setAttribute("d", `M ${pinCoords.x} ${pinCoords.y} L ${pinCoords.x} ${pinCoords.y}`);
    }

    if (canvasHintText) {
      canvasHintText.innerHTML = `⚡ <strong>Wiring:</strong> Started from <code>${pinId}</code>. Now click target pin (or press <kbd>Esc</kbd> to cancel).`;
    }
    if (wireDrawingStatus) {
      wireDrawingStatus.textContent = `Connecting ${pinId}...`;
      wireDrawingStatus.className = "status-indicator wiring";
    }

    logConsole(`Selected pin [${pinId}]. Click another pin to connect wire.`);
    return;
  }

  const startId = wireDraw.startPin.id;
  const targetId = pinId;

  if (startId === targetId) {
    cancelWireDrawing();
    logConsole("Cancelled wire (clicked the same pin).");
    return;
  }

  const alreadyExists = circuitState.wires.some(
    w => (w.from === startId && w.to === targetId) || (w.from === targetId && w.to === startId)
  );
  if (alreadyExists) {
    cancelWireDrawing();
    logConsole(`⚠️ A wire between [${startId}] and [${targetId}] already exists.`, "error");
    return;
  }

  let from = startId;
  let to = targetId;
  const isStartBoard = !startId.includes(".");
  const isTargetBoard = !targetId.includes(".");

  if (isStartBoard && !isTargetBoard) {
    from = targetId;
    to = startId;
  }

  const color = chooseWireColor(from, to);
  const newWire = { from, to, color };

  circuitState.wires.push(newWire);
  cancelWireDrawing();
  renderWires();
  updateCircuitDebugView();

  if (arduinoSim && arduinoSim.running) {
    arduinoSim.updateVisuals();
  }

  logConsole(`⚡ Connected wire: ${from} ↔ ${to}`, "ready");
}

function cancelWireDrawing() {
  wireDraw.isDrawing = false;
  if (wireDraw.startPin) {
    highlightPin(wireDraw.startPin.id, false);
    wireDraw.startPin = null;
  }
  if (tempWire) {
    tempWire.style.display = "none";
  }
  if (canvasHintText) {
    canvasHintText.innerHTML = "💡 <strong>Tip:</strong> Drag components from the tray onto the breadboard, click pins to draw wires, click wires to delete.";
  }
  if (wireDrawingStatus) {
    wireDrawingStatus.textContent = "Ready";
    wireDrawingStatus.className = "status-indicator";
  }
}

function highlightPin(pinId, active) {
  if (!breadboardSvg) return;
  const pinEl = breadboardSvg.querySelector(`[data-pin-id="${pinId}"]`);
  if (pinEl) {
    if (active) pinEl.classList.add("active-pin");
    else pinEl.classList.remove("active-pin");
  }

  if (!pinMarkersLayer) return;
  pinMarkersLayer.innerHTML = "";
  if (active) {
    const coords = getPinCoordinates(pinId);
    if (coords) {
      pinMarkersLayer.innerHTML = `
        <circle cx="${coords.x}" cy="${coords.y}" r="11" fill="none" stroke="#f59e0b" stroke-width="2.5" stroke-dasharray="3 3">
          <animateTransform attributeName="transform" type="rotate" from="0 ${coords.x} ${coords.y}" to="360 ${coords.x} ${coords.y}" dur="4s" repeatCount="indefinite" />
        </circle>
      `;
    }
  }
}

// ============================================================================
// 7. RENDER WIRES & CLICK-TO-DELETE
// ============================================================================
function renderWires() {
  if (!wiresLayer) return;

  const html = circuitState.wires.map((wire, idx) => {
    const p1 = getPinCoordinates(wire.from);
    const p2 = getPinCoordinates(wire.to);
    if (!p1 || !p2) return "";

    const pathD = calculateSagCurve(p1.x, p1.y, p2.x, p2.y);

    return `
      <g class="wire-group" data-wire-index="${idx}">
        <path d="${pathD}" stroke="rgba(15, 23, 42, 0.2)" stroke-width="5" fill="none" stroke-linecap="round" />
        <path class="wire-main" d="${pathD}" stroke="${wire.color}" stroke-width="3.5" fill="none" stroke-linecap="round" filter="url(#wire-shadow)" />
        <path class="wire-hitbox" d="${pathD}" stroke="transparent" stroke-width="16" fill="none" stroke-linecap="round">
          <title>Click to delete wire (${wire.from} ↔ ${wire.to})</title>
        </path>
      </g>
    `;
  }).join("\n");

  wiresLayer.innerHTML = html;
  bindWireHitboxEvents();
  updateWireCount();
}

function bindWireHitboxEvents() {
  if (!wiresLayer) return;
  const hitboxes = wiresLayer.querySelectorAll(".wire-hitbox");
  hitboxes.forEach(hitbox => {
    hitbox.addEventListener("click", (evt) => {
      evt.stopPropagation();
      const parentGroup = hitbox.closest(".wire-group");
      if (!parentGroup) return;
      const wireIdx = parseInt(parentGroup.dataset.wireIndex, 10);
      deleteWireByIndex(wireIdx);
    });
  });
}

function deleteWireByIndex(idx) {
  if (idx < 0 || idx >= circuitState.wires.length) return;
  const removed = circuitState.wires.splice(idx, 1)[0];
  renderWires();
  updateCircuitDebugView();

  if (arduinoSim && arduinoSim.running) {
    arduinoSim.updateVisuals();
  }

  logConsole(`🗑️ Deleted wire: ${removed.from} ↔ ${removed.to}`);
}

function updateWireCount() {
  const count = circuitState.wires.length;
  if (wireCountBadge) wireCountBadge.textContent = `${count} wires`;
  if (debugWireCount) debugWireCount.textContent = `${count} wires`;
}

// ============================================================================
// 8. CIRCUIT JSON VIEW & DEBUG PANEL
// ============================================================================
function getCircuitJSON() {
  return circuitState.wires.map(w => ({
    from: w.from,
    to: w.to,
  }));
}

function updateCircuitDebugView() {
  const jsonArr = getCircuitJSON();
  const formatted = JSON.stringify(jsonArr, null, 2);
  if (circuitJsonView) {
    circuitJsonView.textContent = formatted;
  }
  updateWireCount();
}

function setupDebugPanelEvents() {
  if (btnCopyCircuit) {
    btnCopyCircuit.addEventListener("click", () => {
      const jsonStr = JSON.stringify(getCircuitJSON(), null, 2);
      navigator.clipboard.writeText(jsonStr).then(() => {
        const origText = btnCopyCircuit.textContent;
        btnCopyCircuit.textContent = "✅ Copied!";
        setTimeout(() => { btnCopyCircuit.textContent = origText; }, 1500);
        logConsole("📋 Circuit JSON copied to clipboard.", "ready");
      }).catch(err => {
        console.error("Copy failed:", err);
        logConsole("Failed to copy JSON to clipboard.", "error");
      });
    });
  }

  if (btnClearCircuit) {
    btnClearCircuit.addEventListener("click", () => {
      if (circuitState.wires.length === 0) return;
      const count = circuitState.wires.length;
      circuitState.wires = [];
      renderWires();
      updateCircuitDebugView();
      if (arduinoSim && arduinoSim.running) {
        arduinoSim.updateVisuals();
      }
      logConsole(`🗑️ Cleared all ${count} wires from breadboard.`);
    });
  }

  if (btnToggleDebug) {
    btnToggleDebug.addEventListener("click", () => {
      if (!circuitDebugPanel) return;
      circuitDebugPanel.classList.toggle("collapsed");
      btnToggleDebug.textContent = circuitDebugPanel.classList.contains("collapsed") ? "▲" : "▼";
    });
  }

  if (btnToggleDebugTop) {
    btnToggleDebugTop.addEventListener("click", () => {
      if (!circuitDebugPanel) return;
      circuitDebugPanel.classList.toggle("collapsed");
      if (btnToggleDebug) {
        btnToggleDebug.textContent = circuitDebugPanel.classList.contains("collapsed") ? "▲" : "▼";
      }
    });
  }
}

// ============================================================================
// 9. EVENT LISTENERS & DOM BINDINGS
// ============================================================================
function setupTrayDragAndDrop() {
  const trayItems = document.querySelectorAll(".tray-item");

  trayItems.forEach(item => {
    const compName = item.dataset.component;

    item.addEventListener("dragstart", (e) => {
      e.dataTransfer.setData("text/plain", compName);
      e.dataTransfer.effectAllowed = "copy";
      item.classList.add("active");
    });

    item.addEventListener("dragend", () => {
      item.classList.remove("active");
    });

    const addBtn = item.querySelector(".tray-add-btn");
    if (addBtn) {
      addBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        addComponent(compName);
      });
    }

    item.addEventListener("click", () => {
      addComponent(compName);
    });
  });

  if (breadboardSvg) {
    breadboardSvg.addEventListener("dragover", (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = "copy";
    });

    breadboardSvg.addEventListener("drop", (e) => {
      e.preventDefault();
      const compName = e.dataTransfer.getData("text/plain");
      if (compName) {
        const { x, y } = getSvgCoords(e);
        addComponent(compName, x, y);
      }
    });
  }
}

function setupCanvasEvents() {
  if (!breadboardSvg) return;

  breadboardSvg.addEventListener("mousemove", (e) => {
    if (wireDraw.isDrawing && wireDraw.startPin && tempWire) {
      const { x, y } = getSvgCoords(e);
      const pathD = calculateSagCurve(wireDraw.startPin.x, wireDraw.startPin.y, x, y);
      tempWire.setAttribute("d", pathD);
    }
  });

  breadboardSvg.addEventListener("click", (e) => {
    if (wireDraw.isDrawing && !e.target.classList.contains("pin-terminal")) {
      cancelWireDrawing();
      logConsole("Cancelled wire connection.");
    }
  });

  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && wireDraw.isDrawing) {
      cancelWireDrawing();
      logConsole("Cancelled wire (Esc).");
    }
  });
}

function setupArduinoPins() {
  if (!breadboardSvg) return;

  const boardPins = breadboardSvg.querySelectorAll(".pin-terminal.board-pin, .pin-terminal.rail-pin");
  boardPins.forEach(pin => {
    pin.addEventListener("click", (e) => {
      const pinId = pin.dataset.pinId;
      if (pinId) handlePinClick(pinId, e);
    });
  });
}

function bindComponentDOMEvents() {
  if (!placedCompsLayer) return;

  const compPins = placedCompsLayer.querySelectorAll(".pin-terminal.comp-pin");
  compPins.forEach(pin => {
    pin.addEventListener("click", (e) => {
      const pinId = pin.dataset.pinId;
      if (pinId) handlePinClick(pinId, e);
    });
  });

  const delBtns = placedCompsLayer.querySelectorAll(".comp-del-btn");
  delBtns.forEach(btn => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const compId = btn.dataset.id;
      if (compId) removeComponent(compId);
    });
  });

  // Placed Push Button Plungers
  const plungers = placedCompsLayer.querySelectorAll(".interactive-btn-plunger");
  plungers.forEach(plunger => {
    plunger.addEventListener("mousedown", (e) => {
      e.stopPropagation();
      setButtonPressState(true);
    });
    plunger.addEventListener("mouseup", (e) => {
      e.stopPropagation();
      setButtonPressState(false);
    });
    plunger.addEventListener("mouseleave", () => {
      setButtonPressState(false);
    });
  });

  const placedComps = placedCompsLayer.querySelectorAll(".placed-comp");
  placedComps.forEach(compEl => {
    compEl.addEventListener("mousedown", (e) => {
      if (e.target.classList.contains("pin-terminal") || e.target.classList.contains("interactive-btn-plunger") || e.target.closest(".comp-del-btn")) {
        return;
      }
      e.stopPropagation();

      const compId = compEl.dataset.id;
      const comp = circuitState.components.find(c => c.id === compId);
      if (!comp) return;

      compDrag.isDragging = true;
      compDrag.comp = comp;
      const curSvg = getSvgCoords(e);
      compDrag.dragOffset = {
        x: curSvg.x - comp.x,
        y: curSvg.y - comp.y,
      };

      compEl.classList.add("dragging");

      function onMouseMove(moveEvt) {
        if (!compDrag.isDragging || !compDrag.comp) return;
        const moveCoords = getSvgCoords(moveEvt);
        compDrag.comp.x = Math.max(50, Math.min(650, moveCoords.x - compDrag.dragOffset.x));
        compDrag.comp.y = Math.max(200, Math.min(420, moveCoords.y - compDrag.dragOffset.y));
        compEl.setAttribute("transform", `translate(${compDrag.comp.x}, ${compDrag.comp.y})`);

        renderWires();
      }

      function onMouseUp() {
        compDrag.isDragging = false;
        compDrag.comp = null;
        compEl.classList.remove("dragging");
        window.removeEventListener("mousemove", onMouseMove);
        window.removeEventListener("mouseup", onMouseUp);
      }

      window.addEventListener("mousemove", onMouseMove);
      window.addEventListener("mouseup", onMouseUp);
    });
  });
}

function setupAppEvents() {
  if (expSelect) {
    expSelect.addEventListener("change", (e) => {
      selectExperiment(e.target.value);
    });
  }

  if (btnReset) {
    btnReset.addEventListener("click", () => {
      if (currentExperiment && currentExperiment.starter_code) {
        codeEditor.value = currentExperiment.starter_code.trim();
        logConsole("Code editor reset to starter code.", "ready");
      }
    });
  }

  if (btnRun) {
    btnRun.addEventListener("click", handleRunCircuit);
  }
}

// ============================================================================
// 10. HARDWARE CONTROLS (BUTTON & DISTANCE SENSOR)
// ============================================================================
function setupHardwareControls() {
  // Push Button Controls (Exp 2)
  if (btnPressVirtual) {
    btnPressVirtual.addEventListener("mousedown", () => setButtonPressState(true));
    btnPressVirtual.addEventListener("mouseup", () => setButtonPressState(false));
    btnPressVirtual.addEventListener("mouseleave", () => setButtonPressState(false));

    // Touch support for mobile / tablet
    btnPressVirtual.addEventListener("touchstart", (e) => { e.preventDefault(); setButtonPressState(true); });
    btnPressVirtual.addEventListener("touchend", (e) => { e.preventDefault(); setButtonPressState(false); });
  }

  // Distance Sensor Slider (Exp 3)
  if (distanceSlider) {
    distanceSlider.addEventListener("input", (e) => {
      setSensorDistance(parseInt(e.target.value, 10));
    });
  }

  // Presets buttons for Distance Sensor
  const presetBtns = document.querySelectorAll(".preset-btn");
  presetBtns.forEach(btn => {
    btn.addEventListener("click", () => {
      const dist = parseInt(btn.dataset.dist, 10);
      if (!isNaN(dist)) {
        if (distanceSlider) distanceSlider.value = dist;
        setSensorDistance(dist);
      }
    });
  });
}

function setButtonPressState(isPressed) {
  hardwareState.isButtonPressed = isPressed;

  if (buttonStatePill) {
    if (isPressed) {
      buttonStatePill.textContent = "Status: Pressed (LOW)";
      buttonStatePill.className = "status-pill alert";
    } else {
      buttonStatePill.textContent = "Status: Released (HIGH)";
      buttonStatePill.className = "status-pill safe";
    }
  }

  if (btnPressVirtual) {
    if (isPressed) btnPressVirtual.classList.add("pressed");
    else btnPressVirtual.classList.remove("pressed");
  }

  // Animate SVG button plungers
  const buttons = circuitState.components.filter(c => c.type === "Button");
  buttons.forEach(b => {
    const plunger = document.getElementById(`btn-plunger-${b.id}`);
    if (plunger) {
      if (isPressed) {
        plunger.setAttribute("fill", "#dc2626");
        plunger.setAttribute("transform", "scale(0.88)");
        plunger.setAttribute("transform-origin", "32 26");
      } else {
        plunger.setAttribute("fill", "#ef4444");
        plunger.removeAttribute("transform");
      }
    }
  });

  // If simulator is running, trigger immediate step check
  if (arduinoSim && arduinoSim.running) {
    arduinoSim.updateVisuals();
  }
}

function setSensorDistance(distCm) {
  hardwareState.sensorDistance = distCm;

  if (distanceValDisplay) {
    distanceValDisplay.textContent = `${distCm} cm`;
  }

  if (distanceStatusPill) {
    if (distCm < 20) {
      distanceStatusPill.textContent = `⚠️ Alarm Zone (${distCm} cm < 20 cm)`;
      distanceStatusPill.className = "status-pill alert";
    } else {
      distanceStatusPill.textContent = `✅ Safe Zone (${distCm} cm ≥ 20 cm)`;
      distanceStatusPill.className = "status-pill safe";
    }
  }

  if (arduinoSim && arduinoSim.running) {
    arduinoSim.updateVisuals();
  }
}

// ============================================================================
// 11. WEB AUDIO API SYNTHESIZER FOR BUZZER (tone / noTone)
// ============================================================================
function getAudioContext() {
  if (!audioCtx) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (AudioContextClass) {
      audioCtx = new AudioContextClass();
    }
  }
  if (audioCtx && audioCtx.state === "suspended") {
    audioCtx.resume();
  }
  return audioCtx;
}

function playBuzzerTone(freq = 1000) {
  try {
    const ctx = getAudioContext();
    if (!ctx) return;

    if (!activeOscillator) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = "square";
      osc.frequency.setValueAtTime(freq, ctx.currentTime);
      gain.gain.setValueAtTime(0.08, ctx.currentTime);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();

      activeOscillator = osc;
      activeGainNode = gain;
    } else {
      activeOscillator.frequency.setValueAtTime(freq, ctx.currentTime);
    }

    setBuzzerBeeping(true);
  } catch (err) {
    console.warn("Web Audio tone play error:", err);
  }
}

function stopBuzzerTone() {
  try {
    if (activeOscillator) {
      activeOscillator.stop();
      activeOscillator.disconnect();
      activeOscillator = null;
      activeGainNode = null;
    }
    setBuzzerBeeping(false);
  } catch (err) {
    console.warn("Web Audio tone stop error:", err);
  }
}

// ============================================================================
// 12. CIRCUIT GRAPH ANALYSIS & CONNECTIVITY ENGINE
// ============================================================================
function analyzeCircuit() {
  const adj = {};
  function addEdge(u, v) {
    if (!adj[u]) adj[u] = new Set();
    if (!adj[v]) adj[v] = new Set();
    adj[u].add(v);
    adj[v].add(u);
  }

  circuitState.wires.forEach(w => {
    addEdge(w.from, w.to);
  });

  function areWired(startNode, targetNode) {
    if (!startNode || !targetNode) return false;
    if (startNode === targetNode) return true;
    const visited = new Set();
    const queue = [startNode];
    visited.add(startNode);

    while (queue.length > 0) {
      const cur = queue.shift();
      if (cur === targetNode) return true;
      const neighbors = adj[cur] || [];
      for (const n of neighbors) {
        if (!visited.has(n)) {
          visited.add(n);
          queue.push(n);
        }
      }
    }
    return false;
  }

  function isConnectedToGND(node) {
    const gndTargets = ["GND", "GND2", "RAIL_GND_TOP"];
    return gndTargets.some(g => areWired(node, g));
  }

  function isConnectedTo5V(node) {
    const pwrTargets = ["5V", "RAIL_5V_TOP"];
    return pwrTargets.some(p => areWired(node, p));
  }

  function getConnectedPin(node) {
    const pins = ["D13", "D10", "D9", "D8", "D2", "5V"];
    for (const p of pins) {
      if (areWired(node, p)) return p;
    }
    return null;
  }

  // 1. Analyze LEDs
  const leds = circuitState.components.filter(c => c.type === "LED");
  const resistors = circuitState.components.filter(c => c.type === "Resistor");
  const ledResults = {};

  leds.forEach(led => {
    const anode = `${led.id}.anode`;
    const cathode = `${led.id}.cathode`;

    let res = {
      ledId: led.id,
      isValid: false,
      connectedPin: null,
      hasResistor: false,
      isReversePolarity: false,
      hasGround: false,
      errorType: "none",
      message: ""
    };

    const pinAnode = getConnectedPin(anode);
    if (pinAnode) {
      res.connectedPin = pinAnode;
      for (const r of resistors) {
        const r1 = `${r.id}.pin1`;
        const r2 = `${r.id}.pin2`;

        if (areWired(cathode, r1) && isConnectedToGND(r2)) {
          res.isValid = true;
          res.hasResistor = true;
          res.hasGround = true;
          res.message = `Verified: ${pinAnode} → ${anode} → ${cathode} → ${r.id} → GND`;
          break;
        } else if (areWired(cathode, r2) && isConnectedToGND(r1)) {
          res.isValid = true;
          res.hasResistor = true;
          res.hasGround = true;
          res.message = `Verified: ${pinAnode} → ${anode} → ${cathode} → ${r.id} → GND`;
          break;
        }
      }

      if (!res.isValid && isConnectedToGND(cathode)) {
        res.hasGround = true;
        res.hasResistor = false;
        res.errorType = "missing_resistor";
        res.message = `Missing resistor: LED ${led.id} is connected directly between ${pinAnode} and GND.`;
      }
    }

    if (!res.isValid) {
      for (const r of resistors) {
        const r1 = `${r.id}.pin1`;
        const r2 = `${r.id}.pin2`;

        const pinR1 = getConnectedPin(r1);
        const pinR2 = getConnectedPin(r2);

        if (pinR1 && areWired(r2, anode) && isConnectedToGND(cathode)) {
          res.isValid = true;
          res.connectedPin = pinR1;
          res.hasResistor = true;
          res.hasGround = true;
          res.message = `Verified: ${pinR1} → ${r.id} → ${anode} → ${cathode} → GND`;
          break;
        } else if (pinR2 && areWired(r1, anode) && isConnectedToGND(cathode)) {
          res.isValid = true;
          res.connectedPin = pinR2;
          res.hasResistor = true;
          res.hasGround = true;
          res.message = `Verified: ${pinR2} → ${r.id} → ${anode} → ${cathode} → GND`;
          break;
        }
      }
    }

    if (!res.isValid) {
      const pinCathode = getConnectedPin(cathode);
      if (pinCathode) {
        res.connectedPin = pinCathode;
        res.isReversePolarity = true;
        res.errorType = "reversed_polarity";
        res.message = `Reversed polarity: LED cathode (-) is connected to ${pinCathode}! Anode (+) must connect to the pin.`;
      }
    }

    if (!res.isValid && !res.hasGround) {
      if (res.connectedPin && !isConnectedToGND(cathode) && !isConnectedToGND(anode)) {
        res.errorType = "missing_ground";
        res.message = `Missing ground: LED circuit is not connected to GND.`;
      }
    }

    ledResults[led.id] = res;
  });

  // 2. Analyze Buzzer
  const buzzers = circuitState.components.filter(c => c.type === "Buzzer");
  const buzzerResults = {};
  buzzers.forEach(b => {
    const pos = `${b.id}.positive`;
    const neg = `${b.id}.negative`;
    const pin = getConnectedPin(pos);
    const hasGnd = isConnectedToGND(neg);
    buzzerResults[b.id] = {
      buzzerId: b.id,
      isValid: Boolean(pin && hasGnd),
      connectedPin: pin,
      hasGround: hasGnd,
      message: pin && hasGnd ? `Verified: ${pin} → ${b.id} → GND` : `Buzzer wiring incomplete (Pin: ${pin || 'none'}, GND: ${hasGnd})`,
    };
  });

  // 3. Analyze Push Button
  const buttons = circuitState.components.filter(c => c.type === "Button");
  const buttonResults = {};
  buttons.forEach(btn => {
    const p1 = `${btn.id}.pin1`;
    const p2 = `${btn.id}.pin2`;
    const pin = getConnectedPin(p1) || getConnectedPin(p2);
    const hasGnd = isConnectedToGND(p1) || isConnectedToGND(p2);
    buttonResults[btn.id] = {
      buttonId: btn.id,
      isValid: Boolean(pin && hasGnd),
      connectedPin: pin,
      hasGround: hasGnd,
    };
  });

  // 4. Analyze HC-SR04 Sensor
  const sensors = circuitState.components.filter(c => c.type === "HCSR04");
  const sensorResults = {};
  sensors.forEach(s => {
    const has5V = isConnectedTo5V(`${s.id}.VCC`);
    const hasGnd = isConnectedToGND(`${s.id}.GND`);
    const trigPin = getConnectedPin(`${s.id}.TRIG`);
    const echoPin = getConnectedPin(`${s.id}.ECHO`);
    sensorResults[s.id] = {
      sensorId: s.id,
      isValid: Boolean(has5V && hasGnd && trigPin && echoPin),
      has5V,
      hasGnd,
      trigPin,
      echoPin,
    };
  });

  return { ledResults, buzzerResults, buttonResults, sensorResults };
}

// ============================================================================
// 13. ARDUINO SUBSET JAVASCRIPT SIMULATOR
// ============================================================================
class ArduinoSimulator {
  constructor() {
    this.running = false;
    this.pins = {};
    this.modes = {};
    this.abortController = null;
    this.stepCount = 0;
    this.ledHasLightedUp = false;
  }

  stop() {
    this.running = false;
    if (this.abortController) {
      this.abortController.abort();
      this.abortController = null;
    }
    stopBuzzerTone();
    this.resetHardwareVisuals();
    updateRunButtonState(false);
  }

  resetHardwareVisuals() {
    const p13Led = document.getElementById("arduino-pin13-led");
    if (p13Led) {
      p13Led.setAttribute("fill", "#475569");
      p13Led.style.filter = "none";
    }
    circuitState.components.filter(c => c.type === "LED").forEach(led => {
      setLEDGlow(led.id, false);
      led._isGlowing = false;
    });
    setBuzzerBeeping(false);
  }

  transpile(code) {
    let js = code;

    js = js.replace(/\/\*[\s\S]*?\*\//g, "");
    js = js.replace(/\/\/.*$/gm, "");

    js = js.replace(/\b(int|long|float|double|char|bool|unsigned int|unsigned long|const int|const long)\s+([a-zA-Z_][a-zA-Z0-9_]*)/g, "let $2");

    js = js.replace(/\bawait\s+delay\s*\(/g, "delay(");
    js = js.replace(/\bdelay\s*\(/g, "await delay(");

    js = js.replace(/\bvoid\s+setup\s*\(\s*\)/g, "async function __setup()");
    js = js.replace(/\bvoid\s+loop\s*\(\s*\)/g, "async function __loop()");

    return js;
  }

  async run(rawCode) {
    this.stop();
    this.running = true;
    this.ledHasLightedUp = false;
    this.abortController = new AbortController();
    const signal = this.abortController.signal;
    this.stepCount = 0;

    updateRunButtonState(true);
    logConsole("⚙️ Compiling Arduino sketch...", "ready");

    let transpiled = "";
    try {
      transpiled = this.transpile(rawCode);
    } catch (err) {
      logConsole(`❌ Compiler Error: ${err.message}`, "error");
      this.stop();
      return;
    }

    const HIGH = 1;
    const LOW = 0;
    const OUTPUT = "OUTPUT";
    const INPUT = "INPUT";
    const INPUT_PULLUP = "INPUT_PULLUP";

    const sim = this;

    const pinMode = (pin, mode) => {
      const pinStr = String(pin).replace(/^D/i, "");
      sim.modes[pinStr] = mode;
      sim.modes[`D${pinStr}`] = mode;
      logConsole(`pinMode(${pin}, ${mode})`);
    };

    const digitalWrite = (pin, val) => {
      const pinStr = String(pin).replace(/^D/i, "");
      const numVal = (val === 1 || val === "HIGH" || val === HIGH) ? 1 : 0;
      sim.pins[pinStr] = numVal;
      sim.pins[`D${pinStr}`] = numVal;

      sim.updateVisuals();
    };

    const digitalRead = (pin) => {
      const pinStr = String(pin).replace(/^D/i, "");

      // For Experiment 2: Check if button is pressed on D2
      if (pinStr === "2") {
        const { buttonResults } = analyzeCircuit();
        const hasValidButton = Object.values(buttonResults).some(b => b.isValid);
        if (hasValidButton && hardwareState.isButtonPressed) {
          return LOW; // Tactile button active LOW to GND
        }
        return HIGH; // Pulled HIGH
      }

      if (sim.modes[pinStr] === "INPUT_PULLUP") {
        return sim.pins[pinStr] !== undefined ? sim.pins[pinStr] : HIGH;
      }
      return sim.pins[pinStr] || LOW;
    };

    const delay = (ms) => {
      return new Promise((resolve, reject) => {
        if (signal.aborted || !sim.running) return reject(new Error("ABORTED"));
        const timer = setTimeout(() => {
          resolve();
        }, Math.max(10, ms));

        signal.addEventListener("abort", () => {
          clearTimeout(timer);
          reject(new Error("ABORTED"));
        });
      });
    };

    const tone = (pin, freq = 1000) => {
      const pinStr = String(pin).replace(/^D/i, "");
      const { buzzerResults } = analyzeCircuit();
      const validBuzzer = Object.values(buzzerResults).find(b => b.isValid && (b.connectedPin === pinStr || b.connectedPin === `D${pinStr}`));

      if (validBuzzer) {
        playBuzzerTone(freq);
      } else {
        stopBuzzerTone();
      }
    };

    const noTone = (pin) => {
      stopBuzzerTone();
    };

    const readDistance = () => {
      // Experiment 3 Ultrasonic Distance
      const { sensorResults } = analyzeCircuit();
      const validSensor = Object.values(sensorResults).find(s => s.isValid);

      if (validSensor) {
        return hardwareState.sensorDistance;
      }
      return 999; // Sensor not wired
    };

    try {
      const fn = new Function(
        "api",
        `
        const { pinMode, digitalWrite, digitalRead, delay, tone, noTone, readDistance, HIGH, LOW, OUTPUT, INPUT, INPUT_PULLUP } = api;
        ${transpiled}
        return {
          setup: typeof __setup === 'function' ? __setup : null,
          loop: typeof __loop === 'function' ? __loop : null
        };
        `
      );

      const sketch = fn({
        pinMode, digitalWrite, digitalRead, delay, tone, noTone, readDistance,
        HIGH, LOW, OUTPUT, INPUT, INPUT_PULLUP
      });

      logConsole("✅ Sketch running!", "ready");

      if (sketch.setup) {
        logConsole("▶ Running setup()...");
        await sketch.setup();
      }

      if (sketch.loop) {
        logConsole("▶ Running loop()...");
        while (sim.running && !signal.aborted) {
          sim.stepCount++;
          await sketch.loop();
          await new Promise(r => setTimeout(r, 10));
        }
      } else {
        logConsole("ℹ️ No loop() function defined.");
        this.stop();
      }

    } catch (err) {
      if (err.message === "ABORTED") return;
      logConsole(`❌ Simulation error: ${err.message}`, "error");
      this.stop();
    }
  }

  updateVisuals() {
    // 1. Arduino Uno Onboard L LED
    const pin13Val = this.pins["13"] || this.pins["D13"] || 0;
    const p13Led = document.getElementById("arduino-pin13-led");
    if (p13Led) {
      if (pin13Val === 1) {
        p13Led.setAttribute("fill", "#facc15");
        p13Led.style.filter = "drop-shadow(0 0 6px #facc15)";
      } else {
        p13Led.setAttribute("fill", "#475569");
        p13Led.style.filter = "none";
      }
    }

    // 2. Breadboard Placed LEDs
    const { ledResults } = analyzeCircuit();
    const leds = circuitState.components.filter(c => c.type === "LED");

    leds.forEach(led => {
      const check = ledResults[led.id];
      if (!check) return;

      const pinKey = check.connectedPin ? check.connectedPin.replace(/^D/i, "") : null;
      const isPinHigh = pinKey ? (this.pins[pinKey] === 1 || this.pins[`D${pinKey}`] === 1) : false;

      // LED conducts and glows ONLY when pin is HIGH and correctly wired to GND through resistor!
      const shouldGlow = Boolean(check.isValid && isPinHigh);
      setLEDGlow(led.id, shouldGlow);

      if (shouldGlow) {
        this.ledHasLightedUp = true;
      }

      if (shouldGlow !== led._isGlowing) {
        led._isGlowing = shouldGlow;
        if (shouldGlow) {
          logConsole(`💡 [${led.id}] GLOWING (Pin ${check.connectedPin} is HIGH, complete circuit to GND)`, "ready");
        } else {
          logConsole(`🌑 [${led.id}] OFF (Pin ${check.connectedPin || "none"} is LOW or 0V)`);
        }
      }
    });
  }
}

const arduinoSim = new ArduinoSimulator();

function updateRunButtonState(isRunning) {
  if (!btnRun) return;
  if (isRunning) {
    btnRun.textContent = "⏹ Stop Circuit";
    btnRun.classList.add("btn-stop");
    btnRun.title = "Click to stop circuit simulation";
  } else {
    btnRun.textContent = "▶ Run Circuit";
    btnRun.classList.remove("btn-stop");
    btnRun.title = "Run virtual circuit and code";
  }
}

// ============================================================================
// 14. AI LAB PARTNER CHAT BUBBLE & TUTORING SYSTEM
// ============================================================================
function showAILabPartnerBubble(praise, hint, fix = null, title = "LED Blink") {
  if (!aiLabPartnerBubble) return;

  if (partnerExpTitle) partnerExpTitle.textContent = title;
  if (partnerPraiseText) partnerPraiseText.textContent = praise || "Good attempt at setting up the circuit!";
  if (partnerHintText) partnerHintText.textContent = hint || "Can you check that your components are connected to GND?";

  if (partnerFix && partnerFixText) {
    if (fix && fix.trim()) {
      partnerFixText.textContent = fix;
      partnerFix.style.display = "block";
    } else {
      partnerFix.style.display = "none";
    }
  }

  aiLabPartnerBubble.style.display = "block";
  logConsole(`🤖 AI Lab Partner: "${hint}"`, "normal");
}

function hideAILabPartnerBubble() {
  if (aiLabPartnerBubble) {
    aiLabPartnerBubble.style.display = "none";
  }
}

function setupPartnerBubbleEvents() {
  if (btnClosePartnerBubble) {
    btnClosePartnerBubble.addEventListener("click", hideAILabPartnerBubble);
  }
  if (btnGotIt) {
    btnGotIt.addEventListener("click", hideAILabPartnerBubble);
  }

  // Ask for Direct Fix button (Rule 4: give direct fix when student asks again)
  if (btnAskDirectFix) {
    btnAskDirectFix.addEventListener("click", () => {
      logConsole("🙋 Student requested direct fix from AI Lab Partner...");
      triggerAILabPartnerCheck(true);
    });
  }
}

async function triggerAILabPartnerCheck(askAgain = false) {
  const circuitJson = getCircuitJSON();
  const code = codeEditor ? codeEditor.value : "";
  const expTitle = currentExperiment ? currentExperiment.title : "LED Blink";

  try {
    const payload = {
      experiment_id: currentExperimentId,
      student_id: 1,
      circuit: circuitJson,
      code: code,
      ask_again: askAgain,
    };

    const res = await fetch("/api/lab/check", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (res.ok) {
      const feedback = await res.json();
      showAILabPartnerBubble(
        feedback.praise,
        feedback.hint,
        feedback.fix,
        expTitle
      );
      return;
    }
  } catch (err) {
    // Local fallback heuristic if network / API unavailable
    const { ledResults, buzzerResults, sensorResults } = analyzeCircuit();
    let praise = "You placed the components and wrote Arduino code nicely!";
    let hint = "Which pin did you connect the component to? Check that it connects to GND.";
    let fix = "Connect Pin D13 to LED Anode (+), LED Cathode (-) to Resistor, and the other Resistor leg to GND.";

    if (currentExperimentId === 1) {
      const ledCheck = ledResults["LED1"];
      if (ledCheck) {
        if (ledCheck.isReversePolarity) {
          praise = "You have the LED wired to the circuit!";
          hint = "Which leg of the LED did you connect to Pin 13? Did you know current only flows from Anode (+) to Cathode (-)?";
          fix = "Swap the LED wires: connect the Anode (+) to Pin 13 and Cathode (-) to the resistor.";
        } else if (!ledCheck.hasResistor) {
          praise = "You wired the LED to Pin 13!";
          hint = "Robots need resistors to protect LEDs from burning out. Can you add the 220Ω resistor between the LED and GND?";
          fix = "Place the 220Ω resistor on the breadboard. Connect LED cathode to pin1, and pin2 to GND.";
        } else if (!ledCheck.hasGround) {
          praise = "The LED and resistor are on the board!";
          hint = "Every circuit needs a complete loop. Which pin on the Arduino Uno gives zero volts ground?";
          fix = "Draw a wire from the resistor's second leg to the Arduino GND pin.";
        }
      }
    } else if (currentExperimentId === 2) {
      praise = "You set up the buzzer experiment components!";
      hint = "Is your buzzer's positive pin connected to D8, and the button to D2 and GND?";
      fix = "Wire Button between D2 and GND. Wire Buzzer positive to D8 and negative to GND.";
    } else if (currentExperimentId === 3) {
      praise = "You added the HC-SR04 sensor!";
      hint = "The ultrasonic sensor needs 4 wires: VCC, GND, TRIG, and ECHO. Are all 4 connected?";
      fix = "Wire VCC to 5V, GND to GND, TRIG to D9, and ECHO to D10. Wire Buzzer to D8 and GND.";
    }

    showAILabPartnerBubble(praise, hint, askAgain ? fix : null, expTitle);
  }
}

// ============================================================================
// 15. EXPERIMENTS LOADER & STARTER CIRCUITS
// ============================================================================
async function loadExperiments() {
  try {
    const res = await fetch("/api/experiments");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    allExperiments = data.experiments || [];

    if (expSelect) {
      expSelect.innerHTML = "";
      allExperiments.forEach(exp => {
        const opt = document.createElement("option");
        opt.value = exp.id;
        opt.textContent = `${exp.id}. ${exp.title}`;
        expSelect.appendChild(opt);
      });
    }

    if (allExperiments.length > 0) {
      const urlParams = new URLSearchParams(window.location.search);
      const expParam = urlParams.get("exp");
      const targetExpId = expParam ? parseInt(expParam, 10) : allExperiments[0].id;
      if (expSelect) expSelect.value = targetExpId;
      selectExperiment(targetExpId);
    }
  } catch (err) {
    console.warn("Could not fetch /api/experiments from backend:", err);
    logConsole("⚠️ Working in offline/local simulator mode.", "normal");
    loadDefaultExperimentFallback();
  }
}

async function selectExperiment(expId) {
  currentExperimentId = parseInt(expId, 10);
  hideAILabPartnerBubble();

  try {
    const res = await fetch(`/api/experiments/${currentExperimentId}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    currentExperiment = await res.json();

    if (expGoalText) expGoalText.textContent = currentExperiment.goal || "Build and run the circuit.";
    if (codeEditor) {
      if (currentExperimentId === 1) {
        codeEditor.value = "void setup(){\n  pinMode(13, OUTPUT);\n}\n\nvoid loop(){\n  digitalWrite(13, HIGH);\n  delay(1000);\n  digitalWrite(13, LOW);\n  delay(1000);\n}";
      } else {
        codeEditor.value = (currentExperiment.starter_code || currentExperiment.solution_code || "").trim();
      }
    }

    logConsole(`Loaded Experiment ${currentExperiment.id}: "${currentExperiment.title}"`, "ready");
    loadStarterComponentsForExperiment(currentExperimentId);
    updateHardwareUIForExperiment(currentExperimentId);
  } catch (err) {
    console.warn(`Error loading experiment ${expId}:`, err);
    loadDefaultExperimentFallback();
  }
}

function updateHardwareUIForExperiment(expId) {
  if (!interactiveHardwareBar) return;

  if (expId === 1) {
    interactiveHardwareBar.style.display = "none";
    if (distanceControlGroup) distanceControlGroup.style.display = "none";
    if (buttonControlGroup) buttonControlGroup.style.display = "none";
  } else if (expId === 2) {
    interactiveHardwareBar.style.display = "flex";
    if (buttonControlGroup) buttonControlGroup.style.display = "flex";
    if (distanceControlGroup) distanceControlGroup.style.display = "none";
  } else if (expId === 3) {
    interactiveHardwareBar.style.display = "flex";
    if (distanceControlGroup) distanceControlGroup.style.display = "flex";
    if (buttonControlGroup) buttonControlGroup.style.display = "none";
  }
}

function loadDefaultExperimentFallback() {
  currentExperiment = {
    id: 1,
    title: "LED Blink",
    goal: "Blink an LED on and off every second",
    components: "Arduino Uno; LED; 220 ohm resistor; wires",
    starter_code: "void setup(){\n  pinMode(13, OUTPUT);\n}\n\nvoid loop(){\n  digitalWrite(13, HIGH);\n  delay(1000);\n  digitalWrite(13, LOW);\n  delay(1000);\n}",
  };
  if (expGoalText) expGoalText.textContent = currentExperiment.goal;
  if (codeEditor) codeEditor.value = currentExperiment.starter_code;
  loadStarterComponentsForExperiment(1);
  updateHardwareUIForExperiment(1);
}

function loadStarterComponentsForExperiment(expId) {
  if (arduinoSim && arduinoSim.running) {
    arduinoSim.stop();
  }

  circuitState.components = [];
  circuitState.wires = [];
  circuitState.counters = { LED: 0, Resistor: 0, Button: 0, Buzzer: 0, HCSR04: 0 };

  if (expId === 1) {
    // Exp 1: LED Blink
    addComponent("LED", 230, 270);
    addComponent("220 ohm Resistor", 370, 280);

    circuitState.wires = [
      { from: "LED1.anode", to: "D13", color: "#2563eb" },
      { from: "LED1.cathode", to: "R1.pin1", color: "#8b5cf6" },
      { from: "R1.pin2", to: "GND", color: "#1e293b" },
    ];
    logConsole("Placed and wired Experiment 1 starter circuit: D13 → LED1 → 220Ω Resistor → GND.");
  } else if (expId === 2) {
    // Exp 2: Buzzer + Button
    addComponent("Push Button", 220, 275);
    addComponent("Buzzer", 410, 270);

    circuitState.wires = [
      { from: "Button1.pin1", to: "D2", color: "#f97316" },
      { from: "Button1.pin2", to: "GND", color: "#1e293b" },
      { from: "Buzzer1.positive", to: "D8", color: "#eab308" },
      { from: "Buzzer1.negative", to: "GND", color: "#1e293b" },
    ];
    logConsole("Placed and wired Experiment 2 starter circuit: Button on D2/GND, Buzzer on D8/GND.");
  } else if (expId === 3) {
    // Exp 3: Distance Alarm
    addComponent("HC-SR04 Ultrasonic Sensor", 210, 270);
    addComponent("Buzzer", 430, 270);

    circuitState.wires = [
      { from: "HCSR04_1.VCC", to: "5V", color: "#ef4444" },
      { from: "HCSR04_1.GND", to: "GND", color: "#1e293b" },
      { from: "HCSR04_1.TRIG", to: "D9", color: "#eab308" },
      { from: "HCSR04_1.ECHO", to: "D10", color: "#10b981" },
      { from: "Buzzer1.positive", to: "D8", color: "#eab308" },
      { from: "Buzzer1.negative", to: "GND", color: "#1e293b" },
    ];
    logConsole("Placed and wired Experiment 3 starter circuit: HC-SR04 on 5V/GND/D9/D10, Buzzer on D8/GND.");
  }

  renderPlacedComponents();
  renderWires();
  updateCircuitDebugView();
}

// ============================================================================
// 16. RUN CIRCUIT HANDLER & AI LAB PARTNER CHECK
// ============================================================================
async function handleRunCircuit() {
  if (arduinoSim.running) {
    arduinoSim.stop();
    logConsole("⏹ Simulation stopped by user.");
    return;
  }

  const code = codeEditor ? codeEditor.value.trim() : "";
  if (!code) {
    logConsole("⚠️ Please enter Arduino code in the editor.", "error");
    return;
  }

  logConsole("▶ Verifying circuit connections and compiling code...", "ready");

  const { ledResults, buzzerResults, buttonResults, sensorResults } = analyzeCircuit();
  let expectedBehaviorOk = true;

  // 1. Goal Check based on active experiment
  if (currentExperimentId === 1) {
    const ledCheck = ledResults["LED1"];
    if (!ledCheck || !ledCheck.isValid) {
      expectedBehaviorOk = false;
      logConsole(ledCheck ? ledCheck.message : "⚠️ LED1 is not wired to D13 and GND through a resistor.", "error");
    } else {
      logConsole(`✅ Circuit Check: ${ledCheck.message}`, "ready");
    }
  } else if (currentExperimentId === 2) {
    const btnCheck = buttonResults["Button1"];
    const buzzCheck = buzzerResults["Buzzer1"];
    if (!btnCheck || !btnCheck.isValid || !buzzCheck || !buzzCheck.isValid) {
      expectedBehaviorOk = false;
      logConsole("⚠️ Buzzer or Push Button wiring is incomplete.", "error");
    }
  } else if (currentExperimentId === 3) {
    const sensCheck = sensorResults["HCSR04_1"];
    const buzzCheck = buzzerResults["Buzzer1"];
    if (!sensCheck || !sensCheck.isValid || !buzzCheck || !buzzCheck.isValid) {
      expectedBehaviorOk = false;
      logConsole("⚠️ HC-SR04 Sensor or Buzzer wiring is incomplete.", "error");
    }
  }

  // 2. Start Arduino Simulation
  arduinoSim.run(code);

  // 3. If the goal was not met immediately, call AI Lab Partner
  if (!expectedBehaviorOk) {
    triggerAILabPartnerCheck(false);
  } else {
    // If circuit was ok, verify that LED actually lights up within 2.5 seconds (in case code forgot to digitalWrite HIGH)
    if (currentExperimentId === 1) {
      setTimeout(() => {
        if (arduinoSim.running && !arduinoSim.ledHasLightedUp) {
          logConsole("⚠️ LED has not lighted up! Calling AI Lab Partner for code guidance...", "normal");
          triggerAILabPartnerCheck(false);
        }
      }, 2500);
    }
  }
}

// Helper: Append formatted log line to status console
function logConsole(msg, type = "normal") {
  if (!consoleOutput) return;
  const line = document.createElement("div");
  line.className = `console-log ${type}`;
  line.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
  consoleOutput.appendChild(line);
  consoleOutput.scrollTop = consoleOutput.scrollHeight;
}

// Expose circuit state & simulator for tests or external scripts
window.getCircuitJSON = getCircuitJSON;
window.circuitState = circuitState;
window.arduinoSim = arduinoSim;
window.analyzeCircuit = analyzeCircuit;
window.deleteWireByIndex = deleteWireByIndex;
window.loadStarterComponentsForExperiment = loadStarterComponentsForExperiment;
window.hardwareState = hardwareState;
window.setButtonPressState = setButtonPressState;
window.setSensorDistance = setSensorDistance;
window.showAILabPartnerBubble = showAILabPartnerBubble;
window.triggerAILabPartnerCheck = triggerAILabPartnerCheck;

// Bootstrap on DOM ready
document.addEventListener("DOMContentLoaded", initVirtualLab);
