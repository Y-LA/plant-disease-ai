/* ═══════════════════════════════════════════════════════
   CONFIG
═══════════════════════════════════════════════════════ */
const API_BASE       = 'http://localhost:8000';
const POLL_MS        = 5_000;    // poll sensor every 5s (for live cards)
const CHART_MIN_MS   = 5 * 60_000;  // log chart point every 5 min
const MAX_POINTS     = 30;
const ESP_TIMEOUT_MS = 45_000;   // no fresh reading within 45s → ESP offline

// Parse a backend timestamp. If it has no timezone marker, treat it as UTC
// (the backend sends UTC), so we don't get shifted by the local offset.
function parseServerTs(s) {
  if (!s) return NaN;
  const hasTz = /[zZ]$|[+-]\d{2}:?\d{2}$/.test(s);
  return Date.parse(hasTz ? s : s + 'Z');
}

/* ═══════════════════════════════════════════════════════
   STATE
═══════════════════════════════════════════════════════ */
let db = [];                      // disease database (classes array)
let selectedFile = null;
let sparkTemp, sparkHum, sparkLight;
let chartTemp, chartHum, chartLight;
let lastChartTs = 0;
let lastEspTs   = null;

/* ═══════════════════════════════════════════════════════
   INIT
═══════════════════════════════════════════════════════ */
document.addEventListener('DOMContentLoaded', () => {
    initSparks();
    initCharts();
    loadDb();
    setupUpload();
    setupTabs();
    fetchSensor();
    setInterval(fetchSensor, POLL_MS);
});

/* ═══════════════════════════════════════════════════════
   SENSOR FETCH
═══════════════════════════════════════════════════════ */
async function fetchSensor() {
    try {
        const res  = await fetch(`${API_BASE}/sensor-data`, { signal: AbortSignal.timeout(4000) });
        const json = await res.json();

        setApiStatus(true);

        // The backend keeps returning the LAST reading even after the ESP32
        // stops sending, so "status: ok" alone isn't enough — check freshness.
        const tsMs  = json.data ? parseServerTs(json.data.timestamp) : NaN;
        const fresh = !isNaN(tsMs) && (Date.now() - tsMs) < ESP_TIMEOUT_MS;

        if (json.status === 'ok' && json.data && fresh) {
            setEspStatus(true);
            renderCards(json.data);

            // Log chart point only if timestamp changed (new ESP32 reading)
            if (json.data.timestamp !== lastEspTs) {
                lastEspTs = json.data.timestamp;
                const now = Date.now();
                if (now - lastChartTs >= CHART_MIN_MS) {
                    lastChartTs = now;
                    const label = new Date().toLocaleTimeString('en-US', {hour:'2-digit',minute:'2-digit',hour12:false});
                    const lPct  = toPct(json.data.light);
                    logChart(chartTemp,  label, json.data.temperature);
                    logChart(chartHum,   label, json.data.humidity);
                    logChart(chartLight, label, lPct);
                    updateChartNextLabel();
                }
            }
        } else {
            setEspStatus(false);
        }
    } catch (_) {
        setApiStatus(false);
        setEspStatus(false);
    }
}

/* ═══════════════════════════════════════════════════════
   CARD RENDER
═══════════════════════════════════════════════════════ */
function renderCards(d) {
    const t = d.temperature, h = d.humidity, lPct = toPct(d.light);

    // Values
    if (window.animateCount) {
        animateCount('temp-val',  t,    1);
        animateCount('hum-val',   h,    1);
        animateCount('light-val', lPct, 0);
    } else {
        set('temp-val',  t.toFixed(1));
        set('hum-val',   h.toFixed(1));
        set('light-val', lPct.toString());
    }

    // Badges & hints
    const tb = tempBadge(t);
    const hb = humBadge(h);
    const lb = lightBadge(lPct);

    setBadge('temp-badge',  tb);
    setBadge('hum-badge',   hb);
    setBadge('light-badge', lb);

    set('temp-hint',  `DHT22 · ${t < 18 ? 'Below' : t > 30 ? 'Above' : 'Within'} optimal range (18–30 °C)`);
    set('hum-hint',   `DHT22 · ${h < 40 ? 'Below' : h > 80 ? 'Above' : 'Within'} optimal range (40–80 %)`);
    set('light-hint', lPct < 20 ? 'LDR · Low light — may reduce immunity' : lPct > 68 ? 'LDR · Good sunlight level' : 'LDR · Moderate light level');

    // Mark cards as having data (shows accent line)
    ['card-temp','card-hum','card-light'].forEach(id => document.getElementById(id).classList.add('has-data'));

    // Sparks (update on every poll)
    const sparkLabel = new Date().toLocaleTimeString('en-US',{hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false});
    logSpark(sparkTemp,  sparkLabel, t);
    logSpark(sparkHum,   sparkLabel, h);
    logSpark(sparkLight, sparkLabel, lPct);

    // Topbar timestamp
    const tsEl = document.getElementById('ts-pill');
    tsEl.style.display = 'inline-flex';
    set('ts-text', 'Updated ' + new Date().toLocaleTimeString());
}

/* ═══════════════════════════════════════════════════════
   STATUS
═══════════════════════════════════════════════════════ */
function setApiStatus(ok) {
    const el = document.getElementById('api-pill');
    el.className = 'pill ' + (ok ? 'ok' : 'err');
    el.querySelector('span').textContent = ok ? 'API Online' : 'API Offline';
}
function setEspStatus(ok) {
    const el = document.getElementById('esp-pill');
    el.className = 'pill ' + (ok ? 'ok' : 'warn');
    el.querySelector('span').textContent = ok ? 'ESP32 Connected' : 'Waiting for ESP32…';
}

/* ═══════════════════════════════════════════════════════
   BADGE HELPERS
═══════════════════════════════════════════════════════ */
function tempBadge(t) {
    if (t < 10)  return { label:'Very Cold', cls:'b-low' };
    if (t < 18)  return { label:'Cold',      cls:'b-low' };
    if (t <= 28) return { label:'Normal',    cls:'b-normal' };
    if (t <= 35) return { label:'High',      cls:'b-high' };
    return               { label:'Critical', cls:'b-crit' };
}
function humBadge(h) {
    if (h < 30)  return { label:'Dry',        cls:'b-low' };
    if (h <= 60) return { label:'Normal',     cls:'b-normal' };
    if (h <= 80) return { label:'Humid',      cls:'b-high' };
    return               { label:'Very Humid',cls:'b-crit' };
}
function lightBadge(p) {
    if (p < 20)  return { label:'Dim',    cls:'b-low' };
    if (p <= 68) return { label:'Normal', cls:'b-normal' };
    return               { label:'Bright', cls:'b-high' };
}
function setBadge(id, { label, cls }) {
    const el = document.getElementById(id);
    el.textContent = label;
    el.className = 's-badge ' + cls;
}
function toPct(raw) { return raw <= 100 ? Math.round(raw) : Math.round(raw / 4095 * 100); }

