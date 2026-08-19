(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];

  const KEY = "cw.v1";
  const defaults = {
    online: true,
    models: [],
    activeId: null,
    agent: {
      name: "Wilk",
      role: "Wierny asystent właściciela urządzenia",
      system:
        "Jesteś prywatnym asystentem AI w aplikacji Czarne Wilki. Odpowiadasz rzeczowo, po polsku, w tonie godnym i konkretnym. Rozmowa odbywa się na urządzeniu użytkownika.",
      temperature: 0.7,
    },
    voice: { name: null, rate: 1, pitch: 1 },
    messages: [],
  };

  const state = load();
  let busy = false;
  let recognition = null;
  let micOn = false;

  function load() {
    try {
      return { ...defaults, ...JSON.parse(localStorage.getItem(KEY) || "{}") };
    } catch {
      return structuredClone(defaults);
    }
  }
  function save() {
    localStorage.setItem(KEY, JSON.stringify(state));
    paintHome();
  }

  function go(id) {
    $$(".screen").forEach((s) => s.classList.toggle("active", s.id === id));
    if (id === "voices") renderVoices();
    if (id === "models") renderModels();
    if (id === "agent") fillAgent();
    if (id === "chat") renderChat();
  }

  function activeModel() {
    return state.models.find((m) => m.id === state.activeId) || null;
  }

  function paintHome() {
    const m = activeModel();
    const net = $("#chip-net");
    net.textContent = state.online ? "SIECIOWY" : "OFFLINE";
    net.className = "chip " + (state.online ? "on" : "off");
    $("#chip-model").textContent = m ? m.display : "BRAK MODELU";
    $("#chat-model").textContent = m ? m.display : "wybierz model";
    $("#net-toggle").checked = state.online;
    $("#net-toggle-2").checked = state.online;
    $("#net-hint").textContent = state.online
      ? "Dozwolone połączenia: chmura."
      : "OFFLINE — zero połączeń.";
  }

  function setOnline(v) {
    state.online = v;
    save();
  }

  function showErr(msg) {
    const box = $("#chat-err");
    box.hidden = !msg;
    if (msg) box.querySelector("span").textContent = msg;
  }

  function renderChat() {
    const log = $("#chat-log");
    log.innerHTML = "";
    for (const m of state.messages) {
      const el = document.createElement("div");
      el.className = "bubble " + (m.role === "user" ? "user" : "ai");
      if (m.image) {
        const img = document.createElement("img");
        img.className = "gen";
        img.src = m.image;
        el.appendChild(img);
      }
      if (m.content) el.appendChild(document.createTextNode(m.content));
      if (m.model) {
        const meta = document.createElement("span");
        meta.className = "meta";
        meta.textContent = m.model;
        el.appendChild(meta);
      }
      log.appendChild(el);
    }
    log.scrollTop = log.scrollHeight;
  }

  function effectiveSystem() {
    const a = state.agent;
    return [
      a.name ? `Nazywasz się ${a.name}.` : "",
      a.role ? `Twoja rola: ${a.role}.` : "",
      a.system || "",
    ]
      .filter(Boolean)
      .join(" ");
  }

  async function send(text) {
    const model = activeModel();
    if (!model) {
      showErr(
        state.online
          ? "Brak aktywnego modelu — wybierz model w ekranie Modeli."
          : "Tryb Offline bez modelu lokalnego. Włącz tryb Sieciowy i dodaj model chmurowy."
      );
      return;
    }
    if (!state.online) {
      showErr("Tryb Offline = zero połączeń. Włącz tryb Sieciowy, aby użyć chmury.");
      return;
    }
    showErr("");
    state.messages.push({ role: "user", content: text });
    save();
    renderChat();
    busy = true;
    $("#chat-busy").hidden = false;

    const turns = state.messages
      .filter((m) => m.content && (m.role === "user" || m.role === "assistant"))
      .map((m) => ({ role: m.role, content: m.content }));

    const bubble = document.createElement("div");
    bubble.className = "bubble ai";
    $("#chat-log").appendChild(bubble);

    let acc = "";
    try {
      const url = model.base.replace(/\/+$/, "") + "/chat/completions";
      const headers = {
        "Content-Type": "application/json",
        Authorization: "Bearer " + model.key,
      };
      if ((model.base || "").includes("openrouter")) {
        headers["HTTP-Referer"] = "https://czarne-wilki.local";
        headers["X-Title"] = "Czarne Wilki";
      }
      const res = await fetch(url, {
        method: "POST",
        headers,
        body: JSON.stringify({
          model: model.modelId,
          stream: true,
          temperature: state.agent.temperature,
          max_tokens: 2048,
          messages: [{ role: "system", content: effectiveSystem() }, ...turns],
        }),
      });
      if (!res.ok) {
        const t = await res.text();
        throw new Error("HTTP " + res.status + " " + t.slice(0, 220));
      }
      const reader = res.body.getReader();
      const dec = new TextDecoder();
      let buf = "";
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += dec.decode(value, { stream: true });
        const lines = buf.split("\n");
        buf = lines.pop() || "";
        for (const line of lines) {
          const s = line.trim();
          if (!s.startsWith("data:")) continue;
          const payload = s.slice(5).trim();
          if (payload === "[DONE]") continue;
          try {
            const json = JSON.parse(payload);
            const piece = json.choices?.[0]?.delta?.content;
            if (piece) {
              acc += piece;
              bubble.textContent = acc + " ▍";
              $("#chat-log").scrollTop = $("#chat-log").scrollHeight;
            }
          } catch {
            /* keep-alive */
          }
        }
      }
      bubble.textContent = acc;
      state.messages.push({
        role: "assistant",
        content: acc,
        model: model.display,
      });
      save();
    } catch (e) {
      showErr(
        "Błąd silnika: " +
          e.message +
          " — sprawdź klucz API, Base URL i tryb Sieciowy."
      );
      bubble.remove();
    } finally {
      busy = false;
      $("#chat-busy").hidden = true;
      renderChat();
    }
  }

  async function generateImage(prompt) {
    if (!state.online) {
      showErr("Generowanie obrazów wymaga trybu Sieciowego.");
      return;
    }
    busy = true;
    $("#chat-busy").hidden = false;
    try {
      const url =
        "https://image.pollinations.ai/prompt/" +
        encodeURIComponent(prompt) +
        "?width=1024&height=1024&nologo=true&seed=" +
        (Date.now() % 100000);
      const res = await fetch(url);
      if (!res.ok) throw new Error("HTTP " + res.status);
      const blob = await res.blob();
      const data = await blobToData(blob);
      state.messages.push({ role: "user", content: prompt });
      state.messages.push({
        role: "assistant",
        content: "Wygenerowano obraz.",
        image: data,
      });
      save();
      renderChat();
    } catch (e) {
      showErr("Nie udało się wygenerować obrazu: " + e.message);
    } finally {
      busy = false;
      $("#chat-busy").hidden = true;
    }
  }

  function blobToData(blob) {
    return new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(r.result);
      r.onerror = reject;
      r.readAsDataURL(blob);
    });
  }

  function renderModels() {
    const box = $("#model-list");
    box.innerHTML = "";
    for (const m of state.models) {
      const el = document.createElement("div");
      el.className = "list-item" + (m.id === state.activeId ? " active" : "");
      el.innerHTML = `<div class="grow"><h3>${esc(m.display)}</h3><p>${esc(m.modelId)}</p></div><span>✕</span>`;
      el.querySelector(".grow").onclick = () => {
        state.activeId = m.id;
        save();
        renderModels();
      };
      el.querySelector("span").onclick = (ev) => {
        ev.stopPropagation();
        state.models = state.models.filter((x) => x.id !== m.id);
        if (state.activeId === m.id) state.activeId = state.models[0]?.id || null;
        save();
        renderModels();
      };
      box.appendChild(el);
    }
  }

  function esc(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function fillAgent() {
    $("#ag-name").value = state.agent.name;
    $("#ag-role").value = state.agent.role;
    $("#ag-sys").value = state.agent.system;
    $("#ag-temp").value = state.agent.temperature;
    $("#temp-val").textContent = Number(state.agent.temperature).toFixed(2);
  }

  function renderVoices() {
    const voices = speechSynthesis.getVoices();
    const pl = voices.filter((v) => (v.lang || "").toLowerCase().startsWith("pl"));
    const rest = voices.filter((v) => !(v.lang || "").toLowerCase().startsWith("pl"));
    const ordered = [...pl, ...rest];
    const box = $("#voice-list");
    box.innerHTML = "";
    if (!ordered.length) {
      box.innerHTML =
        '<div class="card"><p class="muted">Brak głosów TTS na tym urządzeniu (silnik systemowy).</p></div>';
      return;
    }
    for (const v of ordered) {
      const el = document.createElement("div");
      el.className =
        "list-item" + (state.voice.name === v.name ? " active" : "");
      el.innerHTML = `<div class="grow"><h3>${esc(v.name)}</h3><p>${esc(v.lang)}${pl.includes(v) ? " · polski" : ""}</p></div><span>▶</span>`;
      el.querySelector(".grow").onclick = () => {
        state.voice.name = v.name;
        save();
        renderVoices();
      };
      el.querySelector("span").onclick = (ev) => {
        ev.stopPropagation();
        speak("Czarne Wilki. To jest próbka głosu " + v.name, v);
      };
      box.appendChild(el);
    }
  }

  function speak(text, voiceObj) {
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.rate = state.voice.rate;
    u.pitch = state.voice.pitch;
    const voices = speechSynthesis.getVoices();
    const pick =
      voiceObj ||
      voices.find((v) => v.name === state.voice.name) ||
      voices.find((v) => (v.lang || "").startsWith("pl"));
    if (pick) u.voice = pick;
    speechSynthesis.speak(u);
  }

  function toggleMic() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) {
      showErr("Rozpoznawanie mowy niedostępne na tym urządzeniu.");
      return;
    }
    if (micOn) {
      micOn = false;
      recognition && recognition.stop();
      $("#btn-mic").classList.remove("live");
      return;
    }
    recognition = new SR();
    recognition.lang = "pl-PL";
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.onresult = (ev) => {
      let t = "";
      for (const r of ev.results) t += r[0].transcript;
      $("#chat-input").value = t;
    };
    recognition.onend = () => {
      if (micOn) recognition.start();
    };
    recognition.start();
    micOn = true;
    $("#btn-mic").classList.add("live");
  }

  function exportBackup() {
    const blob = new Blob(
      [
        JSON.stringify(
          {
            format: "czarne-wilki-backup",
            version: 1,
            created_at: Date.now(),
            agent: state.agent,
            models: state.models.map((m) => ({ ...m, key: undefined })),
            messages: state.messages,
          },
          null,
          2
        ),
      ],
      { type: "application/json" }
    );
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "czarne_wilki_backup.json";
    a.click();
  }

  function importBackup(file) {
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const data = JSON.parse(reader.result);
        if (data.format !== "czarne-wilki-backup") throw new Error("zły format");
        if (data.agent) state.agent = { ...state.agent, ...data.agent };
        if (Array.isArray(data.messages)) state.messages = data.messages;
        save();
        alert("Zaimportowano kopię.");
      } catch (e) {
        alert("Nie udało się odczytać pliku: " + e.message);
      }
    };
    reader.readAsText(file);
  }

  // events
  $$("[data-go]").forEach((el) =>
    el.addEventListener("click", () => go(el.dataset.go))
  );
  $("#net-toggle").onchange = (e) => setOnline(e.target.checked);
  $("#net-toggle-2").onchange = (e) => setOnline(e.target.checked);

  $("#btn-send").onclick = () => {
    const t = $("#chat-input").value.trim();
    if (!t || busy) return;
    $("#chat-input").value = "";
    send(t);
  };
  $("#chat-input").addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      $("#btn-send").click();
    }
  });
  $("#btn-new").onclick = () => {
    state.messages = [];
    save();
    renderChat();
    showErr("");
  };
  $("#chat-err button").onclick = () => showErr("");
  $("#btn-mic").onclick = toggleMic;
  $("#btn-plus").onclick = () => {
    const p = prompt("Opisz obraz do wygenerowania (Pollinations):");
    if (p && p.trim()) generateImage(p.trim());
  };

  $$(".preset").forEach((b) => {
    b.onclick = () => {
      $("#m-base").value = b.dataset.base;
      $("#m-id").value = b.dataset.model;
    };
  });
  $("#btn-save-model").onclick = () => {
    const base = $("#m-base").value.trim();
    const key = $("#m-key").value.trim();
    const modelId = $("#m-id").value.trim();
    if (!base || !key || !modelId) {
      alert("Uzupełnij Base URL, klucz API i nazwę modelu.");
      return;
    }
    const entry = {
      id: "m" + Date.now(),
      display: modelId.split("/").pop(),
      base,
      key,
      modelId,
    };
    state.models.push(entry);
    state.activeId = entry.id;
    save();
    renderModels();
    alert("Model chmurowy aktywny.");
  };

  $("#btn-save-agent").onclick = () => {
    state.agent.name = $("#ag-name").value;
    state.agent.role = $("#ag-role").value;
    state.agent.system = $("#ag-sys").value;
    state.agent.temperature = Number($("#ag-temp").value);
    save();
    alert("Zapisano profil agenta.");
  };
  $("#ag-temp").oninput = (e) =>
    ($("#temp-val").textContent = Number(e.target.value).toFixed(2));
  $("#tts-rate").oninput = (e) => {
    state.voice.rate = Number(e.target.value);
    $("#rate-val").textContent = state.voice.rate.toFixed(2);
    save();
  };
  $("#tts-pitch").oninput = (e) => {
    state.voice.pitch = Number(e.target.value);
    $("#pitch-val").textContent = state.voice.pitch.toFixed(2);
    save();
  };

  $("#btn-export").onclick = exportBackup;
  $("#btn-import").onclick = () => $("#import-file").click();
  $("#import-file").onchange = (e) => {
    const f = e.target.files?.[0];
    if (f) importBackup(f);
  };

  speechSynthesis.onvoiceschanged = () => {
    if ($("#voices").classList.contains("active")) renderVoices();
  };

  $("#tts-rate").value = state.voice.rate;
  $("#tts-pitch").value = state.voice.pitch;
  $("#rate-val").textContent = Number(state.voice.rate).toFixed(2);
  $("#pitch-val").textContent = Number(state.voice.pitch).toFixed(2);
  paintHome();
})();
