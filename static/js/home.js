/**
 * Learnix AI — Student Home Hub JS
 * Fetches data from /api/coach/{student_id} and /api/reports/parent/{student_id}
 * Displays:
 * - Circular SVG Progress Ring with animated stroke
 * - AI Coach personalized voice & advice
 * - "Your Next Step" recommended concepts & hands-on project cards
 * - Weak concepts needing practice with diagnostic reasons
 */

var STUDENT_ID = window.STUDENT_ID || 1;

document.addEventListener("DOMContentLoaded", () => {
  loadStudentDashboard();
  setupSpeechSynthesis();
});

async function loadStudentDashboard() {
  try {
    // Parallel fetch of coach diagnostic data and stats
    const [coachRes, parentRes] = await Promise.all([
      fetch(`/api/coach/${STUDENT_ID}`).catch(() => null),
      fetch(`/api/reports/parent/${STUDENT_ID}`).catch(() => null),
    ]);

    const coachData = coachRes && coachRes.ok ? await coachRes.json() : null;
    const parentData = parentRes && parentRes.ok ? await parentRes.json() : null;

    if (coachData) {
      renderStudentHeader(coachData.student);
      renderCoachMessage(coachData.coach_message);
      renderNextSteps(coachData.next_concepts, coachData.recommended_experiment);
      renderWeakConcepts(coachData.weak_concepts);
    }

    // Compute and animate progress ring
    renderProgressRing(coachData, parentData);
  } catch (err) {
    console.error("Error loading student dashboard:", err);
  }
}

function renderStudentHeader(student) {
  if (!student) return;
  const name = student.first_name || "Aarav";
  const grade = student.grade || 8;
  const centre = student.centre_name || "Namakkal STEM Lab";

  const greetingEl = document.getElementById("hero-greeting");
  const badgeEl = document.getElementById("header-student-badge");

  if (greetingEl) {
    greetingEl.textContent = `Hi, ${name}! Ready to build something awesome? 🚀`;
  }
  if (badgeEl) {
    badgeEl.textContent = `${name} (Grade ${grade} &bull; ${centre})`;
  }
}

function renderProgressRing(coachData, parentData) {
  const stats = (parentData && parentData.stats) || {};
  const totalQuizzes = stats.total_quizzes || 6;
  const totalLabs = stats.total_lab_runs || 7;
  const successLabs = stats.successful_lab_runs || 1;
  const strongConcepts = (stats.strong_concepts && stats.strong_concepts.length) || 4;

  const statQuizzesEl = document.getElementById("stat-quizzes-count");
  const statLabsEl = document.getElementById("stat-labs-count");
  const statMasteredEl = document.getElementById("stat-mastered-count");
  const masteryDisplay = document.getElementById("mastery-pct-display");
  const circleBar = document.getElementById("progress-circle-bar");

  if (statQuizzesEl) statQuizzesEl.textContent = totalQuizzes;
  if (statLabsEl) statLabsEl.textContent = totalLabs;
  if (statMasteredEl) statMasteredEl.textContent = strongConcepts;

  // Calculate mastery score: weighted average of quiz completion and lab builds
  const quizFactor = Math.min(100, (totalQuizzes / 10) * 100);
  const labFactor = Math.min(100, (totalLabs / 10) * 100);
  const calculatedPct = Math.round((quizFactor * 0.4) + (labFactor * 0.6)) || 65;

  if (masteryDisplay) {
    animateCounter(masteryDisplay, calculatedPct, "%");
  }

  if (circleBar) {
    // Circumference = 2 * PI * 64 ≈ 402
    const circumference = 402;
    const offset = circumference - (calculatedPct / 100) * circumference;
    setTimeout(() => {
      circleBar.style.strokeDashoffset = `${offset}`;
    }, 100);
  }
}

function renderCoachMessage(message) {
  const coachEl = document.getElementById("coach-message-text");
  if (coachEl && message) {
    coachEl.textContent = message;
  }
}

function setupSpeechSynthesis() {
  const btnSpeak = document.getElementById("btn-speak-coach");
  const coachEl = document.getElementById("coach-message-text");

  if (!btnSpeak || !coachEl) return;

  btnSpeak.addEventListener("click", () => {
    if (!("speechSynthesis" in window)) {
      alert("Text-to-speech is not supported in this browser.");
      return;
    }

    if (window.speechSynthesis.speaking) {
      window.speechSynthesis.cancel();
      btnSpeak.innerHTML = "🔊 Listen";
      return;
    }

    const text = coachEl.textContent || "";
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 0.95;
    utterance.pitch = 1.05;

    utterance.onstart = () => {
      btnSpeak.innerHTML = "⏹ Stop";
    };
    utterance.onend = () => {
      btnSpeak.innerHTML = "🔊 Listen";
    };

    window.speechSynthesis.speak(utterance);
  });
}

