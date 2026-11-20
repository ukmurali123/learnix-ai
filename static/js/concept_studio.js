/**
 * Learnix AI — Concept Studio
 * Reusable visual renderers for textbook-to-visuals learning:
 * - animated_steps (interactive step-by-step SVG with play/pause/next, glowing highlights, electron flow)
 * - simulation (live SVG with sliders, e.g. LED brightness vs resistor, ultrasonic distance)
 * - labelled_diagram (tap-to-explain interactive parts)
 * - mind_map (hierarchical concept nodes & links)
 * - story_comic (4-panel comic strip cards)
 * - comparison (side-by-side contrast cards)
 * 
 * Plus: "Ask a Doubt" AI assistant, visual quizzes with instant feedback & scoring,
 * and seamless "Try it in the Virtual Lab" integration.
 */

// Global State
var STUDENT_ID = window.STUDENT_ID || 1;
let currentLanguage = "English";
let currentUploadedFile = null;
let activeConcepts = [];
let animationIntervals = {};

// DOM Elements
const tabUpload = document.getElementById("tab-upload");
const tabTopic = document.getElementById("tab-topic");
const panelUpload = document.getElementById("panel-upload");
const panelTopic = document.getElementById("panel-topic");
const pageFileInput = document.getElementById("page-file-input");
const dropzone = document.getElementById("dropzone");
const filePreviewCard = document.getElementById("file-preview-card");
const filePreviewImg = document.getElementById("file-preview-img");
const filePreviewPdf = document.getElementById("file-preview-pdf");
const filePreviewName = document.getElementById("file-preview-name");
const filePreviewSize = document.getElementById("file-preview-size");
const btnChangeFile = document.getElementById("btn-change-file");
const topicTextInput = document.getElementById("topic-text-input");
const langSelect = document.getElementById("lang-select");
const btnGenerate = document.getElementById("btn-generate");
const csAlertBanner = document.getElementById("cs-alert-banner");
const csAlertText = document.getElementById("cs-alert-text");
const btnCloseAlert = document.getElementById("btn-close-alert");
const csLoadingState = document.getElementById("cs-loading-state");
const loadingTitle = document.getElementById("loading-title");
const loadingSubtitle = document.getElementById("loading-subtitle");
const conceptsContainer = document.getElementById("concepts-container");
const csEmptyState = document.getElementById("cs-empty-state");
const recentLessonsSection = document.getElementById("recent-lessons-section");
const recentPillsList = document.getElementById("recent-pills-list");

// ============================================================================
// 1. INITIALIZATION & TAB SWITCHING
// ============================================================================
document.addEventListener("DOMContentLoaded", () => {
  if (!document.getElementById("concepts-container") && !document.getElementById("topic-text-input")) {
    // Only initialize studio page handlers if on Concept Studio page
    return;
  }
  setupTabEvents();
  setupUploadEvents();
  setupTopicEvents();
  setupControlEvents();
  loadRecentLessons();
});

function setupTabEvents() {
  if (tabUpload && tabTopic) {
    tabUpload.addEventListener("click", () => switchMode("upload"));
    tabTopic.addEventListener("click", () => switchMode("topic"));
  }
}

function switchMode(mode) {
  if (mode === "upload") {
    tabUpload.classList.add("active");
    tabUpload.setAttribute("aria-selected", "true");
    tabTopic.classList.remove("active");
    tabTopic.setAttribute("aria-selected", "false");
    panelUpload.style.display = "block";
    panelTopic.style.display = "none";
  } else {
    tabTopic.classList.add("active");
    tabTopic.setAttribute("aria-selected", "true");
    tabUpload.classList.remove("active");
    tabUpload.setAttribute("aria-selected", "false");
    panelTopic.style.display = "block";
    panelUpload.style.display = "none";
  }
  hideAlert();
}

function setupControlEvents() {
  if (langSelect) {
    langSelect.addEventListener("change", (e) => {
      currentLanguage = e.target.value;
    });
  }

  if (btnCloseAlert) {
    btnCloseAlert.addEventListener("click", hideAlert);
  }

  if (btnGenerate) {
    btnGenerate.addEventListener("click", handleGenerateLesson);
  }
}

// ============================================================================
// 2. UPLOAD & DRAG-AND-DROP HANDLERS
// ============================================================================
function setupUploadEvents() {
  if (!dropzone || !pageFileInput) return;

  dropzone.addEventListener("click", () => pageFileInput.click());

  pageFileInput.addEventListener("change", (e) => {
    if (e.target.files && e.target.files[0]) {
      handleSelectedFile(e.target.files[0]);
    }
  });

  // Drag and drop
  ["dragenter", "dragover"].forEach((eventName) => {
    dropzone.addEventListener(eventName, (e) => {
      e.preventDefault();
      dropzone.classList.add("drag-active");
    });
  });

  ["dragleave", "drop"].forEach((eventName) => {
    dropzone.addEventListener(eventName, (e) => {
      e.preventDefault();
      dropzone.classList.remove("drag-active");
    });
  });

  dropzone.addEventListener("drop", (e) => {
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleSelectedFile(e.dataTransfer.files[0]);
    }
  });

  if (btnChangeFile) {
    btnChangeFile.addEventListener("click", () => pageFileInput.click());
  }
}

function handleSelectedFile(file) {
  currentUploadedFile = file;
  hideAlert();

  filePreviewName.textContent = file.name;
  filePreviewSize.textContent = `${(file.size / (1024 * 1024)).toFixed(2)} MB`;

  if (file.type.startsWith("image/")) {
    const reader = new FileReader();
    reader.onload = (e) => {
      filePreviewImg.src = e.target.result;
      filePreviewImg.style.display = "block";
      filePreviewPdf.style.display = "none";
    };
    reader.readAsDataURL(file);
  } else {
    filePreviewImg.style.display = "none";
    filePreviewPdf.style.display = "flex";
  }

  dropzone.style.display = "none";
  filePreviewCard.style.display = "flex";
}

function setupTopicEvents() {
  document.querySelectorAll(".topic-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      const topic = chip.getAttribute("data-topic");
      if (topicTextInput) {
        topicTextInput.value = topic;
        switchMode("topic");
        topicTextInput.focus();
      }
    });
  });

  if (topicTextInput) {
    topicTextInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        handleGenerateLesson();
      }
    });
  }
}

function showAlert(message) {
  if (csAlertBanner && csAlertText) {
    csAlertText.textContent = message;
    csAlertBanner.style.display = "flex";
  }
}

function hideAlert() {
  if (csAlertBanner) csAlertBanner.style.display = "none";
}

