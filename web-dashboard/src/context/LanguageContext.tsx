import React, { createContext, useContext, useState } from 'react';

export type Language = 'en' | 'hi';

interface Translations {
  [key: string]: {
    en: string;
    hi: string;
  };
}

export const DICTIONARY: Translations = {
  // Navigation & Shell
  'nav.overview': { en: 'Overview', hi: 'कमांड सेंटर' },
  'nav.feed': { en: 'Live Telemetry Feed', hi: 'लाइव टेलीमेट्री फीड' },
  'nav.diagnostics': { en: 'Diagnostic Workspace', hi: 'डायग्नोस्टिक वर्कस्पेस' },
  'nav.training': { en: 'Training Studio', hi: 'व्यावसायिक प्रशिक्षण स्टूडियो' },
  'nav.devices': { en: 'Devices', hi: 'उपकरण बेड़ा (Fleet)' },
  'nav.sessions': { en: 'Sessions', hi: 'प्रशिक्षण सत्र' },
  'nav.trainees': { en: 'Trainees', hi: 'प्रशिक्षु निर्देशिका' },
  'nav.assessments': { en: 'Assessments', hi: 'कौशल मूल्यांकन (NSQF)' },
  'nav.alerts': { en: 'Alerts', hi: 'खतरे की चेतावनी' },
  'nav.bom': { en: 'Hardware BOM', hi: 'हार्डवेयर लागत सूची (BOM)' },
  'nav.signout': { en: 'Sign Out', hi: 'लॉग आउट' },
  'nav.role': { en: 'Role: Trainer / Assessor', hi: 'भूमिका: प्रशिक्षक / परीक्षक' },

  // Topbar Titles
  'title.overview': { en: 'Command Centre Overview', hi: 'कमांड सेंटर अवलोकन' },
  'title.feed': { en: 'Real-Time Combined Telemetry Feed', hi: 'मल्टी-डिवाइस लाइव टेलीमेट्री फीड' },
  'title.diagnostics': { en: 'Diagnostic Workspace', hi: 'डायग्नोस्टिक वर्कस्पेस' },
  'title.training': { en: 'Vocational Training Studio', hi: 'व्यावसायिक प्रशिक्षण स्टूडियो' },
  'title.devices': { en: 'Device Fleet Management', hi: 'उपकरण बेड़ा प्रबंधन' },
  'title.sessions': { en: 'Training Sessions', hi: 'प्रशिक्षण सत्र लॉग' },
  'title.trainees': { en: 'Trainee Directory', hi: 'प्रशिक्षु निर्देशिका' },
  'title.assessments': { en: 'NSQF Skill Assessments', hi: 'कौशल मूल्यांकन एवं प्रमाणन' },
  'title.alerts': { en: 'Hazard Alerts Log', hi: 'खतरे की चेतावनियां' },
  'title.bom': { en: 'Hardware Procurement & BOM', hi: 'हार्डवेयर खरीद व बीओएम संदर्भ' },

  // Modes & Toggles
  'mode.demo_on': { en: '🧪 Demo Mode: ON', hi: '🧪 डेमो मोड: सक्रिय' },
  'mode.live': { en: 'Live Backend', hi: 'लाइव बैकएंड' },
  'theme.dark': { en: 'Dark Mode', hi: 'डार्क मोड' },
  'theme.light': { en: 'Light Mode', hi: 'लाइट मोड' },
  'lang.switch': { en: 'हिंदी', hi: 'English' },

  // Device & Telemetry Statuses
  'status.online': { en: 'Online', hi: 'सक्रिय (Online)' },
  'status.stale': { en: 'Stale (>60s)', hi: 'विलंबित / पुराना' },
  'status.offline': { en: 'Offline (>5m)', hi: 'ऑफलाइन' },
  'status.unknown': { en: 'Unknown', hi: 'अज्ञात' },
  'status.safe': { en: 'Safe / Normal', hi: 'सुरक्षित / सामान्य' },
  'status.caution': { en: 'Caution', hi: 'सावधानी' },
  'status.danger': { en: 'Danger / Alarm', hi: 'खतरा / अलार्म' },

  // Actions
  'action.refresh': { en: 'Refresh', hi: 'रीफ़्रेश' },
  'action.export_csv': { en: 'Export CSV', hi: 'सीएसवी डाउनलोड' },
  'action.print_report': { en: 'Print / PDF Report', hi: 'प्रिंट / पीडीएफ रिपोर्ट' },
  'action.filter': { en: 'Filter', hi: 'फ़िल्टर' },
  'action.search': { en: 'Search...', hi: 'खोजें...' },
  'action.close': { en: 'Close', hi: 'बंद करें' },
  'action.view_detail': { en: 'View Details', hi: 'विवरण देखें' },
  'action.start_session': { en: 'Start Inspection Session', hi: 'निरीक्षण सत्र शुरू करें' },
  'action.end_session': { en: 'End Session & Evaluate', hi: 'सत्र समाप्त व मूल्यांकन करें' },
  'action.save_assessment': { en: 'Save Assessment', hi: 'मूल्यांकन सहेजें' },
  'action.pause_feed': { en: 'Pause Feed', hi: 'फीड रोकें' },
  'action.resume_feed': { en: 'Resume Feed', hi: 'फीड चालू करें' },

  // Diagnostics & Hazards
  'hazard.acoustic_leak': { en: 'Acoustic Leak Vibration', hi: 'ध्वनिक रिसाव कंपन (Piezo)' },
  'hazard.gas_buildup': { en: 'Combustible Gas Elevation', hi: 'ज्वलनशील गैस वृद्धि (MQ-2)' },
  'hazard.prox_breach': { en: 'Proximity Breach (<150mm)', hi: 'निकटता उल्लंघन (<150mm ToF)' },
  'hazard.arc_flash': { en: 'Optical Flare / Arc Flash', hi: 'ऑप्टिकल फ्लेयर / आर्क फ्लैश' },
  'hazard.heat_overheat': { en: 'Workpiece Overheat', hi: 'वर्कपीस अत्यधिक ताप' },
  'hazard.normal': { en: 'Normal Acoustic / Ambient', hi: 'सामान्य परिवेश' },

  // NSQF Outcomes
  'outcome.competent': { en: 'Demonstrated (Competent)', hi: 'प्रमाणित / सफल (Competent)' },
  'outcome.needs_improvement': { en: 'Needs Improvement', hi: 'सुधार की आवश्यकता' },
  'outcome.not_observed': { en: 'Not Observed', hi: 'अवलोकन नहीं किया गया' },
  'outcome.pending': { en: 'Pending Review', hi: 'समीक्षा लंबित' },

  // Disclaimers
  'disclaimer.title': { en: 'Operational Disclaimers & Safety Notice', hi: 'परिचालन अस्वीकरण एवं सुरक्षा सूचना' },
  'disclaimer.wifi': {
    en: 'Same-Wi-Fi Discovery Limitation: Browser sandboxing prohibits raw subnet packet sweeps. Devices must register outbound to the central registry.',
    hi: 'समान वाई-फाई खोज सीमा: ब्राउज़र सुरक्षा स्थानीय सबनेट पर रॉ पैकेट स्वीप की अनुमति नहीं देती। उपकरणों को सीधे बैकएंड पर पंजीकृत होना आवश्यक है।'
  },
  'disclaimer.nsqf': {
    en: 'Educational diagnostic tool only. Does not confer formal awarding-body NVQ/NCVET accreditation without certified proctoring.',
    hi: 'यह केवल शैक्षणिक डायग्नोस्टिक टूल है। औपचारिक प्रमाणन के लिए अधिकृत परीक्षा केंद्र का अनुमोदन अनिवार्य है।'
  },
  'disclaimer.sensors': {
    en: 'Contact piezo detects local pipe surface vibration only (no acoustic triangulation). MQ-2 readings represent uncalibrated relative gas delta.',
    hi: 'पीजो सेंसर केवल स्थानीय सतह कंपन मापता है (स्थान का त्रिकोणीकरण नहीं)। MQ-2 केवल सापेक्ष गैस ढलान दर्शाता है।'
  }
};

interface LanguageContextType {
  lang: Language;
  setLang: (lang: Language) => void;
  toggleLang: () => void;
  t: (key: string, fallback?: string) => string;
}

const LanguageContext = createContext<LanguageContextType>({
  lang: 'en',
  setLang: () => {},
  toggleLang: () => {},
  t: (key, fallback) => fallback || key,
});

export const LanguageProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [lang, setLangState] = useState<Language>(() => {
    const saved = localStorage.getItem('hg_language');
    return saved === 'hi' ? 'hi' : 'en';
  });

  const setLang = (newLang: Language) => {
    setLangState(newLang);
    localStorage.setItem('hg_language', newLang);
  };

  const toggleLang = () => {
    setLang(lang === 'en' ? 'hi' : 'en');
  };

  const t = (key: string, fallback?: string): string => {
    if (DICTIONARY[key]) {
      return DICTIONARY[key][lang] || fallback || DICTIONARY[key]['en'] || key;
    }
    return fallback || key;
  };

  return (
    <LanguageContext.Provider value={{ lang, setLang, toggleLang, t }}>
      {children}
    </LanguageContext.Provider>
  );
};

export function useLanguage() {
  return useContext(LanguageContext);
}
