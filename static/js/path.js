/**
 * Learnix AI — My Learning Path JS
 * Handles 10-day interactive path:
 * - Roadmap grid with status: locked (grey), current (highlighted), done (green tick + score)
 * - 3-step active mission modal:
 *   Step 1: Learn (Concept Studio visual model)
 *   Step 2: Try (Virtual Lab experiment)
 *   Step 3: Check (3-question visual quiz with instant feedback)
 * - On complete: calls /api/path/{student_id}/day/{day}/complete
 * - If score < 50%, shows AI Coach revision step with analogy and encouragement before unlocking!
 */

const STUDENT_ID = 1;
let currentPathData = null;
let activeDayNumber = 1;
let activeDayContent = null;
let currentMissionStep = "learn";
let quizAnswers = {};
let latestQuizScore = 0;

document.addEventListener("DOMContentLoaded", () => {
  loadLearningPath();
  setupModalEvents();
  setupMissionStepNav();
});

// ============================================================================
// 1. LOAD & RENDER LEARNING PATH ROADMAP
// ============================================================================
async function loadLearningPath() {
  const grid = document.getElementById("days-grid");
  try {
    const res = await fetch(`/api/path/${STUDENT_ID}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    currentPathData = await res.json();
    renderOverallProgress(currentPathData);
    renderDaysGrid(currentPathData.days);
  } catch (err) {
    console.error("Error loading learning path:", err);
    if (grid) {
      grid.innerHTML = `<div class="empty-diag-box"><p>Unable to load learning path. Retrying...</p></div>`;
    }
  }
}

function renderOverallProgress(data) {
  const completedCount = data.completed_count || 0;
  const totalDays = data.total_days || 10;
  const pct = data.progress_percentage || Math.round((completedCount / totalDays) * 100);

  const countEl = document.getElementById("completed-days-count");
  const pctEl = document.getElementById("path-pct-text");
  const barFill = document.getElementById("path-progress-bar-fill");

  if (countEl) countEl.textContent = completedCount;
  if (pctEl) pctEl.textContent = `${pct}% Complete`;
  if (barFill) barFill.style.width = `${pct}%`;
}

function renderDaysGrid(days) {
  const grid = document.getElementById("days-grid");
  if (!grid || !days) return;

  grid.innerHTML = "";

  days.forEach((day) => {
    const card = document.createElement("div");
    card.className = `day-card ${day.status}`;
    card.id = `day-card-${day.day_number}`;

    const visualTypeBadge = day.visual_type ? `[${day.visual_type.replace('_', ' ')}]` : '';
    const hasLabTag = day.experiment ? `<span class="lab-indicator-pill">🔬 Lab: ${escapeHtml(day.experiment.title)}</span>` : '';

    let statusHeader = "";
    let actionBtn = "";

    if (day.status === "done") {
      statusHeader = `
        <span class="day-status-pill done">✅ Completed</span>
        <span class="day-score-pill">Score: ${day.quiz_score !== null ? day.quiz_score : 3}/3 ⭐</span>
      `;
      actionBtn = `
        <button class="btn btn-sm btn-outline-done" onclick="openDayMission(${day.day_number})">
          Review Day ${day.day_number}
        </button>
      `;
    } else if (day.status === "current") {
      statusHeader = `
        <span class="day-status-pill current">🔥 Today's Mission</span>
        <span class="day-pulse-dot"></span>
      `;
      actionBtn = `
        <button class="btn btn-sm btn-primary-day" onclick="openDayMission(${day.day_number})">
          ▶ Start Day ${day.day_number}
        </button>
      `;
    } else {
      statusHeader = `
        <span class="day-status-pill locked">🔒 Locked</span>
      `;
      actionBtn = `
        <button class="btn btn-sm btn-disabled" disabled>
          Locked (Complete Day ${day.day_number - 1})
        </button>
      `;
    }

    card.innerHTML = `
      <div class="day-card-top">
        <span class="day-number-label">DAY ${day.day_number}</span>
        <div class="day-card-status-badges">${statusHeader}</div>
      </div>
      <h3 class="day-card-title">${escapeHtml(day.title)}</h3>
      <p class="day-card-desc">${escapeHtml(day.concept ? day.concept.summary : '')}</p>
      <div class="day-card-tags">
        <span class="vtype-pill">${visualTypeBadge}</span>
        ${hasLabTag}
      </div>
      <div class="day-card-footer">
        ${actionBtn}
      </div>
    `;

    grid.appendChild(card);
  });
}

// ============================================================================
// 2. ACTIVE DAY MISSION (MODAL & 3 STEPS)
// ============================================================================
function setupModalEvents() {
  const btnClose = document.getElementById("btn-close-modal");
  const modal = document.getElementById("day-modal");

  if (btnClose && modal) {
    btnClose.addEventListener("click", () => {
      modal.style.display = "none";
    });
  }
}

function setupMissionStepNav() {
  const stepLearn = document.getElementById("step-tab-learn");
  const stepTry = document.getElementById("step-tab-try");
  const stepCheck = document.getElementById("step-tab-check");

  const btnGotoTry = document.getElementById("btn-goto-try");
  const btnBackLearn = document.getElementById("btn-back-learn");
  const btnGotoCheck = document.getElementById("btn-goto-check");
  const btnBackTry = document.getElementById("btn-back-try");
  const btnFinish = document.getElementById("btn-finish-day");

  if (stepLearn) stepLearn.addEventListener("click", () => switchMissionStep("learn"));
  if (stepTry) stepTry.addEventListener("click", () => switchMissionStep("try"));
  if (stepCheck) stepCheck.addEventListener("click", () => switchMissionStep("check"));

  if (btnGotoTry) btnGotoTry.addEventListener("click", () => switchMissionStep("try"));
  if (btnBackLearn) btnBackLearn.addEventListener("click", () => switchMissionStep("learn"));
  if (btnGotoCheck) btnGotoCheck.addEventListener("click", () => switchMissionStep("check"));
  if (btnBackTry) btnBackTry.addEventListener("click", () => switchMissionStep("try"));
  if (btnFinish) btnFinish.addEventListener("click", submitDayCompletion);
}

function switchMissionStep(stepName) {
  currentMissionStep = stepName;

  document.querySelectorAll(".mission-step-tab").forEach((tab) => {
    tab.classList.toggle("active", tab.getAttribute("data-step") === stepName);
  });

  const viewLearn = document.getElementById("step-view-learn");
  const viewTry = document.getElementById("step-view-try");
  const viewCheck = document.getElementById("step-view-check");

  if (viewLearn) viewLearn.style.display = stepName === "learn" ? "block" : "none";
  if (viewTry) viewTry.style.display = stepName === "try" ? "block" : "none";
  if (viewCheck) viewCheck.style.display = stepName === "check" ? "block" : "none";
}

// Open active day mission
async function openDayMission(dayNumber) {
  activeDayNumber = dayNumber;
  quizAnswers = {};
  latestQuizScore = 0;

  const modal = document.getElementById("day-modal");
  const dayBadge = document.getElementById("modal-day-badge");
  const dayTitle = document.getElementById("modal-day-title");

  if (dayBadge) dayBadge.textContent = `DAY ${dayNumber}`;
  if (modal) modal.style.display = "flex";

  // Reset completion banners and revision boxes
  const revCard = document.getElementById("coach-revision-card");
  const doneBanner = document.getElementById("day-completed-banner");
  const btnFinish = document.getElementById("btn-finish-day");

  if (revCard) revCard.style.display = "none";
  if (doneBanner) doneBanner.style.display = "none";
  if (btnFinish) btnFinish.style.display = "none";

  // Switch to Step 1: Learn
  switchMissionStep("learn");

  try {
    const res = await fetch(`/api/path/day/${dayNumber}/content`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    activeDayContent = await res.json();
    if (dayTitle) dayTitle.textContent = activeDayContent.title;

    renderStep1Learn(activeDayContent.learn);
    renderStep2Try(activeDayContent.try);
    renderStep3Check(activeDayContent.check);
  } catch (err) {
    console.error("Error loading day content:", err);
  }
}

// Render Step 1: Learn
function renderStep1Learn(learnSpec) {
  const container = document.getElementById("learn-visual-container");
  const summaryEl = document.getElementById("learn-summary-text");
  if (!container || !learnSpec) return;

  container.innerHTML = "";
  if (summaryEl) summaryEl.textContent = learnSpec.summary || "Explore the interactive visual concept.";

  // Dispatch to modular renderers from concept_studio.js
  const vType = learnSpec.type || "animated_steps";
  switch (vType) {
    case "animated_steps":
      if (typeof renderAnimatedSteps === "function") {
        renderAnimatedSteps(learnSpec, container, 500 + activeDayNumber);
      } else {
        container.innerHTML = `<div class="p-3 text-white">Visual diagram for ${escapeHtml(learnSpec.title)}</div>`;
      }
      break;
    case "simulation":
      if (typeof renderSimulation === "function") {
        renderSimulation(learnSpec, container, 600 + activeDayNumber);
      }
      break;
    case "labelled_diagram":
      if (typeof renderLabelledDiagram === "function") {
        renderLabelledDiagram(learnSpec, container, 700 + activeDayNumber);
      }
      break;
    case "story_comic":
      if (typeof renderStoryComic === "function") {
        renderStoryComic(learnSpec, container, 800 + activeDayNumber);
      }
      break;
    case "comparison":
      if (typeof renderComparison === "function") {
        renderComparison(learnSpec, container, 900 + activeDayNumber);
      }
      break;
    default:
      if (typeof renderAnimatedSteps === "function") {
        renderAnimatedSteps(learnSpec, container, 500 + activeDayNumber);
      }
      break;
  }
}

// Render Step 2: Try
function renderStep2Try(trySpec) {
  const tryCard = document.getElementById("try-content-card");
  const tryTitle = document.getElementById("try-exp-title");
  const tryDesc = document.getElementById("try-exp-desc");
  const tryComponents = document.getElementById("try-components-list");
  const btnOpenLab = document.getElementById("btn-open-lab");
  const tryGoalText = document.getElementById("try-goal-text");

  if (!tryCard) return;

  if (trySpec && trySpec.experiment_id) {
    tryCard.style.display = "flex";
    if (tryTitle) tryTitle.textContent = `Experiment #${trySpec.experiment_id}: ${trySpec.title}`;
    if (tryDesc) tryDesc.textContent = trySpec.goal;
    if (tryGoalText) tryGoalText.textContent = trySpec.goal;
    if (tryComponents) tryComponents.textContent = `Components: ${trySpec.components}`;
    if (btnOpenLab) btnOpenLab.href = `/virtual_lab.html?exp=${trySpec.experiment_id}`;
  } else {
    // Conceptual Day without hardware experiment
    if (tryTitle) tryTitle.textContent = `Hands-on Activity for Day ${activeDayNumber}`;
    if (tryDesc) tryDesc.textContent = `Review component rules, sketch the diagram in your notebook, or test circuit variables!`;
    if (tryComponents) tryComponents.textContent = `Tools: Pen, Paper, and Concept Studio`;
    if (btnOpenLab) btnOpenLab.href = `/concept_studio.html`;
  }
}

// Render Step 3: Check (3-Question Quiz)
function renderStep3Check(questions) {
  const container = document.getElementById("quiz-questions-container");
  if (!container || !questions) return;

  container.innerHTML = "";
  quizAnswers = {};
  latestQuizScore = 0;

  questions.forEach((q, qIdx) => {
    const qCard = document.createElement("div");
    qCard.className = "mission-quiz-q-card";

    qCard.innerHTML = `
      <div class="q-prompt-row">
        <span class="q-badge">Q${qIdx + 1}</span>
        <strong>${escapeHtml(q.question)}</strong>
      </div>
      <div class="quiz-options-grid" id="q-opt-grid-${qIdx}"></div>
      <div class="quiz-feedback-box" id="q-feedback-${qIdx}" style="display: none;"></div>
    `;

    const optGrid = qCard.querySelector(`#q-opt-grid-${qIdx}`);
    const feedbackBox = qCard.querySelector(`#q-feedback-${qIdx}`);
    const options = q.options || ["Option A", "Option B", "Option C", "Option D"];
    const correctIdx = typeof q.answer === "number" ? q.answer : 0;

    options.forEach((optText, optIdx) => {
      const btn = document.createElement("button");
      btn.className = "quiz-option-btn";
      btn.innerHTML = `
        <span class="opt-letter">${String.fromCharCode(65 + optIdx)}</span>
        <span class="opt-label">${escapeHtml(optText)}</span>
      `;

      btn.addEventListener("click", () => {
        if (btn.disabled) return;
        optGrid.querySelectorAll(".quiz-option-btn").forEach((b) => (b.disabled = true));

        const isCorrect = optIdx === correctIdx;
        quizAnswers[qIdx] = isCorrect;

        if (isCorrect) {
          btn.classList.add("correct");
          feedbackBox.className = "quiz-feedback-box correct";
          feedbackBox.innerHTML = `✅ <strong>Correct!</strong> ${escapeHtml(q.why || "Great job!")}`;
        } else {
          btn.classList.add("incorrect");
          const rightBtn = optGrid.children[correctIdx];
          if (rightBtn) rightBtn.classList.add("correct-reveal");
          feedbackBox.className = "quiz-feedback-box incorrect";
          feedbackBox.innerHTML = `❌ <strong>Not quite.</strong> ${escapeHtml(q.why || "Review the concept diagram!")}`;
        }
        feedbackBox.style.display = "block";

        // Check if all 3 questions answered
        if (Object.keys(quizAnswers).length === questions.length) {
          latestQuizScore = Object.values(quizAnswers).filter(Boolean).length;
          const btnFinish = document.getElementById("btn-finish-day");
          if (btnFinish) {
            btnFinish.style.display = "inline-flex";
            btnFinish.scrollIntoView({ behavior: "smooth", block: "nearest" });
          }
        }
      });

      optGrid.appendChild(btn);
    });

    container.appendChild(qCard);
  });
}

// Complete Day API call
async function submitDayCompletion() {
  const btnFinish = document.getElementById("btn-finish-day");
  if (btnFinish) btnFinish.disabled = true;

  try {
    const res = await fetch(`/api/path/${STUDENT_ID}/day/${activeDayNumber}/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        quiz_score: latestQuizScore,
        max_score: 3,
      }),
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();

    // Check if AI Coach inserted a revision step (< 50%)
    const revCard = document.getElementById("coach-revision-card");
    const recapText = document.getElementById("rev-recap-text");
    const analogyText = document.getElementById("rev-analogy-text");
    const tipText = document.getElementById("rev-tip-text");

    if (data.revision && data.revision.needed) {
      if (recapText) recapText.textContent = data.revision.recap || "Let's review the fundamental rules!";
      if (analogyText) analogyText.textContent = data.revision.analogy || "Think of current like water flow.";
      if (tipText) tipText.textContent = data.revision.coach_tip || "Take a moment to check your notes.";
      if (revCard) {
        revCard.style.display = "block";
        revCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
      }
    } else {
      if (revCard) revCard.style.display = "none";
    }

    // Show completion banner
    const doneBanner = document.getElementById("day-completed-banner");
    const bannerTitle = document.getElementById("completed-banner-title");
    const bannerSub = document.getElementById("completed-banner-subtitle");

    if (bannerTitle) bannerTitle.textContent = `Day ${activeDayNumber} Completed! (${latestQuizScore}/3 ⭐)`;
    if (bannerSub) {
      bannerSub.textContent = data.unlocked_day
        ? `Day ${data.unlocked_day} is now unlocked on your roadmap!`
        : `Congratulations! You have completed the entire 10-day robotics curriculum!`;
    }
    if (doneBanner) {
      doneBanner.style.display = "flex";
      doneBanner.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }

    if (btnFinish) btnFinish.style.display = "none";

    // Reload roadmap
    loadLearningPath();
  } catch (err) {
    console.error("Error completing day:", err);
  } finally {
    if (btnFinish) btnFinish.disabled = false;
  }
}

function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
