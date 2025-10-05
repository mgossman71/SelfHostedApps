#!/bin/sh
set -eu

APP_DIR="${1:-wopr}"
IMAGE_NAME="${2:-wopr}"

# Create dirs
mkdir -p "$APP_DIR/src"
cd "$APP_DIR"

############################################
# package.json (includes type packages)
############################################
cat > package.json <<'EOF'
{
  "name": "wopr-norad",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -p tsconfig.json && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "framer-motion": "^11.0.0",
    "d3-geo": "^3.1.0",
    "topojson-client": "^3.1.0",
    "world-atlas": "^2.0.2"
  },
  "devDependencies": {
    "vite": "^5.1.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/d3-geo": "^3.0.3",
    "@types/topojson-client": "^3.1.5",
    "typescript": "^5.3.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.35",
    "autoprefixer": "^10.4.17"
  }
}
EOF

############################################
# tsconfig.json
############################################
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "jsx": "react-jsx",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "isolatedModules": true,
    "baseUrl": "."
  },
  "include": ["src"]
}
EOF

############################################
# index.html
############################################
cat > index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>WOPR NORAD Finale</title>
  </head>
  <body class="bg-black">
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

############################################
# Tailwind / PostCSS / CSS
############################################
cat > tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: []
};
EOF

cat > postcss.config.js <<'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {}
  }
};
EOF

cat > src/index.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

html, body, #root { height: 100%; }
EOF

############################################
# src/main.tsx
############################################
cat > src/main.tsx <<'EOF'
import React from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import WOPR from "./index";

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <WOPR />
  </React.StrictMode>
);
EOF

