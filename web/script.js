/* ═══════════════════════════════════════════════════════════════
   AI Plant Disease Detection — Dashboard Script
   Project: Graduation Project 2026, MUST University
═══════════════════════════════════════════════════════════════ */

const API_BASE    = 'http://localhost:8000';
const REFRESH_MS  = 5000;   // 5 seconds
const MAX_POINTS  = 25;     // history length for mini-charts

/* ── State ─────────────────────────────────────────────── */
let diseaseDb = [];
let selectedFile = null;
let chartTemp, chartHum, chartLight;
let refreshTimer = null;

/* ══════════════════════════════════════════════════════════
   INIT
══════════════════════════════════════════════════════════ */
document.addEventListener('DOMContentLoaded', () => {
    initCharts();
    loadDiseaseDb();
    setupUpload();
    fetchSensor();          // immediate first fetch
    startAutoRefresh();
});

/* ══════════════════════════════════════════════════════════
   AUTO REFRESH
══════════════════════════════════════════════════════════ */
function startAutoRefresh() {
    clearInterval(refreshTimer);
    refreshTimer = setInterval(fetchSensor, REFRESH_MS);
}

/* ══════════════════════════════════════════════════════════
   SENSOR FETCH
══════════════════════════════════════════════════════════ */
async function fetchSensor() {
    try {
        const res  = await fetch(API_BASE + '/sensor-data', { signal: AbortSignal.timeout(4000) });
        const json = await res.json();

        setApiStatus(true);

        if (json.status === 'ok' && json.data) {
            renderSensors(json.data);
            setEspStatus(true, json.data.timestamp);
            updateTimestamp();
        } else {
            setEspStatus(false, null);
            showNoData();
        }
    } catch (_) {
        setApiStatus(false);
        setEspStatus(false, null);
    }
}

/* ── Render sensor values + badges + charts ── */
function renderSensors(data) {
    const { temperature: t, humidity: h, light: lRaw } = data;
    const lPct = toPercent(lRaw);

    // Values
    setText('val-temp',  t.toFixed(1));
    setText('val-hum',   h.toFixed(1));
    setText('val-light', lPct.toString());

    // Badges
    applyBadge('badge-temp',  tempBadge(t));
    applyBadge('badge-hum',   humBadge(h));
    applyBadge('badge-light', lightBadge(lPct));

    // Range hints
    setText('hint-temp',  tempHint(t));
    setText('hint-hum',   humHint(h));
    setText('hint-light', lightHint(lPct));

    // Push to charts
    const time = new Date().toLocaleTimeString('en-US', { hour12: false, hour:'2-digit', minute:'2-digit', second:'2-digit' });
    pushPoint(chartTemp,  time, t);
    pushPoint(chartHum,   time, h);
    pushPoint(chartLight, time, lPct);
}

function showNoData() {
    ['val-temp','val-hum','val-light'].forEach(id => setText(id, '--'));
    ['badge-temp','badge-hum','badge-light'].forEach(id => applyBadge(id, { label:'N/A', cls:'badge-na' }));
    ['hint-temp','hint-hum','hint-light'].forEach(id => setText(id, 'No data'));
}

/* ══════════════════════════════════════════════════════════
   STATUS INDICATORS
══════════════════════════════════════════════════════════ */
function setApiStatus(ok) {
    const el = document.getElementById('api-conn');
    el.className = 'conn-badge ' + (ok ? 'connected' : 'disconnected');
    el.querySelector('span').textContent = ok ? 'API Connected' : 'API Offline';
}

function setEspStatus(ok, timestamp) {
    const el = document.getElementById('esp-conn');
    el.className = 'conn-badge ' + (ok ? 'connected' : 'waiting');
    el.querySelector('span').textContent = ok ? 'ESP32 Online' : 'Waiting for ESP32…';
}

function updateTimestamp() {
    const el = document.getElementById('last-ts');
    if (el) el.textContent = 'Last update: ' + new Date().toLocaleTimeString();
}

/* ══════════════════════════════════════════════════════════
   BADGE HELPERS
══════════════════════════════════════════════════════════ */
function tempBadge(t) {
    if (t < 10)  return { label: 'Very Cold', cls: 'badge-low' };
    if (t < 18)  return { label: 'Cold',      cls: 'badge-low' };
    if (t <= 28) return { label: 'Normal',    cls: 'badge-normal' };
    if (t <= 35) return { label: 'High',      cls: 'badge-high' };
    return               { label: 'Critical', cls: 'badge-critical' };
}
function humBadge(h) {
    if (h < 30)  return { label: 'Dry',       cls: 'badge-low' };
    if (h <= 60) return { label: 'Normal',    cls: 'badge-normal' };
    if (h <= 80) return { label: 'Humid',     cls: 'badge-high' };
    return               { label: 'Very Humid',cls:'badge-critical' };
}
function lightBadge(p) {
    if (p < 20)  return { label: 'Dim',    cls: 'badge-low' };
    if (p <= 68) return { label: 'Normal', cls: 'badge-normal' };
    return               { label: 'Bright', cls: 'badge-high' };
}

