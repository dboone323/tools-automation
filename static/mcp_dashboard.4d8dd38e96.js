// backoff-aware loader for /api/status
let backoff = 0.5; // seconds
let polling = true;
let intervalHandle = null;
async function load() {
  try {
    let r = await fetch("/api/status");
    if (r.status === 429) {
      backoff = Math.min(backoff * 2, 10);
      scheduleNext();
      return;
    }
    backoff = 0.5;
    let j = await r.json();
    let tbody = document.getElementById("tasks");
    tbody.innerHTML = "";
    for (let t of j.tasks || []) {
      let tr = document.createElement("tr");
      tr.innerHTML = `<td><a href="/task/${t.id}">${t.id || ""}</a></td><td>${t.project || ""}</td><td>${t.status || ""}</td><td>${t.returncode || ""}</td><td>${(t.stdout || "").slice(0, 200)}</td>`;
      tbody.appendChild(tr);
    }
  } catch (e) {
    console.error(e);
    backoff = Math.min(backoff * 2, 10);
  }
  scheduleNext();
}
function scheduleNext() {
  if (intervalHandle) clearTimeout(intervalHandle);
  intervalHandle = setTimeout(() => {
    if (document.getElementById("autorefresh").checked) load();
  }, backoff * 1000);
}
window.addEventListener("load", () => {
  load();
  scheduleNext();
});

// artifacts + health poller
async function loadArtifacts() {
  try {
    let r = await fetch("/artifacts");
    let arr = await r.json();
    let ul = document.getElementById("artlist");
    ul.innerHTML = "";
    for (let a of arr) {
      let li = document.createElement("li");
      li.innerHTML = `<a href="/artifacts/download/${encodeURIComponent(a)}">${a}</a>`;
      ul.appendChild(li);
    }
  } catch (e) {
    console.error(e);
  }
}
// health poller with shared backoff strategy
let healthBackoff = 0.5;
async function pollHealth() {
  try {
    let r = await fetch("/health");
    if (r.status === 200) {
      document.getElementById("health-indicator").style.background = "green";
      document.getElementById("health-text").textContent = "ok";
      healthBackoff = 0.5;
    } else if (r.status === 429) {
      document.getElementById("health-indicator").style.background = "orange";
      document.getElementById("health-text").textContent = "rate_limited";
      healthBackoff = Math.min(healthBackoff * 2, 10);
    } else {
      document.getElementById("health-indicator").style.background = "red";
      document.getElementById("health-text").textContent = "error";
      healthBackoff = Math.min(healthBackoff * 2, 10);
    }
  } catch (e) {
    document.getElementById("health-indicator").style.background = "red";
    document.getElementById("health-text").textContent = "offline";
    healthBackoff = Math.min(healthBackoff * 2, 10);
  }
  setTimeout(pollHealth, healthBackoff * 1000);
}
// start health polling and load artifacts on script load
pollHealth();
loadArtifacts();