// ============================================================================
// 3. GENERATION ORCHESTRATOR (PAGE OR TOPIC)
// ============================================================================
async function handleGenerateLesson() {
  const isUploadMode = tabUpload.classList.contains("active");

  if (isUploadMode) {
    if (!currentUploadedFile) {
      showAlert("Please choose or take a photo of your textbook page first!");
      return;
    }
    await processPageUpload(currentUploadedFile);
  } else {
    const topic = topicTextInput.value.trim();
    if (!topic) {
      showAlert("Please enter a science or robotics topic above!");
      topicTextInput.focus();
      return;
    }
    await processTopicLesson(topic);
  }
}

function setGeneratingState(isGenerating, title = "", subtitle = "") {
  if (btnGenerate) {
    btnGenerate.disabled = isGenerating;
    const spinner = btnGenerate.querySelector(".btn-spinner");
    const text = btnGenerate.querySelector(".btn-text");
    if (spinner) spinner.style.display = isGenerating ? "inline-block" : "none";
    if (text) text.textContent = isGenerating ? "Analyzing..." : "✨ Generate Visual Lesson";
  }

  if (csLoadingState) {
    csLoadingState.style.display = isGenerating ? "flex" : "none";
    if (loadingTitle && title) loadingTitle.textContent = title;
    if (loadingSubtitle && subtitle) loadingSubtitle.textContent = subtitle;
  }

  if (isGenerating && csEmptyState) {
    csEmptyState.style.display = "none";
  }
}

// Process page upload -> POST /api/concept-studio/from-page
async function processPageUpload(file) {
  hideAlert();
  setGeneratingState(
    true,
    "Reading Textbook Page with Gemini AI...",
    "Extracting concepts, matching physics curriculum, and building interactive visual circuits..."
  );

  try {
    const formData = new FormData();
    formData.append("file", file);
    formData.append("student_id", STUDENT_ID);
    formData.append("language", currentLanguage);

    const res = await fetch("/api/concept-studio/from-page", {
      method: "POST",
      body: formData,
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || `Server error (HTTP ${res.status})`);
    }

    const data = await res.json();

    if (data.blurred) {
      showAlert(data.message || "The photo seems blurred or unreadable. Please upload a clearer photo of your textbook page.");
      setGeneratingState(false);
      return;
    }

    const concepts = data.concepts || [];
    if (concepts.length === 0) {
      showAlert("No clear science concepts could be extracted from this page. Try another page or topic.");
      setGeneratingState(false);
      return;
    }

    renderAllConcepts(concepts);
    loadRecentLessons();
  } catch (err) {
    console.error("Error processing page upload:", err);
    showAlert(`Could not process textbook page: ${err.message}`);
  } finally {
    setGeneratingState(false);
  }
}

// Process topic -> POST /api/concept-studio
async function processTopicLesson(topic) {
  hideAlert();
  setGeneratingState(
    true,
    "Synthesizing Visual Lesson with Gemini AI...",
    `Building interactive diagrams, analogies, and quizzes for "${topic}" in ${currentLanguage}...`
  );

  try {
    const res = await fetch("/api/concept-studio", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        topic: topic,
        student_id: STUDENT_ID,
        language: currentLanguage,
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || `Server error (HTTP ${res.status})`);
    }

    const lesson = await res.json();

    // Normalize topic response into uniform concept object
    const visual = lesson.visual || {};
    const normalizedConcept = {
      concept_id: lesson.concept_id || 1,
      title: lesson.title || topic,
      summary: lesson.explanation || "",
      analogy: lesson.analogy || "",
      real_life_example: lesson.real_life_example || "",
      type: visual.type || "animated_steps",
      steps: visual.steps || [],
      parts: visual.parts || [],
      sliders: visual.sliders || [],
      nodes: visual.nodes || [],
      links: visual.links || [],
      panels: visual.panels || [],
      left: visual.left || null,
      right: visual.right || null,
      quiz: lesson.quiz || [],
      try_it: lesson.try_it || null,
    };

    renderAllConcepts([normalizedConcept]);
    loadRecentLessons();
  } catch (err) {
    console.error("Error generating topic lesson:", err);
    showAlert(`Could not generate lesson: ${err.message}`);
  } finally {
    setGeneratingState(false);
  }
}

// ============================================================================
// 4. MAIN CONCEPTS RENDERER
// ============================================================================
function renderAllConcepts(concepts) {
  // Clear any existing animation timers
  Object.values(animationIntervals).forEach(clearInterval);
  animationIntervals = {};

  activeConcepts = concepts;
  conceptsContainer.innerHTML = "";

  if (concepts.length === 0) {
    if (csEmptyState) csEmptyState.style.display = "block";
    return;
  }

  // Header Summary if multiple concepts
  if (concepts.length > 1) {
    const countBadge = document.createElement("div");
    countBadge.className = "cs-results-count";
    countBadge.innerHTML = `<span>✨ Extracted <strong>${concepts.length} Concepts</strong> from your textbook page:</span>`;
    conceptsContainer.appendChild(countBadge);
  }

  concepts.forEach((concept, idx) => {
    const card = renderSingleConceptCard(concept, idx);
    conceptsContainer.appendChild(card);
  });

  // Smooth scroll to results
  conceptsContainer.scrollIntoView({ behavior: "smooth", block: "start" });
}