/* ═══════════════════════════════════════════════════════
   CHARTS
═══════════════════════════════════════════════════════ */
function makeChart(id, color, unit, minY, maxY) {
    const ctx = document.getElementById(id).getContext('2d');
    return new Chart(ctx, {
        type: 'line',
        data: { labels:[], datasets:[{ data:[], borderColor:color,
            backgroundColor: color+'18', borderWidth:1.5,
            pointRadius:3, pointHoverRadius:5, fill:true, tension:0.4 }] },
        options: {
            responsive:true, maintainAspectRatio:false,
            plugins: { legend:{display:false}, tooltip:{
                callbacks:{ label: c => c.parsed.y.toFixed(1)+unit }
            }},
            scales: {
                x: { display:true, grid:{color:'rgba(255,255,255,0.04)'},
                     ticks:{color:'#475569',font:{size:10},maxTicksLimit:6} },
                y: { display:true, min:minY, max:maxY,
                     grid:{color:'rgba(255,255,255,0.04)'},
                     ticks:{color:'#475569',font:{size:10},maxTicksLimit:4} }
            },
            animation:{duration:400}
        }
    });
}

function initCharts() {
    chartTemp  = makeChart('ch-temp',  '#f59e0b', '°C', 0,  50);
    chartHum   = makeChart('ch-hum',   '#38bdf8', '%',  0, 100);
    chartLight = makeChart('ch-light', '#facc15', '%',  0, 100);
}

function logChart(ch, label, val) {
    if (!ch) return;
    const ds = ch.data.datasets[0];
    if (ds.data.length >= MAX_POINTS) { ch.data.labels.shift(); ds.data.shift(); }
    ch.data.labels.push(label);
    ds.data.push(val);
    ch.update('none');
    // update latest pill
    const id = ch.canvas.id;
    if      (id==='ch-temp')  set('ch-temp-latest',  val.toFixed(1)+'°C');
    else if (id==='ch-hum')   set('ch-hum-latest',   val.toFixed(1)+'%');
    else if (id==='ch-light') set('ch-light-latest', val+'%');
}

function updateChartNextLabel() {
    const nextMs = CHART_MIN_MS - (Date.now() - lastChartTs);
    const nextMin = Math.ceil(nextMs / 60000);
    ['ch-temp-next','ch-hum-next','ch-light-next'].forEach(id =>
        set(id, `Next log in ~${nextMin} min`)
    );
}

/* ─── Sparklines (mini inside cards, update on every poll) ─── */
function makeSpark(id, color) {
    const ctx = document.getElementById(id).getContext('2d');
    return new Chart(ctx, {
        type: 'line',
        data: { labels:[], datasets:[{ data:[], borderColor:color,
            backgroundColor:color+'14', borderWidth:1.5,
            pointRadius:0, fill:true, tension:0.4 }] },
        options: {
            responsive:true, maintainAspectRatio:false,
            plugins:{ legend:{display:false}, tooltip:{enabled:false} },
            scales:{ x:{display:false}, y:{display:false} },
            animation:{duration:200}
        }
    });
}
function initSparks() {
    sparkTemp  = makeSpark('spark-temp',  '#f59e0b');
    sparkHum   = makeSpark('spark-hum',   '#38bdf8');
    sparkLight = makeSpark('spark-light', '#facc15');
}
function logSpark(ch, label, val) {
    if (!ch) return;
    const ds = ch.data.datasets[0];
    if (ds.data.length >= 20) { ch.data.labels.shift(); ds.data.shift(); }
    ch.data.labels.push(label);
    ds.data.push(val);
    ch.update('none');
}

/* ═══════════════════════════════════════════════════════
   DATABASE
═══════════════════════════════════════════════════════ */
function loadDb() {
    // Data is embedded inline — no fetch needed (works from file:// too)
    db = typeof DISEASE_DB !== 'undefined' ? DISEASE_DB : [];
    console.log('[db] Loaded', db.length, 'disease records inline');
}
// Look up a disease entry by NAME first (order-independent), falling back to
// class_id. This matters because the model's class indices shifted by +1 after
// the "Not_plant" class was inserted at index 15, so the old class_id numbering
// in the disease DB no longer lines up — but the class_name still does.
console.log('%c[plant-app] build 2026-06-18 · not-plant aware','color:#10b981;font-weight:bold');
function findEntry(ref) {
    if (ref == null) return null;
    const name = (typeof ref === 'object') ? (ref.class_name || ref.disease) : ref;
    const id   = (typeof ref === 'object') ? ref.class_id : ref;
    return db.find(r => r.class_name === name)
        || (id != null ? db.find(r => String(r.class_id) === String(id)) : null)
        || null;
}

/* ═══════════════════════════════════════════════════════
   UPLOAD
═══════════════════════════════════════════════════════ */
function setupUpload() {
    const dz  = document.getElementById('drop-zone');
    const fi  = document.getElementById('file-input');
    const btn = document.getElementById('btn-analyze');

    dz.addEventListener('click', () => fi.click());
    fi.addEventListener('change', e => { if (e.target.files[0]) handleFile(e.target.files[0]); });
    dz.addEventListener('dragover',  e => { e.preventDefault(); dz.classList.add('over'); });
    dz.addEventListener('dragleave', ()=> dz.classList.remove('over'));
    dz.addEventListener('dragend',   ()=> dz.classList.remove('over'));
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
        const img = document.getElementById('dz-preview');
        img.src = e.target.result;
        img.style.display = 'block';
        // hide drop-zone text
        document.querySelectorAll('#drop-zone .dz-icon, #drop-zone .dz-text, #drop-zone .dz-sub')
            .forEach(el => el.style.opacity = '0');
        document.getElementById('btn-analyze').disabled = false;
    };
    reader.readAsDataURL(file);
}

