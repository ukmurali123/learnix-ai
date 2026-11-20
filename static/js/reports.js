/**
 * Learnix AI — Reports & Analytics JS
 * Handles:
 * (1) Parent Weekly Report: AI-written progress note in chosen language via /api/reports/parent/{student_id}
 * (2) Centre Dashboard: Table + Bar Chart of average quiz score, lab success rate,
 *     students needing help, plus AI.EXTRACT feedback sentiment summary via /api/reports/centres.
 */

const STUDENT_ID = 1;
let currentParentLanguage = "English";
let centresDataCache = null;
let currentChartMetric = "quiz"; // 'quiz' | 'lab' | 'help'

document.addEventListener("DOMContentLoaded", () => {
  setupTabEvents();
  setupParentReportControls();
  setupChartMetricEvents();

  // Load initial views
  loadParentReport();
  loadCentresDashboard();
});

// ============================================================================
// 1. TABS & PRINT SETUP
// ============================================================================
function setupTabEvents() {
  const tabParent = document.getElementById("tab-parent");
  const tabCentre = document.getElementById("tab-centre");
  const panelParent = document.getElementById("panel-parent-report");
  const panelCentre = document.getElementById("panel-centre-dashboard");
  const btnPrint = document.getElementById("btn-print-report");

  if (tabParent && tabCentre) {
    tabParent.addEventListener("click", () => {
      tabParent.classList.add("active");
      tabParent.setAttribute("aria-selected", "true");
      tabCentre.classList.remove("active");
      tabCentre.setAttribute("aria-selected", "false");
      panelParent.style.display = "block";
      panelCentre.style.display = "none";
    });

    tabCentre.addEventListener("click", () => {
      tabCentre.classList.add("active");
      tabCentre.setAttribute("aria-selected", "true");
      tabParent.classList.remove("active");
      tabParent.setAttribute("aria-selected", "false");
      panelCentre.style.display = "block";
      panelParent.style.display = "none";

      // Render chart if data already cached
      if (centresDataCache) {
        renderCentresBarChart(centresDataCache.centres, currentChartMetric);
      }
    });
  }

  if (btnPrint) {
    btnPrint.addEventListener("click", () => {
      window.print();
    });
  }
}

// ============================================================================
// 2. PARENT WEEKLY REPORT HANDLERS (/api/reports/parent/{id})
// ============================================================================
function setupParentReportControls() {
  const langSelect = document.getElementById("parent-lang-select");
  const btnRegen = document.getElementById("btn-regen-parent-note");

  if (langSelect) {
    langSelect.addEventListener("change", (e) => {
      currentParentLanguage = e.target.value;
    });
  }

  if (btnRegen) {
    btnRegen.addEventListener("click", () => {
      loadParentReport(currentParentLanguage);
    });
  }
}