function renderSingleConceptCard(concept, index) {
  const card = document.createElement("article");
  card.className = "concept-card";
  card.id = `concept-card-${index}`;

  const typeLabelMap = {
    animated_steps: "🎬 Animated Steps",
    simulation: "🎛️ Live Simulation",
    labelled_diagram: "🏷️ Labelled Diagram",
    mind_map: "🗺️ Concept Mind Map",
    story_comic: "📖 Comic Story",
    comparison: "⚖️ Comparison",
  };

  const badgeText = typeLabelMap[concept.type] || "🔬 Visual Model";

  // Card Header
  const header = document.createElement("div");
  header.className = "concept-header";
  header.innerHTML = `
    <div class="concept-meta-top">
      <span class="concept-type-badge ${concept.type}">${badgeText}</span>
      <span class="concept-num">Concept ${index + 1}</span>
    </div>
    <h2 class="concept-title">${escapeHtml(concept.title || "Science Concept")}</h2>
    <p class="concept-summary">${escapeHtml(concept.summary || "")}</p>
    ${
      concept.analogy
        ? `<div class="concept-analogy-box">
             <span class="analogy-icon">💡</span>
             <div class="analogy-text"><strong>Everyday Analogy:</strong> ${escapeHtml(concept.analogy)}</div>
           </div>`
        : ""
    }
  `;
  card.appendChild(header);

  // Main Visual Workspace Container
  const visualWrapper = document.createElement("div");
  visualWrapper.className = "concept-visual-workspace";
  card.appendChild(visualWrapper);

  // Dispatch to the appropriate modular visual renderer
  switch (concept.type) {
    case "animated_steps":
      renderAnimatedSteps(concept, visualWrapper, index);
      break;
    case "simulation":
      renderSimulation(concept, visualWrapper, index);
      break;
    case "labelled_diagram":
      renderLabelledDiagram(concept, visualWrapper, index);
      break;
    case "mind_map":
      renderMindMap(concept, visualWrapper, index);
      break;
    case "story_comic":
      renderStoryComic(concept, visualWrapper, index);
      break;
    case "comparison":
      renderComparison(concept, visualWrapper, index);
      break;
    default:
      renderAnimatedSteps(concept, visualWrapper, index);
      break;
  }

  // Interactive Parts Legend (Tapping a part shows explain text)
  if (concept.parts && concept.parts.length > 0) {
    const partsLegend = renderPartsLegend(concept.parts, index);
    card.appendChild(partsLegend);
  }

  // "Try it in the Virtual Lab" CTA Button (if try_it is set)
  if (concept.try_it && concept.try_it.experiment_id) {
    const tryItCard = document.createElement("div");
    tryItCard.className = "concept-try-it-cta";
    const expId = concept.try_it.experiment_id;
    const instruction = concept.try_it.instruction || "Wire and test this circuit yourself in the Virtual Lab!";
    tryItCard.innerHTML = `
      <div class="try-it-content">
        <span class="try-it-icon">🚀</span>
        <div class="try-it-info">
          <strong>Interactive Experiment Ready!</strong>
          <p>${escapeHtml(instruction)}</p>
        </div>
      </div>
      <a href="/virtual_lab.html?exp=${expId}" class="btn btn-try-it">
        ▶ Open in Virtual Lab (Exp ${expId})
      </a>
    `;
    card.appendChild(tryItCard);
  }

  // "Ask a Doubt" Box
  const doubtBox = renderDoubtBox(concept, index);
  card.appendChild(doubtBox);

  // Visual Quiz
  if (concept.quiz && concept.quiz.length > 0) {
    const quizCard = renderVisualQuiz(concept, index);
    card.appendChild(quizCard);
  }

  return card;
}

// ============================================================================
// 5. MODULAR RENDERER 1: ANIMATED STEPS (Process & Current Flow)
// ============================================================================
function renderAnimatedSteps(concept, container, cardIndex) {
  const steps = concept.steps && concept.steps.length > 0 ? concept.steps : [
    { caption: "Battery pushes electric current out of positive terminal (+)", highlight: ["battery_plus"] },
    { caption: "Current passes through the resistor which safely limits flow", highlight: ["resistor"] },
    { caption: "Current enters LED anode (+) to cathode (-) causing it to glow brightly!", highlight: ["led", "gnd"] }
  ];

  let currentStep = 0;
  let isPlaying = true;
  const timerId = `anim_${cardIndex}`;

  const wrapper = document.createElement("div");
  wrapper.className = "anim-steps-renderer";

  // Step Status Bar
  const statusBar = document.createElement("div");
  statusBar.className = "anim-status-bar";
  statusBar.innerHTML = `
    <div class="step-counter-pill">
      Step <span id="step-num-${cardIndex}">1</span> of ${steps.length}
    </div>
    <div class="step-caption-display" id="step-caption-${cardIndex}">
      ${escapeHtml(steps[0].caption)}
    </div>
  `;
  wrapper.appendChild(statusBar);

  // Interactive SVG Canvas
  const svgContainer = document.createElement("div");
  svgContainer.className = "anim-svg-canvas";
  svgContainer.innerHTML = createCircuitSVG(cardIndex);
  wrapper.appendChild(svgContainer);

  // Controls Toolbar (Play/Pause, Step indicators, Next/Prev)
  const controlsBar = document.createElement("div");
  controlsBar.className = "anim-controls-bar";

  const btnPrev = document.createElement("button");
  btnPrev.className = "btn-step btn-step-prev";
  btnPrev.innerHTML = "◀ Prev";

  const btnPlay = document.createElement("button");
  btnPlay.className = "btn-step btn-step-play active";
  btnPlay.innerHTML = "⏸ Pause";

  const btnNext = document.createElement("button");
  btnNext.className = "btn-step btn-step-next";
  btnNext.innerHTML = "Next ▶";

  const indicatorsContainer = document.createElement("div");
  indicatorsContainer.className = "step-dots-container";
  steps.forEach((_, sIdx) => {
    const dot = document.createElement("button");
    dot.className = `step-dot-pill ${sIdx === 0 ? "active" : ""}`;
    dot.textContent = `${sIdx + 1}`;
    dot.title = `Jump to Step ${sIdx + 1}`;
    dot.addEventListener("click", () => {
      pauseAnimation();
      goToStep(sIdx);
    });
    indicatorsContainer.appendChild(dot);
  });

  controlsBar.appendChild(btnPrev);
  controlsBar.appendChild(btnPlay);
  controlsBar.appendChild(indicatorsContainer);
  controlsBar.appendChild(btnNext);
  wrapper.appendChild(controlsBar);

  container.appendChild(wrapper);

  // Step Navigation Engine
  function goToStep(stepIdx) {
    currentStep = (stepIdx + steps.length) % steps.length;
    const step = steps[currentStep];

    const stepNumEl = document.getElementById(`step-num-${cardIndex}`);
    const captionEl = document.getElementById(`step-caption-${cardIndex}`);
    if (stepNumEl) stepNumEl.textContent = `${currentStep + 1}`;
    if (captionEl) {
      captionEl.textContent = step.caption;
      captionEl.classList.remove("fade-in-text");
      void captionEl.offsetWidth; // trigger reflow
      captionEl.classList.add("fade-in-text");
    }

    // Update indicator dots
    indicatorsContainer.querySelectorAll(".step-dot-pill").forEach((dot, i) => {
      dot.classList.toggle("active", i === currentStep);
    });

    // Update SVG highlights
    updateSVGHighlights(svgContainer, step.highlight || []);
  }

  function nextStep() {
    goToStep(currentStep + 1);
  }

  function prevStep() {
    goToStep(currentStep - 1);
  }

  function playAnimation() {
    isPlaying = true;
    btnPlay.innerHTML = "⏸ Pause";
    btnPlay.classList.add("active");
    if (animationIntervals[timerId]) clearInterval(animationIntervals[timerId]);
    animationIntervals[timerId] = setInterval(nextStep, 2600);
  }

  function pauseAnimation() {
    isPlaying = false;
    btnPlay.innerHTML = "▶ Play";
    btnPlay.classList.remove("active");
    if (animationIntervals[timerId]) {
      clearInterval(animationIntervals[timerId]);
      delete animationIntervals[timerId];
    }
  }

  btnPlay.addEventListener("click", () => {
    if (isPlaying) pauseAnimation();
    else playAnimation();
  });

  btnNext.addEventListener("click", () => {
    pauseAnimation();
    nextStep();
  });

  btnPrev.addEventListener("click", () => {
    pauseAnimation();
    prevStep();
  });

  // Start auto-play
  playAnimation();
  goToStep(0);
}

