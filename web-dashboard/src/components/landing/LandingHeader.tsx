import React from 'react';
import { Link } from 'react-router-dom';

export const LandingHeader: React.FC = () => {
  return (
    <div className="cbar" id="top">
      <div className="w">
        <b>Concept 05</b>
        <span>Cinematic Industrial Storytelling</span>
        <em>Design preview, not the production site</em>
        <Link to="/dashboard" className="cbar-link" aria-label="Open trainer dashboard">
          Open Console →
        </Link>
      </div>
    </div>
  );
};
