import React from 'react';

export const HazardFrames: React.FC = () => {
  return (
    <section className="s" id="hazards">
      <div className="w">
        <div className="eyebrow">Beyond the leak</div>
        <h3 className="big">
          The same story,<br />four hazards
        </h3>
        <p className="sub">
          The pipe-leak probe is the working prototype. Three more modules complete the wider vision.
        </p>

        <div className="frames">
          {/* Frame 1: Pipe Leak (Prototype) */}
          <article className="fr" tabIndex={0} aria-label="Hazard: Pipe leak. The first chapter, and the working prototype.">
            <svg viewBox="0 0 440 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
              <defs>
                <radialGradient id="a1" cx=".5" cy=".6">
                  <stop offset="0" stopColor="#FF6A2B" stopOpacity=".35" />
                  <stop offset="1" stopColor="#FF6A2B" stopOpacity="0" />
                </radialGradient>
              </defs>
              <rect width="440" height="200" fill="#0E0B0A" />
              <circle cx="230" cy="110" r="120" fill="url(#a1)" />
              <rect x="0" y="62" width="440" height="34" fill="#2A2320" />
              <rect x="214" y="54" width="22" height="50" fill="#3a2f2a" />
              <circle cx="225" cy="106" r="4" fill="#FF6A2B" />
              <path d="M225 112v22" stroke="#FF6A2B" strokeWidth="2.5" />
              <circle cx="225" cy="142" r="5" fill="#FF6A2B" />
              <circle className="wv" cx="225" cy="106" r="22" fill="none" stroke="#FF6A2B" />
              <circle className="wv" cx="225" cy="106" r="22" fill="none" stroke="#FF6A2B" />
            </svg>
            <div className="cp">
              <div>
                <h4>Pipe leak</h4>
                <small>The first chapter, and the working prototype.</small>
              </div>
              <span className="chip pr">PROTOTYPE</span>
            </div>
          </article>

          {/* Frame 2: Gas Monitoring (Proposed) */}
          <article className="fr" tabIndex={0} aria-label="Hazard: Gas monitoring. The air nobody can see.">
            <svg viewBox="0 0 440 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
              <rect width="440" height="200" fill="#0E0B0A" />
              <rect x="40" y="50" width="40" height="110" rx="12" fill="#2A2320" stroke="#4a3d35" />
              <g fill="#F2A20C">
                <circle cx="120" cy="80" r="5" opacity=".9" />
                <circle cx="160" cy="64" r="8" opacity=".6" />
                <circle cx="215" cy="92" r="11" opacity=".4" />
                <circle cx="270" cy="70" r="15" opacity=".26" />
                <circle cx="330" cy="104" r="20" opacity=".16" />
                <circle cx="190" cy="130" r="7" opacity=".5" />
                <circle cx="260" cy="140" r="12" opacity=".2" />
              </g>
            </svg>
            <div className="cp">
              <div>
                <h4>Gas monitoring</h4>
                <small>The air nobody can see.</small>
              </div>
              <span className="chip" style={{ border: '1px solid #6b5d52', color: '#A0968B' }}>
                PROPOSED
              </span>
            </div>
          </article>

          {/* Frame 3: Welding Safety (Proposed) */}
          <article className="fr" tabIndex={0} aria-label="Hazard: Welding safety. Before the arc is struck.">
            <svg viewBox="0 0 440 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
              <defs>
                <radialGradient id="a3" cx=".5" cy=".7">
                  <stop offset="0" stopColor="#FFD9A8" stopOpacity=".5" />
                  <stop offset="1" stopColor="#FF6A2B" stopOpacity="0" />
                </radialGradient>
              </defs>
              <rect width="440" height="200" fill="#0E0B0A" />
              <circle cx="220" cy="150" r="110" fill="url(#a3)" />
              <path d="M40 156h360" stroke="#4a3d35" strokeWidth="8" />
              <path d="M226 44l-14 44 30 12-20 52" fill="none" stroke="#FFE2BC" strokeWidth="3" />
              <g stroke="#FF6A2B" strokeWidth="2">
                <path d="M220 150l-70-52M220 150l86-70M220 150l-110 -4M220 150l120 12M220 150l-14-110" />
              </g>
            </svg>
            <div className="cp">
              <div>
                <h4>Welding safety</h4>
                <small>Before the arc is struck.</small>
              </div>
              <span className="chip" style={{ border: '1px solid #6b5d52', color: '#A0968B' }}>
                PROPOSED
              </span>
            </div>
          </article>

          {/* Frame 4: Electrical Hotspots (Proposed) */}
          <article className="fr" tabIndex={0} aria-label="Hazard: Electrical hotspots. Heat before it becomes harm.">
            <svg viewBox="0 0 440 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
              <defs>
                <radialGradient id="a4">
                  <stop offset="0" stopColor="#EE4B3E" />
                  <stop offset=".45" stopColor="#F2A20C" stopOpacity=".55" />
                  <stop offset="1" stopColor="#F2A20C" stopOpacity="0" />
                </radialGradient>
              </defs>
              <rect width="440" height="200" fill="#0E0B0A" />
              <rect x="130" y="24" width="180" height="152" fill="#221C19" stroke="#4a3d35" />
              <circle cx="262" cy="96" r="76" fill="url(#a4)" />
              <g fill="#3a2f2a">
                <rect x="150" y="44" width="38" height="14" />
                <rect x="150" y="76" width="38" height="14" />
                <rect x="150" y="108" width="38" height="14" />
                <rect x="150" y="140" width="38" height="14" />
              </g>
            </svg>
            <div className="cp">
              <div>
                <h4>Electrical hotspots</h4>
                <small>Heat before it becomes harm.</small>
              </div>
              <span className="chip" style={{ border: '1px solid #6b5d52', color: '#A0968B' }}>
                PROPOSED
              </span>
            </div>
          </article>
        </div>
      </div>
    </section>
  );
};