function tempHint(t)  { return `Ideal range for most crops: 18–28 °C`; }
function humHint(h)   { return `Optimal: 40–70 % — Above 80% increases disease risk`; }
function lightHint(p) { return p < 20 ? 'Low light may reduce plant immunity' : p > 68 ? 'Good sunlight — favours healthy growth' : 'Moderate light level'; }

function toPercent(raw) {
    return raw <= 100 ? raw : Math.round(raw / 4095 * 100);
}

function applyBadge(id, { label, cls }) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent  = label;
    el.className    = 'card-status-badge ' + cls;
}

function setText(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
}

/* ══════════════════════════════════════════════════════════
   MINI CHARTS (Chart.js sparklines)
══════════════════════════════════════════════════════════ */
function initCharts() {
    chartTemp  = mkChart('mini-temp',  '#f59e0b', '°C');
    chartHum   = mkChart('mini-hum',   '#3b82f6', '%');
    chartLight = mkChart('mini-light', '#eab308', '%');
}

function mkChart(id, color, unit) {
    const ctx = document.getElementById(id);
    if (!ctx) return null;
    return new Chart(ctx.getContext('2d'), {
        type: 'line',
        data: { labels: [], datasets: [{ data: [], borderColor: color,
            backgroundColor: color + '18', borderWidth: 1.8,
            pointRadius: 0, fill: true, tension: 0.4 }] },
        options: {
            responsive: true, maintainAspectRatio: false,
            plugins: { legend:{display:false}, tooltip:{
                callbacks: { label: c => c.parsed.y.toFixed(1) + unit }
            }},
            scales: {
                x: { display: false },
                y: { display: false }
            },
            animation: { duration: 300 }
        }
    });
}

function pushPoint(chart, label, value) {
    if (!chart) return;
    const ds = chart.data.datasets[0];
    if (ds.data.length >= MAX_POINTS) {
        chart.data.labels.shift();
        ds.data.shift();
    }
    chart.data.labels.push(label);
    ds.data.push(value);
    chart.update('none');
}

/* ══════════════════════════════════════════════════════════
   DISEASE DATABASE
══════════════════════════════════════════════════════════ */
function loadDiseaseDb() {
    const paths = ['../data/diseases_database.json', 'diseases_database.json'];
    const tryFetch = (i) => {
        if (i >= paths.length) return;
        fetch(paths[i])
            .then(r => r.ok ? r.json() : Promise.reject())
            .then(d => { diseaseDb = d.records || d; })
            .catch(() => tryFetch(i + 1));
    };
    tryFetch(0);
}

function findDisease(classId) {
    return diseaseDb.find(d => d.class_id == classId) || null;
}

/* ══════════════════════════════════════════════════════════
   UPLOAD & PREDICT
══════════════════════════════════════════════════════════ */
function setupUpload() {
    const dz    = document.getElementById('drop-zone');
    const fi    = document.getElementById('file-input');
    const btn   = document.getElementById('btn-predict');

    dz.addEventListener('click', () => fi.click());
    fi.addEventListener('change', e => { if (e.target.files[0]) handleFile(e.target.files[0]); });

    dz.addEventListener('dragover',  e => { e.preventDefault(); dz.classList.add('over'); });
    dz.addEventListener('dragleave', () => dz.classList.remove('over'));
    dz.addEventListener('dragend',   () => dz.classList.remove('over'));
    dz.addEventListener('drop', e => {
        e.preventDefault(); dz.classList.remove('over');
        if (e.dataTransfer.files[0]) handleFile(e.dataTransfer.files[0]);
    });

    btn.addEventListener('click', runPredict);
}

function handleFile(file) {
    if (!file.type.startsWith('image/')) return;
    selectedFile = file;
    const reader = new FileReader();
    reader.onload = e => {
        const img = document.getElementById('preview-img');
        img.src = e.target.result;
        img.style.display = 'block';
        // hide the placeholder text
        document.querySelectorAll('#drop-zone .dz-icon, #drop-zone .dz-text, #drop-zone .dz-sub')
            .forEach(el => el.style.display = 'none');
        document.getElementById('btn-predict').disabled = false;
    };
    reader.readAsDataURL(file);
}

async function runPredict() {
    if (!selectedFile) return;

    const btn     = document.getElementById('btn-predict');
    const btnTxt  = document.getElementById('btn-text');
    const spinner = document.getElementById('spinner');

    btn.disabled = true;
    btnTxt.style.display = 'none';
    spinner.style.display = 'block';

    const fd = new FormData();
    fd.append('file', selectedFile);

    try {
        const res  = await fetch(API_BASE + '/predict', { method: 'POST', body: fd });
        if (!res.ok) throw new Error('API error ' + res.status);
        const data = await res.json();
        renderPrediction(data);
        renderEnvRisk(data.env_analysis);
    } catch (e) {
        alert('Error: Make sure the API is running at ' + API_BASE);
        console.error(e);
    } finally {
        btn.disabled = false;
        btnTxt.style.display = 'inline';
        spinner.style.display = 'none';
    }
}

