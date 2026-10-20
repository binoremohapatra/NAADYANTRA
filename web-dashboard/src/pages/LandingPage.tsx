import React, { useEffect } from 'react';
import '../styles/landing.css';
import { LandingHeader } from '../components/landing/LandingHeader';
import { StoryScene } from '../components/landing/StoryScene';
import { HazardFrames } from '../components/landing/HazardFrames';
import { FilmStrip } from '../components/landing/FilmStrip';
import { TrainerScreenPreview } from '../components/landing/TrainerScreenPreview';
import { FinaleSection } from '../components/landing/FinaleSection';

export const LandingPage: React.FC = () => {
  useEffect(() => {
    // Ensure title matches concept and product
    const prevTitle = document.title;
    document.title = 'HAZEGUARD — Cinematic Industrial Safety Story';

    return () => {
      document.title = prevTitle;
    };
  }, []);

  return (
    <main className="hg-landing" id="top">
      <LandingHeader />
      <StoryScene />
      <HazardFrames />
      <FilmStrip />
      <TrainerScreenPreview />
      <FinaleSection />
    </main>
  );
};

export default LandingPage;