async function runPredict() {
    if (!selectedFile) return;
    const btn = document.getElementById('btn-analyze');
    const txt = document.getElementById('btn-txt');
    const sp  = document.getElementById('spin');

    btn.disabled = true;
    txt.style.display = 'none';
    sp.style.display = 'block';

    const fd = new FormData();
    fd.append('file', selectedFile);
    try {
        const res = await fetch(`${API_BASE}/predict`, { method: 'POST', body: fd });

        if (!res.ok) {
            // Try to read the actual error detail from FastAPI's response
            let detail = `HTTP ${res.status}`;
            try {
                const errJson = await res.json();
                detail = errJson.detail || JSON.stringify(errJson);
            } catch (_) {
                try { detail = await res.text(); } catch (_) {}
            }
            showPredictError(`API error ${res.status}`, detail);
            return;
        }

        const data = await res.json();
        hidePredictError();
        renderPrediction(data);
        if (window.addToArchive) {
            try { addToArchive(data, findEntry(data), document.getElementById('dz-preview')?.src); } catch (_) {}
        }
        const notPlant = (data.is_plant === false) || (data.disease === 'Not_plant');
        if (window.toast && !notPlant) {
            const ok = !(data.disease||'').toLowerCase().includes('healthy');
            toast(t2(ok ? 'diseasedTag' : 'healthyTag') + ' · ' + Math.round((data.confidence||0)*100) + '%', ok ? 'info' : 'ok');
        }

    } catch (e) {
        const isNetworkErr = e instanceof TypeError && e.message.includes('fetch');
        const title  = isNetworkErr ? 'Could not reach the API' : 'Unexpected error';
        const detail = isNetworkErr
            ? `Make sure the server is running at ${API_BASE}.\n\nDetails: ${e.message}`
            : e.message;
        showPredictError(title, detail);
        console.error('[predict]', e);
    } finally {
        btn.disabled = false;
        txt.style.display = 'inline-flex';
        sp.style.display = 'none';
    }
}

function showPredictError(title, detail) {
    let box = document.getElementById('predict-error');
    if (!box) {
        box = document.createElement('div');
        box.id = 'predict-error';
        box.style.cssText = `
            margin-top: 10px;
            background: var(--rose-bg);
            border: 1px solid rgba(244,63,94,.25);
            border-radius: var(--r-inner);
            padding: 10px 12px;
            font-size: 12px;
            color: var(--rose);
            line-height: 1.6;
            white-space: pre-wrap;
        `;
        document.getElementById('btn-analyze').insertAdjacentElement('afterend', box);
    }
    box.innerHTML = `<strong>⚠ ${title}</strong><br><span style="color:var(--text-2)">${detail}</span>`;
    box.style.display = 'block';
    console.error('[predict]', title, detail);
}

function hidePredictError() {
    const box = document.getElementById('predict-error');
    if (box) box.style.display = 'none';
}

/* ═══════════════════════════════════════════════════════
   PREDICTION RENDER
═══════════════════════════════════════════════════════ */
function renderPrediction(result) {
    window._lastResult = result;   // saved for language-switch re-render

    // ── Non-plant image ──────────────────────────────────────────────────
    // If the model says the image is not a plant, show a clear message and
    // skip all disease info, treatment and environmental recommendations.
    const notPlant = (result.is_plant === false) || (result.disease === 'Not_plant');
    if (notPlant) { renderNotPlant(result); return; }

    const entry     = findEntry(result);
    const isHealthy = result.disease?.toLowerCase().includes('healthy');

    // Show tabs + hide empty state
    document.getElementById('r-empty').style.display = 'none';
    document.getElementById('res-tabs').style.display = 'flex';
    // Restore the info/env tabs (they may have been hidden by a non-plant scan)
    document.getElementById('tab-btn-info').style.display = '';
    document.getElementById('tab-btn-env').style.display  = '';
    activateTab('diagnosis');

    /* ── TAB 1: Diagnosis ── */
    const sb = document.getElementById('r-status');
    sb.textContent = isHealthy ? '✓ Healthy' : '⚠ Diseased';
    sb.className   = 'r-status ' + (isHealthy ? 'rs-healthy' : 'rs-diseased');

    const sev = entry?.severity || '';
    const sevEl = document.getElementById('r-severity');
    if (sev) {
        sevEl.textContent = 'Severity: ' + sev;
        sevEl.className   = 'r-severity sev-' + sev.toLowerCase();
    } else {
        sevEl.textContent = '';
    }

    set('r-disease', entry?.disease_en  || fmt(result.disease));
    set('r-crop',    (entry?.crop_en    || result.disease?.split('___')[0] || '—'));
    document.getElementById('r-crop').innerHTML =
        `<i class="fas fa-seedling"></i> ${entry?.crop_en || result.disease?.split('___')[0] || '—'}`;

    const pathEl = document.getElementById('r-pathogen');
    if (entry?.pathogen_en) {
        pathEl.style.display = 'inline-flex';
        pathEl.innerHTML = `<i class="fas fa-virus"></i> ${entry.pathogen_en}`;
    } else {
        pathEl.style.display = 'none';
    }

    const pct = Math.round((result.confidence || 0) * 100);
    if (window.animateCount) animateCount('r-conf', pct, 0, '%'); else set('r-conf', pct + '%');
    document.getElementById('r-prog').style.width = pct + '%';
    const gauge = document.getElementById('r-gauge');
    if (gauge) { const C = 169.6; gauge.style.strokeDashoffset = (C * (1 - pct/100)).toFixed(1); }

    const top3El = document.getElementById('r-top3');
    top3El.innerHTML = '';
    (result.top3 || []).slice(0, 3).forEach((item, i) => {
        const p = Math.round(item.confidence * 100);
        const d = document.createElement('div');
        d.className = 'top3-row';
        d.innerHTML = `<span class="t3-rank">${i+1}</span>
            <span class="t3-name">${fmt(item.disease)}</span>
            <span class="t3-pct">${p}%</span>`;
        top3El.appendChild(d);
    });

    /* ── TAB 2: Disease Info ── */
    const L = currentLang;
    set('inf-symptoms',    entry?.[`symptoms_${L}`]             || entry?.symptoms_en           || '—');
    set('inf-env-factors', entry?.[`environmental_factors_${L}`]|| entry?.environmental_factors_en || '—');
    set('inf-chem',        entry?.[`chemical_treatment_${L}`]   || entry?.chemical_treatment_en || '—');
    set('inf-organic',     entry?.[`organic_treatment_${L}`]    || entry?.organic_treatment_en  || '—');
    set('inf-prevention',  entry?.[`prevention_${L}`]           || entry?.prevention_en         || '—');
    set('inf-season',      entry?.[`season_${L}`]               || entry?.season_en             || '—');

    const srcEl = document.getElementById('inf-source');
    if (entry?.source_url) {
        srcEl.href = entry.source_url;
        srcEl.style.display = 'inline-flex';
        srcEl.style.gap = '5px';
        srcEl.style.alignItems = 'center';
    } else {
        srcEl.style.display = 'none';
    }

    /* ── TAB 3: Env Risk ── */
    renderEnvRisk(result.env_analysis);

    // Update risk card in sensor row
    updateRiskCard(result.env_analysis);
}

