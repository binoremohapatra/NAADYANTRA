import React from 'react';
import { Link } from 'react-router-dom';
import { BRAND_NAME, BRAND_WORKSHOP, BRAND_TEAM } from '../../constants/brand';

export const FinaleSection: React.FC = () => {
  const handleReplay = (e: React.MouseEvent) => {
    e.preventDefault();
    window.scrollTo({
      top: 0,
      behavior: 'smooth',
    });
  };

  return (
    <>
      <section className="fin">
        <div className="w">
          <h3>
            <span className="o">Detect early.</span>
            <span className="ln">Alert clearly.</span>
            <span>Build safer skills.</span>
          </h3>

          <div className="fin-actions">
            <button className="btn" onClick={handleReplay}>
              Replay the film
            </button>
            <Link to="/dashboard" className="btn-secondary">
              Open Dashboard Console →
            </Link>
          </div>
        </div>
      </section>

      <footer>
        <div className="w">
          <span>
            {BRAND_NAME} · {BRAND_WORKSHOP}
          </span>
          <span>{BRAND_TEAM}</span>
        </div>
      </footer>
    </>
  );
};