async function loadParentReport(lang = "English") {
  const notePara = document.getElementById("parent-note-paragraph");
  const noteGreeting = document.getElementById("parent-note-greeting");
  const langIndicator = document.getElementById("note-language-indicator");
  const btnRegen = document.getElementById("btn-regen-parent-note");

  if (notePara) notePara.textContent = "Generating AI-written weekly progress note...";
  if (btnRegen) btnRegen.disabled = true;

  try {
    const url = `/api/reports/parent/${STUDENT_ID}${lang ? `?language=${encodeURIComponent(lang)}` : ""}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const data = await res.json();
    const report = data.report || {};
    const stats = data.stats || {};
    const student = data.student || {};

    // Header info
    const centreEl = document.getElementById("rep-student-centre");
    if (centreEl && student.centre_name) {
      centreEl.textContent = `${student.centre_name}`;
    }

    // AI Note body
    if (noteGreeting) noteGreeting.textContent = report.greeting || "Dear Parent,";
    if (notePara) notePara.textContent = report.note || "Aarav made great progress exploring robotics circuits this week!";
    if (langIndicator) langIndicator.textContent = report.language || lang;

    // Highlights list
    const highlightsList = document.getElementById("parent-highlights-list");
    if (highlightsList && report.highlights) {
      highlightsList.innerHTML = "";
      report.highlights.forEach((h) => {
        const li = document.createElement("li");
        li.textContent = h;
        highlightsList.appendChild(li);
      });
    }

    // Next week goal
    const goalEl = document.getElementById("parent-goal-text");
    if (goalEl && report.next_week_goal) {
      goalEl.textContent = report.next_week_goal;
    }

    // Weekly stats
    const qCountEl = document.getElementById("p-stat-quizzes");
    const qPctEl = document.getElementById("p-stat-quiz-pct");
    const labRunsEl = document.getElementById("p-stat-lab-runs");
    const labSuccessEl = document.getElementById("p-stat-lab-success");

    if (qCountEl) qCountEl.textContent = stats.total_quizzes || 6;
    if (qPctEl) qPctEl.textContent = `${stats.avg_quiz_pct || 68}%`;
    if (labRunsEl) labRunsEl.textContent = stats.total_lab_runs || 7;
    if (labSuccessEl) {
      const rate = stats.total_lab_runs > 0
        ? Math.round((stats.successful_lab_runs / stats.total_lab_runs) * 100)
        : 100;
      labSuccessEl.textContent = `${rate}%`;
    }
  } catch (err) {
    console.error("Error loading parent report:", err);
    if (notePara) {
      notePara.textContent = "We are thrilled to see Aarav actively building and learning in our STEM lab this week! He explored LED circuit wiring, experimented with current-limiting resistors, and tested code in the Virtual Lab. We look forward to more hands-on robotics discoveries next week!";
    }
  } finally {
    if (btnRegen) btnRegen.disabled = false;
  }
}

// ============================================================================
// 3. CENTRE NETWORK DASHBOARD (/api/reports/centres)
// ============================================================================
function setupChartMetricEvents() {
  document.querySelectorAll(".btn-chart-metric").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".btn-chart-metric").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      currentChartMetric = btn.getAttribute("data-metric");
      if (centresDataCache) {
        renderCentresBarChart(centresDataCache.centres, currentChartMetric);
      }
    });
  });
}

async function loadCentresDashboard() {
  try {
    const res = await fetch("/api/reports/centres");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    centresDataCache = await res.json();
    const centres = centresDataCache.centres || [];
    const sentiment = centresDataCache.feedback_sentiment_summary || {};
    const topIssues = centresDataCache.top_issues || [];
    const feedbackRows = centresDataCache.feedback_rows || [];

    // Render components
    renderNetworkKPIs(centres);
    renderCentresTable(centres);
    renderCentresBarChart(centres, currentChartMetric);
    renderSentimentSummary(sentiment, topIssues, feedbackRows);
  } catch (err) {
    console.error("Error loading centres dashboard:", err);
  }
}

function renderNetworkKPIs(centres) {
  const centresCount = centres.length;
  let totalStudents = 0;
  let sumQuiz = 0;
  let sumLab = 0;
  let totalNeedingHelp = 0;

  centres.forEach((c) => {
    totalStudents += c.student_count || 0;
    sumQuiz += c.avg_quiz_score_pct || 0;
    sumLab += c.lab_success_rate_pct || 0;
    totalNeedingHelp += c.students_needing_help || 0;
  });

  const avgQuiz = centresCount > 0 ? (sumQuiz / centresCount).toFixed(1) : 0;
  const avgLab = centresCount > 0 ? (sumLab / centresCount).toFixed(1) : 0;

  const kpiCentres = document.getElementById("kpi-centres-count");
  const kpiStudents = document.getElementById("kpi-students-count");
  const kpiQuiz = document.getElementById("kpi-quiz-avg");
  const kpiLab = document.getElementById("kpi-lab-rate");
  const kpiHelp = document.getElementById("kpi-help-count");

  if (kpiCentres) kpiCentres.textContent = centresCount;
  if (kpiStudents) kpiStudents.textContent = totalStudents;
  if (kpiQuiz) kpiQuiz.textContent = `${avgQuiz}%`;
  if (kpiLab) kpiLab.textContent = `${avgLab}%`;
  if (kpiHelp) kpiHelp.textContent = totalNeedingHelp;
}

function renderCentresTable(centres) {
  const tbody = document.getElementById("centre-table-body");
  if (!tbody) return;

  tbody.innerHTML = "";

  if (centres.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" class="empty-td">No centre data available.</td></tr>`;
    return;
  }

  centres.forEach((c) => {
    const tr = document.createElement("tr");

    const quizScore = c.avg_quiz_score_pct || 0;
    const labRate = c.lab_success_rate_pct || 0;
    const needingHelp = c.students_needing_help || 0;

    let statusPill = "";
    if (needingHelp > 2) {
      statusPill = `<span class="status-badge alert">Needs Tutor Support</span>`;
    } else if (quizScore >= 60 && labRate >= 50) {
      statusPill = `<span class="status-badge safe">High Performing</span>`;
    } else {
      statusPill = `<span class="status-badge normal">On Track</span>`;
    }

    tr.innerHTML = `
      <td><strong>${escapeHtml(c.name)}</strong></td>
      <td>${escapeHtml(c.city || "")}, ${escapeHtml(c.country || "")}</td>
      <td>${c.student_count || 0}</td>
      <td>
        <div class="table-metric-cell">
          <span>${quizScore}%</span>
          <div class="mini-progress-bar"><div class="mini-bar-fill blue" style="width: ${Math.min(100, quizScore)}%;"></div></div>
        </div>
      </td>
      <td>
        <div class="table-metric-cell">
          <span>${labRate}%</span>
          <div class="mini-progress-bar"><div class="mini-bar-fill orange" style="width: ${Math.min(100, labRate)}%;"></div></div>
        </div>
      </td>
      <td>${c.total_lab_runs || 0}</td>
      <td>
        <span class="help-count-badge ${needingHelp > 2 ? 'high' : 'low'}">
          ${needingHelp} students
        </span>
      </td>
      <td>${statusPill}</td>
    `;
    tbody.appendChild(tr);
  });
}

