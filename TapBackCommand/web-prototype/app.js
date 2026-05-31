/* TapBack Command — web prototype logic
   Faithful port of the SwiftUI app behaviour for testing on desktop.
   Mirrors: AppRouter, the 3 ViewModels, the local Summarizer heuristic,
   Speech transcription (Web Speech API), and StorageService (localStorage). */

(() => {
  "use strict";

  // ---------- Storage (≈ StorageService) ----------
  const Store = {
    get(key, fallback) {
      try { return JSON.parse(localStorage.getItem("tbc_" + key)) ?? fallback; }
      catch { return fallback; }
    },
    set(key, val) { localStorage.setItem("tbc_" + key, JSON.stringify(val)); }
  };

  // ---------- App state (≈ AppRouter + ViewModels) ----------
  const State = {
    scene: "home",          // "home" (springboard) | "app"
    tab: "notes",
    todoArchive: false,     // onglet To-Do : false = À faire, true = Terminées
    notes: Store.get("notes", []),
    todos: Store.get("todos", []),
    searches: Store.get("searches", []),
  };

  const $ = (sel, root = document) => root.querySelector(sel);
  const el = (tag, cls, html) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html != null) n.innerHTML = html;
    return n;
  };
  const uid = () => Math.random().toString(36).slice(2);
  const esc = (s) => (s ?? "").replace(/[&<>"]/g, c => ({ "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;" }[c]));

  function stamp(ts) {
    const d = new Date(ts), now = new Date();
    const hm = d.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
    if (d.toDateString() === now.toDateString()) return "Aujourd'hui " + hm;
    const y = new Date(now); y.setDate(now.getDate() - 1);
    if (d.toDateString() === y.toDateString()) return "Hier " + hm;
    return d.toLocaleDateString("fr-FR", { day: "numeric", month: "short" }) + " " + hm;
  }
  function clock(sec) {
    const s = Math.floor(sec);
    return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
  }

  // ---------- Local summarizer (≈ LocalHeuristicSummarizer) ----------
  const STOP = new Set("le la les un une des de du et ou à au aux ce cette ces mon ma mes que qui est être avoir faire pour avec dans sur par plus pas ne je tu il elle nous vous ils the a an and or to of in on for is it this that".split(" "));
  function tokens(t) {
    return t.toLowerCase().split(/[^a-zàâçéèêëîïôûùüÿñæœ0-9]+/i).filter(w => w.length > 2 && !STOP.has(w));
  }
  function summarize(text) {
    const sentences = text.match(/[^.!?]+[.!?]*/g) || [text];
    if (sentences.length <= 1) return text.trim();
    const freq = {}; tokens(text).forEach(w => freq[w] = (freq[w] || 0) + 1);
    const max = Math.max(1, ...Object.values(freq));
    const ranked = sentences.map(s => {
      const tk = tokens(s);
      const score = tk.reduce((a, w) => a + (freq[w] || 0) / max, 0) / Math.sqrt(Math.max(tk.length, 1));
      return { s: s.trim(), score };
    });
    const top = ranked.slice().sort((a, b) => b.score - a.score).slice(0, 2).map(r => r.s);
    return sentences.map(s => s.trim()).filter(s => top.includes(s)).join(" ").trim();
  }
  function generatePlan(text) {
    let t = text.replace(/fais un plan/gi, "");
    const steps = t.split(/[.!?;\n]| puis | ensuite /i).map(s => s.trim()).filter(s => s.length > 3);
    const out = steps.map(s => s.charAt(0).toUpperCase() + s.slice(1));
    return out.length ? out : ["Définir l'objectif", "Lister les étapes", "Planifier le suivi"];
  }
  const PLAN_KEYWORD = "fais un plan";

  // ---------- Context detection (≈ ContextDetectionService) ----------
  function ytTimestamp(url) {
    try {
      const u = new URL(url);
      const v = u.searchParams.get("t") || u.searchParams.get("start");
      if (!v) return null;
      if (/^\d+$/.test(v)) return parseInt(v, 10);
      let tot = 0; (v.match(/(\d+)([hms])/g) || []).forEach(p => {
        const n = parseInt(p, 10), u2 = p.slice(-1);
        tot += n * (u2 === "h" ? 3600 : u2 === "m" ? 60 : 1);
      });
      return tot || null;
    } catch { return null; }
  }
  function classifyURL(url) {
    let host = ""; try { host = new URL(url).host.toLowerCase(); } catch {}
    if (host.includes("youtube.com") || host.includes("youtu.be")) {
      const t = ytTimestamp(url);
      return { kind: "youtube", icon: "▶️", title: url,
        subtitle: "youtube" + (t != null ? " • " + clock(t) : ""), url, tags: ["video"] };
    }
    return { kind: "safari", icon: "🧭", title: url, subtitle: host, url, tags: [] };
  }

  // ============================================================
  // RENDER
  // ============================================================
  const content = $("#content");

  function render() {
    document.querySelectorAll(".tab").forEach(t =>
      t.classList.toggle("active", t.dataset.tab === State.tab));
    if (State.tab === "notes") renderNotes();
    if (State.tab === "todos") renderTodos();
    if (State.tab === "searches") renderSearches();
  }

  function emptyState(ico, title, msg) {
    const e = el("div", "empty");
    e.innerHTML = `<div class="ico">${ico}</div><h3>${title}</h3><div>${msg}</div>`;
    return e;
  }

  // ----- Notes -----
  function renderNotes() {
    content.innerHTML = "";
    content.appendChild(el("div", "page-title", "Notes"));
    if (!State.notes.length) {
      content.appendChild(emptyState("🎙️", "Aucune note",
        "Clique sur <b>Tap Back</b> puis 🎙️ pour enregistrer une note vocale."));
      return;
    }
    State.notes.forEach(n => {
      const c = el("div", "card");
      c.innerHTML = `
        <div class="row-title">${esc(n.title)} ${n.plan && n.plan.length ? "📋" : ""}</div>
        <div class="row-sub">${esc(n.summary || n.transcript).slice(0, 120)}</div>
        <div class="row-date">${stamp(n.createdAt)}</div>`;
      const actions = el("div", "card-actions");
      if (n.audioURL) {
        const play = el("button", "linkbtn", "▶︎ Écouter");
        play.onclick = () => new Audio(n.audioURL).play();
        actions.appendChild(play);
      }
      const del = el("button", "linkbtn", "🗑 Supprimer");
      del.style.color = "var(--record)";
      del.onclick = () => { State.notes = State.notes.filter(x => x.id !== n.id); Store.set("notes", State.notes); render(); };
      actions.appendChild(del);
      c.appendChild(actions);
      content.appendChild(c);
    });
  }

  // ----- Todos -----
  // Une tâche est archivée si terminée depuis ≥ 24 h.
  const DAY_MS = 24 * 60 * 60 * 1000;
  const isArchived = (t) => t.done && t.doneAt && (Date.now() - t.doneAt) >= DAY_MS;

  function renderTodos() {
    content.innerHTML = "";
    content.appendChild(el("div", "page-title", "To-Do"));

    const active = State.todos.filter(t => !isArchived(t));
    const done = State.todos.filter(t => t.done)
      .sort((a, b) => (b.doneAt || b.createdAt) - (a.doneAt || a.createdAt));

    // Sélecteur À faire / Terminées
    const seg = el("div", "tabseg");
    const mkSeg = (label, on, fn) => {
      const b = el("button", "tabseg-btn" + (on ? " on" : ""), label);
      b.onclick = fn;
      return b;
    };
    seg.append(
      mkSeg(`À faire (${active.length})`, !State.todoArchive,
        () => { State.todoArchive = false; render(); }),
      mkSeg(`Terminées (${done.length})`, State.todoArchive,
        () => { State.todoArchive = true; render(); })
    );
    content.appendChild(seg);

    const list = State.todoArchive ? done : active;
    if (!list.length) {
      content.appendChild(emptyState(
        State.todoArchive ? "🗂️" : "✅",
        State.todoArchive ? "Aucune tâche terminée" : "Aucune tâche",
        State.todoArchive
          ? "Les tâches cochées « Fait » sont conservées ici avec leurs dates."
          : "Clique sur <b>Tap Back</b> puis ✏️ pour ajouter une tâche."));
      return;
    }

    list.forEach(t => State.todoArchive ? content.appendChild(archiveCard(t))
                                        : content.appendChild(activeCard(t)));
  }

  function activeCard(t) {
    const c = el("div", "card");
    const r = el("div", "row-flex");
    const chk = el("button", null, t.done ? "✅" : "⚪️");
    chk.style.cssText = "background:none;border:none;font-size:22px;cursor:pointer;line-height:1;";
    chk.onclick = () => {
      t.done = !t.done;
      t.doneAt = t.done ? Date.now() : null;
      Store.set("todos", State.todos);
      render();
    };
    const mid = el("div");
    mid.style.flex = "1";
    mid.innerHTML =
      `<div class="row-title" style="${t.done ? "opacity:.4;text-decoration:line-through" : ""}">${esc(t.text)}</div>` +
      (t.done ? `<div class="row-sub">Fait · retiré de la liste dans 24 h</div>` : "");
    const del = el("button", "swipe-del", "🗑");
    del.onclick = () => { State.todos = State.todos.filter(x => x.id !== t.id); Store.set("todos", State.todos); render(); };
    r.append(chk, mid, del);
    c.appendChild(r);
    return c;
  }

  function archiveCard(t) {
    const c = el("div", "card");
    const r = el("div", "row-flex");
    const ic = el("div", "thumb"); ic.textContent = "✅";
    const mid = el("div"); mid.style.flex = "1";
    mid.innerHTML =
      `<div class="row-title" style="text-decoration:line-through;opacity:.7">${esc(t.text)}</div>` +
      `<div class="row-date">Créée : ${stamp(t.createdAt)}</div>` +
      (t.doneAt ? `<div class="row-sub" style="color:#30d158">Faite : ${stamp(t.doneAt)}</div>` : "");
    const del = el("button", "swipe-del", "🗑");
    del.onclick = () => { State.todos = State.todos.filter(x => x.id !== t.id); Store.set("todos", State.todos); render(); };
    r.append(ic, mid, del);
    c.appendChild(r);
    return c;
  }

  // ----- Searches (historique des recherches) -----
  function renderSearches() {
    content.innerHTML = "";
    content.appendChild(el("div", "page-title", "Recherches"));
    if (!State.searches.length) {
      content.appendChild(emptyState("🔍", "Aucune recherche",
        "Clique sur <b>Tap Back</b> puis 🔍 pour obtenir la définition ou l'explication d'un mot."));
      return;
    }
    State.searches.forEach(s => {
      const c = el("div", "card");
      const r = el("div", "row-flex");
      const thumb = el("div", "thumb");
      thumb.textContent = s.type === "Définition" ? "📖" : "💡";
      const mid = el("div"); mid.style.flex = "1";
      const preview = s.meanings ? (s.meanings[0]?.defs[0] || "") : (s.body || "");
      mid.innerHTML = `<div class="row-title">${esc(s.term || s.query)}</div>` +
        `<div class="row-sub">${esc(preview).slice(0, 120)}</div>` +
        `<div class="tags">${s.type} · ${esc(s.source || "")}</div>`;
      const right = el("div");
      right.style.cssText = "display:flex;flex-direction:column;gap:6px;align-items:flex-end;";
      if (s.url) {
        const open = el("a", "linkbtn", "Ouvrir ↗");
        open.href = s.url; open.target = "_blank";
        right.appendChild(open);
      }
      const del = el("button", "swipe-del", "🗑");
      del.onclick = () => { State.searches = State.searches.filter(x => x.id !== s.id); Store.set("searches", State.searches); render(); };
      right.appendChild(del);
      r.append(thumb, mid, right);
      c.appendChild(r);
      content.appendChild(c);
    });
  }

  // ============================================================
  // FLOATING COMMAND OVERLAY (≈ FloatingCommandView)
  // ============================================================
  const overlayHost = $("#overlayHost");
  const island = $("#island");

  function showOverlay() {
    overlayHost.innerHTML = `<div class="overlay-backdrop"></div><div class="floating"></div>`;
    requestAnimationFrame(() => overlayHost.classList.add("show"));
    haptic();
    $(".overlay-backdrop", overlayHost).onclick = hideOverlay;
    renderChoices(false); // initial : la fenêtre arrive déjà en slide-down
  }

  /** Affiche les 4 touches dans la fenêtre du haut. */
  function renderChoices(smooth = true) {
    const floating = $(".floating", overlayHost);
    if (!floating) return;
    const build = () => {
      floating.className = "floating";
      floating.innerHTML = `
        <button class="cmd-btn rec" data-act="voice"><span class="ci">🎙️</span><span>Note</span></button>
        <button class="cmd-btn" data-act="todo"><span class="ci">✏️</span><span>To-Do</span></button>
        <button class="cmd-btn" data-act="search"><span class="ci">🔍</span><span>Rechercher</span></button>
        <div class="cmd-open-row">
          <button class="cmd-btn wide" data-act="notes"><span class="ci">📓</span><span>Voir les notes</span></button>
          <button class="cmd-btn wide" data-act="todos"><span class="ci">✅</span><span>Voir To-Do</span></button>
        </div>`;
      floating.querySelectorAll(".cmd-btn").forEach(b =>
        b.onclick = () => {
          const act = b.dataset.act;
          if (act === "voice")  return openPanel("Note vocale", voicePanel);
          if (act === "todo")   return openPanel("To-Do", todoPanel);
          if (act === "search") return openPanel("Rechercher", searchPanel);
          if (act === "notes")  { hideOverlay(); setTimeout(showNotesList, 180); }
          if (act === "todos")  { hideOverlay(); setTimeout(showTodosList, 180); }
        });
    };
    if (smooth) smoothSwap(floating, build); else build();
  }

  /** Ouvre une action EN PLACE dans la fenêtre du haut (Note / To-Do / Rechercher).
      Header avec retour + titre, puis contenu rendu par `builder`. */
  function openPanel(title, builder) {
    const floating = $(".floating", overlayHost);
    if (!floating) return;
    haptic();
    smoothSwap(floating, () => {
      floating.className = "floating panel";
      floating.innerHTML = `
        <div class="panel-head">
          <button class="panel-back" id="panelBack" aria-label="Retour">‹</button>
          <div class="panel-title">${title}</div>
        </div>
        <div class="panel-body" id="panelBody"></div>`;
      $("#panelBack", floating).onclick = () => { stopRecording(true); renderChoices(true); };
      builder($("#panelBody", floating));
    });
  }

  /** Anime en douceur le changement de contenu de la fenêtre (hauteur + fondu). */
  function smoothSwap(floating, renderFn) {
    const startH = floating.offsetHeight;
    renderFn();
    const endH = floating.offsetHeight;
    if (!startH) return;                 // 1er rendu : pas d'anim de hauteur
    floating.style.overflow = "hidden";
    floating.style.height = startH + "px";
    void floating.offsetHeight;          // reflow
    floating.style.transition = "height .30s cubic-bezier(.3,1,.4,1)";
    floating.style.height = endH + "px";
    const done = (e) => {
      if (e.propertyName !== "height") return;
      floating.style.transition = "";
      floating.style.height = "";
      floating.style.overflow = "";
      floating.removeEventListener("transitionend", done);
    };
    floating.addEventListener("transitionend", done);
  }

  // ----- To-Do : zone d'écriture dans la fenêtre -----
  function todoPanel(body) {
    body.innerHTML = `
      <textarea class="top-field" id="topTodo" rows="2" placeholder="Nouvelle tâche…"></textarea>
      <button class="btn btn-primary" id="todoAdd" style="margin-top:10px" disabled>Ajouter</button>`;
    const ta = $("#topTodo", body), add = $("#todoAdd", body);
    ta.focus();
    ta.oninput = () => add.disabled = !ta.value.trim();
    ta.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); add.click(); }
    });
    add.onclick = () => {
      if (!ta.value.trim()) return;
      State.todos.unshift({ id: uid(), createdAt: Date.now(), text: ta.value.trim(), done: false, doneAt: null });
      Store.set("todos", State.todos);
      State.tab = "todos"; render();
      hideOverlay(); haptic();
    };
  }

  /** "Voir les notes" : ouvre l'app sur l'onglet Notes. */
  function showNotesList() {
    launchApp();
    State.tab = "notes";
    render();
    haptic();
  }
  /** "Voir To-Do" : ouvre l'app sur l'onglet To-Do. */
  function showTodosList() {
    launchApp();
    State.tab = "todos";
    render();
    haptic();
  }
  function hideOverlay() {
    stopRecording(true);
    overlayHost.classList.remove("show");
    setTimeout(() => overlayHost.innerHTML = "", 350);
  }

  // ----- Voice sheet (≈ VoiceRecorderView + RecorderViewModel) -----
  const MAX_REC_SECONDS = 120; // ~2 min max
  let rec = { recording: false, t0: 0, timer: null, transcript: "", recognition: null,
              mediaRecorder: null, chunks: [], audioCtx: null, analyser: null, raf: null, stream: null,
              container: null };

  function voicePanel(body) {
    rec.container = body;
    body.innerHTML = `
      <div class="rec-status" id="recStatus">Appuie pour enregistrer (max 2 min)</div>
      <div class="waveform" id="wave"></div>
      <button class="record-button" id="recBtn"><span class="inner"></span></button>
      <div id="recResults"></div>`;
    const wave = $("#wave", body);
    for (let i = 0; i < 28; i++) { const b = el("div", "bar"); b.style.height = "10px"; wave.appendChild(b); }
    $("#recBtn", body).onclick = () => rec.recording ? stopRecording() : startRecording(body);
  }

  async function startRecording(body) {
    rec.transcript = ""; rec.chunks = [];
    $("#recResults", body).innerHTML = "";
    rec.recording = true; rec.t0 = Date.now();
    $("#recBtn", body).classList.add("recording");
    island.classList.add("recording");
    haptic();

    // Timer
    rec.timer = setInterval(() => {
      const s = (Date.now() - rec.t0) / 1000;
      const st = $("#recStatus"); if (st) st.innerHTML = `<span class="big">${clock(s)}</span>`;
      if (s >= MAX_REC_SECONDS) stopRecording();
    }, 200);

    // Web Speech transcription (Chrome/Edge)
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (SR) {
      const r = new SR();
      r.lang = "fr-FR"; r.continuous = true; r.interimResults = true;
      r.onresult = (e) => {
        let final = "";
        for (let i = 0; i < e.results.length; i++) final += e.results[i][0].transcript;
        rec.transcript = final;
      };
      r.onerror = () => {};
      try { r.start(); rec.recognition = r; } catch {}
    }

    // Mic + waveform (Web Audio) + recording (MediaRecorder)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      rec.stream = stream;
      rec.mediaRecorder = new MediaRecorder(stream);
      rec.mediaRecorder.ondataavailable = e => rec.chunks.push(e.data);
      rec.mediaRecorder.start();

      rec.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      const src = rec.audioCtx.createMediaStreamSource(stream);
      rec.analyser = rec.audioCtx.createAnalyser();
      rec.analyser.fftSize = 64;
      src.connect(rec.analyser);
      animateWave();
    } catch (e) {
      // No mic permission → still animate a synthetic waveform.
      animateWave(true);
    }
  }

  function animateWave(synthetic = false) {
    const bars = document.querySelectorAll("#wave .bar");
    if (!bars.length) return;
    const data = rec.analyser ? new Uint8Array(rec.analyser.frequencyBinCount) : null;
    const tick = () => {
      if (!rec.recording) return;
      let level = 0.3;
      if (rec.analyser) {
        rec.analyser.getByteFrequencyData(data);
        level = data.reduce((a, b) => a + b, 0) / data.length / 255;
      }
      bars.forEach((b, i) => {
        const wave = Math.abs(Math.sin(Date.now() / 200 + i * 0.5));
        const h = synthetic ? 10 + wave * 50 : 8 + (0.3 + level * 1.4) * wave * 70;
        b.style.height = Math.max(6, h) + "px";
      });
      rec.raf = requestAnimationFrame(tick);
    };
    tick();
  }

  function stopRecording(silent = false) {
    if (!rec.recording) return;
    rec.recording = false;
    clearInterval(rec.timer);
    cancelAnimationFrame(rec.raf);
    island.classList.remove("recording");
    if (rec.recognition) { try { rec.recognition.stop(); } catch {} }
    if (rec.mediaRecorder && rec.mediaRecorder.state !== "inactive") rec.mediaRecorder.stop();
    if (rec.stream) rec.stream.getTracks().forEach(t => t.stop());
    if (rec.audioCtx) { try { rec.audioCtx.close(); } catch {} }
    document.querySelectorAll(".record-button").forEach(b => b.classList.remove("recording"));
    if (silent) return;
    haptic();
    setTimeout(() => processRecording(), 400); // let final speech result arrive
  }

  function processRecording() {
    const body = rec.container;
    if (!body || !document.body.contains(body)) return;
    const st = $("#recStatus"); if (st) st.textContent = "Transcription & résumé…";
    const results = $("#recResults", body);
    results.innerHTML = `<div class="spinner"></div>`;

    setTimeout(() => {
      const transcript = (rec.transcript || "").trim() || "(Aucune parole détectée — Web Speech indisponible ? Essaie Chrome/Edge et autorise le micro.)";
      const summary = summarize(transcript);
      let plan = [];
      if (transcript.toLowerCase().includes(PLAN_KEYWORD)) plan = generatePlan(transcript);

      let audioURL = null;
      if (rec.chunks.length) audioURL = URL.createObjectURL(new Blob(rec.chunks, { type: "audio/webm" }));

      const note = { id: uid(), createdAt: Date.now(), transcript, summary, plan, audioURL,
        title: summary ? summary.slice(0, 40) : "Note vocale" };
      State.notes.unshift(note);
      // Note: object URLs aren't persistable; store text only.
      Store.set("notes", State.notes.map(n => ({ ...n, audioURL: null })));

      if (st) st.textContent = "Terminé ✓";
      results.innerHTML = "";
      results.appendChild(resultBlock("Résumé", summary || "—"));
      results.appendChild(resultBlock("Transcription", transcript));
      if (plan.length) results.appendChild(planBlock(plan));
      else {
        const gen = el("button", "btn btn-ghost", "📋 Générer un plan");
        gen.style.marginTop = "14px";
        gen.onclick = () => {
          note.plan = generatePlan(transcript);
          Store.set("notes", State.notes.map(n => ({ ...n, audioURL: null })));
          gen.replaceWith(planBlock(note.plan));
        };
        results.appendChild(gen);
      }
      const done = el("button", "btn btn-primary", "✓ Sauver & fermer");
      done.style.marginTop = "14px";
      done.onclick = () => { State.tab = "notes"; render(); hideOverlay(); };
      results.appendChild(done);
      haptic();
    }, 700);
  }
  function resultBlock(label, val) {
    const d = el("div", "card result-block");
    d.innerHTML = `<div class="lbl">${label}</div><div class="val">${esc(val)}</div>`;
    return d;
  }
  function planBlock(steps) {
    const d = el("div", "card result-block");
    d.appendChild(el("div", "lbl", "📋 Plan"));
    steps.forEach((s, i) => {
      const row = el("div", "plan-step");
      row.innerHTML = `<span class="plan-num">${i + 1}</span><span class="val">${esc(s)}</span>`;
      d.appendChild(row);
    });
    return d;
  }

  // ----- Recherche : mot → définition / explication (dans la fenêtre) -----
  function searchPanel(body) {
    body.innerHTML = `
      <div style="display:flex;gap:8px">
        <input class="field" id="searchInput" placeholder="Un mot, une définition, une explication…" style="flex:1" autocomplete="off">
        <button class="btn btn-primary" id="searchBtn" style="width:auto;padding:0 20px">🔍</button>
      </div>
      <div id="searchResult"></div>`;

    const input = $("#searchInput", body), btn = $("#searchBtn", body), out = $("#searchResult", body);
    input.focus();

    const run = async () => {
      const q = input.value.trim();
      if (!q) return;
      out.innerHTML = `<div class="spinner"></div>`;
      btn.disabled = true;
      const res = await lookup(q);
      btn.disabled = false;
      if (!res) {
        out.innerHTML = `<div class="card" style="margin-top:16px"><div class="row-title">Aucun résultat</div>
          <div class="row-sub">Rien trouvé pour « ${esc(q)} ». Essaie un autre mot ou une orthographe différente.</div></div>`;
        Haptics_warn();
        return;
      }
      renderSearchResult(out, res);
      // Historise dans l'onglet Recherches
      State.searches.unshift({ id: uid(), createdAt: Date.now(), query: q, ...res });
      Store.set("searches", State.searches);
      haptic();
    };

    btn.onclick = run;
    input.addEventListener("keydown", e => { if (e.key === "Enter") run(); });
  }

  function renderSearchResult(out, res) {
    const d = el("div", "search-result card");
    let html = `<div class="sr-type">${res.type}</div><div class="sr-term">${esc(res.term)}</div>`;
    if (res.meanings) {
      res.meanings.forEach(m => {
        if (m.pos) html += `<div class="sr-pos">${esc(m.pos)}</div>`;
        m.defs.forEach((def, i) => html += `<div class="sr-def">${i + 1}. ${esc(def)}</div>`);
      });
    } else if (res.body) {
      html += `<div class="sr-def" style="margin-top:10px">${esc(res.body)}</div>`;
    }
    if (res.source) {
      html += `<div class="sr-source">Source : ${res.url ? `<a href="${res.url}" target="_blank">${res.source} ↗</a>` : esc(res.source)}</div>`;
    }
    d.innerHTML = html;
    out.innerHTML = "";
    out.appendChild(d);
  }

  /** Cherche une définition (dictionnaire FR) puis une explication (Wikipédia FR). */
  async function lookup(query) {
    // 1) Dictionnaire français — idéal pour un mot unique
    try {
      const r = await fetch("https://api.dictionaryapi.dev/api/v2/entries/fr/" + encodeURIComponent(query));
      if (r.ok) {
        const data = await r.json();
        if (Array.isArray(data) && data[0] && data[0].meanings) {
          const meanings = data[0].meanings.slice(0, 3).map(m => ({
            pos: m.partOfSpeech || "",
            defs: (m.definitions || []).slice(0, 3).map(d => d.definition).filter(Boolean)
          })).filter(m => m.defs.length);
          if (meanings.length) {
            return { term: data[0].word || query, type: "Définition", meanings,
                     source: "Wiktionnaire / dictionaryapi.dev" };
          }
        }
      }
    } catch {}

    // 2) Wikipédia FR — explication pour un terme, une personne, un concept…
    try {
      const r = await fetch("https://fr.wikipedia.org/api/rest_v1/page/summary/" + encodeURIComponent(query),
        { headers: { Accept: "application/json" } });
      if (r.ok) {
        const d = await r.json();
        if (d.extract && d.type !== "disambiguation") {
          return { term: d.title || query, type: "Explication", body: d.extract,
                   source: "Wikipédia", url: d.content_urls && d.content_urls.desktop && d.content_urls.desktop.page };
        }
      }
    } catch {}

    return null;
  }

  function Haptics_warn() { if (navigator.vibrate) navigator.vibrate([10, 40, 10]); }

  // ---------- Haptics (vibration where supported) ----------
  function haptic() { if (navigator.vibrate) navigator.vibrate(8); }

  // ============================================================
  // SCENE: home screen <-> app (≈ launching the app to foreground)
  // ============================================================
  const screen = $("#screen");

  function launchApp() {
    if (State.scene === "app") return;
    State.scene = "app";
    screen.classList.add("scene-app");
    render();
  }
  function goHome() {
    hideOverlay();
    State.scene = "home";
    screen.classList.remove("scene-app");
  }

  /** Tap Back from ANYWHERE: shows ONLY the floating command window on top
      of the CURRENT page (home screen or app). It does NOT open the app. */
  function tapBack() {
    showOverlay();
  }

  // ============================================================
  // WIRING
  // ============================================================
  document.querySelectorAll(".tab").forEach(t =>
    t.onclick = () => { State.tab = t.dataset.tab; render(); });

  $("#tapbackBtn").onclick = tapBack;

  // Launch the app by tapping its home-screen / dock icon
  $("#iconTapBack").onclick = () => { launchApp(); haptic(); };
  $("#dockTapBack").onclick = () => { launchApp(); haptic(); };

  // Return to home screen
  $("#homeIndicator").onclick = goHome;

  // Double-click the phone frame (= tapping the back of the device) → Tap Back
  $("#phone").addEventListener("dblclick", tapBack);

  // Keyboard: T = Tap Back, H = home, Esc = ferme la fenêtre
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") { hideOverlay(); return; }
    const typing = /input|textarea/i.test(document.activeElement.tagName);
    if (typing) return;
    const k = e.key.toLowerCase();
    if (k === "t") tapBack();
    if (k === "h") goHome();
  });

  // Live clock (status bar + home screen)
  function tickClock() {
    const now = new Date();
    const hm = now.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
    $("#clock").textContent = hm;
    const sbTime = $("#sbTime"), sbDate = $("#sbDate");
    if (sbTime) sbTime.textContent = hm;
    if (sbDate) sbDate.textContent = now.toLocaleDateString("fr-FR", { weekday: "long", day: "numeric", month: "long" });
  }
  tickClock(); setInterval(tickClock, 30000);

  render();
})();