// Generate an SVG circuit diagram with battery, resistor, LED, wires, and current arrows
function createCircuitSVG(cardIndex) {
  return `
    <svg viewBox="0 0 680 320" class="svg-diagram" id="circuit-svg-${cardIndex}">
      <defs>
        <!-- Gradients -->
        <linearGradient id="batteryGrad-${cardIndex}" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#3b82f6" />
          <stop offset="100%" stop-color="#1d4ed8" />
        </linearGradient>
        <radialGradient id="ledGlowGrad-${cardIndex}" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#fef08a" stop-opacity="0.9" />
          <stop offset="60%" stop-color="#eab308" stop-opacity="0.5" />
          <stop offset="100%" stop-color="#eab308" stop-opacity="0" />
        </radialGradient>
        <filter id="neonGlow-${cardIndex}" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="6" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>
      </defs>

      <!-- Background Grid -->
      <rect width="680" height="320" rx="14" fill="#0f172a" />
      <g stroke="#1e293b" stroke-width="1" stroke-dasharray="6,6">
        <line x1="0" y1="80" x2="680" y2="80" />
        <line x1="0" y1="160" x2="680" y2="160" />
        <line x1="0" y1="240" x2="680" y2="240" />
        <line x1="170" y1="0" x2="170" y2="320" />
        <line x1="340" y1="0" x2="340" y2="320" />
        <line x1="510" y1="0" x2="510" y2="320" />
      </g>

      <!-- Main Copper Circuit Wires -->
      <!-- Top Wire (+ 5V rail): from Battery + (120, 100) -> Resistor in (260, 100) -->
      <path class="circuit-wire wire-positive" d="M 120 100 L 260 100" stroke="#f59e0b" stroke-width="5" fill="none" stroke-linecap="round" />
      <!-- Wire from Resistor out (380, 100) -> LED Anode (500, 100) -->
      <path class="circuit-wire wire-mid" d="M 380 100 L 490 100" stroke="#f59e0b" stroke-width="5" fill="none" stroke-linecap="round" />
      <!-- Wire from LED Cathode (500, 220) -> Battery - (120, 220) via Bottom Rail -->
      <path class="circuit-wire wire-negative" d="M 490 220 L 120 220" stroke="#38bdf8" stroke-width="5" fill="none" stroke-linecap="round" />

      <!-- Animated Current Flow Particles -->
      <g class="current-particles" id="current-particles-${cardIndex}">
        <circle class="electron-dot" cx="160" cy="100" r="4" fill="#fef08a" />
        <circle class="electron-dot" cx="210" cy="100" r="4" fill="#fef08a" />
        <circle class="electron-dot" cx="420" cy="100" r="4" fill="#fef08a" />
        <circle class="electron-dot" cx="450" cy="100" r="4" fill="#fef08a" />
        <circle class="electron-dot" cx="400" cy="220" r="4" fill="#38bdf8" />
        <circle class="electron-dot" cx="300" cy="220" r="4" fill="#38bdf8" />
        <circle class="electron-dot" cx="200" cy="220" r="4" fill="#38bdf8" />
      </g>

      <!-- 1. BATTERY / POWER COMPONENT (id: battery_plus, battery) -->
      <g class="svg-part" id="part-battery-${cardIndex}" data-part="battery battery_plus" transform="translate(60, 80)">
        <rect x="0" y="0" width="60" height="160" rx="8" fill="url(#batteryGrad-${cardIndex})" stroke="#60a5fa" stroke-width="2" />
        <!-- Battery Terminal Caps -->
        <rect x="18" y="-10" width="24" height="10" rx="3" fill="#f59e0b" />
        <!-- Labels -->
        <text x="30" y="32" fill="#ffffff" font-size="20" font-weight="bold" text-anchor="middle">+</text>
        <text x="30" y="145" fill="#93c5fd" font-size="22" font-weight="bold" text-anchor="middle">−</text>
        <text x="30" y="85" fill="#ffffff" font-size="12" font-weight="bold" text-anchor="middle">5V</text>
        <text x="30" y="100" fill="#cbd5e1" font-size="10" text-anchor="middle">Battery</text>
        <!-- Highlight Ring -->
        <rect class="highlight-ring" x="-6" y="-16" width="72" height="182" rx="12" fill="none" stroke="#f59e0b" stroke-width="3" opacity="0" />
      </g>

      <!-- 2. RESISTOR COMPONENT (id: resistor) -->
      <g class="svg-part" id="part-resistor-${cardIndex}" data-part="resistor" transform="translate(260, 75)">
        <!-- Leads -->
        <line x1="0" y1="25" x2="20" y2="25" stroke="#94a3b8" stroke-width="4" />
        <line x1="100" y1="25" x2="120" y2="25" stroke="#94a3b8" stroke-width="4" />
        <!-- Resistor Body -->
        <rect x="20" y="8" width="80" height="34" rx="8" fill="#d97706" stroke="#b45309" stroke-width="2" />
        <!-- Color Bands (Red, Red, Brown, Gold = 220Ω) -->
        <rect x="34" y="8" width="6" height="34" fill="#dc2626" />
        <rect x="46" y="8" width="6" height="34" fill="#dc2626" />
        <rect x="58" y="8" width="6" height="34" fill="#78350f" />
        <rect x="80" y="8" width="6" height="34" fill="#eab308" />
        <!-- Label -->
        <text x="60" y="62" fill="#fbbf24" font-size="12" font-weight="bold" text-anchor="middle">220 Ω</text>
        <text x="60" y="76" fill="#94a3b8" font-size="10" text-anchor="middle">Resistor (Limits Current)</text>
        <!-- Highlight Ring -->
        <rect class="highlight-ring" x="12" y="0" width="96" height="50" rx="12" fill="none" stroke="#fbbf24" stroke-width="3" opacity="0" />
      </g>

      <!-- 3. LED COMPONENT (id: led, anode, cathode) -->
      <g class="svg-part" id="part-led-${cardIndex}" data-part="led anode cathode" transform="translate(490, 60)">
        <!-- Glowing Light Aura -->
        <circle id="led-aura-${cardIndex}" class="led-glow-aura" cx="25" cy="50" r="55" fill="url(#ledGlowGrad-${cardIndex})" opacity="0.8" />
        
        <!-- LED Anode Wire (Top) -->
        <line x1="0" y1="40" x2="25" y2="40" stroke="#f59e0b" stroke-width="4" />
        <!-- LED Cathode Wire (Bottom) -->
        <line x1="25" y1="160" x2="0" y2="160" stroke="#38bdf8" stroke-width="4" />
        <line x1="25" y1="75" x2="25" y2="160" stroke="#94a3b8" stroke-width="4" />

        <!-- LED Dome / Bulb -->
        <path id="led-bulb-${cardIndex}" d="M 10 50 A 15 15 0 0 1 40 50 L 40 65 L 10 65 Z" fill="#eab308" stroke="#ca8a04" stroke-width="2" />
        <!-- Base Rim -->
        <rect x="8" y="65" width="34" height="6" rx="2" fill="#ca8a04" />
        
        <!-- Emission Light Beams -->
        <g id="led-beams-${cardIndex}" class="emission-beams" stroke="#fde047" stroke-width="2.5" stroke-linecap="round">
          <line x1="45" y1="35" x2="65" y2="22" />
          <line x1="50" y1="50" x2="72" y2="50" />
          <line x1="45" y1="65" x2="65" y2="78" />
        </g>

        <!-- Labels -->
        <text x="50" y="95" fill="#facc15" font-size="13" font-weight="bold">LED (Light)</text>
        <text x="50" y="112" fill="#a3e635" font-size="10">+ Anode (Long Leg)</text>
        <text x="50" y="126" fill="#38bdf8" font-size="10">− Cathode (Short)</text>

        <!-- Highlight Ring -->
        <circle class="highlight-ring" cx="25" cy="55" r="45" fill="none" stroke="#fde047" stroke-width="3" opacity="0" />
      </g>

      <!-- Direction of Current Flow Arrow -->
      <g transform="translate(200, 85)" fill="#fbbf24">
        <polygon points="0,0 8,5 0,10" />
        <text x="12" y="9" fill="#fbbf24" font-size="10" font-weight="600">Current Flow (I)</text>
      </g>
    </svg>
  `;
}