############################################
# src/index.tsx  (full, fixed app)
############################################
cat > src/index.tsx <<'EOF'
import React, { useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { geoEquirectangular, geoPath, geoInterpolate } from "d3-geo";
import { feature, mesh } from "topojson-client";
import land110m from "world-atlas/land-110m.json";

type Vec2 = [number, number];

const LED_ROWS = 14;
const LED_COLS = 40;

function randomChoice<T>(arr: T[]): T { return arr[(Math.random() * arr.length) | 0]; }
function clamp(n: number, a: number, b: number) { return Math.max(a, Math.min(b, n)); }
function easeOutCubic(t: number) { return 1 - Math.pow(1 - t, 3); }
function sleep(ms: number) { return new Promise(res => setTimeout(res, ms)); }

function Glare() {
  return (
    <div className="pointer-events-none absolute inset-0 mix-blend-screen opacity-70">
      <div className="absolute inset-0"
        style={{
          background:
            "radial-gradient(1200px 400px at 50% -10%, rgba(255,255,255,0.07), transparent 60%), linear-gradient(transparent 97%, rgba(255,255,255,0.08) 100%)",
          maskImage: "linear-gradient(to bottom, black 40%, transparent 100%)",
        }}
      />
      <div className="absolute inset-0 opacity-15"
        style={{
          backgroundSize: "100% 3px",
          backgroundImage: "linear-gradient(to bottom, rgba(255,255,255,0.1) 1px, transparent 1px)",
        }}
      />
    </div>
  );
}

function HeaderBar({ war }: { war: boolean }) {
  return (
    <div className="flex items-center justify-between px-4 py-3 bg-neutral-900/80 backdrop-blur rounded-xl border border-neutral-800">
      <div className="flex items-center gap-3">
        <div className="text-neutral-200 tracking-widest font-semibold">WOPR</div>
        <div className="text-[10px] text-neutral-400 uppercase tracking-[0.35em] hidden sm:block">
          War Operation Plan Response
        </div>
      </div>
      <div className="flex items-center gap-2">
        {Array.from({ length: 10 }).map((_, i) => (
          <motion.div
            key={i}
            className="h-2 w-5 rounded-sm bg-neutral-700"
            animate={{ opacity: war ? [0.4, 1, 0.6, 1] : [0.3, 0.6, 0.3] }}
            transition={{ repeat: Infinity, repeatType: "mirror", duration: 2, delay: i * 0.12 }}
          />
        ))}
      </div>
    </div>
  );
}

function StatusLamp({ label, on, color }: { label: string; on?: boolean; color: string }) {
  return (
    <div className="flex items-center gap-2">
      <motion.div
        className="h-3 w-3 rounded-full"
        style={{ background: on ? color : "#222" }}
        animate={{
          opacity: on ? [0.5, 1, 0.6, 1] : 0.25,
          boxShadow: on ? `0 0 10px ${color}` : "none",
        }}
        transition={{ repeat: on ? Infinity : 0, duration: 2, ease: "easeInOut" }}
      />
      <div className="text-[10px] text-neutral-400 tracking-widest">{label}</div>
    </div>
  );
}

function CanvasLEDWall({ rows, cols, intensity, warMode }:
  { rows: number; cols: number; intensity: number; warMode: boolean; }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const stateRef = useRef<{ b: Float32Array; colorIndex: Uint8Array; w: number; h: number }>({
    b: new Float32Array(rows * cols),
    colorIndex: new Uint8Array(rows * cols),
    w: 0, h: 0
  });

  useEffect(() => {
    const total = rows * cols;
    const st = stateRef.current;
    st.b = new Float32Array(total);
    st.colorIndex = new Uint8Array(total);
    for (let i = 0; i < total; i++) {
      st.b[i] = Math.random();
      st.colorIndex[i] = (Math.random() * 6) | 0;
    }
  }, [rows, cols]);

  useEffect(() => {
    const canvas = canvasRef.current!;
    const ctx = canvas.getContext("2d", { alpha: true })!;
    let mounted = true;

    function resize() {
      const dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
      const rect = canvas.getBoundingClientRect();
      const w = Math.max(300, rect.width);
      const h = Math.max(160, rect.height);
      canvas.width = Math.floor(w * dpr);
      canvas.height = Math.floor(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      stateRef.current.w = w; stateRef.current.h = h;
    }
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    let last = 0; const target = 1000 / 30;
    function loop(ts: number) {
      if (!mounted) return;
      rafRef.current = requestAnimationFrame(loop);
      if (ts - last < target) return; last = ts;

      const st = stateRef.current;
      const w = st.w || canvas.clientWidth;
      const h = st.h || canvas.clientHeight;
      const cw = cols, ch = rows;
      const cellW = w / cw, cellH = h / ch;
      const changes = Math.max(1, Math.floor(cw * ch * (0.03 + intensity * (warMode ? 0.12 : 0.06))));
      for (let i = 0; i < changes; i++) {
        const idx = (Math.random() * cw * ch) | 0;
        if (Math.random() < 0.06) st.colorIndex[idx] = (st.colorIndex[idx] + 1 + ((Math.random() * 5) | 0)) % 6;
        st.b[idx] = Math.random();
      }
      for (let i = 0, n = cw * ch; i < n; i++) st.b[i] = st.b[i] * 0.985 + 0.01;

      ctx.clearRect(0, 0, w, h);
      for (let y = 0; y < ch; y++) {
        for (let x = 0; x < cw; x++) {
          const i = y * cw + x;
          const c = [
            [255, 69, 58],
            [255, 214, 10],
            [48, 209, 88],
            [100, 210, 255],
            [10, 132, 255],
            [255, 255, 255],
          ][st.colorIndex[i]];
          const alpha = 0.18 + st.b[i] * 0.82;
          ctx.fillStyle = `rgba(${c[0]},${c[1]},${c[2]},${alpha})`;
          const pad = 2;
          ctx.fillRect(x * cellW + pad, y * cellH + pad, Math.max(1, cellW - pad * 2), Math.max(1, cellH - pad * 2));
        }
      }
    }
    rafRef.current = requestAnimationFrame(loop);
    return () => { mounted = false; if (rafRef.current) cancelAnimationFrame(rafRef.current); ro.disconnect(); };
  }, [rows, cols, intensity, warMode]);

  return <canvas ref={canvasRef} className="block w-full h-[300px] sm:h-[360px] md:h-[420px] rounded-2xl bg-neutral-950" />;
}

function ControlPanel({
  speedLabel, setSpeedLabel, intensity, setIntensity, warMode, setWarMode
}: {
  speedLabel: "Slow" | "Medium" | "Fast";
  setSpeedLabel: (v: "Slow" | "Medium" | "Fast") => void;
  intensity: number; setIntensity: (n: number) => void;
  warMode: boolean; setWarMode: React.Dispatch<React.SetStateAction<boolean>>;
}) {
  const speeds: ("Slow" | "Medium" | "Fast")[] = ["Slow", "Medium", "Fast"];
  return (
    <div className="rounded-2xl border border-neutral-800 bg-neutral-950 p-4 sm:p-5">
      <div className="text-sm font-semibold tracking-wide text-neutral-200">Controls</div>
      <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <div className="text-[11px] uppercase tracking-widest text-neutral-400 mb-2">Blink Speed</div>
          <div className="flex gap-2 flex-wrap">
            {speeds.map((label) => (
              <button
                key={label}
                onClick={() => setSpeedLabel(label)}
                className={
                  "px-3 py-1.5 rounded-lg border text-xs tracking-widest " +
                  (speedLabel === label
                    ? "bg-neutral-800 border-neutral-700 text-neutral-100"
                    : "bg-neutral-900 border-neutral-800 text-neutral-400 hover:border-neutral-700")
                }
              >
                {label}
              </button>
            ))}
          </div>
        </div>
        <div>
          <div className="text-[11px] uppercase tracking-widest text-neutral-400 mb-2">Intensity</div>
          <input
            type="range" min={0.04} max={0.5} step={0.01}
            value={intensity} onChange={(e) => setIntensity(parseFloat(e.target.value))}
            className="w-full"
          />
        </div>
      </div>
      <div className="mt-4 flex items-center justify-between gap-3">
        <div className="text-[11px] uppercase tracking-widest text-neutral-400">Scenario</div>
        <button
          onClick={() => setWarMode((v) => !v)}
          className={
            "px-3 py-1.5 rounded-lg border text-xs tracking-widest " +
            (warMode
              ? "bg-red-900/30 border-red-700/50 text-red-300"
              : "bg-neutral-900 border-neutral-800 text-neutral-300 hover:border-neutral-700")
          }
        >
          {warMode ? "GLOBAL THERMONUCLEAR WAR" : "IDLE"}
        </button>
      </div>
    </div>
  );
}

function Terminal({ onWarMode, onFinale }: { onWarMode: () => void; onFinale: () => void }) {
  const [history, setHistory] = useState<string[]>([]);
  const [line, setLine] = useState("");
  const [bootDone, setBootDone] = useState(false);
  const [scenarioRunning, setScenarioRunning] = useState(false);
  const endRef = useRef<HTMLDivElement | null>(null);
  const cancelRef = useRef(false);

  const bootLines = useMemo(() => [
    "WS GAMES V2.1 (C) 1983 – N. NORAD",
    "TERMINAL READY",
    "> GREETINGS PROFESSOR FALKEN",
    "WOPR: HELLO.",
    "WOPR: SHALL WE PLAY A GAME?",
    "> LIST GAMES",
    "GLOBAL THERMONUCLEAR WAR, CHESS, CHECKERS, POKER, TIC-TAC-TOE, BACKGAMMON"
  ], []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      for (const l of bootLines) { if (cancelled) return; setHistory((h) => [...h, l]); await sleep(120); }
      setBootDone(true);
    })();
    return () => { cancelled = true; };
  }, [bootLines]);

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth" }); }, [history]);

  async function runScenario() {
    setScenarioRunning(true); cancelRef.current = false;
    const seq = [
      "SCENARIO: GLOBAL THERMONUCLEAR WAR",
      "LINKING SATCOM CHANNELS...",
      "AUTH CODE: CPE1704TKS",
      "ACQUIRING TARGET PACKAGES: ICBM / SLBM / ALCM",
      "LAUNCH AUTHORIZATION: CONFIRMED",
      "ICBM LAUNCH DETECTED...",
      "MIRV TRAJECTORIES: 16",
      "EST. IMPACT WINDOWS: 03:12–04:07 ZULU",
      "RUNNING OPTIMAL RESPONSE MODEL...",
      'WOPR: "A STRANGE GAME. THE ONLY WINNING MOVE IS NOT TO PLAY."',
      "SCENARIO COMPLETE. DISPLAYING GLOBAL TRAJECTORY ANALYSIS..."
    ];
    for (const s of seq) { if (cancelRef.current) { setHistory((h) => [...h, "SCENARIO ABORTED."]); setScenarioRunning(false); return; } setHistory((h) => [...h, s]); await sleep(420); }
    setScenarioRunning(false); onFinale();
  }

  function handleCommand(raw: string) {
    const cmd = raw.trim(); if (!cmd) return;
    const upper = cmd.toUpperCase();
    const append = (s: string | string[]) => setHistory((h) => [...h, "> " + cmd, ...(Array.isArray(s) ? s : [s])]);
    switch (upper) {
      case "HELP": append(["AVAILABLE: LIST GAMES, HELP, CLEAR, STATUS, ABORT, GREETINGS PROFESSOR FALKEN, GLOBAL THERMONUCLEAR WAR"]); break;
      case "CLEAR": setHistory([]); break;
      case "LIST GAMES": append(["GLOBAL THERMONUCLEAR WAR, CHESS, CHECKERS, POKER, TIC-TAC-TOE, BACKGAMMON"]); break;
      case "STATUS": append([`WAR MODE: ${scenarioRunning ? "ACTIVE" : "IDLE"}`]); break;
      case "ABORT": cancelRef.current = true; append(["ABORT REQUESTED. RETURNING TO IDLE."]); onWarMode(); break;
      case "GREETINGS PROFESSOR FALKEN": append(["HELLO.", "WOULD YOU LIKE TO PLAY A GAME?"]); break;
      case "GLOBAL THERMONUCLEAR WAR":
      case "PLAY GLOBAL THERMONUCLEAR WAR":
      case "GTW":
        append(["INITIATING SCENARIO: GLOBAL THERMONUCLEAR WAR", "WOULDN'T YOU PREFER A GOOD GAME OF CHESS?"]);
        if (!scenarioRunning) { onWarMode(); runScenario(); }
        break;
      default: append(["UNKNOWN COMMAND."]);
    }
  }

  return (
    <div className="relative rounded-2xl border border-neutral-800 bg-neutral-950 overflow-hidden">
      <Glare />
      <div className="p-4 sm:p-5 md:p-6 font-mono text-[13px] leading-relaxed text-green-400">
        <div className="text-[10px] text-green-500/80 tracking-widest mb-2">WOPR TERMINAL</div>
        <div className="h-64 sm:h-72 md:h-80 overflow-y-auto pr-1" id="crt">
          {history.map((h, i) => (<div key={i} className="whitespace-pre-wrap">{h}</div>))}
          {!bootDone && (<div className="text-green-500/80">BOOTING…</div>)}
          <div ref={endRef} />
        </div>
        <div className="mt-3 flex items-center gap-2">
          <span className="text-green-500">&gt;</span>
          <input
            value={line}
            onChange={(e) => setLine(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") { handleCommand(line); setLine(""); } }}
            disabled={!bootDone}
            className="flex-1 bg-black border border-green-900/60 rounded px-2 py-1 text-green-100 placeholder-green-600 caret-green-200 focus:outline-none focus:ring-1 focus:ring-green-500/60"
            placeholder={bootDone ? "type a command (try: LIST GAMES)" : "initializing…"}
            autoCapitalize="off" autoCorrect="off" spellCheck={false}
          />
        </div>
      </div>
    </div>
  );
}

/** Finale Map — fixed-timestep missile simulation, seam-aware, persistent trails */
type GArc = {
  from: Vec2; to: Vec2;
  stroke: string; glow: string;
  t0: number; dur: number; // seconds
  segs: number; speedSeg: number; // segments per second
  head: number; lastHead: number;
  active: boolean; done?: boolean;
  polyLL: Vec2[]; polyXY: Vec2[];
};
type Blast = { x: number; y: number; t0: number };

function MapFinale({ onClose }: { onClose: () => void }) {
  const bgCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const fxCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number | null>(null);

  const sizeRef = useRef<{ w: number; h: number; dpr: number }>({ w: 0, h: 0, dpr: 1 });
  const startRef = useRef<number>(0);
  const lastFrameRef = useRef<number>(0);

  const arcsRef = useRef<GArc[]>([]);
  const blastsRef = useRef<Blast[]>([]);
  const flashRef = useRef<number>(0);

  const worldRef = useRef<any | null>(null);
  const bordersRef = useRef<any | null>(null);
  const projectionRef = useRef<any | null>(null);
  const pathRef = useRef<any | null>(null);

  const PACE = 0.55;
  const MAX_DT = 1 / 15;
  const TRAIL_FADE = 0.03;

  useEffect(() => {
    // Local vector world (bundled JSON, no network)
    const topo: any = land110m as any;
    worldRef.current = feature(topo, topo.objects.land || topo.objects.countries);
    bordersRef.current = topo.objects.countries ? mesh(topo, topo.objects.countries, (a: any, b: any) => a !== b) : null;

    const bg = bgCanvasRef.current!;
    const fx = fxCanvasRef.current!;
    const bgctx = bg.getContext("2d")!;
    const fxctx = fx.getContext("2d")!;

    function drawStatic(w: number, h: number, proj: any) {
      const path = pathRef.current!;
      const grad = bgctx.createLinearGradient(0, 0, 0, h);
      grad.addColorStop(0, "#02060a");
      grad.addColorStop(1, "#050b12");
      bgctx.fillStyle = grad;
      bgctx.fillRect(0, 0, w, h);

      // Land + borders (no graticule)
      const land = worldRef.current;
      bgctx.lineWidth = 1.6;
      bgctx.fillStyle = "rgba(100,210,255,0.18)";
      bgctx.strokeStyle = "rgba(100,210,255,0.45)";
      bgctx.beginPath(); (path as any)(land); bgctx.fill(); bgctx.stroke();

      if (bordersRef.current) {
        bgctx.lineWidth = 1.2;
        bgctx.strokeStyle = "rgba(100,210,255,0.6)";
        bgctx.beginPath(); (path as any)(bordersRef.current); bgctx.stroke();
      }

      // City labels
      bgctx.save();
      bgctx.font = "11px ui-monospace, SFMono-Regular, Menlo, monospace";
      bgctx.fillStyle = "rgba(100,210,255,0.9)";
      bgctx.strokeStyle = "rgba(0,0,0,0.6)";
      bgctx.lineWidth = 3;
      for (const l of LABELS) {
        const p = proj([l.lon, l.lat]); if (!p) continue;
        const [x, y] = p as [number, number];
        bgctx.beginPath(); bgctx.arc(x, y, 2.5, 0, Math.PI * 2); bgctx.fill();
        bgctx.strokeText(l.name, x + 6, y - 6); bgctx.fillText(l.name, x + 6, y - 6);
      }
      bgctx.restore();
    }

    function resize() {
      const dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
      const w = window.innerWidth, h = window.innerHeight;
      for (const c of [bg, fx]) {
        c.width = Math.floor(w * dpr); c.height = Math.floor(h * dpr);
        const cctx = c.getContext("2d")!; cctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      }
      const scale = Math.min(w / (2 * Math.PI), h / Math.PI) * 0.98;
      const proj = geoEquirectangular().translate([w / 2, h / 2]).scale(scale);
      pathRef.current = geoPath(proj, bgctx as any);
      drawStatic(w, h, proj);
      for (const a of arcsRef.current) a.polyXY = a.polyLL.map((ll) => proj(ll as any) as Vec2);
      fxctx.clearRect(0, 0, w, h);
    }

    resize(); window.addEventListener("resize", resize);

    arcsRef.current = scheduleArcs(0.55);
    const proj = geoEquirectangular().translate([window.innerWidth/2, window.innerHeight/2])
      .scale(Math.min(window.innerWidth / (2 * Math.PI), window.innerHeight / Math.PI) * 0.98);
    for (const a of arcsRef.current) a.polyXY = a.polyLL.map((ll) => proj(ll as any) as Vec2);
    let last = performance.now();

    const loop = () => {
      const raf = requestAnimationFrame(loop);

      const now = performance.now();
      let dt = (now - last) / 1000; if (dt > 1/15) dt = 1/15; last = now;

      const fx = fxCanvasRef.current!;
      const fxctx = fx.getContext('2d')!;
      const w = window.innerWidth, h = window.innerHeight;

      // Fade ONLY previous missile strokes; keep map bright
      fxctx.globalCompositeOperation = "destination-out";
      fxctx.fillStyle = "rgba(0,0,0,0.03)";
      fxctx.fillRect(0, 0, w, h);
      fxctx.globalCompositeOperation = "source-over";

      const seam = w * 0.5;

      for (const a of arcsRef.current) {
        if (!a.active && (now - 0) / 1000 >= a.t0) a.active = true;
        if (!a.active || a.done) continue;
        const step = a.speedSeg * dt;
        a.head = Math.min(a.segs - 1, a.head + step);

        // draw segment
        const i0 = Math.max(1, Math.floor(a.lastHead));
        const i1 = Math.max(i0, Math.floor(a.head));
        const drawSeamAware = (startIdx: number, endIdx: number, lineWidth: number, color: string, glow?: string, innerCore = false) => {
          fxctx.save();
          fxctx.lineCap = "round";
          fxctx.globalAlpha = glow ? 0.98 : 0.9;
          if (glow) { fxctx.shadowColor = glow as any; fxctx.shadowBlur = 14; }
          fxctx.strokeStyle = color as any;
          fxctx.lineWidth = lineWidth;
          fxctx.beginPath();
          let moved = false;
          for (let i = startIdx; i <= endIdx; i++) {
            const axy = a.polyXY[i - 1]; const bxy = a.polyXY[i];
            if (!axy || !bxy) continue;
            if (!moved) { fxctx.moveTo(axy[0], axy[1]); moved = true; }
            if (Math.abs(axy[0] - bxy[0]) > seam) {
              fxctx.moveTo(bxy[0], bxy[1]);
            } else {
              fxctx.lineTo(bxy[0], bxy[1]);
            }
          }
          fxctx.stroke();
          if (innerCore) {
            fxctx.shadowBlur = 0;
            fxctx.globalAlpha = 0.7;
            fxctx.strokeStyle = "#ffffff";
            fxctx.lineWidth = Math.max(1, lineWidth - 1.8);
            fxctx.stroke();
          }
          fxctx.restore();
        };

        drawSeamAware(i0, i1, 2.2, "#ffffff");
        const headIdx = Math.floor(a.head);
        const start = Math.max(1, headIdx - 28);
        drawSeamAware(start, headIdx, 3.6, "#ffffff", a.glow, true);

        const head = a.polyXY[headIdx];
        if (head) {
          fxctx.save();
          fxctx.beginPath(); fxctx.arc(head[0], head[1], 4.6, 0, Math.PI * 2);
          fxctx.fillStyle = "#ffffff";
          fxctx.shadowColor = a.glow as any; fxctx.shadowBlur = 14;
          fxctx.fill();
          fxctx.restore();
        }

        a.lastHead = a.head;
        if (a.head >= a.segs - 1 && !a.done) {
          a.done = true;
          const end = a.polyXY[a.segs - 1];
          if (end) {
            const tNow = (now - 0) / 1000;
            blastsRef.current.push({ x: end[0], y: end[1], t0: tNow });
            const extras = 2 + Math.floor(Math.random() * 3);
            for (let j = 0; j < extras; j++) {
              const ox = (Math.random() - 0.5) * 16; const oy = (Math.random() - 0.5) * 16;
              blastsRef.current.push({ x: end[0] + ox, y: end[1] + oy, t0: tNow + Math.random() * 0.25 });
            }
          }
        }
      }

      // Explosions
      for (let i = blastsRef.current.length - 1; i >= 0; i--) {
        const b = blastsRef.current[i];
        const age = (now - 0) / 1000 - b.t0;
        if (age > 2.0) { blastsRef.current.splice(i, 1); continue; }
        const r = (6 + (1 - Math.pow(1 - Math.max(0, Math.min(1, age / 1.2)), 3)) * 36) / 4;
        const alpha = 1 - Math.max(0, Math.min(1, age / 1.6));
        const grad = fxctx.createRadialGradient(b.x, b.y, 0, b.x, b.y, r);
        grad.addColorStop(0, "rgba(255,255,255," + alpha + ")");
        grad.addColorStop(0.5, "rgba(255,214,10," + (alpha * 0.7) + ")");
        grad.addColorStop(1, "rgba(0,0,0,0)");
        fxctx.fillStyle = grad;
        fxctx.beginPath(); fxctx.arc(b.x, b.y, r, 0, Math.PI * 2); fxctx.fill();
        fxctx.beginPath(); fxctx.arc(b.x, b.y, r * 1.05, 0, Math.PI * 2);
        fxctx.strokeStyle = "rgba(255,255,255," + (alpha * 0.5) + ")";
        fxctx.lineWidth = 1; fxctx.setLineDash([4, 6]); fxctx.stroke(); fxctx.setLineDash([]);
      }
    };

    rafRef.current = requestAnimationFrame(loop);
    return () => { if (rafRef.current) cancelAnimationFrame(rafRef.current); };
  }, [onClose]);

  return (
    <div className="relative w-full h-full">
      <canvas ref={bgCanvasRef} className="absolute inset-0 w-full h-full" />
      <canvas ref={fxCanvasRef} className="absolute inset-0 w-full h-full" />
      <div className="absolute top-0 inset-x-0 p-4 flex items-center justify-between text-neutral-200">
        <div className="tracking-[0.35em] text-xs">NORAD STRATEGIC DISPLAY</div>
        <div className="flex items-center gap-2 text-[10px]">
          <span className="opacity-70">WOPR</span>
          <span className="opacity-40">•</span>
          <span className="opacity-70">GLOBAL THERMONUCLEAR WAR</span>
        </div>
      </div>
    </div>
  );
}

const LABELS: { name: string; lon: number; lat: number }[] = [
  { name: "SEATTLE", lon: -122.33, lat: 47.61 },
  { name: "SAN FRANCISCO", lon: -122.42, lat: 37.77 },
  { name: "LOS ANGELES", lon: -118.24, lat: 34.05 },
  { name: "DENVER", lon: -104.99, lat: 39.74 },
  { name: "CHEYENNE MTN", lon: -104.85, lat: 38.74 },
  { name: "CHICAGO", lon: -87.62, lat: 41.88 },
  { name: "WASHINGTON D.C.", lon: -77.04, lat: 38.91 },
  { name: "NEW YORK", lon: -74.01, lat: 40.71 },
  { name: "LONDON", lon: -0.13, lat: 51.51 },
  { name: "PARIS", lon: 2.35, lat: 48.86 },
  { name: "BERLIN", lon: 13.41, lat: 52.52 },
  { name: "MOSCOW", lon: 37.62, lat: 55.75 },
  { name: "LENINGRAD", lon: 30.31, lat: 59.93 },
  { name: "TOKYO", lon: 139.69, lat: 35.68 },
  { name: "BEIJING", lon: 116.41, lat: 39.90 },
  { name: "SEOUL", lon: 126.98, lat: 37.56 }
];

function makeArc(from: Vec2, to: Vec2, stroke: string, glow: string, t0: number, dur: number) {
  const segs = 140 + Math.floor(Math.random() * 80);
  const interp = geoInterpolate(from, to) as (t: number) => Vec2;
  const polyLL: Vec2[] = [];
  for (let i = 0; i < segs; i++) polyLL.push(interp(i / (segs - 1)));
  return {
    from, to, stroke, glow, t0, dur,
    segs, speedSeg: (segs - 1) / dur, head: 0, lastHead: 0, active: false,
    polyLL, polyXY: []
  };
}

function scheduleArcs(pace: number) {
  const SITES: Record<string, Vec2> = {
    US_EAST: [-74.01, 40.71], US_CENTRAL: [-100, 45], US_WEST: [-122.33, 47.61],
    SO_CAL: [-118.24, 34.05], SF: [-122.42, 37.77], DEN: [-104.99, 39.74],
    RU_WEST: [37.62, 55.75], RU_EAST: [135, 60],
    UK: [-0.13, 51.51], FR: [2.35, 48.86], DE: [13.41, 52.52],
    CN: [116.4, 39.9], JP: [139.69, 35.68], KR: [126.98, 37.56]
  };
  const WEST = [SITES.US_EAST, SITES.US_CENTRAL, SITES.US_WEST, SITES.SO_CAL, SITES.SF, SITES.DEN, SITES.UK, SITES.FR, SITES.DE];
  const EAST = [SITES.RU_WEST, SITES.RU_EAST, SITES.CN, SITES.JP, SITES.KR];

  const list: any[] = [];
  let t = 0.8;

  for (let i = 0; i < 30; i++) {
    const fromW = randomChoice(WEST), toE = randomChoice(EAST);
    const fromE = randomChoice(EAST), toW = randomChoice(WEST);
    const dur = (9 + Math.random() * 3) / pace;
    list.push(makeArc(fromW, toE, "#ffffff", "#64d2ff", t, dur));
    list.push(makeArc(fromE, toW, "#ffffff", "#ff453a", t + 0.14, dur));
    t += (0.22 + Math.random() * 0.14) / pace;
  }

  const TOTAL = 1000;
  for (let i = 0; i < TOTAL; i++) {
    const westToEast = Math.random() < 0.5;
    const from = westToEast ? randomChoice(WEST) : randomChoice(EAST);
    const to = westToEast ? randomChoice(EAST) : randomChoice(WEST);
    const dur = (10 + Math.random() * 7) / pace;
    const jitter = (Math.random() * 0.16 + 0.08) / pace;
    t += jitter;
    list.push(makeArc(from, to, "#ffffff", westToEast ? "#64d2ff" : "#ff453a", t, dur));
  }
  return list;
}

export default function WOPR() {
  const [speedLabel, setSpeedLabel] = useState<"Slow" | "Medium" | "Fast">("Medium");
  const [warMode, setWarMode] = useState(false);
  const [intensity, setIntensity] = useState(0.15);
  const [showFinale, setShowFinale] = useState(false);

  return (
    <div className="min-h-screen w-full bg-black text-neutral-200">
      <div className="mx-auto max-w-7xl p-4 sm:p-6 md:p-8">
        <HeaderBar war={warMode} />
        <div className="mt-4 grid grid-cols-1 lg:grid-cols-3 gap-4">
          <div className="relative lg:col-span-2 overflow-hidden rounded-2xl border border-neutral-800 bg-neutral-950">
            <CanvasLEDWall rows={LED_ROWS} cols={LED_COLS} intensity={intensity} warMode={warMode} />
            <Glare />
            <div className="absolute bottom-0 left-0 right-0 p-3 sm:p-4 text-[10px] sm:text-xs text-neutral-400/80 bg-gradient-to-t from-black/60 to-transparent">
              <div className="flex items-center justify-between gap-3">
                <div className="tracking-widest">NORAD MAIN OPS • DISPLAY A-17</div>
                <div className="flex gap-2 items-center">
                  <StatusLamp label="POWER" on color="#30d158" />
                  <StatusLamp label="NET" on={warMode} color="#64d2ff" />
                  <StatusLamp label="TACTICAL" on={warMode} color="#ff453a" />
                </div>
              </div>
            </div>
          </div>
          <div className="flex flex-col gap-4">
            <ControlPanel
              speedLabel={speedLabel} setSpeedLabel={setSpeedLabel}
              intensity={intensity} setIntensity={setIntensity}
              warMode={warMode} setWarMode={setWarMode}
            />
            <Terminal onWarMode={() => setWarMode((v) => !v)} onFinale={() => setShowFinale(true)} />
          </div>
        </div>
        <div className="mt-6 text-center text-[11px] text-neutral-500">
          WOPR-inspired UI for educational/fan use. No affiliation with the original film.
        </div>
      </div>

      <AnimatePresence>
        {showFinale && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            transition={{ duration: 0.6 }}
            className="fixed inset-0 z-[60] bg-black"
          >
            <MapFinale onClose={() => setShowFinale(false)} />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
EOF

############################################
# Dockerfile
############################################
cat > Dockerfile <<'EOF'
# --- Build stage ---
FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install --no-fund --no-audit; fi

COPY . .
RUN npm run build

# --- Serve stage ---
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

############################################
# nginx.conf (correct MIME types; SPA fallback)
############################################
cat > nginx.conf <<'EOF'
server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  # Ensure correct Content-Type for HTML/CSS/JS
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  location / {
    try_files $uri $uri/ /index.html;
  }
}
EOF

############################################
# .dockerignore
############################################
cat > .dockerignore <<'EOF'
node_modules
dist
.git
.gitignore
.vscode
.DS_Store
EOF

echo
echo "✅ Project scaffolded in: $APP_DIR"
echo
echo "Next:"
echo "  cd $APP_DIR"
echo "  npm install"
echo "  npm run build"
echo "  docker build -t $IMAGE_NAME ."
echo "  docker run --rm -p 8080:80 $IMAGE_NAME"
echo
echo "Open http://<host>:8080 and type: GLOBAL THERMONUCLEAR WAR"