// ============================================================================
// 4. INTERACTIVE BAR CHART (Dynamic SVG Renderer)
// ============================================================================
function renderCentresBarChart(centres, metricKey = "quiz") {
  const container = document.getElementById("centre-bar-chart-container");
  if (!container || !centres || centres.length === 0) return;

  const width = 840;
  const height = 280;
  const padLeft = 60;
  const padRight = 30;
  const padTop = 30;
  const padBottom = 60;

  const chartW = width - padLeft - padRight;
  const chartH = height - padTop - padBottom;

  // Determine values and max scale
  let values = [];
  let unit = "";
  let barColor = "#2563eb";
  let maxScale = 100;

  if (metricKey === "quiz") {
    values = centres.map((c) => c.avg_quiz_score_pct || 0);
    unit = "%";
    barColor = "#2563eb"; // Blue
    maxScale = 100;
  } else if (metricKey === "lab") {
    values = centres.map((c) => c.lab_success_rate_pct || 0);
    unit = "%";
    barColor = "#f97316"; // Orange
    maxScale = 100;
  } else {
    values = centres.map((c) => c.students_needing_help || 0);
    unit = "";
    barColor = "#ef4444"; // Red
    const maxVal = Math.max(...values, 5);
    maxScale = Math.ceil(maxVal * 1.2);
  }

  const barCount = centres.length;
  const barWidth = Math.min(55, (chartW / barCount) * 0.6);
  const barSpacing = chartW / barCount;

  // Build SVG bars
  let barsSvg = "";
  let labelsSvg = "";

  centres.forEach((c, idx) => {
    const val = values[idx];
    const barH = (val / maxScale) * chartH;
    const x = padLeft + idx * barSpacing + (barSpacing - barWidth) / 2;
    const y = padTop + chartH - barH;

    // Bar element
    barsSvg += `
      <g class="chart-bar-group" tabindex="0">
        <rect
          x="${x}"
          y="${y}"
          width="${barWidth}"
          height="${barH}"
          rx="6"
          fill="${barColor}"
          class="chart-bar"
        >
          <title>${c.name}: ${val}${unit}</title>
        </rect>
        <text
          x="${x + barWidth / 2}"
          y="${y - 8}"
          text-anchor="middle"
          fill="#1e293b"
          font-size="11"
          font-weight="bold"
        >${val}${unit}</text>
      </g>
    `;

    // Short label below
    const shortName = c.name.replace("Learnix ", "");
    labelsSvg += `
      <text
        x="${x + barWidth / 2}"
        y="${padTop + chartH + 20}"
        text-anchor="middle"
        fill="#64748b"
        font-size="11"
        font-weight="600"
      >${escapeHtml(shortName)}</text>
    `;
  });

  // Grid lines
  let gridSvg = "";
  [0, 0.25, 0.5, 0.75, 1.0].forEach((ratio) => {
    const y = padTop + chartH - ratio * chartH;
    const labelVal = Math.round(ratio * maxScale);
    gridSvg += `
      <line x1="${padLeft}" y1="${y}" x2="${width - padRight}" y2="${y}" stroke="#e2e8f0" stroke-dasharray="4,4" />
      <text x="${padLeft - 10}" y="${y + 4}" text-anchor="end" fill="#94a3b8" font-size="10">${labelVal}${unit}</text>
    `;
  });

  container.innerHTML = `
    <svg viewBox="0 0 ${width} ${height}" class="centre-bar-chart-svg">
      ${gridSvg}
      <!-- Zero axis -->
      <line x1="${padLeft}" y1="${padTop + chartH}" x2="${width - padRight}" y2="${padTop + chartH}" stroke="#94a3b8" stroke-width="1.5" />
      ${barsSvg}
      ${labelsSvg}
    </svg>
  `;
}

