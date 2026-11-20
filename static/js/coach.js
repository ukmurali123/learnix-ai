/**
 * Learnix AI — AI Coach Page JS
 */

var STUDENT_ID = window.STUDENT_ID || 1;

const ERROR_TIPS = {
  missing_resistor: {
    label: "Missing Resistor (Overcurrent Risk)",
    tip: "Always place a 220Ω resistor in series with the LED to prevent excessive current from damaging the diode junction."
  },
  reversed_polarity: {
    label: "Reversed LED Polarity",
    tip: "The longer leg is the Anode (+) and must connect to power; the shorter leg with the flat rim is Cathode (-) going to Ground."
  },
  missing_ground: {
    label: "Open Circuit (Missing GND)",
    tip: "Electric current must return to Ground (GND) to complete the circuit loop. Without GND, electrons cannot flow."
  },
  wrong_pin: {
    label: "Mismatched Arduino Pin",
    tip: "Ensure the digital pin in your code (e.g. pinMode(13, OUTPUT)) matches the exact pin socket on the board."
  },
  code_logic: {
    label: "Code Timing or Logic Loop",
    tip: "Check delay(ms) values and make sure state changes between HIGH and LOW so actuators switch properly."
  },
  wrong_component: {
    label: "Incorrect Component Placed",
    tip: "Double check the component required for the experiment (e.g. Ultrasonic sensor vs Button)."
  }
};

document.addEventListener("DOMContentLoaded", () => {
  loadCoachData();
  setupSparkIdea();
});

async function loadCoachData() {
  try {
    const res = await fetch(`/api/coach/${STUDENT_ID}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const data = await res.json();

    const msgEl = document.getElementById("coach-full-message");
    if (msgEl) msgEl.textContent = data.coach_message || "Keep building! Focus on foundational circuit safety.";

    renderLabErrors(data.top_lab_errors);
    renderRecommendedSequence(data.next_concepts, data.weak_concepts);
  } catch (err) {
    console.error("Error loading coach data:", err);
  }
}

function renderLabErrors(labErrors) {
  const container = document.getElementById("diag-errors-list");
  if (!container) return;

  container.innerHTML = "";

  if (!labErrors || labErrors.length === 0) {
    container.innerHTML = `
      <div class="empty-diag-box">
        <span class="empty-icon">✅</span>
        <strong>Clean wiring track record!</strong>
        <p>No recurring circuit faults detected in your virtual builds.</p>
      </div>
    `;
    return;
  }

  labErrors.forEach((err) => {
    const key = err.error_type;
    const meta = ERROR_TIPS[key] || {
      label: key.replace(/_/g, " ").toUpperCase(),
      tip: "Double check connections and verify all leads are firmly seated in the breadboard."
    };

    const card = document.createElement("div");
    card.className = "diag-error-card";
    card.innerHTML = `
      <div class="diag-error-top">
        <span class="error-name">⚠️ ${escapeHtml(meta.label)}</span>
        <span class="error-count-pill">${err.error_count}x detected</span>
      </div>
      <p class="error-tip-text"><strong>Coach Advice:</strong> ${escapeHtml(meta.tip)}</p>
    `;
    container.appendChild(card);
  });
}

function renderRecommendedSequence(nextConcepts, weakConcepts) {
  const container = document.getElementById("coach-sequence-list");
  if (!container) return;

  container.innerHTML = "";

  const allItems = [...(nextConcepts || []), ...(weakConcepts || [])].slice(0, 4);

  if (allItems.length === 0) {
    container.innerHTML = `<div class="empty-diag-box"><p>Sequence complete! You're ready for advanced robotics.</p></div>`;
    return;
  }

  allItems.forEach((c, idx) => {
    const card = document.createElement("div");
    card.className = "seq-step-card";
    card.innerHTML = `
      <div class="seq-num-badge">${idx + 1}</div>
      <div class="seq-content">
        <h4>${escapeHtml(c.title)}</h4>
        <p>${escapeHtml(c.why_recommended || c.reason || c.summary || "")}</p>
      </div>
      <a href="/concept_studio.html" class="btn btn-sm btn-outline-coach">Study &rarr;</a>
    `;
    container.appendChild(card);
  });
}

function setupSparkIdea() {
  const input = document.getElementById("spark-input");
  const btn = document.getElementById("btn-spark-idea");
  const resultCard = document.getElementById("spark-result-card");
  const resultTitle = document.getElementById("spark-result-title");
  const resultExplain = document.getElementById("spark-result-explain");
  const resultComponents = document.getElementById("spark-components-list");
  const resultLaunchBtn = document.getElementById("spark-launch-btn");
  const resultMatch = document.getElementById("spark-exp-match");

  if (!btn || !input) return;

  btn.addEventListener("click", generateSparkIdea);
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      generateSparkIdea();
    }
  });

  async function generateSparkIdea() {
    const text = input.value.trim();
    if (!text) return;

    btn.disabled = true;
    const spinner = btn.querySelector(".spark-spinner");
    const btnText = btn.querySelector(".spark-btn-text");
    if (spinner) spinner.style.display = "inline-block";
    if (btnText) btnText.textContent = "Synthesizing...";

    try {
      const res = await fetch("/api/coach/spark-idea", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          student_id: STUDENT_ID,
          idea: text,
        }),
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      if (resultTitle) resultTitle.textContent = data.title || "Custom Project";
      if (resultExplain) resultExplain.textContent = data.explanation || "Here is your custom invention plan!";
      if (resultComponents) {
        resultComponents.textContent = Array.isArray(data.components)
          ? data.components.join(", ")
          : (data.components || "Arduino, Sensors, Wires");
      }

      const expId = data.experiment_id || 1;
      if (resultMatch) resultMatch.textContent = `Closest Kit Project: Exp #${expId}`;
      if (resultLaunchBtn) resultLaunchBtn.href = `/virtual_lab.html?exp=${expId}`;

      if (resultCard) {
        resultCard.style.display = "block";
        resultCard.scrollIntoView({ behavior: "smooth", block: "nearest" });
      }
    } catch (err) {
      console.error("Spark idea error:", err);
      if (resultTitle) resultTitle.textContent = "Smart Distance Buzzer Alarm";
      if (resultExplain) resultExplain.textContent = "Use an HC-SR04 ultrasonic distance sensor to measure distance and sound a buzzer when an object is closer than 20cm!";
      if (resultComponents) resultComponents.textContent = "Arduino UNO, HC-SR04, Piezo Buzzer, Breadboard, Jumper Wires";
      if (resultLaunchBtn) resultLaunchBtn.href = "/virtual_lab.html?exp=3";
      if (resultCard) resultCard.style.display = "block";
    } finally {
      btn.disabled = false;
      if (spinner) spinner.style.display = "none";
      if (btnText) btnText.textContent = "Generate Circuit & Code";
    }
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
