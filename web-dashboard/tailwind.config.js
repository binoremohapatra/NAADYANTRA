/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // HazGuard brand colors — cinematic light industrial
        industrialIvory: '#F7F5F0',   // primary app canvas
        offWhite: '#F7F5F0',           // alias for bg-offWhite utilities
        obsidian: '#252525',           // carbon — primary headings
        graphite: '#252525',
        burntOrange: '#F07842',        // brand accent
        // Supporting palette
        pureWhite: '#FFFFFF',
        warmStone: '#E9E5DE',
        warmGraphite: '#716D67',
        darkBurntOrange: '#A94E29',
        softSand: '#D8C9BA',
        // Alert colours
        alertOk: '#4CAF50',
        alertCaution: '#FF9800',
        alertDanger: '#F44336',
      },
    },
  },
  plugins: [],
}