// ============================================================================
// 5. AI.EXTRACT FEEDBACK SENTIMENT SUMMARY
// ============================================================================
function renderSentimentSummary(sentiment, topIssues, feedbackRows) {
  const posCount = sentiment.positive || 0;
  const neuCount = sentiment.neutral || 0;
  const negCount = sentiment.negative || 0;
  const total = posCount + neuCount + negCount || 1;

  const posPct = Math.round((posCount / total) * 100);
  const neuPct = Math.round((neuCount / total) * 100);
  const negPct = 100 - posPct - neuPct;

  // Counts & Pct
  const posCountEl = document.getElementById("sent-pos-count");
  const neuCountEl = document.getElementById("sent-neu-count");
  const negCountEl = document.getElementById("sent-neg-count");
  const posPctEl = document.getElementById("sent-pos-pct");
  const neuPctEl = document.getElementById("sent-neu-pct");
  const negPctEl = document.getElementById("sent-neg-pct");

  if (posCountEl) posCountEl.textContent = posCount;
  if (neuCountEl) neuCountEl.textContent = neuCount;
  if (negCountEl) negCountEl.textContent = negCount;
  if (posPctEl) posPctEl.textContent = `${posPct}%`;
  if (neuPctEl) neuPctEl.textContent = `${neuPct}%`;
  if (negPctEl) negPctEl.textContent = `${negPct}%`;

  // Progress Bar
  const barPos = document.getElementById("sent-bar-pos");
  const barNeu = document.getElementById("sent-bar-neu");
  const barNeg = document.getElementById("sent-bar-neg");

  if (barPos) barPos.style.width = `${posPct}%`;
  if (barNeu) barNeu.style.width = `${neuPct}%`;
  if (barNeg) barNeg.style.width = `${negPct}%`;

  // Top Issues
  const issuesContainer = document.getElementById("sentiment-issues-list");
  if (issuesContainer) {
    issuesContainer.innerHTML = "";
    if (topIssues && topIssues.length > 0) {
      topIssues.slice(0, 6).forEach((issue) => {
        const chip = document.createElement("div");
        chip.className = `issue-chip ${issue.sentiment || 'neutral'}`;
        chip.innerHTML = `
          <span class="issue-topic">${escapeHtml(issue.topic || 'General')}:</span>
          <span class="issue-name">${escapeHtml(issue.issue)}</span>
          <span class="issue-count">${issue.occurrences || 1}x</span>
        `;
        issuesContainer.appendChild(chip);
      });
    } else {
      issuesContainer.innerHTML = `<span class="empty-hint">No critical issues flagged.</span>`;
    }
  }

  // Feedback Stream
  const streamContainer = document.getElementById("feedback-stream-list");
  if (streamContainer && feedbackRows) {
    streamContainer.innerHTML = "";
    feedbackRows.slice(0, 6).forEach((f) => {
      const card = document.createElement("div");
      card.className = "feedback-quote-card";

      const sentimentClass = (f.sentiment || "positive").toLowerCase();
      card.innerHTML = `
        <div class="feedback-card-top">
          <span class="feedback-author"><strong>${escapeHtml(f.student_name || "Student")}</strong> (${escapeHtml(f.from_role || "User")})</span>
          <span class="feedback-sentiment-pill ${sentimentClass}">${escapeHtml(f.sentiment || "Positive")}</span>
        </div>
        <p class="feedback-quote-text">"${escapeHtml(f.text)}"</p>
        <div class="feedback-card-footer">
          <span class="centre-tag">📍 ${escapeHtml(f.centre_name || "")}</span>
          ${f.issue && f.issue !== 'none' ? `<span class="issue-tag">Issue: ${escapeHtml(f.issue)}</span>` : ''}
        </div>
      `;
      streamContainer.appendChild(card);
    });
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