/* ── Non-plant image render ──────────────────────────────────────────────
   Shows a clear "this is not a plant" message and hides all disease info,
   treatment and environmental recommendation tabs (they stay empty). */
function renderNotPlant(result) {
    const isAr = currentLang === 'ar';

    document.getElementById('r-empty').style.display = 'none';
    document.getElementById('res-tabs').style.display = 'flex';
    // Hide the disease-info / env-risk tabs — not relevant for a non-plant image
    document.getElementById('tab-btn-info').style.display = 'none';
    document.getElementById('tab-btn-env').style.display  = 'none';
    activateTab('diagnosis');

    // Status badge (neutral)
    const sb = document.getElementById('r-status');
    sb.textContent      = isAr ? 'ليست نبتة' : 'Not a plant';
    sb.className        = 'r-status';
    sb.style.background = 'rgba(100,116,139,.15)';
    sb.style.color      = '#64748b';
    document.getElementById('r-severity').textContent = '';

    // Main message
    set('r-disease', isAr ? 'الصورة ليست نبتة' : 'This image is not a plant');
    document.getElementById('r-crop').innerHTML =
        `<i class="fas fa-circle-info"></i> ` +
        (isAr ? 'من فضلك ارفع صورة لورقة نبات وأعد المحاولة'
              : 'Please upload a plant leaf image and try again');
    document.getElementById('r-pathogen').style.display = 'none';

    // Confidence gauge
    const pct = Math.round((result.confidence || 0) * 100);
    if (window.animateCount) animateCount('r-conf', pct, 0, '%'); else set('r-conf', pct + '%');
    document.getElementById('r-prog').style.width = pct + '%';
    const gauge = document.getElementById('r-gauge');
    if (gauge) { const C = 169.6; gauge.style.strokeDashoffset = (C * (1 - pct/100)).toFixed(1); }

    // No top-3 list for a non-plant image
    document.getElementById('r-top3').innerHTML = '';

    // Empty out disease-info + env tabs (recommendations stay empty)
    ['inf-symptoms','inf-env-factors','inf-chem','inf-organic','inf-prevention','inf-season']
        .forEach(id => set(id, '—'));
    const src = document.getElementById('inf-source');
    if (src) src.style.display = 'none';
    const envContent = document.getElementById('env-content');
    if (envContent) { envContent.classList.add('hidden'); envContent.style.display = 'none'; }
    document.getElementById('env-waiting').classList.remove('hidden');

    if (window.toast) toast(isAr ? 'الصورة ليست نبتة' : 'Not a plant', 'info');
}

function renderEnvRisk(env) {
    document.getElementById('env-waiting').classList.add('hidden');
    const content = document.getElementById('env-content');
    content.classList.remove('hidden');
    content.style.display = 'flex';

    const riskCfg = {
        none:   { label:'None',   icon:'🟢', cls:'fv-norm', row:'', lvl:'rv-none' },
        low:    { label:'Low',    icon:'🟢', cls:'fv-norm', row:'border-color:rgba(16,185,129,.25)', lvl:'rv-low' },
        medium: { label:'Medium', icon:'🟡', cls:'fv-unk',  row:'border-color:rgba(245,158,11,.25)', lvl:'rv-medium' },
        high:   { label:'High',   icon:'🔴', cls:'fv-fav',  row:'border-color:rgba(244,63,94,.25)',  lvl:'rv-high' },
    };
    const r = riskCfg[env?.environmental_risk] || riskCfg.none;

    set('env-icon',    r.icon);
    set('env-lvl-txt', r.label + ' Risk');
    if (r.row) document.getElementById('env-risk-row').style.cssText += r.row;

    setFactor('fc-temp',   env?.temperature_status);
    setFactor('fc-hum',    env?.humidity_status);
    setFactor('fc-light',  env?.light_status);
    document.getElementById('fc-driven').textContent = env?.env_driven ? 'Yes' : 'No';
    document.getElementById('fc-driven').className   = 'fc-val ' + (env?.env_driven ? 'fv-fav' : 'fv-norm');

    const L2 = currentLang;
    set('env-summary', env?.[`summary_${L2}`] || env?.summary_en || '—');

    const tips = env?.[`improvement_tips_${L2}`] || env?.improvement_tips_en || [];
    const tipsWrap = document.getElementById('tips-wrap');
    if (tips.length) {
        tipsWrap.classList.remove('hidden');
        const tl = document.getElementById('tips-list');
        tl.innerHTML = '';
        tips.forEach(t => {
            const el = document.createElement('div');
            el.className = 'tip';
            el.textContent = t;
            tl.appendChild(el);
        });
    } else {
        tipsWrap.classList.add('hidden');
    }
}

function setFactor(id, status) {
    const el = document.getElementById(id);
    const map = {
        favorable:   ['Favorable ↑', 'fv-fav'],
        unfavorable: ['Unfavorable', 'fv-unfav'],
        low:         ['Low',         'fv-low'],
        high:        ['High',        'fv-high'],
        normal:      ['Normal',      'fv-norm'],
        unknown:     ['Unknown',     'fv-unk'],
    };
    const [label, cls] = map[status] || ['—', 'fv-unk'];
    el.textContent = label;
    el.className   = 'fc-val ' + cls;
}

function updateRiskCard(env) {
    if (!env) return;
    const risk = env.environmental_risk || 'none';
    const labels = { none:'None', low:'Low', medium:'Medium', high:'High' };
    const classes = { none:'rv-none', low:'rv-low', medium:'rv-medium', high:'rv-high' };
    const badgeCls = { none:'b-none', low:'b-normal', medium:'b-high', high:'b-crit' };

    const rEl = document.getElementById('risk-val');
    rEl.textContent = labels[risk] || '—';
    rEl.className   = 'risk-val ' + (classes[risk] || 'rv-none');
    setBadge('risk-badge', { label: labels[risk]+' Risk', cls: badgeCls[risk]||'b-none' });
    set('risk-sub', env[`summary_${currentLang}`] || env.summary_en || '');
    document.getElementById('card-risk').classList.add('has-data');
}

/* ═══════════════════════════════════════════════════════
   TABS
═══════════════════════════════════════════════════════ */
function setupTabs() {
    document.querySelectorAll('.res-tab').forEach(btn => {
        btn.addEventListener('click', () => activateTab(btn.dataset.tab));
    });
}
function activateTab(name) {
    document.querySelectorAll('.res-tab').forEach(b => b.classList.toggle('active', b.dataset.tab === name));
    document.querySelectorAll('.res-tab-content').forEach(c => c.classList.toggle('active', c.id === 'tab-'+name));
    document.querySelectorAll('.res-tab-content.active').forEach(c => c.style.display = 'flex');
    document.querySelectorAll('.res-tab-content:not(.active)').forEach(c => c.style.display = 'none');
}

