import React, { useEffect, useRef, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { BRAND_PREFIX, BRAND_ACCENT } from '../../constants/brand';

interface StorySceneProps {
  onChapterChange?: (chapterIndex: number) => void;
}

const CHAPTER_NAMES = ['I', 'II', 'III', 'IV', 'V'];

const CHAPTER_DOTS = [
  { index: 0, label: 'I · THE DRIP' },
  { index: 1, label: 'II · THE GROWTH' },
  { index: 2, label: 'III · DETECT' },
  { index: 3, label: 'IV · ALERT' },
  { index: 4, label: 'V · BUILD' },
];

function clamp(v: number, a: number, b: number) {
  return Math.max(a, Math.min(b, v));
}

function seg(p: number, a: number, b: number) {
  return clamp((p - a) / (b - a), 0, 1);
}

function ease(x: number) {
  return x * x * (3 - 2 * x);
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export const StoryScene: React.FC<StorySceneProps> = ({ onChapterChange }) => {
  const storyRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const tcRef = useRef<HTMLSpanElement>(null);
  const dotsRef = useRef<(HTMLButtonElement | null)[]>([]);

  const ch0Ref = useRef<HTMLDivElement>(null);
  const ch1Ref = useRef<HTMLDivElement>(null);
  const ch2Ref = useRef<HTMLDivElement>(null);
  const ch3Ref = useRef<HTMLDivElement>(null);
  const ch4Ref = useRef<HTMLDivElement>(null);

  // Animation and sizing refs
  const targetRef = useRef(0);
  const curRef = useRef(0);
  const animFrameRef = useRef<number | null>(null);
  const reducedMotionRef = useRef(false);
  const currentChapterIndexRef = useRef(-1);

  // Canvas size and DPR
  const sizeRef = useRef({ w: 0, h: 0, dpr: 1 });

  // Update canvas sizing
  const updateSize = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = canvas.clientWidth || window.innerWidth;
    const h = canvas.clientHeight || window.innerHeight;
    if (w === 0 || h === 0) return;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    sizeRef.current = { w, h, dpr };
  }, []);

  // Compute scroll progress (0..4.999)
  const calcScroll = useCallback(() => {
    const story = storyRef.current;
    if (!story) return;
    const r = story.getBoundingClientRect();
    const tot = r.height - window.innerHeight;
    if (tot <= 0) {
      targetRef.current = 0;
      return;
    }
    const q = Math.max(0, Math.min(1, -r.top / tot));
    targetRef.current = q * 4.999;
  }, []);

  // Draw 2D canvas scene
  const drawScene = useCallback((t: number, p: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    if (
      canvas.clientWidth > 0 &&
      (canvas.clientWidth !== sizeRef.current.w || canvas.clientHeight !== sizeRef.current.h)
    ) {
      updateSize();
    }

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const { w, h, dpr } = sizeRef.current;
    if (w === 0 || h === 0) return;

    const k = Math.min(w, h * 1.5) / 900;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const calm = ease(seg(p, 3.85, 4.6));
    const z = 1 - calm * 0.08;

    ctx.save();
    ctx.translate(w / 2, h / 2);
    ctx.scale(z, z);
    ctx.translate(-w / 2, -h / 2);

    // Dark workshop background
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, '#0b0908');
    g.addColorStop(1, '#1b1411');
    ctx.fillStyle = g;
    ctx.fillRect(-w, -h, w * 3, h * 3);

    // Warm ambient overhead beam
    ctx.fillStyle = `rgba(255,196,150,${0.05 + 0.015 * Math.sin(t * 0.4)})`;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(w * 0.34, 0);
    ctx.lineTo(w * 0.64, h);
    ctx.lineTo(w * 0.18, h);
    ctx.closePath();
    ctx.fill();

    // Workshop furniture & equipment silhouettes
    ctx.fillStyle = '#0e0b0a';
    ctx.fillRect(w * 0.03, h * 0.74, w * 0.34, h * 0.025);
    ctx.fillRect(w * 0.05, h * 0.765, w * 0.012, h * 0.24);
    ctx.fillRect(w * 0.33, h * 0.765, w * 0.012, h * 0.24);
    ctx.fillRect(w * 0.08, h * 0.7, w * 0.05, h * 0.04);
    ctx.fillRect(w * 0.12, h * 0.68, w * 0.012, h * 0.04);

    ctx.fillRect(w * 0.87, h * 0.46, w * 0.12, h * 0.6);
    ctx.fillStyle = '#17110f';
    ctx.fillRect(w * 0.88, h * 0.5, w * 0.1, h * 0.012);
    ctx.fillRect(w * 0.88, h * 0.62, w * 0.1, h * 0.012);
    ctx.fillRect(w * 0.88, h * 0.74, w * 0.1, h * 0.012);

    // Overhead pipe system
    const py = h * 0.3;
    const pt = Math.max(26, h * 0.075);
    const jx = w * (w > h ? 0.62 : 0.56);

    ctx.fillStyle = '#17110f';
    ctx.fillRect(w * 0.2, 0, 5 * k + 2, py);
    ctx.fillRect(w * 0.86, 0, 5 * k + 2, py);

    const pg = ctx.createLinearGradient(0, py, 0, py + pt);
    pg.addColorStop(0, '#4d423b');
    pg.addColorStop(0.5, '#2c2521');
    pg.addColorStop(1, '#120e0c');
    ctx.fillStyle = pg;
    ctx.fillRect(-w, py, w * 3, pt);

    // Pipe Joint Collar
    ctx.fillStyle = '#3b312c';
    ctx.fillRect(jx - pt * 0.45, py - pt * 0.18, pt * 0.9, pt * 1.36);
    ctx.fillStyle = '#14100e';
    for (let b = 0; b < 3; b++) {
      ctx.beginPath();
      ctx.arc(jx, py + pt * (0.12 + b * 0.38), pt * 0.06, 0, 7);
      ctx.fill();
    }

    const oy = py + pt * 1.2;
    const fl = h * 0.9;
    const dist = fl - oy;
    const leak = 1 - calm * 0.85;

    // Wet glow on pipe joint
    const wet = ctx.createRadialGradient(jx, oy, 0, jx, oy, pt * 1.4);
    wet.addColorStop(0, `rgba(255,170,120,${0.22 * leak})`);
    wet.addColorStop(1, 'rgba(255,170,120,0)');
    ctx.fillStyle = wet;
    ctx.fillRect(jx - pt * 2, oy - pt * 2, pt * 4, pt * 4);

    // Floor puddle growth
    const pud = (18 + seg(p, 0, 3.2) * 70) * k * (1 - calm * 0.45);
    ctx.fillStyle = 'rgba(255,170,120,.10)';
    ctx.strokeStyle = 'rgba(255,170,120,.35)';
    ctx.beginPath();
    ctx.ellipse(jx, fl, pud, pud * 0.18, 0, 0, 7);
    ctx.fill();
    ctx.stroke();

    // Falling water drip & floor ripples
    if (leak > 0.1) {
      const T = 1.7 + calm * 2.5;
      const ph = (t % T) / T;
      const f = Math.min(1, ph / 0.8);
      if (ph < 0.8) {
        ctx.fillStyle = 'rgba(255,185,140,.95)';
        ctx.beginPath();
        ctx.ellipse(jx, oy + f * f * dist, 3.2 * k + 1, 5.5 * k + 1.5, 0, 0, 7);
        ctx.fill();
      } else {
        const rp = (ph - 0.8) / 0.2;
        ctx.strokeStyle = `rgba(255,185,140,${(1 - rp) * 0.8})`;
        ctx.beginPath();
        ctx.ellipse(jx, fl, (6 + rp * 46) * k, (6 + rp * 46) * k * 0.18, 0, 0, 7);
        ctx.stroke();
      }
    }

    // Wall warning light (Chapter II)
    const wl = seg(p, 0.7, 1.2) * (1 - seg(p, 2.2, 2.8));
    if (wl > 0) {
      const fx = w * 0.1;
      const fy = h * 0.2;
      const gl = 0.45 + 0.55 * Math.abs(Math.sin(t * 1.6));
      ctx.fillStyle = `rgba(242,162,12,${0.16 * gl * wl})`;
      ctx.beginPath();
      ctx.arc(fx, fy, 60 * k, 0, 7);
      ctx.fill();
      ctx.strokeStyle = `rgba(242,162,12,${wl})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(fx, fy - 20 * k);
      ctx.lineTo(fx + 22 * k, fy + 16 * k);
      ctx.lineTo(fx - 22 * k, fy + 16 * k);
      ctx.closePath();
      ctx.stroke();
      ctx.fillStyle = `rgba(242,162,12,${wl})`;
      ctx.fillRect(fx - 1.5, fy - 8 * k, 3, 12 * k);
    }

    // Handheld probe entering (Chapter III)
    const pr = ease(seg(p, 1.5, 2.4));
    const tipX = jx + 6 * k;
    const tipY = py + pt * 1.55 + 14 * k;
    const off = (1 - pr) * 480 * k;
    const ang = 0.5;
    const cs = Math.cos(ang);
    const sn = Math.sin(ang);
    const px = tipX + off * cs;
    const py2 = tipY + off * sn;

    const al = seg(p, 3.0, 3.3) * (1 - calm);
    const sens = seg(p, 2.0, 2.4) * (1 - calm * 0.55);
    const col = calm > 0.5 ? '53,194,122' : '255,106,43';

    if (pr > 0.02) {
      // Sensing acoustic waves
      if (sens > 0) {
        for (let i = 0; i < 3; i++) {
          const q = (t * 0.7 + i / 3) % 1;
          ctx.strokeStyle = `rgba(${col},${(1 - q) * 0.75 * sens})`;
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.arc(px, py2, (10 + q * 150) * k, 0, 7);
          ctx.stroke();
        }
      }

      ctx.save();
      ctx.translate(px, py2);
      ctx.rotate(ang);

      // Probe shaft
      const sg = ctx.createLinearGradient(0, -5 * k, 0, 5 * k);
      sg.addColorStop(0, '#f2efe9');
      sg.addColorStop(1, '#8d867b');
      ctx.fillStyle = sg;
      ctx.fillRect(0, -5 * k, 250 * k, 10 * k);

      // Connector collar
      ctx.fillStyle = '#2b2623';
      ctx.beginPath();
      ctx.moveTo(250 * k, -5 * k);
      ctx.lineTo(300 * k, -26 * k);
      ctx.lineTo(300 * k, 26 * k);
      ctx.lineTo(250 * k, 5 * k);
      ctx.closePath();
      ctx.fill();

      // Hand grip
      const hg = ctx.createLinearGradient(0, -30 * k, 0, 30 * k);
      hg.addColorStop(0, '#4a423d');
      hg.addColorStop(0.35, '#2a2522');
      hg.addColorStop(1, '#12100e');
      ctx.fillStyle = hg;
      roundRect(ctx, 300 * k, -30 * k, 330 * k, 60 * k, 30 * k);
      ctx.fill();

      // OLED screen enclosure on probe
      ctx.fillStyle = '#17130f';
      roundRect(ctx, 380 * k, -56 * k, 190 * k, 30 * k, 6 * k);
      ctx.fill();
      ctx.fillStyle = '#0a0908';
      ctx.fillRect(390 * k, -51 * k, 100 * k, 20 * k);

      // Signal level bars on probe screen
      ctx.fillStyle = '#35C27A';
      for (let b2 = 0; b2 < 5; b2++) {
        ctx.fillRect((396 + b2 * 16) * k, (-36 - b2 * 2.2) * k, 10 * k, (5 + b2 * 2.2) * k);
      }

      // Status indicator LED (Green -> Red on alert)
      const lc = al > 0.05 ? '#EE4B3E' : '#35C27A';
      ctx.fillStyle = lc;
      ctx.shadowColor = lc;
      ctx.shadowBlur = al > 0.05 ? 18 : 8;
      ctx.beginPath();
      ctx.arc(520 * k, -41 * k, 5 * k + 1, 0, 7);
      ctx.fill();
      ctx.shadowBlur = 0;

      // Probe sensor tip glow
      ctx.fillStyle = '#FF6A2B';
      ctx.shadowColor = '#FF6A2B';
      ctx.shadowBlur = 16;
      ctx.beginPath();
      ctx.arc(0, 0, 7 * k + 1, 0, 7);
      ctx.fill();
      ctx.shadowBlur = 0;

      ctx.restore();

      // Alert pulses radiating from probe LED
      if (al > 0) {
        const lx = px + 520 * k * cs - -41 * k * sn;
        const ly = py2 + 520 * k * sn + -41 * k * cs;
        for (let j = 0; j < 3; j++) {
          const q2 = (t * 0.9 + j / 3) % 1;
          ctx.strokeStyle = `rgba(238,75,62,${(1 - q2) * 0.7 * al})`;
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.arc(lx, ly, (8 + q2 * 110) * k, 0, 7);
          ctx.stroke();
        }
      }
    }

    // Diagnostic Lock-on Reticle (Chapter IV)
    const lk = ease(seg(p, 2.45, 2.95));
    if (lk > 0) {
      const rx = jx;
      const ry = py + pt * 1.05;
      const s = (70 - 34 * lk) * k;
      const lc2 = calm > 0.5 ? 'rgba(53,194,122,' : 'rgba(255,106,43,';
      ctx.strokeStyle = lc2 + lk + ')';
      ctx.lineWidth = 2;
      const c = s * 0.35;

      const corners = [
        [-1, -1],
        [1, -1],
        [1, 1],
        [-1, 1],
      ];
      corners.forEach((d) => {
        ctx.beginPath();
        ctx.moveTo(rx + d[0] * s, ry + d[1] * (s - c));
        ctx.lineTo(rx + d[0] * s, ry + d[1] * s);
        ctx.lineTo(rx + d[0] * (s - c), ry + d[1] * s);
        ctx.stroke();
      });

      ctx.setLineDash([6, 6]);
      ctx.beginPath();
      ctx.arc(rx, ry, s * 0.72, t * 0.8, t * 0.8 + Math.PI * 1.6);
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = lc2 + lk + ')';
      ctx.font = `500 ${Math.max(10, 12 * k * 1.3)}px 'JetBrains Mono', monospace`;
      ctx.textAlign = 'left';
      ctx.fillText(calm > 0.5 ? 'LOGGED' : 'POSSIBLE LEAK', rx + s + 10, ry - s * 0.5);
    }

    ctx.restore();

    // Alert ambient glow
    if (al > 0) {
      const ag = ctx.createRadialGradient(
        w / 2,
        h / 2,
        Math.min(w, h) * 0.2,
        w / 2,
        h / 2,
        Math.max(w, h) * 0.8
      );
      ag.addColorStop(0, 'rgba(238,75,62,0)');
      ag.addColorStop(
        1,
        `rgba(238,75,62,${0.2 * al * (0.7 + 0.3 * Math.sin(t * 5))})`
      );
      ctx.fillStyle = ag;
      ctx.fillRect(0, 0, w, h);
    }

    // Workshop lens vignette
    const vg = ctx.createRadialGradient(
      w / 2,
      h / 2,
      Math.min(w, h) * 0.3,
      w / 2,
      h / 2,
      Math.max(w, h) * 0.75
    );
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(0,0,0,.72)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, w, h);
  }, [updateSize]);

  // Update chapter overlays directly in the DOM for buttery 60fps performance
  const updateOverlays = useCallback(
    (p: number) => {
      const ci = Math.min(4, Math.floor(p));
      const chRefs = [ch0Ref, ch1Ref, ch2Ref, ch3Ref, ch4Ref];

      chRefs.forEach((ref, i) => {
        const el = ref.current;
        if (!el) return;
        let o: number;
        if (i === 0) {
          o = 1 - clamp((p - 0.62) / 0.22, 0, 1);
        } else if (i === 4) {
          o = clamp((p - 3.78) / 0.22, 0, 1);
        } else {
          o = 1 - clamp((Math.abs(p - (i + 0.5)) - 0.3) / 0.22, 0, 1);
        }

        el.style.opacity = o.toFixed(3);
        el.style.transform = `translateY(calc(-50% + ${(1 - o) * 18}px))`;
        el.style.visibility = o < 0.02 ? 'hidden' : 'visible';
        el.style.pointerEvents = o > 0.5 ? 'auto' : 'none';
      });

      // Update dots attribute directly
      dotsRef.current.forEach((d, i) => {
        if (d) {
          d.setAttribute('aria-current', String(i === ci));
        }
      });

      // Update timecode text directly
      if (tcRef.current) {
        tcRef.current.textContent = `Chapter ${CHAPTER_NAMES[ci]} of V${p < 0.15 ? ' · Scroll to play' : ''}`;
      }

      if (currentChapterIndexRef.current !== ci) {
        currentChapterIndexRef.current = ci;
        onChapterChange?.(ci);
      }
    },
    [onChapterChange]
  );

  // Smooth continuous animation loop
  useEffect(() => {
    reducedMotionRef.current = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const onMotionChange = (e: MediaQueryListEvent) => {
      reducedMotionRef.current = e.matches;
    };
    const motionMql = window.matchMedia('(prefers-reduced-motion: reduce)');
    motionMql.addEventListener('change', onMotionChange);

    // Initial sizing and scroll calculation
    updateSize();
    calcScroll();
    curRef.current = targetRef.current;
    drawScene(0, curRef.current);
    updateOverlays(curRef.current);

    const loop = (ms: number) => {
      const isReduced = reducedMotionRef.current;
      const target = targetRef.current;

      curRef.current += (target - curRef.current) * (isReduced ? 1 : 0.12);
      if (Math.abs(target - curRef.current) < 0.0005) {
        curRef.current = target;
      }

      drawScene(isReduced ? 0 : ms / 1000, curRef.current);
      updateOverlays(curRef.current);

      if (!isReduced) {
        animFrameRef.current = requestAnimationFrame(loop);
      }
    };

    if (!reducedMotionRef.current) {
      animFrameRef.current = requestAnimationFrame(loop);
    } else {
      loop(0);
    }

    // Resize listener
    const handleResize = () => {
      updateSize();
      calcScroll();
      if (reducedMotionRef.current) {
        drawScene(0, curRef.current);
        updateOverlays(curRef.current);
      }
    };
    window.addEventListener('resize', handleResize);

    // Canvas ResizeObserver for layout shifts
    let ro: ResizeObserver | null = null;
    if (canvasRef.current && typeof ResizeObserver !== 'undefined') {
      ro = new ResizeObserver(() => {
        updateSize();
        calcScroll();
        if (reducedMotionRef.current) {
          drawScene(0, curRef.current);
          updateOverlays(curRef.current);
        }
      });
      ro.observe(canvasRef.current);
    }

    // Scroll listener (passive)
    const handleScroll = () => {
      calcScroll();
      if (reducedMotionRef.current) {
        curRef.current = targetRef.current;
        drawScene(0, curRef.current);
        updateOverlays(curRef.current);
      }
    };
    window.addEventListener('scroll', handleScroll, { passive: true });

    return () => {
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
      motionMql.removeEventListener('change', onMotionChange);
      ro?.disconnect();
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('scroll', handleScroll);
    };
  }, [calcScroll, drawScene, updateOverlays, updateSize]);

  // Jump to chapter on dot click
  const handleDotClick = (i: number) => {
    const story = storyRef.current;
    if (!story) return;
    const tot = story.offsetHeight - window.innerHeight;
    const top = story.getBoundingClientRect().top + window.scrollY;
    const targetScrollY = top + tot * ((i + 0.5) / 4.999);
    window.scrollTo({
      top: targetScrollY,
      behavior: reducedMotionRef.current ? 'auto' : 'smooth',
    });
  };

  return (
    <div className="story" id="story" ref={storyRef}>
      <div className="pin">
        <canvas
          id="scene"
          ref={canvasRef}
          aria-label="Animated workshop scene that changes as you scroll: a slow leak, a probe detecting it, an alert and a recorded review"
        />
        <div className="grain" />
        <div className="lb t" />
        <div className="lb b" />

        {/* Head-Up Display */}
        <div className="hud">
          <div className="w">
            <a className="logo" href="#top">
              {BRAND_PREFIX}
              <i>{BRAND_ACCENT[0]}</i>
              {BRAND_ACCENT.slice(1)}
            </a>
            <span className="tc" id="tc" ref={tcRef}>
              Chapter I of V · Scroll to play
            </span>
            <Link to="/dashboard" className="hud-cta">
              Trainer View →
            </Link>
          </div>
        </div>

        {/* Chapter Dots Navigation */}
        <nav className="dots" id="dots" aria-label="Chapters">
          {CHAPTER_DOTS.map((dot) => (
            <button
              key={dot.index}
              data-i={dot.index}
              ref={(el) => {
                dotsRef.current[dot.index] = el;
              }}
              aria-current={dot.index === 0 ? 'true' : 'false'}
              onClick={() => handleDotClick(dot.index)}
            >
              <span>{dot.label}</span>
              <i />
            </button>
          ))}
        </nav>

        {/* Chapter Overlays */}
        {/* Chapter 0: The Drip */}
        <div className="ch" data-i="0" ref={ch0Ref}>
          <div className="w">
            <div>
              <div className="t">09:41 · The workshop is quiet</div>
              <h2>
                A leak nobody <em>hears.</em>
              </h2>
              <p>
                One joint above the bench lets go of a single drop at a time. Trainees are busy
                learning the trade. Nothing looks wrong yet.
              </p>
            </div>
          </div>
        </div>

        {/* Chapter 1: The Growth */}
        <div className="ch" data-i="1" ref={ch1Ref}>
          <div className="w">
            <div>
              <div className="t">09:58 · Still unnoticed</div>
              <h2>
                It grows while everyone <em>works.</em>
              </h2>
              <p>
                Drops become a puddle. Wet floors, metal tools and electrical gear share the same
                room.
              </p>
            </div>
          </div>
        </div>

        {/* Chapter 2: Detect Early */}
        <div className="ch" data-i="2" ref={ch2Ref}>
          <div className="w">
            <div>
              <div className="t">Chapter III · Sense</div>
              <h2>
                <em>Detect</em> early.
              </h2>
              <p>
                A handheld probe, traced along the pipe, reads the signal at the joint before the
                problem is obvious.
              </p>
            </div>
          </div>
        </div>

        {/* Chapter 3: Alert Clearly */}
        <div className="ch" data-i="3" ref={ch3Ref}>
          <div className="w">
            <div>
              <div className="t">Chapter IV · Alert and guide</div>
              <h2>
                <em>Alert</em> clearly.
              </h2>
              <p>
                A physical alert reaches the trainee at once, and plain guidance says what to do next.
              </p>
            </div>
            <div className="card">
              <h4>Guidance on screen · concept</h4>
              <p className="g">Possible leak at this joint.</p>
              <div className="r">
                <b>1</b>
                <span>Stop work and step back.</span>
              </div>
              <div className="r">
                <b>2</b>
                <span>Tell your trainer.</span>
              </div>
              <div className="r">
                <b>3</b>
                <span>Wait for the all-clear.</span>
              </div>
            </div>
          </div>
        </div>

        {/* Chapter 4: Build Safer Skills */}
        <div className="ch" data-i="4" ref={ch4Ref}>
          <div className="w">
            <div>
              <div className="t">Chapter V · Record and review</div>
              <h2>
                Build safer <em>skills.</em>
              </h2>
              <p>
                Every event is recorded. The trainer reviews it with the trainee and turns one near
                miss into a lesson.
              </p>
            </div>
            <div className="card">
              <h4>Trainer review · sample</h4>
              <div className="r">
                <b>09:42</b>
                <span>
                  <i className="chip cau">CAUTION</i>Reading crossed the early-warning line
                </span>
              </div>
              <div className="r">
                <b>09:43</b>
                <span>
                  <i className="chip dgr">DANGER</i>Alert fired, guidance shown
                </span>
              </div>
              <div className="r">
                <b>09:47</b>
                <span>
                  <i className="chip ok">OK</i>Cleared. Trainer note added
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Scope Note */}
        <div className="scope">
          <div className="w">
            <span>
              <b>PROTOTYPE</b> water-pipe leak probe
            </span>
            <span>
              <b>PROPOSED</b> gas · welding · electrical modules
            </span>
            <span>Scene is an illustration, not live data</span>
          </div>
        </div>
      </div>
    </div>
  );
};