function updateSVGHighlights(svgContainer, highlightIds) {
  // Reset all highlight rings
  svgContainer.querySelectorAll(".highlight-ring").forEach((ring) => {
    ring.style.opacity = "0";
    ring.classList.remove("pulsing-ring");
  });

  const aura = svgContainer.querySelector(".led-glow-aura");
  const beams = svgContainer.querySelector(".emission-beams");
  const particles = svgContainer.querySelector(".current-particles");

  // Determine if LED or Battery or Resistor is highlighted
  const hasLED = highlightIds.some((h) => ["led", "anode", "cathode"].includes(h.toLowerCase()));
  const hasBattery = highlightIds.some((h) => ["battery", "battery_plus", "pin", "5v"].includes(h.toLowerCase()));
  const hasResistor = highlightIds.some((h) => ["resistor"].includes(h.toLowerCase()));

  if (aura) aura.style.opacity = hasLED ? "1" : "0.3";
  if (beams) beams.style.opacity = hasLED ? "1" : "0.2";
  if (particles) particles.style.display = (hasBattery || hasResistor || hasLED) ? "block" : "none";

  svgContainer.querySelectorAll(".svg-part").forEach((part) => {
    const partKeys = (part.getAttribute("data-part") || "").split(" ");
    const isMatched = highlightIds.some((h) => partKeys.includes(h.toLowerCase()));
    const ring = part.querySelector(".highlight-ring");
    if (ring && isMatched) {
      ring.style.opacity = "1";
      ring.classList.add("pulsing-ring");
    }
  });
}

// ============================================================================
// 6. MODULAR RENDERER 2: SIMULATION (Dynamic Sliders & Real-Time Physics)
// ============================================================================
function renderSimulation(concept, container, cardIndex) {
  const sliders = concept.sliders && concept.sliders.length > 0 ? concept.sliders : [
    {
      id: "resistor",
      label: "Resistor Value",
      min: 100,
      max: 1000,
      value: 220,
      unit: "Ω",
      effect: "Bigger resistor limits current -> LED brightness goes down"
    }
  ];

  const wrapper = document.createElement("div");
  wrapper.className = "simulation-renderer";

  // Simulation Status Readout Bar
  const readoutBar = document.createElement("div");
  readoutBar.className = "sim-readout-bar";
  readoutBar.innerHTML = `
    <div class="readout-metric">
      <span class="metric-label">Resistance (R):</span>
      <span class="metric-val" id="sim-res-val-${cardIndex}">220 Ω</span>
    </div>
    <div class="readout-metric">
      <span class="metric-label">Calculated Current (I):</span>
      <span class="metric-val" id="sim-cur-val-${cardIndex}">13.6 mA</span>
    </div>
    <div class="readout-metric">
      <span class="metric-label">LED Status:</span>
      <span class="metric-status safe" id="sim-led-status-${cardIndex}">✅ Bright & Safe</span>
    </div>
  `;
  wrapper.appendChild(readoutBar);

  // SVG Drawing
  const svgWrapper = document.createElement("div");
  svgWrapper.className = "sim-svg-canvas";
  svgWrapper.innerHTML = createCircuitSVG(cardIndex + 100);
  wrapper.appendChild(svgWrapper);

  // Dynamic Sliders Control Deck
  const slidersDeck = document.createElement("div");
  slidersDeck.className = "sim-sliders-deck";

  sliders.forEach((sliderDef, sIdx) => {
    const sliderRow = document.createElement("div");
    sliderRow.className = "sim-slider-group";

    const min = sliderDef.min || 100;
    const max = sliderDef.max || 1000;
    const initialVal = sliderDef.value || 220;
    const unit = sliderDef.unit || "Ω";

    sliderRow.innerHTML = `
      <div class="slider-label-row">
        <label for="sim-slider-${cardIndex}-${sIdx}">
          <strong>🎛️ ${escapeHtml(sliderDef.label || "Resistance")}:</strong>
          <span class="slider-live-value" id="slider-disp-${cardIndex}-${sIdx}">${initialVal} ${unit}</span>
        </label>
        <span class="slider-effect-hint">${escapeHtml(sliderDef.effect || "")}</span>
      </div>
      <div class="slider-control-row">
        <span class="slider-bound">${min} ${unit}</span>
        <input
          type="range"
          id="sim-slider-${cardIndex}-${sIdx}"
          class="sim-range-input"
          min="${min}"
          max="${max}"
          value="${initialVal}"
          step="${sliderDef.step || 10}"
        />
        <span class="slider-bound">${max} ${unit}</span>
      </div>
    `;

    const input = sliderRow.querySelector("input");
    const display = sliderRow.querySelector(`#slider-disp-${cardIndex}-${sIdx}`);

    input.addEventListener("input", (e) => {
      const val = parseFloat(e.target.value);
      display.textContent = `${val} ${unit}`;
      updateSimulationPhysics(cardIndex + 100, val, cardIndex);
    });

    slidersDeck.appendChild(sliderRow);
  });

  wrapper.appendChild(slidersDeck);
  container.appendChild(wrapper);

  // Initial physics update
  setTimeout(() => updateSimulationPhysics(cardIndex + 100, 220, cardIndex), 50);
}