/* ═══════════════════════════════════════════════════════
   UTILS
═══════════════════════════════════════════════════════ */
function set(id, val) { const el = document.getElementById(id); if (el) el.textContent = val; }
function fmt(s) { return s ? s.replace(/___/g,' — ').replace(/_/g,' ') : '—'; }

/* ═══════════════════════════════════════════════════════
   LANGUAGE TOGGLE
═══════════════════════════════════════════════════════ */
let currentLang = 'en';

// Static UI strings — key: [en, ar]
const UI = {
  brandTitle:     ['AI Plant Disease Detection', 'نظام الكشف عن أمراض النباتات بالذكاء الاصطناعي'],
  brandSub:       ['Real-time Environmental Monitoring & Disease Diagnosis', 'مراقبة بيئية فورية وتشخيص الأمراض'],
  apiOnline:      ['API Online',          'الـ API متصل'],
  apiOffline:     ['API Offline',         'الـ API غير متاح'],
  apiConn:        ['Connecting…',         'جاري الاتصال…'],
  espConn:        ['ESP32 Connected',     'ESP32 متصل'],
  espWait:        ['Waiting for ESP32…',  'بانتظار ESP32…'],
  secSensors:     ['Live Sensor Readings — ESP32-S3', 'قراءات الحساسات الفورية — ESP32-S3'],
  secCharts:      ['Reading History — logged every 5 min', 'سجل القراءات — كل 5 دقائق'],
  secPredict:     ['Disease Prediction',  'تشخيص المرض'],
  tempName:       ['Temperature',         'درجة الحرارة'],
  humName:        ['Relative Humidity',   'الرطوبة النسبية'],
  lightName:      ['Light Intensity',     'شدة الضوء'],
  riskName:       ['Environmental Risk',  'الخطر البيئي'],
  noScanYet:      ['No scan yet',         'لم يتم المسح بعد'],
  riskSubDef:     ['Run a prediction to see the risk level', 'شخّص صورة لرؤية مستوى الخطر'],
  tempWait:       ['Waiting for sensor data', 'بانتظار بيانات الحساس'],
  humWait:        ['Waiting for sensor data', 'بانتظار بيانات الحساس'],
  lightWait:      ['Waiting for sensor data', 'بانتظار بيانات الحساس'],
  chTempLbl:      ['Temperature', 'درجة الحرارة'],
  chHumLbl:       ['Humidity',    'الرطوبة'],
  chLightLbl:     ['Light Intensity', 'شدة الضوء'],
  panelLeaf:      ['Leaf Image',      'صورة الورقة'],
  dzText:         ['Drop a leaf image here', 'اسحب صورة الورقة هنا'],
  dzSub:          ['or click to browse — JPG / PNG', 'أو اضغط للاختيار — JPG / PNG'],
  btnAnalyze:     ['Analyze',     'تحليل'],
  panelResults:   ['Analysis Results', 'نتائج التحليل'],
  tabDiagnosis:   ['Diagnosis',    'التشخيص'],
  tabInfo:        ['Disease Info', 'معلومات المرض'],
  tabEnv:         ['Env Risk',     'الخطر البيئي'],
  emptyMsg:       ['Upload a plant leaf image and\nclick Analyze to get the prediction',
                   'ارفع صورة ورقة نبات\nواضغط تحليل للحصول على التشخيص'],
  healthy:        ['✓ Healthy',   '✓ سليم'],
  diseased:       ['⚠ Diseased',  '⚠ مصاب'],
  sevLabel:       ['Severity:',   'الشدة:'],
  cropLabel:      ['Crop',        'المحصول'],
  confLabel:      ['Confidence',  'نسبة التأكد'],
  top3Label:      ['Top 3 Predictions', 'أفضل 3 توقعات'],
  infSymptoms:    ['Symptoms',    'الأعراض'],
  infEnvFact:     ['Environmental Factors', 'العوامل البيئية'],
  infChem:        ['Chemical Treatment', 'العلاج الكيميائي'],
  infOrganic:     ['Organic Treatment',  'العلاج العضوي'],
  infPrev:        ['Prevention',  'الوقاية'],
  infSeason:      ['Season',      'الموسم'],
  srcLink:        ['View scientific source', 'المصدر العلمي'],
  envRiskWait:    ['Run a prediction to see the environmental risk analysis for the detected disease.',
                   'قم بالتشخيص لرؤية تحليل الخطر البيئي للمرض المكتشف.'],
  envRiskLbl:     ['Environmental risk for current conditions', 'الخطر البيئي للظروف الحالية'],
  fcTemp:         ['Temperature', 'الحرارة'],
  fcHum:          ['Humidity',    'الرطوبة'],
  fcLight:        ['Light',       'الضوء'],
  fcDriven:       ['Env Driven',  'مرتبط بالبيئة'],
  tipsLbl:        ['Improvement Tips', 'نصائح للتحسين'],
  footer:         ['AI Plant Disease Detection System · Graduation Project 2026 · Misr University for Science and Technology · Supervisor: Dr. Heba ELnemr',
                   'نظام الكشف عن أمراض النباتات · مشروع تخرج 2026 · جامعة مصر للعلوم والتكنولوجيا · المشرف: د. هبة النمر'],
  langBtn:        ['العربية', 'English'],
  badgeNormal:    ['Normal',    'طبيعي'],
  badgeHigh:      ['High',      'مرتفع'],
  badgeLow:       ['Low',       'منخفض'],
  badgeCrit:      ['Critical',  'حرج'],
  badgeDry:       ['Dry',       'جاف'],
  badgeHumid:     ['Humid',     'رطب'],
  badgeVHumid:    ['Very Humid','رطب جداً'],
  badgeDim:       ['Dim',       'خافت'],
  badgeBright:    ['Bright',    'مشرق'],
  badgeVCold:     ['Very Cold', 'بارد جداً'],
  badgeCold:      ['Cold',      'بارد'],
  apiUpdated:     ['Updated',   'تم التحديث'],
  riskNone:       ['None',      'لا يوجد'],
  riskLow:        ['Low',       'منخفض'],
  riskMed:        ['Medium',    'متوسط'],
  riskHigh:       ['High',      'مرتفع'],
  riskSuffix:     ['Risk',      'خطر'],
  favStatus:      ['Favorable ↑', 'مؤاتٍ ↑'],
  unfavStatus:    ['Unfavorable', 'غير مؤاتٍ'],
  lowStatus:      ['Low',         'منخفض'],
  highStatus:     ['High',        'مرتفع'],
  normStatus:     ['Normal',      'طبيعي'],
  unkStatus:      ['Unknown',     'غير معروف'],
  yesNo:          [['Yes','No'],  ['نعم','لا']],
  nextLog:        ['Next log in ~', 'التسجيل القادم خلال ~'],
  min:            ['min', 'دقيقة'],
};

