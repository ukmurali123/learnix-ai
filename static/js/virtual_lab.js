/**
 * Learnix AI — Virtual Lab Layout & Controller
 */

// State
let allExperiments = [];
let currentExperiment = null;
let currentExperimentId = 1;

// DOM Elements
const expSelect = document.getElementById("exp-select");
const expGoalText = document.getElementById("exp-goal-text");
const codeEditor = document.getElementById("code-editor");
const btnRun = document.getElementById("btn-run");
const btnReset = document.getElementById("btn-reset");
const consoleOutput = document.getElementById("console-output");
const activeCompCount = document.getElementById("active-comp-count");

// Initialize Virtual Lab
async function initVirtualLab() {
  logConsole("Initializing Learnix Virtual Lab...", "ready");
  setupEventListeners();
  await loadExperiments();
}

// 1. Fetch Experiments list from /api/experiments
async function loadExperiments() {
  try {
    const res = await fetch("/api/experiments");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    allExperiments = data.experiments || [];

    // Populate dropdown
    expSelect.innerHTML = "";
    allExperiments.forEach((exp) => {
      const opt = document.createElement("option");
      opt.value = exp.id;
      opt.textContent = `${exp.id}. ${exp.title}`;
      expSelect.appendChild(opt);
    });

    // Default to experiment 1
    if (allExperiments.length > 0) {
      selectExperiment(allExperiments[0].id);
    }
  } catch (err) {
    console.error("Failed to load experiments:", err);
    logConsole("⚠️ Could not fetch experiments from backend.", "error");
  }
}

// 2. Load Single Experiment & its starter code from /api/experiments/{id}
async function selectExperiment(expId) {
  currentExperimentId = parseInt(expId, 10);
  try {
    const res = await fetch(`/api/experiments/${currentExperimentId}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    currentExperiment = await res.json();

    // Update Top Goal pill
    expGoalText.textContent = currentExperiment.goal || "Build and run the circuit.";

    // Set code editor with experiment starter code
    codeEditor.value = (currentExperiment.starter_code || "").trim();

    // Log status
    logConsole(`Loaded Experiment ${currentExperiment.id}: "${currentExperiment.title}"`, "ready");
    logConsole(`Components required: ${currentExperiment.components}`);

    // Update active components counter
    if (activeCompCount) {
      activeCompCount.textContent = "0 placed";
    }
  } catch (err) {
    console.error(`Failed to load experiment ${expId}:`, err);
    logConsole(`⚠️ Error loading experiment ${expId}`, "error");
  }
}

// 3. Setup Button and Dropdown Events
function setupEventListeners() {
  // Experiment picker change
  expSelect.addEventListener("change", (e) => {
    selectExperiment(e.target.value);
  });

  // Reset button: resets code back to starter code
  btnReset.addEventListener("click", () => {
    if (currentExperiment && currentExperiment.starter_code) {
      codeEditor.value = currentExperiment.starter_code.trim();
      logConsole("Code editor reset to starter code.", "ready");
    } else {
      codeEditor.value = "";
    }
  });

  // Run button (layout stub before simulator integration)
  btnRun.addEventListener("click", () => {
    logConsole("▶ Run triggered — simulator will execute this circuit & code in Prompt 5.", "ready");
  });

  // Component tray click handling
  const trayItems = document.querySelectorAll(".tray-item");
  trayItems.forEach((item) => {
    item.addEventListener("click", () => {
      const compName = item.dataset.component;
      logConsole(`Selected component: ${compName} (ready to place on canvas)`);
    });
  });
}

// Helper: Append formatted message to console pane
function logConsole(msg, type = "normal") {
  if (!consoleOutput) return;
  const line = document.createElement("div");
  line.className = `console-log ${type}`;
  line.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
  consoleOutput.appendChild(line);
  consoleOutput.scrollTop = consoleOutput.scrollHeight;
}

// Start
document.addEventListener("DOMContentLoaded", initVirtualLab);