function renderNextSteps(nextConcepts, recommendedExperiment) {
  const container = document.getElementById("next-steps-grid");
  if (!container) return;

  container.innerHTML = "";

  // 1. Render recommended next concepts (1 or 2 cards)
  if (nextConcepts && nextConcepts.length > 0) {
    nextConcepts.forEach((c) => {
      const card = document.createElement("div");
      card.className = "next-step-card concept-step-card";

      card.innerHTML = `
        <div class="step-card-header">
          <span class="step-type-pill">📘 Theory &amp; Visuals</span>
          <span class="step-level-tag">${escapeHtml(c.level || "Beginner")}</span>
        </div>
        <h3 class="step-card-title">${escapeHtml(c.title)}</h3>
        <p class="step-card-summary">${escapeHtml(c.summary || "")}</p>
        <div class="step-why-box">
          <span class="why-icon">💡</span>
          <span class="why-text"><strong>Why:</strong> ${escapeHtml(c.why_recommended || "Recommended next step in curriculum")}</span>
        </div>
        <a href="/concept_studio.html" class="btn btn-step-action btn-blue">
          📖 Study in Concept Studio &rarr;
        </a>
      `;
      container.appendChild(card);
    });
  }

  // 2. Render recommended hands-on experiment card
  if (recommendedExperiment) {
    const exp = recommendedExperiment;
    const card = document.createElement("div");
    card.className = "next-step-card experiment-step-card highlight-orange";

    card.innerHTML = `
      <div class="step-card-header">
        <span class="step-type-pill orange">🔬 Hands-on Lab Project</span>
        <span class="step-level-tag">Exp #${exp.id}</span>
      </div>
      <h3 class="step-card-title">${escapeHtml(exp.title)}</h3>
      <p class="step-card-summary"><strong>Goal:</strong> ${escapeHtml(exp.goal || "Build circuit on breadboard and run code.")}</p>
      <div class="step-components-row">
        <span class="comp-label">Components:</span>
        <span class="comp-tags">${escapeHtml(exp.components || "Arduino, Breadboard, Wires")}</span>
      </div>
      <a href="/virtual_lab.html?exp=${exp.id}" class="btn btn-step-action btn-orange">
        🚀 Build Project in Virtual Lab &rarr;
      </a>
    `;
    container.appendChild(card);
  }
}

function renderWeakConcepts(weakConcepts) {
  const container = document.getElementById("weak-concepts-grid");
  if (!container) return;

  container.innerHTML = "";

  if (!weakConcepts || weakConcepts.length === 0) {
    container.innerHTML = `
      <div class="empty-weak-card">
        <span class="empty-icon">🌟</span>
        <strong>All clear!</strong>
        <p>No critical weak concepts detected. Great job mastering your robotics lessons!</p>
      </div>
    `;
    return;
  }

  weakConcepts.slice(0, 4).forEach((wc) => {
    const card = document.createElement("div");
    card.className = "weak-concept-card";

    const quizScoreBadge = wc.avg_quiz_pct !== null && wc.avg_quiz_pct !== undefined
      ? `<span class="weak-metric-badge red">Quiz Avg: ${wc.avg_quiz_pct}%</span>`
      : "";
    const labErrorBadge = wc.lab_error_count > 0
      ? `<span class="weak-metric-badge orange">⚠️ ${wc.lab_error_count} Lab Error(s)</span>`
      : "";

    card.innerHTML = `
      <div class="weak-header">
        <h4>${escapeHtml(wc.title)}</h4>
        <span class="weak-cat-pill">${escapeHtml(wc.category || "Robotics")}</span>
      </div>
      <div class="weak-metrics-row">
        ${quizScoreBadge}
        ${labErrorBadge}
      </div>
      <p class="weak-reason-text">${escapeHtml(wc.reason || "Needs review and concept reinforcement.")}</p>
      <a href="/concept_studio.html" class="btn btn-sm btn-outline-weak">
        ✨ Visual Practice in Studio &rarr;
      </a>
    `;
    container.appendChild(card);
  });
}

function animateCounter(el, target, suffix = "") {
  let start = 0;
  const duration = 800;
  const stepTime = 20;
  const increment = target / (duration / stepTime);

  const timer = setInterval(() => {
    start += increment;
    if (start >= target) {
      el.textContent = `${target}${suffix}`;
      clearInterval(timer);
    } else {
      el.textContent = `${Math.round(start)}${suffix}`;
    }
  }, stepTime);
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