function updateSimulationPhysics(svgId, resistanceOhm, cardIndex) {
  // Ohm's law calculation: I = (5V - 2.0V) / R
  const voltageDrop = 3.0; // 5V source minus 2V LED forward drop
  const currentAmps = voltageDrop / resistanceOhm;
  const currentMilliAmps = (currentAmps * 1000).toFixed(1);

  // Update readouts
  const resValEl = document.getElementById(`sim-res-val-${cardIndex}`);
  const curValEl = document.getElementById(`sim-cur-val-${cardIndex}`);
  const ledStatusEl = document.getElementById(`sim-led-status-${cardIndex}`);

  if (resValEl) resValEl.textContent = `${resistanceOhm} Ω`;
  if (curValEl) curValEl.textContent = `${currentMilliAmps} mA`;

  if (ledStatusEl) {
    if (resistanceOhm < 150) {
      ledStatusEl.className = "metric-status danger";
      ledStatusEl.textContent = "🚨 Dangerous Current (>20mA)! LED may burn out!";
    } else if (resistanceOhm > 600) {
      ledStatusEl.className = "metric-status dim";
      ledStatusEl.textContent = "💤 Dim Glow (Low Current < 5mA)";
    } else {
      ledStatusEl.className = "metric-status safe";
      ledStatusEl.textContent = "✅ Bright & Safe Current";
    }
  }

  // Update SVG visual elements live
  const svg = document.getElementById(`circuit-svg-${svgId}`);
  if (!svg) return;

  const aura = svg.querySelector(".led-glow-aura");
  const beams = svg.querySelector(".emission-beams");
  const bulb = svg.querySelector(`#led-bulb-${svgId}`);

  // Scale brightness from 0.15 to 1.0
  const normalizedBrightness = Math.max(0.12, Math.min(1.0, 1.2 - (resistanceOhm - 100) / 900));

  if (aura) {
    aura.style.opacity = `${normalizedBrightness}`;
    aura.setAttribute("r", `${35 + normalizedBrightness * 35}`);
  }

  if (beams) {
    beams.style.opacity = `${normalizedBrightness}`;
    beams.style.transform = `scale(${0.7 + normalizedBrightness * 0.5})`;
    beams.style.transformOrigin = "25px 50px";
  }

  if (bulb) {
    const yellowIntensity = Math.floor(180 + normalizedBrightness * 75);
    bulb.setAttribute("fill", `rgb(${yellowIntensity}, ${yellowIntensity - 20}, 10)`);
  }
}

// ============================================================================
// 7. MODULAR RENDERERS 3-6 (Labelled Diagram, Mind Map, Comic, Comparison)
// ============================================================================
function renderLabelledDiagram(concept, container, cardIndex) {
  const parts = concept.parts || [
    { id: "led", label: "LED Bulb", explain: "Semiconductor diode emitting photons when energized." },
    { id: "anode", label: "Anode (+)", explain: "Longer lead connected to positive voltage rail." },
    { id: "cathode", label: "Cathode (−)", explain: "Shorter lead with flat spot connected to ground." }
  ];

  const wrapper = document.createElement("div");
  wrapper.className = "labelled-diagram-renderer";

  const svgCanvas = document.createElement("div");
  svgCanvas.className = "diagram-svg-canvas";
  svgCanvas.innerHTML = createCircuitSVG(cardIndex + 200);
  wrapper.appendChild(svgCanvas);

  const calloutBox = document.createElement("div");
  calloutBox.className = "part-callout-card";
  calloutBox.id = `callout-card-${cardIndex}`;
  calloutBox.innerHTML = `
    <span class="callout-icon">👆</span>
    <div class="callout-text">
      <strong>Tap any part above or below</strong>
      <span>Click any component to inspect its role and scientific properties!</span>
    </div>
  `;
  wrapper.appendChild(calloutBox);

  container.appendChild(wrapper);
}

function renderMindMap(concept, container, cardIndex) {
  const nodes = concept.nodes && concept.nodes.length > 0 ? concept.nodes : [
    { label: concept.title || "Electricity", role: "Core Subject" },
    { label: "Voltage (V)", role: "Push from Battery" },
    { label: "Current (I)", role: "Flow of Electrons" },
    { label: "Resistance (R)", role: "Limit & Control" },
    { label: "Complete Circuit", role: "Closed Loop to GND" }
  ];

  const wrapper = document.createElement("div");
  wrapper.className = "mindmap-renderer";

  const centerNode = document.createElement("div");
  centerNode.className = "mindmap-root-node";
  centerNode.innerHTML = `<span>⚡</span><strong>${escapeHtml(concept.title || "Core Idea")}</strong>`;
  wrapper.appendChild(centerNode);

  const branchesGrid = document.createElement("div");
  branchesGrid.className = "mindmap-branches-grid";

  nodes.forEach((node) => {
    const branch = document.createElement("div");
    branch.className = "mindmap-branch-card";
    branch.innerHTML = `
      <div class="branch-connector"></div>
      <h4>${escapeHtml(node.label || node.title || "")}</h4>
      <p>${escapeHtml(node.role || node.explain || node.summary || "")}</p>
    `;
    branchesGrid.appendChild(branch);
  });

  wrapper.appendChild(branchesGrid);
  container.appendChild(wrapper);
}

function renderStoryComic(concept, container, cardIndex) {
  const panels = concept.panels && concept.panels.length > 0 ? concept.panels : [
    { caption: "Meet Electron Eddie!", scene: "Eddie waits at the battery + terminal ready for an adventure." },
    { caption: "The Resistor Gatekeeper", scene: "Eddie meets Resistor Ron who keeps traffic orderly and safe." },
    { caption: "Into the LED Light Castle", scene: "Eddie jumps across the semiconductor junction releasing bright yellow light!" },
    { caption: "Home to Ground (GND)", scene: "Eddie returns home to complete the circuit loop!" }
  ];

  const wrapper = document.createElement("div");
  wrapper.className = "comic-strip-renderer";

  panels.slice(0, 4).forEach((panel, pIdx) => {
    const panelCard = document.createElement("div");
    panelCard.className = "comic-panel";
    panelCard.innerHTML = `
      <div class="panel-header">Panel ${pIdx + 1}</div>
      <div class="panel-scene-art">
        <span class="scene-icon">${["🔋", "🛡️", "💡", "⚡"][pIdx % 4]}</span>
        <p class="scene-desc">${escapeHtml(panel.scene || "")}</p>
      </div>
      <div class="panel-caption-bubble">
        <strong>${escapeHtml(panel.caption || "")}</strong>
      </div>
    `;
    wrapper.appendChild(panelCard);
  });

  container.appendChild(wrapper);
}