function t(key) { return UI[key]?.[currentLang === 'en' ? 0 : 1] ?? key; }
function l(key) { return currentLang; }

function toggleLang() {
    currentLang = currentLang === 'en' ? 'ar' : 'en';
    const html = document.documentElement;
    html.lang = currentLang;
    html.dir  = currentLang === 'ar' ? 'rtl' : 'ltr';
    set('lang-btn-txt', t('langBtn'));
    applyStaticLabels();
}

function applyStaticLabels() {
    // Brand
    set('brand-title', t('brandTitle'));
    set('brand-sub',   t('brandSub'));
    // Section labels
    set('sec-sensors', t('secSensors'));
    set('sec-charts',  t('secCharts'));
    set('sec-predict', t('secPredict'));
    // Sensor names
    set('temp-name',  t('tempName'));
    set('hum-name',   t('humName'));
    set('light-name', t('lightName'));
    set('risk-name',  t('riskName'));
    // Sensor hints (if still default)
    ['temp-hint','hum-hint','light-hint'].forEach(id => {
        const el = document.getElementById(id);
        if (el && el.dataset.hasData !== 'true') set(id, t('tempWait'));
    });
    // Chart labels
    set('ch-temp-lbl',  t('chTempLbl'));
    set('ch-hum-lbl',   t('chHumLbl'));
    set('ch-light-lbl', t('chLightLbl'));
    // Panel titles
    set('panel-leaf',    t('panelLeaf'));
    set('panel-results', t('panelResults'));
    // Drop zone
    set('dz-text', t('dzText'));
    set('dz-sub',  t('dzSub'));
    // Conf label
    set('conf-lbl', t('confLabel'));
    set('top3-lbl', t('top3Label'));
    // Btn
    const btnTxt = document.getElementById('btn-txt');
    if (btnTxt) btnTxt.innerHTML = `<i class="fas fa-magnifying-glass"></i> ${t('btnAnalyze')}`;
    // Tabs
    set('tab-btn-diagnosis',  t('tabDiagnosis'));
    set('tab-btn-info',       t('tabInfo'));
    set('tab-btn-env',        t('tabEnv'));
    // Empty state
    const em = document.getElementById('r-empty-p');
    if (em) em.innerHTML = t('emptyMsg').replace('\n','<br>');
    // Table labels
    set('lbl-symptoms',   t('infSymptoms'));
    set('lbl-env-fact',   t('infEnvFact'));
    set('lbl-chem',       t('infChem'));
    set('lbl-organic',    t('infOrganic'));
    set('lbl-prev',       t('infPrev'));
    set('lbl-season',     t('infSeason'));
    // Env risk labels
    set('fc-lbl-temp',   t('fcTemp'));
    set('fc-lbl-hum',    t('fcHum'));
    set('fc-lbl-light',  t('fcLight'));
    set('fc-lbl-driven', t('fcDriven'));
    set('env-risk-sub',  t('envRiskLbl'));
    const ewEl = document.getElementById('env-waiting');
    if (ewEl) ewEl.textContent = t('envRiskWait');
    // Tips label
    set('tips-lbl', t('tipsLbl'));
    // Footer
    set('footer-txt', t('footer'));
    // Source link
    const sl = document.getElementById('inf-source');
    if (sl && sl.dataset.url) {
        sl.innerHTML = `<i class="fas fa-arrow-up-right-from-square"></i> ${t('srcLink')}`;
    }
    // Enhancement labels (login / nav / archive / about)
    if (window._applyEnhLabels) _applyEnhLabels();
    // Re-render current prediction if any (to swap language in data fields)
    if (window._lastResult) renderPrediction(window._lastResult);
}

// (lang-switch re-render handled inside renderPrediction directly)

