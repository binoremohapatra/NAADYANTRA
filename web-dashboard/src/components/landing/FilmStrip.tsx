import React, { useRef } from 'react';

const BEATS = [
  {
    beat: 'BEAT 1',
    phase: 'SENSE',
    title: 'Sense',
    desc: 'The probe or module reads the signal it was built for.',
    svg: (
      <svg viewBox="0 0 200 70" aria-hidden="true">
        <path
          d="M0 35C20 30 30 40 50 34S80 30 100 34 112 8 124 6 140 30 160 34 190 36 200 35"
          fill="none"
          stroke="#FF6A2B"
          strokeWidth="2"
        />
      </svg>
    ),
  },
  {
    beat: 'BEAT 2',
    phase: 'EVALUATE',
    title: 'Evaluate',
    desc: 'Readings are checked against the early-warning and danger lines.',
    svg: (
      <svg viewBox="0 0 200 70" aria-hidden="true">
        <path d="M0 22H200" stroke="#F2A20C" strokeDasharray="6 5" />
        <path
          d="M0 52C40 50 60 54 90 46S120 14 150 12 190 40 200 44"
          fill="none"
          stroke="#FF6A2B"
          strokeWidth="2"
        />
      </svg>
    ),
  },
  {
    beat: 'BEAT 3',
    phase: 'ALERT',
    title: 'Alert',
    desc: 'A physical alert reaches the trainee at once.',
    svg: (
      <svg viewBox="0 0 200 70" aria-hidden="true">
        <circle cx="100" cy="35" r="8" fill="#FF6A2B" />
        <circle cx="100" cy="35" r="18" fill="none" stroke="#FF6A2B" opacity=".6" />
        <circle cx="100" cy="35" r="30" fill="none" stroke="#FF6A2B" opacity=".3" />
      </svg>
    ),
  },
  {
    beat: 'BEAT 4',
    phase: 'GUIDE',
    title: 'Guide',
    desc: 'Plain steps tell the trainee what to do next.',
    svg: (
      <svg viewBox="0 0 200 70" aria-hidden="true">
        <g fill="none" stroke="#F3ECE3" strokeWidth="1.5">
          <rect x="40" y="10" width="120" height="14" />
          <rect x="40" y="30" width="120" height="14" />
          <rect x="40" y="50" width="120" height="14" />
        </g>
        <circle cx="52" cy="17" r="3" fill="#FF6A2B" />
      </svg>
    ),
  },
  {
    beat: 'BEAT 5',
    phase: 'RECORD',
    title: 'Record',
    desc: 'Each event is logged with its time and zone.',
    svg: (
      <svg viewBox="0 0 200 70" aria-hidden="true">
        <path d="M10 35H190" stroke="#4a3d35" />
        <g fill="#FF6A2B">
          <circle cx="50" cy="35" r="5" />
          <circle cx="110" cy="35" r="5" />
          <circle cx="160" cy="35" r="5" />
        </g>
      </svg>
    ),
  },
  {
    beat: 'BEAT 6',
    phase: 'REVIEW',
    title: 'Review',
    desc: 'The trainer gives structured feedback on every event.',
    svg: (
      <svg viewBox="0 0 200 70" aria-hidden="true">
        <rect x="50" y="8" width="100" height="54" fill="none" stroke="#F3ECE3" />
        <path d="M62 24h76M62 36h56M62 48h66" stroke="#FF6A2B" strokeWidth="2" />
      </svg>
    ),
  },
];

export const FilmStrip: React.FC = () => {
  const stripRef = useRef<HTMLDivElement>(null);

  const scrollNext = () => {
    if (!stripRef.current) return;
    stripRef.current.scrollBy({
      left: stripRef.current.clientWidth * 0.7,
      behavior: 'smooth',
    });
  };

  const scrollPrev = () => {
    if (!stripRef.current) return;
    stripRef.current.scrollBy({
      left: -stripRef.current.clientWidth * 0.7,
      behavior: 'smooth',
    });
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowRight') {
      scrollNext();
    } else if (e.key === 'ArrowLeft') {
      scrollPrev();
    }
  };

  return (
    <section className="s" id="how" style={{ background: 'var(--bg2)' }}>
      <div className="w">
        <div className="eyebrow">How it works</div>
        <h3 className="big">
          Six beats,<br />one cut
        </h3>
        <p className="sub">
          Every hazard module follows the same sequence from first reading to trainer feedback.
        </p>

        <div className="stripw">
          <div
            className="strip"
            id="strip"
            ref={stripRef}
            tabIndex={0}
            role="region"
            aria-label="Six steps sequence, scroll sideways or use arrow keys"
            onKeyDown={handleKeyDown}
          >
            {BEATS.map((beat) => (
              <div className="fm" key={beat.beat} tabIndex={0}>
                <div className="hd">
                  <span>{beat.beat}</span>
                  <span>{beat.phase}</span>
                </div>
                <div className="bd">
                  {beat.svg}
                  <h4>{beat.title}</h4>
                  <p>{beat.desc}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="ctrl">
            <button id="prev" aria-label="Previous beats" onClick={scrollPrev}>
              ← PREV
            </button>
            <button id="next" aria-label="Next beats" onClick={scrollNext}>
              NEXT →
            </button>
          </div>
        </div>
      </div>
    </section>
  );
};