function renderComparison(concept, container, cardIndex) {
  const left = concept.left || { title: "Series Circuit", desc: "One single path for current.", feature: "If one bulb breaks, all go out." };
  const right = concept.right || { title: "Parallel Circuit", desc: "Multiple independent paths.", feature: "If one bulb breaks, others stay lit." };

  const wrapper = document.createElement("div");
  wrapper.className = "comparison-renderer";

  wrapper.innerHTML = `
    <div class="compare-card left">
      <div class="compare-header">
        <span class="compare-icon">🔵</span>
        <h3>${escapeHtml(left.title || "Option A")}</h3>
      </div>
      <p class="compare-desc">${escapeHtml(left.desc || left.summary || "")}</p>
      <div class="compare-feature-pill">${escapeHtml(left.feature || left.key_difference || "")}</div>
    </div>

    <div class="compare-vs-badge">VS</div>

    <div class="compare-card right">
      <div class="compare-header">
        <span class="compare-icon">🟢</span>
        <h3>${escapeHtml(right.title || "Option B")}</h3>
      </div>
      <p class="compare-desc">${escapeHtml(right.desc || right.summary || "")}</p>
      <div class="compare-feature-pill">${escapeHtml(right.feature || right.key_difference || "")}</div>
    </div>
  `;

  container.appendChild(wrapper);
}

// ============================================================================
// 8. INTERACTIVE PARTS LEGEND & CALLOUTS
// ============================================================================
function renderPartsLegend(parts, cardIndex) {
  const section = document.createElement("div");
  section.className = "concept-parts-section";

  section.innerHTML = `
    <div class="parts-header">
      <span>🔍</span>
      <strong>Tap any part to explore:</strong>
    </div>
    <div class="parts-pills-row" id="parts-row-${cardIndex}"></div>
    <div class="part-active-explain-card" id="part-explain-${cardIndex}" style="display: none;">
      <div class="explain-title" id="part-title-${cardIndex}"></div>
      <div class="explain-text" id="part-text-${cardIndex}"></div>
    </div>
  `;

  const pillsRow = section.querySelector(`#parts-row-${cardIndex}`);
  const explainCard = section.querySelector(`#part-explain-${cardIndex}`);
  const titleEl = section.querySelector(`#part-title-${cardIndex}`);
  const textEl = section.querySelector(`#part-text-${cardIndex}`);

  parts.forEach((part) => {
    const pill = document.createElement("button");
    pill.className = "part-chip";
    pill.textContent = part.label || part.id;
    pill.addEventListener("click", () => {
      pillsRow.querySelectorAll(".part-chip").forEach((p) => p.classList.remove("active"));
      pill.classList.add("active");

      titleEl.textContent = `📍 ${part.label || part.id}`;
      textEl.textContent = part.explain || "Component essential for the circuit operation.";
      explainCard.style.display = "block";
      explainCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });
    pillsRow.appendChild(pill);
  });

  return section;
}

// ============================================================================
// 9. "ASK A DOUBT" AI ASSISTANT BOX
// ============================================================================
function renderDoubtBox(concept, cardIndex) {
  const box = document.createElement("div");
  box.className = "concept-doubt-box";

  box.innerHTML = `
    <div class="doubt-header">
      <div class="doubt-title">
        <span>💬</span>
        <strong>Have a doubt about "${escapeHtml(concept.title)}"?</strong>
      </div>
      <span class="doubt-subtitle">Ask Learnix AI in simple words with analogies!</span>
    </div>

    <div class="doubt-suggestions">
      <button class="doubt-chip" data-q="What happens if I connect the LED backwards?">🔄 What if LED is backwards?</button>
      <button class="doubt-chip" data-q="Why doesn't the LED work without a resistor?">🔥 Why is resistor needed?</button>
      <button class="doubt-chip" data-q="Can I use a 9V battery instead of 5V?">🔋 Can I use a 9V battery?</button>
    </div>

    <div class="doubt-input-group">
      <input
        type="text"
        id="doubt-input-${cardIndex}"
        class="doubt-input"
        placeholder="Type your question here (e.g. Why do we need ground?)..."
      />
      <button id="btn-doubt-${cardIndex}" class="btn btn-doubt">
        <span class="btn-doubt-spinner" style="display:none;"></span>
        <span class="btn-doubt-text">Ask AI</span>
      </button>
    </div>

    <div class="doubt-response-bubble" id="doubt-resp-${cardIndex}" style="display: none;">
      <div class="ai-avatar">🤖</div>
      <div class="ai-bubble-content">
        <div class="ai-answer-text" id="doubt-answer-${cardIndex}"></div>
        <div class="ai-tip-badge" id="doubt-tip-${cardIndex}" style="display:none;"></div>
      </div>
    </div>
  `;

  const input = box.querySelector(`#doubt-input-${cardIndex}`);
  const btn = box.querySelector(`#btn-doubt-${cardIndex}`);
  const respBubble = box.querySelector(`#doubt-resp-${cardIndex}`);
  const answerEl = box.querySelector(`#doubt-answer-${cardIndex}`);
  const tipEl = box.querySelector(`#doubt-tip-${cardIndex}`);

  box.querySelectorAll(".doubt-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      input.value = chip.getAttribute("data-q");
      submitDoubt();
    });
  });

  btn.addEventListener("click", submitDoubt);
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      submitDoubt();
    }
  });

  async function submitDoubt() {
    const question = input.value.trim();
    if (!question) return;

    btn.disabled = true;
    const spinner = btn.querySelector(".btn-doubt-spinner");
    const text = btn.querySelector(".btn-doubt-text");
    if (spinner) spinner.style.display = "inline-block";
    if (text) text.textContent = "Thinking...";

    try {
      const res = await fetch("/api/concept-studio/doubt", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          student_id: STUDENT_ID,
          concept_title: concept.title,
          question: question,
          language: currentLanguage,
        }),
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      answerEl.textContent = data.answer || "That is a great question! Current flows like water in a pipe.";
      if (data.tip) {
        tipEl.textContent = `💡 Pro Tip: ${data.tip}`;
        tipEl.style.display = "block";
      } else {
        tipEl.style.display = "none";
      }

      respBubble.style.display = "flex";
      respBubble.scrollIntoView({ behavior: "smooth", block: "nearest" });
    } catch (err) {
      console.error("Doubt API error:", err);
      answerEl.textContent = "Think of a circuit like a water slide: the battery is the water pump, the resistor is a valve, and the LED is the waterwheel!";
      respBubble.style.display = "flex";
    } finally {
      btn.disabled = false;
      if (spinner) spinner.style.display = "none";
      if (text) text.textContent = "Ask AI";
    }
  }

  return box;
}