/* ═══════════════════════════════════════════════════════
   ENHANCEMENTS — Auth · Splash · Nav · Archive · FX
═══════════════════════════════════════════════════════ */
(function(){
  function $(id){ return document.getElementById(id); }

  /* ---- TOAST ---- */
  window.toast = function(msg, type='ok', icon){
    const wrap = $('toast-wrap'); if(!wrap) return;
    const ic = icon || (type==='err'?'fa-circle-exclamation':type==='info'?'fa-circle-info':'fa-circle-check');
    const el = document.createElement('div');
    el.className = 'toast '+type;
    el.innerHTML = '<i class="fas '+ic+'"></i><span>'+msg+'</span>';
    wrap.appendChild(el);
    setTimeout(()=>{ el.classList.add('out'); setTimeout(()=>el.remove(),300); }, 3200);
  };

  /* ---- COUNT-UP ---- */
  window.animateCount = function(id, to, decimals, suffix){
    decimals = decimals||0; suffix = suffix||'';
    const el = $(id); if(!el) return;
    const from = parseFloat(el.dataset.cv||'0') || 0;
    const dur = 600, t0 = performance.now();
    function step(t){
      const p = Math.min((t-t0)/dur, 1);
      const e = 1-Math.pow(1-p,3);
      const v = from + (to-from)*e;
      el.textContent = v.toFixed(decimals)+suffix;
      if(p<1) requestAnimationFrame(step);
      else { el.textContent = to.toFixed(decimals)+suffix; el.dataset.cv = to; }
    }
    requestAnimationFrame(step);
  };

  /* ---- AUTH / SPLASH ---- */
  function showApp(name){            // signed-in state: show user chip, hide login overlay + login button
    window._authed = true;
    const sp = $('splash'); if(sp) sp.classList.add('hide');
    hideLogin();
    const lb = $('topbar-login'); if(lb) lb.style.display='none';
    const chip = $('user-chip');
    if(chip) chip.style.display='inline-flex';
    if($('user-name'))   $('user-name').textContent = name;
    if($('user-avatar')) $('user-avatar').textContent = (name[0]||'U').toUpperCase();
  }
  function signedOut(){              // open/guest state: show login button, hide chip (no forced overlay)
    window._authed = false;
    const chip = $('user-chip'); if(chip) chip.style.display='none';
    const lb = $('topbar-login'); if(lb) lb.style.display='inline-flex';
  }
  function showLogin(){              // open the (optional) login overlay
    const lg = $('login'); if(!lg) return;
    lg.style.display='flex';
    requestAnimationFrame(()=>lg.classList.add('show'));
  }
  function hideLogin(){              // dismiss the login overlay
    const lg = $('login'); if(!lg) return;
    lg.classList.remove('show');
    setTimeout(()=>{ lg.style.display='none'; }, 500);
  }
  function doLogout(){ signedOut(); toast(t2('loggedOut'),'info'); }
  window._showApp   = showApp;
  window._showLogin = showLogin;
  window._signedOut = signedOut;
  window._hideLogin = hideLogin;
  function revealAfterSplash(){      // open marketing site directly — no forced login gate
    const sp = $('splash'); if(sp) sp.classList.add('hide');
  }
  // Robust: don't depend solely on window 'load' (can be delayed/blocked on file://)
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    setTimeout(revealAfterSplash, 1800);
  } else {
    document.addEventListener('DOMContentLoaded', ()=> setTimeout(revealAfterSplash, 1800));
  }
  // Absolute safety net: never leave the page stuck on the splash
  setTimeout(()=>{ const sp=$('splash'); if(sp && !sp.classList.contains('hide')) revealAfterSplash(); }, 4000);

  /* ---- VIEW NAV ---- */
  window.showView = function(name){
    document.querySelectorAll('.nav-item').forEach(b=>b.classList.toggle('active', b.dataset.view===name));
    document.querySelectorAll('.view').forEach(v=>v.classList.toggle('active', v.id==='view-'+name));
    window.scrollTo({top:0,behavior:'smooth'});
    if(name==='about') animateAboutStats();
  };

  let _statsDone = false;
  function animateAboutStats(){
    if(_statsDone) return; _statsDone = true;
    let classes = 0, crops = 0;
    try {
      if (typeof db !== 'undefined' && db && db.length) {
        classes = db.length;
        const set = new Set();
        db.forEach(r => { const c = r.crop_en || (r.disease_en||'').split('___')[0]; if(c) set.add(String(c).trim().toLowerCase()); });
        crops = set.size;
      }
    } catch(_){}
    if(!classes) classes = 38;
    if(!crops)   crops   = 14;
    animateCount('stat-acc', 97, 0);
    animateCount('stat-classes', classes, 0);
    animateCount('stat-crops', crops, 0);
  }

  /* ---- ARCHIVE ---- */
  const archive = [];
  window.addToArchive = function(result, entry, imgSrc){
    const notPlant  = (result.is_plant === false) || (result.disease === 'Not_plant');
    const isHealthy = (result.disease||'').toLowerCase().includes('healthy');
    archive.unshift({
      disease: notPlant
        ? (currentLang==='ar' ? 'ليست نبتة' : 'Not a plant')
        : ((entry&&entry.disease_en) || (result.disease||'').replace(/___/g,' — ').replace(/_/g,' ')),
      crop: notPlant ? '—'
        : ((entry&&entry.crop_en) || (result.disease||'').split('___')[0] || '—'),
      conf: Math.round((result.confidence||0)*100),
      healthy: isHealthy, notPlant: notPlant, img: imgSrc, time: new Date()
    });
    renderArchive();
  };
  function renderArchive(){
    const grid = $('arch-grid'), empty=$('arch-empty'), count=$('arch-count');
    if(!grid) return;
    count.textContent = archive.length ? '· '+archive.length : '';
    if(!archive.length){ empty.style.display='block'; grid.innerHTML=''; return; }
    empty.style.display='none';
    grid.innerHTML='';
    archive.forEach(a=>{
      const card = document.createElement('div');
      card.className='arch-card';
      const tagCls = a.notPlant ? 'b-none' : (a.healthy ? 'b-normal' : 'b-crit');
      const tagTxt = a.notPlant ? (currentLang==='ar' ? 'ليست نبتة' : 'Not a plant')
                                : (a.healthy ? t2('healthyTag') : t2('diseasedTag'));
      const ts = a.time.toLocaleString(currentLang==='ar'?'ar-EG':'en-US',{month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'});
      card.innerHTML =
        '<img class="arch-thumb" src="'+(a.img||'')+'" alt="">'+
        '<div class="arch-body">'+
          '<div class="arch-disease">'+a.disease+'</div>'+
          '<div class="arch-meta"><span>'+a.crop+' · '+a.conf+'%</span>'+
          '<span class="arch-tag '+tagCls+'">'+tagTxt+'</span></div>'+
          '<div class="arch-meta"><span><i class="fas fa-clock" style="font-size:9px"></i> '+ts+'</span></div>'+
        '</div>';
      grid.appendChild(card);
    });
  }

  /* ---- enhancement i18n ---- */
  const X = {
    splashSub:['Graduation Project 2026','مشروع تخرج 2026'],
    loginH:['Welcome back','أهلاً بعودتك'],
    loginP:['Sign in to access the monitoring dashboard','سجّل الدخول للوصول إلى لوحة المراقبة'],
    lblEmail:['Email','البريد الإلكتروني'],
    lblPass:['Password','كلمة المرور'],
    submit:['Sign In','تسجيل الدخول'],
    guestBtn:['Continue as Guest','الدخول كضيف'],
    loginFoot:['Demo access · No real credentials required','وصول تجريبي · لا حاجة لبيانات حقيقية'],
    navDash:['Dashboard','اللوحة'],
    navArch:['Archive','الأرشيف'],
    navDetails:['Details','تفاصيل'],
    navAbout:['About','عن النظام'],
    secArch:['Diagnosis Archive','أرشيف التشخيصات'],
    archEmpty:['No diagnoses yet. Analyze a leaf image to build your history.','لا توجد تشخيصات بعد. حلّل صورة ورقة لبناء سجلك.'],
    aboutTitle:['AI Plant Disease Detection System','نظام الكشف عن أمراض النباتات بالذكاء الاصطناعي'],
    aboutDesc:['An integrated system that diagnoses plant leaf diseases from images using a deep-learning model, while correlating the diagnosis with live environmental readings from IoT sensors to assess and reduce disease risk.','نظام متكامل يشخّص أمراض أوراق النباتات من الصور باستخدام نموذج تعلّم عميق، ويربط التشخيص بقراءات بيئية فورية من حساسات إنترنت الأشياء لتقييم خطر المرض والحدّ منه.'],
    stackH:['Technology Stack','التقنيات المستخدمة'],
    featH:['Key Features','أهم المميزات'],
    teamH:['Team','الفريق'],
    projH:['Project Info','بيانات المشروع'],
    stkFlutter:['Mobile application','تطبيق الموبايل'],
    stkApi:['Backend & inference API','الخادم وواجهة الاستدلال'],
    stkModel:['Disease classification model','نموذج تصنيف الأمراض'],
    stkEsp:['Environmental IoT sensors','حساسات بيئية (IoT)'],
    feat1:['Image-based disease diagnosis','تشخيص الأمراض من الصور'],
    feat2:['Live temperature, humidity & light','حرارة ورطوبة وإضاءة فورية'],
    feat3:['Environmental risk analysis','تحليل الخطر البيئي'],
    feat4:['Bilingual interface (EN / AR)','واجهة ثنائية اللغة (EN / AR)'],
    supL:['Supervisor','المشرف'],
    uniL:['University','الجامعة'],
    uniV:['Misr University for Science and Technology','جامعة مصر للعلوم والتكنولوجيا'],
    yearL:['Graduation Project','مشروع تخرج'],
    welcome:['Welcome! Signed in successfully.','أهلاً! تم تسجيل الدخول بنجاح.'],
    guestMode:['Browsing as guest','تتصفح كضيف'],
    guest:['Guest','ضيف'],
    loggedOut:['Signed out','تم تسجيل الخروج'],
    healthyTag:['Healthy','سليم'],
    diseasedTag:['Diseased','مصاب'],
  };
  window.t2 = function(k){ return X[k] ? X[k][currentLang==='ar'?1:0] : k; };
  function setNav(id,key){ const b=$(id); if(b){ const s=b.querySelector('span'); if(s) s.textContent=t2(key);} }
  window._applyEnhLabels = function(){
    const m = {
      'splash-sub':'splashSub','login-h':'loginH','login-p':'loginP',
      'login-lbl-email':'lblEmail','login-lbl-pass':'lblPass','login-submit-txt':'submit',
      'login-guest':'guestBtn','login-foot':'loginFoot',
      'sec-archive':'secArch','arch-empty-p':'archEmpty',
      'about-title':'aboutTitle','about-desc':'aboutDesc','about-stack-h':'stackH',
      'about-feat-h':'featH','about-team-h':'teamH','about-proj-h':'projH',
      'stk-flutter':'stkFlutter','stk-api':'stkApi','stk-model':'stkModel','stk-esp':'stkEsp',
      'feat-1':'feat1','feat-2':'feat2','feat-3':'feat3','feat-4':'feat4',
      'proj-sup-l':'supL','proj-uni-l':'uniL','proj-uni':'uniV','proj-year-l':'yearL',
    };
    for(const id in m){ const el=$(id); if(el) el.textContent = t2(m[id]); }
    setNav('nav-dashboard','navDash'); setNav('nav-archive','navArch'); setNav('nav-details','navDetails'); setNav('nav-about','navAbout');
    const ll=$('login-lang-txt'); if(ll) ll.textContent = (currentLang==='ar'?'English':'العربية');
    // generic data-en / data-ar swap (portfolio & misc)
    document.querySelectorAll('[data-en]').forEach(el=>{
      const v = currentLang==='ar' ? el.getAttribute('data-ar') : el.getAttribute('data-en');
      if(v!=null) el.innerHTML = v;
    });
    renderArchive();
  };

  /* ---- wire up ---- */
  document.addEventListener('DOMContentLoaded', ()=>{
    const form = $('login-form');
    if(form) form.addEventListener('submit', e=>{
      e.preventDefault();
      const email = ($('login-email').value||'').trim();
      const pass  = ($('login-pass').value||'');
      if(window.fbEmailLogin) window.fbEmailLogin(email, pass);
      else { showApp((email||'User').split('@')[0]); toast(t2('welcome'),'ok'); } // offline fallback
    });
    const g = $('login-guest'); if(g) g.addEventListener('click', ()=>{
      if(window.fbGuest) window.fbGuest();
      else { showApp(t2('guest')); toast(t2('guestMode'),'info'); }
    });
    const lo = $('user-logout'); if(lo) lo.addEventListener('click', ()=>{ if(window.fbLogout) window.fbLogout(); else doLogout(); });
    const tl = $('topbar-login'); if(tl) tl.addEventListener('click', showLogin);   // optional login
    const lc = $('login-close');  if(lc) lc.addEventListener('click', hideLogin);    // dismiss overlay
    document.querySelectorAll('.nav-item').forEach(b=>b.addEventListener('click', ()=>showView(b.dataset.view)));
    if(window._applyEnhLabels) _applyEnhLabels();
    // About is the default view → run its stat counters on load
    const av = $('view-about');
    if (av && av.classList.contains('active')) animateAboutStats();
  });
})();

/* ═══════════════════════════════════════════════════════
   INTERACTIVE FX — scroll reveal (About) + cursor spotlight
═══════════════════════════════════════════════════════ */
(function(){
  document.documentElement.classList.add('js-anim');

  function setupReveal(){
    const els = Array.from(document.querySelectorAll(
      '#view-about .pf-hero, #view-about .pf-stats .pf-stat, #view-about .pf-sec-head,' +
      '#view-about .pf-two > *, #view-about .pf-arch > *, #view-about .pf-future > *,' +
      '#view-about .pf-team .member, #view-about .pf-contact'
    ));
    els.forEach(el => el.classList.add('reveal'));

    if (!('IntersectionObserver' in window)) { els.forEach(el => el.classList.add('in')); return; }

    const io = new IntersectionObserver((entries) => {
      entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });

    els.forEach(el => {
      const sibs = Array.from(el.parentElement.children).filter(c => c.classList.contains('reveal'));
      const idx = Math.max(0, sibs.indexOf(el));
      el.style.transitionDelay = (idx * 70) + 'ms';
      io.observe(el);
    });

    // Failsafe: never leave an in-viewport element hidden
    setTimeout(() => els.forEach(el => {
      if (el.getBoundingClientRect().top < window.innerHeight) el.classList.add('in');
    }), 1400);
  }

  // Cursor-follow spotlight: update CSS vars on the hovered card
  let raf = 0, lastE = null;
  const CARD_SEL = '.pf-card, .acol, .fb, .sum, .pf-stat, .future-step, .techbar .tb';
  function onMove(e){
    lastE = e;
    if (raf) return;
    raf = requestAnimationFrame(() => {
      raf = 0;
      const card = lastE.target.closest && lastE.target.closest(CARD_SEL);
      if (!card) return;
      const r = card.getBoundingClientRect();
      card.style.setProperty('--mx', ((lastE.clientX - r.left) / r.width * 100) + '%');
      card.style.setProperty('--my', ((lastE.clientY - r.top) / r.height * 100) + '%');
    });
  }

  function init(){
    setupReveal();
    document.addEventListener('mousemove', onMove, { passive: true });
  }
  if (document.readyState !== 'loading') init();
  else document.addEventListener('DOMContentLoaded', init);
})();