/* ── Render prediction results ── */
function renderPrediction(result) {
    const details   = findDisease(result.class_id);
    const isHealthy = result.disease?.toLowerCase().includes('healthy');

    // Show result box
    document.getElementById('result-empty').classList.add('hidden');
    const rb = document.getElementById('result-box');
    rb.style.display = 'flex';

    // Status badge
    const sb = document.getElementById('plant-status-badge');
    sb.textContent = isHealthy ? '✓  Healthy' : '⚠  Diseased';
    sb.className   = 'plant-status-badge ' + (isHealthy ? 'ps-healthy' : 'ps-diseased');

    // Disease / crop name
    const diseaseName = result.disease
        ? result.disease.replace(/___/g, ' — ').replace(/_/g, ' ')
        : '—';
    setText('disease-name', details?.disease_en || diseaseName);
    setText('crop-label',   'Crop: ' + (details?.crop_en || result.disease?.split('___')[0] || '—'));

    // Confidence bar
    const pct = Math.round((result.confidence || 0) * 100);
    setText('conf-pct', pct + '%');
    document.getElementById('prog-fill').style.width = pct + '%';

    // Top-3
    const top3El = document.getElementById('top3-list');
    top3El.innerHTML = '';
    (result.top3 || []).slice(0, 3).forEach((item, idx) => {
        const name = item.disease.replace(/___/g,' — ').replace(/_/g,' ');
        const p    = Math.round(item.confidence * 100);
        const li   = document.createElement('div');
        li.className = 'top3-item';
        li.innerHTML = `
            <span class="t3-name">${idx + 1}. ${name}</span>
            <span class="t3-pct">${p}%</span>`;
        top3El.appendChild(li);
    });
}

/* ── Render environmental risk section ── */
function renderEnvRisk(env) {
    if (!env) return;

    document.getElementById('env-waiting').classList.add('hidden');
    document.getElementById('env-content').classList.remove('hidden');

    // Big risk label + pill
    const riskMap = {
        none:   { label: 'None',   cls: 'risk-none',   pill: 'rp-none' },
        low:    { label: 'Low',    cls: 'risk-low',    pill: 'rp-low' },
        medium: { label: 'Medium', cls: 'risk-medium', pill: 'rp-medium' },
        high:   { label: 'High',   cls: 'risk-high',   pill: 'rp-high' },
    };
    const rm = riskMap[env.environmental_risk] || riskMap.none;

    const bigEl = document.getElementById('risk-level-big');
    bigEl.textContent = rm.label;
    bigEl.className   = 'env-risk-big ' + rm.cls;

    const pillEl = document.getElementById('risk-pill');
    pillEl.textContent = 'Env Risk: ' + rm.label;
    pillEl.className   = 'risk-pill ' + rm.pill;

    // Factor chips
    renderFactor('factor-temp',  'Temperature',  env.temperature_status);
    renderFactor('factor-hum',   'Humidity',     env.humidity_status);
    renderFactor('factor-light', 'Light',        env.light_status);
    renderFactor('factor-driven','Env Driven',   env.env_driven ? 'Yes' : 'No');

    // Summary
    const sumEl = document.getElementById('env-summary');
    sumEl.innerHTML = '<strong>Analysis:</strong> ' + (env.summary_en || '—');

    // Improvement tips
    const tipsEl = document.getElementById('tips-list');
    const tips   = env.improvement_tips_en || [];
    if (tips.length) {
        tipsEl.innerHTML = '';
        tips.forEach(tip => {
            const li = document.createElement('li');
            li.textContent = tip;
            tipsEl.appendChild(li);
        });
        document.getElementById('tips-section').classList.remove('hidden');
    } else {
        document.getElementById('tips-section').classList.add('hidden');
    }
}

function renderFactor(id, label, status) {
    const el = document.getElementById(id);
    if (!el) return;
    const statusMap = {
        favorable:   'Favorable ⚠',
        unfavorable: 'Unfavorable',
        low:         'Low',
        high:        'High',
        normal:      'Normal',
        unknown:     'Unknown',
        Yes:         'Yes',
        No:          'No',
    };
    const clsMap = {
        favorable: 'status-favorable', unfavorable: 'status-unfavorable',
        low: 'status-low', high: 'status-high', normal: 'status-normal',
        unknown: 'status-unknown', Yes: 'status-normal', No: 'status-unknown',
    };
    el.innerHTML = `
        <div class="ef-label">${label}</div>
        <div class="ef-value ${clsMap[status] || 'status-unknown'}">${statusMap[status] || status || '—'}</div>`;
}