// ============================================================================
// 10. VISUAL QUIZ (Order / Label / Predict) WITH INSTANT FEEDBACK & SCORING
// ============================================================================
function renderVisualQuiz(concept, cardIndex) {
  const quizQuestions = concept.quiz.slice(0, 3);
  let correctAnswersCount = 0;
  let answeredCount = 0;

  const card = document.createElement("div");
  card.className = "concept-quiz-card";

  card.innerHTML = `
    <div class="quiz-header">
      <div class="quiz-title">
        <span>🏆</span>
        <strong>Visual Quiz &amp; Knowledge Check</strong>
      </div>
      <div class="quiz-score-badge" id="quiz-score-badge-${cardIndex}">
        Score: 0 / ${quizQuestions.length}
      </div>
    </div>
    <div class="quiz-questions-list" id="quiz-list-${cardIndex}"></div>
    <div class="quiz-completed-banner" id="quiz-done-${cardIndex}" style="display: none;">
      <span class="done-icon">🌟</span>
      <div class="done-text">
        <strong id="done-title-${cardIndex}">Awesome job!</strong>
        <p id="done-sub-${cardIndex}">Your score has been saved to your learning profile.</p>
      </div>
    </div>
  `;

  const listEl = card.querySelector(`#quiz-list-${cardIndex}`);
  const scoreBadge = card.querySelector(`#quiz-score-badge-${cardIndex}`);
  const doneBanner = card.querySelector(`#quiz-done-${cardIndex}`);
  const doneTitle = card.querySelector(`#done-title-${cardIndex}`);

  quizQuestions.forEach((q, qIdx) => {
    const qItem = document.createElement("div");
    qItem.className = "quiz-question-item";

    const kindLabel = q.kind ? `[${q.kind.toUpperCase()}] ` : "";
    qItem.innerHTML = `
      <div class="question-prompt">
        <span class="q-num">Q${qIdx + 1}.</span>
        <span class="q-text">${escapeHtml(kindLabel + q.question)}</span>
      </div>
      <div class="quiz-options-grid" id="options-${cardIndex}-${qIdx}"></div>
      <div class="quiz-why-card" id="why-${cardIndex}-${qIdx}" style="display: none;"></div>
    `;

    const optionsGrid = qItem.querySelector(`#options-${cardIndex}-${qIdx}`);
    const whyCard = qItem.querySelector(`#why-${cardIndex}-${qIdx}`);
    const options = q.options || ["Option A", "Option B", "Option C", "Option D"];
    const correctAnswerIdx = typeof q.answer === "number" ? q.answer : 0;

    options.forEach((optText, optIdx) => {
      const optBtn = document.createElement("button");
      optBtn.className = "quiz-option-btn";
      optBtn.innerHTML = `
        <span class="opt-letter">${String.fromCharCode(65 + optIdx)}</span>
        <span class="opt-label">${escapeHtml(optText)}</span>
      `;

      optBtn.addEventListener("click", () => {
        // Prevent double answering
        if (optBtn.disabled) return;

        // Disable all options for this question
        optionsGrid.querySelectorAll(".quiz-option-btn").forEach((b) => (b.disabled = true));

        answeredCount++;
        const isCorrect = optIdx === correctAnswerIdx;

        if (isCorrect) {
          correctAnswersCount++;
          optBtn.classList.add("correct");
          whyCard.className = "quiz-why-card correct";
          whyCard.innerHTML = `<strong>✅ Correct!</strong> ${escapeHtml(q.why || "Great job understanding this concept!")}`;
        } else {
          optBtn.classList.add("incorrect");
          // Highlight the right answer
          const correctBtn = optionsGrid.children[correctAnswerIdx];
          if (correctBtn) correctBtn.classList.add("correct-reveal");
          whyCard.className = "quiz-why-card incorrect";
          whyCard.innerHTML = `<strong>❌ Not quite.</strong> ${escapeHtml(q.why || `The correct answer is ${options[correctAnswerIdx]}.`)}`;
        }

        whyCard.style.display = "block";
        scoreBadge.textContent = `Score: ${correctAnswersCount} / ${quizQuestions.length}`;

        // When all questions answered, save quiz score to backend
        if (answeredCount === quizQuestions.length) {
          saveQuizResult(concept.concept_id || 1, correctAnswersCount, quizQuestions.length);
          doneTitle.textContent = `Scored ${correctAnswersCount} out of ${quizQuestions.length}!`;
          doneBanner.style.display = "flex";
        }
      });

      optionsGrid.appendChild(optBtn);
    });

    listEl.appendChild(qItem);
  });

  return card;
}

// POST /api/quiz-result
async function saveQuizResult(conceptId, score, maxScore) {
  try {
    const res = await fetch("/api/quiz-result", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        student_id: STUDENT_ID,
        concept_id: conceptId,
        score: score,
        max_score: maxScore,
      }),
    });
    if (res.ok) {
      console.log(`Quiz result saved: ${score}/${maxScore} for concept ${conceptId}`);
    }
  } catch (err) {
    console.warn("Could not save quiz attempt:", err);
  }
}

// ============================================================================
// 11. RECENT LESSONS DRAWER (GET /api/visual-lessons/{student_id})
// ============================================================================
async function loadRecentLessons() {
  if (!recentLessonsSection || !recentPillsList) return;

  try {
    const res = await fetch(`/api/visual-lessons/${STUDENT_ID}`);
    if (!res.ok) return;

    const data = await res.json();
    const lessons = data.visual_lessons || [];

    if (lessons.length === 0) {
      recentLessonsSection.style.display = "none";
      return;
    }

    recentPillsList.innerHTML = "";
    lessons.slice(0, 5).forEach((item) => {
      const pill = document.createElement("button");
      pill.className = "recent-lesson-pill";
      const title = item.concept_title || (item.content_json && item.content_json.title) || `Lesson #${item.id}`;
      pill.textContent = `📖 ${title}`;
      pill.addEventListener("click", () => {
        if (item.content_json) {
          const raw = item.content_json;
          // Normalize if page or topic
          const c = raw.concepts ? raw.concepts : [raw];
          renderAllConcepts(c);
        }
      });
      recentPillsList.appendChild(pill);
    });

    recentLessonsSection.style.display = "block";
  } catch (err) {
    console.warn("Could not load recent lessons:", err);
  }
}

// Helper: Escape HTML to avoid injection
function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
