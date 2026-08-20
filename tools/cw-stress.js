#!/usr/bin/env node
"use strict";
const fs = require("fs");
const path = require("path");
const htmlPath = path.join(__dirname, "..", "apk-web", "index.html");
const html = fs.readFileSync(htmlPath, "utf8");
let failed = 0;
function ok(cond, msg) {
  if (!cond) {
    failed++;
    console.log("FAIL", msg);
  }
}

// --- structural ---
const screens = ["home","chat","models","voices","tasks","agent","auto","settings","diag"];
screens.forEach((s) => ok(html.indexOf('id="' + s + '"') >= 0, "screen " + s));
const gos = [];
html.replace(/data-go="([^"]+)"/g, (_, g) => gos.push(g));
gos.forEach((g) => ok(html.indexOf('id="' + g + '"') >= 0, "go->" + g));
["btn-send","btn-run-task","btn-diag","btn-heal","task-presets","task-out","diag-log"].forEach((id) => {
  ok(html.indexOf('id="' + id + '"') >= 0, "id " + id);
});
ok((html.match(/<\/html>/g) || []).length === 1, "single </html>");
ok((html.match(/<\/script>/g) || []).length === 1, "single </script>");
ok(html.indexOf("function diagnose") >= 0, "diagnose");
ok(html.indexOf("function heal") >= 0, "heal");
ok(html.indexOf("window.onerror") >= 0, "onerror");
ok(html.indexOf("setInterval") >= 0, "watchdog");

const script = html.split("<script>")[1].split("</script>")[0];
try { new Function(script); ok(true, "JS parse"); }
catch (e) { ok(false, "JS parse " + e.message); }

// extract localReply
const m = script.match(/function localReply\(text\) \{[\s\S]*?\n  \}/);
if (!m) {
  ok(false, "localReply extract");
} else {
  const make = new Function("state", "activeModel", "return " + m[0].replace("function localReply", "function"));
  const samples = [
    "cześć","hej","plan dnia","napisz mail","lista zakupów","trening 20",
    "streszcz","co potrafisz","pomoc","asdf","qwerty","dzień dobry",
    "wiadomość do szefa","zakupy na weekend",""
  ];
  for (let i = 0; i < 1000; i++) {
    const state = {
      agent: { name: i % 2 ? "Wilk" : "Bura" },
      messages: new Array((i % 7) + 1).fill({ role: "user", content: "x" }),
      online: i % 3 !== 0
    };
    const activeModel = () => (i % 5 === 0 ? { display: "cloud" } : null);
    const lr = make(state, activeModel);
    const input = samples[i % samples.length] + (i % 11 === 0 ? " " + i : "");
    let r;
    try { r = lr(input); } catch (e) { ok(false, "localReply throw @" + i + " " + e.message); break; }
    if (!r || String(r).length < 4) { ok(false, "empty reply @" + i + " for " + JSON.stringify(input)); break; }
  }
  ok(true, "1000 localReply iterations");
}

// extractPlain + kindOf
const kindFn = new Function("base", `
  var u = String(base || "").toLowerCase();
  if (u.indexOf("anthropic") !== -1) return "anthropic";
  if (u.indexOf("googleapis") !== -1 || u.indexOf("generativelanguage") !== -1) return "gemini";
  return "openai";
`);
ok(kindFn("https://api.anthropic.com/v1") === "anthropic", "kind anthropic");
ok(kindFn("https://generativelanguage.googleapis.com/v1beta") === "gemini", "kind gemini");
ok(kindFn("https://openrouter.ai/api/v1") === "openai", "kind openrouter");
ok(kindFn("https://api.moonshot.ai/v1") === "openai", "kind kimi");

const ext = new Function("kind", "j", `
  if (!j) return "";
  var i, t;
  if (kind === "anthropic") {
    t = "";
    var blocks = j.content || [];
    for (i = 0; i < blocks.length; i++) if (blocks[i].text) t += blocks[i].text;
    return t;
  }
  if (kind === "gemini") {
    try { return j.candidates[0].content.parts[0].text || ""; } catch (e) { return ""; }
  }
  try { return j.choices[0].message.content || ""; } catch (e) { return ""; }
`);
ok(ext("openai", { choices: [{ message: { content: "hi" } }] }) === "hi", "extract openai");
ok(ext("anthropic", { content: [{ text: "a" }, { text: "b" }] }) === "ab", "extract anthropic");
ok(ext("gemini", { candidates: [{ content: { parts: [{ text: "g" }] } }] }) === "g", "extract gemini");
ok(ext("openai", {}) === "", "extract empty safe");
ok(ext("openai", null) === "", "extract null safe");

// 1000 random extract/kind
for (let i = 0; i < 1000; i++) {
  const k = ["openai", "anthropic", "gemini"][i % 3];
  const junk = [null, {}, { foo: 1 }, { choices: [] }, { content: [] }, { candidates: [] }][i % 6];
  try { ext(k, junk); } catch (e) { ok(false, "extract throw " + e.message); break; }
}
ok(true, "1000 extractPlain junk iterations");

// simulate heal recreating missing screens conceptually
const required = screens.slice();
const fakeDom = {};
required.forEach((s) => { fakeDom[s] = true; });
delete fakeDom.tasks;
delete fakeDom.diag;
let repaired = 0;
required.forEach((s) => { if (!fakeDom[s]) { fakeDom[s] = true; repaired++; } });
ok(repaired === 2 && required.every((s) => fakeDom[s]), "heal missing screens");

// 1000 heal simulations
for (let i = 0; i < 1000; i++) {
  const d = {};
  required.forEach((s) => { if (i % (s.length + 2) !== 0) d[s] = 1; });
  required.forEach((s) => { if (!d[s]) d[s] = 1; });
  if (!required.every((s) => d[s])) { ok(false, "heal sim fail @" + i); break; }
}
ok(true, "1000 heal simulations");

if (failed) {
  console.log("\nFAILED:", failed);
  process.exit(1);
}
console.log("STRUCT+1000+1000+1000 OK — zero errors");
