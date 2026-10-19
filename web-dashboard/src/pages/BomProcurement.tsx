import { useState } from 'react';

interface BomItem {
  id: string;
  subsystem: string;
  description: string;
  partSpec: string;
  qty: number;
  interface: string;
  voltage: string;
  unitCostInr: number;
  engineeringStatus: 'DESIGN PROPOSED' | 'CAD REVIEWED' | 'OPTIONAL ADDITION';
}

const BOM_ITEMS: BomItem[] = [
  {
    id: '01',
    subsystem: 'Compute & Radio',
    description: 'ESP32-S3 DevKitC-1 (or ESP32-WROOM-32)',
    partSpec: 'ESP32-S3-WROOM-1-N8R2 (Dual-Core 240MHz, 8MB Flash, 2MB PSRAM, Wi-Fi 4 + BLE 5)',
    qty: 1,
    interface: 'Native USB-C / UART / GPIO',
    voltage: '3.3V (5V VBUS in)',
    unitCostInr: 480,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '02',
    subsystem: 'Acoustic Sensing',
    description: 'Brass Contact Piezoelectric Sensor',
    partSpec: '27mm Brass Acoustic Disc Element with acoustic wave coupling cone',
    qty: 1,
    interface: 'Analog Single-Ended (to Op-Amp)',
    voltage: 'Passive (piezo-generated)',
    unitCostInr: 35,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '03',
    subsystem: 'Analog Front-End',
    description: 'Dual Rail-to-Rail Operational Amplifier',
    partSpec: 'Microchip MCP6002-E/P (Dual 1.8V-6V RRIO, 1MHz GBWP, 1pA bias; Sallen-Key LPF fc~1.6kHz)',
    qty: 1,
    interface: 'ADC1 (ESP32-S3 GPIO 4 / Classic GPIO 34)',
    voltage: '3.3V Single Supply (1.65V Virtual Ground)',
    unitCostInr: 38,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '04',
    subsystem: 'Environmental',
    description: 'Combustible Gas Sensor Module',
    partSpec: 'MQ-2 Gas Module with 5.0V heater and 15k/10k 1% divider (signal <= 2.13V into linear ADC) + BAT54S clamp',
    qty: 1,
    interface: 'ADC1 (ESP32-S3 GPIO 5 / Classic GPIO 35)',
    voltage: '5.0V Heater, 2.13V Max Signal',
    unitCostInr: 140,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '05',
    subsystem: 'Surface Moisture',
    description: 'Dual-Prong Liquid Conduction Probe',
    partSpec: 'Gated Interleaved PCB Trace Probe with GPIO excitation switch & 100kΩ pull-down',
    qty: 1,
    interface: 'ADC1 (ESP32-S3 GPIO 6 / Classic GPIO 32) + Gating GPIO 10 (S3)',
    voltage: '3.3V Pulsed (50ms excitation)',
    unitCostInr: 60,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '06',
    subsystem: 'Thermal Safety',
    description: 'Contactless Infrared Pyrometer',
    partSpec: 'MLX90614-ESF-BAA Factory Calibrated Pyrometer (0.5°C accuracy)',
    qty: 1,
    interface: 'I2C (SDA: GPIO 8, SCL: GPIO 9 @ 100kHz)',
    voltage: '3.3V',
    unitCostInr: 420,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '07',
    subsystem: 'Visual Telemetry',
    description: '0.96" Monochrome Display',
    partSpec: 'SSD1306 128x64 OLED Display Module',
    qty: 1,
    interface: 'I2C (Shared bus with Pyrometer, addr 0x3C)',
    voltage: '3.3V',
    unitCostInr: 165,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '08',
    subsystem: 'Actuation / Alarm',
    description: 'Haptic Vibration Motor & Piezo Buzzer',
    partSpec: '1027 ERM Coin Vibration Motor + 5V Active Buzzer driven via 2N2222 NPN Transistors',
    qty: 1,
    interface: 'GPIO 15, 16 (S3) / GPIO 25, 26 (Classic)',
    voltage: '3.3V - 5V',
    unitCostInr: 55,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '09',
    subsystem: 'Status Indicators',
    description: 'Tri-Color Diagnostic LEDs',
    partSpec: '3mm Industrial LEDs (Green, Amber, Red) with 330Ω ballast resistors',
    qty: 3,
    interface: 'GPIO 17, 18, 21 (S3) / GPIO 27, 14, 13 (Classic)',
    voltage: '3.3V',
    unitCostInr: 15,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '10',
    subsystem: 'Power System',
    description: 'Li-Ion Battery & Power Management',
    partSpec: '3.7V 1200mAh LiPo + DW01A/8205A PCM + TP4056 Type-C Charger + MT3608 Boost + AP2112K LDO',
    qty: 1,
    interface: 'Battery JST-PH 2.0mm connector',
    voltage: '3.7V nom (4.2V max)',
    unitCostInr: 290,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '11',
    subsystem: 'Enclosure',
    description: 'Ergonomic Wearable Forearm / Belt Case',
    partSpec: '3D Printed PETG (Impact-resistant, chemical-tolerant) with acoustic isolation gasket',
    qty: 1,
    interface: 'Mechanical wearable',
    voltage: 'N/A',
    unitCostInr: 180,
    engineeringStatus: 'CAD REVIEWED',
  },
  {
    id: '12',
    subsystem: 'Fasteners & Wiring',
    description: 'Hookup Wire, Connectors, Diodes & Strap',
    partSpec: '26 AWG silicone wire, JST headers, BAT54S dual Schottky clamps, 15k/10k resistors, strap',
    qty: 1,
    interface: 'Mechanical / Electrical',
    voltage: 'N/A',
    unitCostInr: 95,
    engineeringStatus: 'DESIGN PROPOSED',
  },
  {
    id: '13',
    subsystem: 'Acoustic (Optional)',
    description: 'Ambient Noise Reference Microphone',
    partSpec: 'MAX4466 (or MAX9814) Electret Mic Module with adjustable gain trimmer (differential subtraction)',
    qty: 1,
    interface: 'ADC1 (ESP32-S3 GPIO 7 / Classic GPIO 39)',
    voltage: '3.3V',
    unitCostInr: 120,
    engineeringStatus: 'OPTIONAL ADDITION',
  },
  {
    id: '14',
    subsystem: 'Optical (Optional)',
    description: 'Analog UV Radiometer',
    partSpec: 'GUVA-S12SD UV photodiode module with analog output (200nm - 370nm band)',
    qty: 1,
    interface: 'ADC1 (Classic GPIO 36 / S3 GPIO 1)',
    voltage: '3.3V',
    unitCostInr: 145,
    engineeringStatus: 'OPTIONAL ADDITION',
  },
  {
    id: '15',
    subsystem: 'Ranging (Optional)',
    description: 'Time-of-Flight Distance Sensor',
    partSpec: 'VL53L0X Laser Ranging Sensor Module (I2C addr 0x29)',
    qty: 1,
    interface: 'I2C (Shared Bus)',
    voltage: '3.3V',
    unitCostInr: 210,
    engineeringStatus: 'OPTIONAL ADDITION',
  },
];

export default function BomProcurement() {
  const [currency, setCurrency] = useState<'INR' | 'USD'>('INR');
  const usdRate = 83.1; // 1 USD = 83.1 INR (Oct 2026 indicative)

  const coreItems = BOM_ITEMS.filter((i) => !['13', '14', '15'].includes(i.id));
  const coreTotalInr = coreItems.reduce((acc, item) => acc + item.unitCostInr, 0);
  const contingencyInr = Math.round(coreTotalInr * 0.15);
  const grandTotalInr = coreTotalInr + contingencyInr;

  const formatCost = (inr: number) => {
    if (currency === 'USD') {
      return `$${(inr / usdRate).toFixed(2)}`;
    }
    return `₹${inr.toLocaleString('en-IN')}`;
  };

  const exportCsv = () => {
    const headers = ['Item #', 'Subsystem', 'Description', 'Specification', 'Qty', 'Interface', 'Voltage', 'Unit Cost (INR)', 'Unit Cost (USD)', 'Status'];
    const rows = BOM_ITEMS.map((item) => [
      item.id,
      `"${item.subsystem}"`,
      `"${item.description}"`,
      `"${item.partSpec.replace(/"/g, '""')}"`,
      item.qty,
      `"${item.interface}"`,
      `"${item.voltage}"`,
      item.unitCostInr,
      (item.unitCostInr / usdRate).toFixed(2),
      item.engineeringStatus,
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `naadyantra_hardware_bom_oct2026.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div>
      <div className="hg-page-header">
        <div>
          <h1 className="hg-page-title">Hardware Bill of Materials (BOM) &amp; Cost Reference</h1>
          <p className="hg-page-subtitle">
            Low-cost diagnostic sensing wearable architecture ($&lt; $35 USD / ₹2,800 INR prototype target)
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <div className="hg-tabs">
            <button
              className={`hg-tab${currency === 'INR' ? ' active' : ''}`}
              onClick={() => setCurrency('INR')}
            >
              INR (₹)
            </button>
            <button
              className={`hg-tab${currency === 'USD' ? ' active' : ''}`}
              onClick={() => setCurrency('USD')}
            >
              USD ($)
            </button>
          </div>
          <button className="hg-btn hg-btn-primary" onClick={exportCsv}>
            <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
              <path d="M6.5 1v8M3.5 6.5l3 3 3-3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M1 11h11" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
            </svg>
            Export BOM CSV
          </button>
        </div>
      </div>

      {/* Pricing Baseline Notice */}
      <div
        className="hg-card"
        style={{
          marginBottom: 20,
          padding: '14px 20px',
          background: 'var(--color-pure-white)',
          borderLeft: '4px solid var(--color-burnt-orange)',
        }}
      >
        <div style={{ fontWeight: 600, fontSize: 13, color: 'var(--color-carbon)' }}>
          Pricing Baseline &amp; Hardware Status Disclosure:
        </div>
        <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', marginTop: 4, lineHeight: 1.5 }}>
          Indicative procurement rates as of <strong>October 2026</strong> based on standard Indian electronics distributors
          (Robu.in, ElectronicsComp, Component's Bazaar) and volume reel distributors (LCSC, Mouser India).
          Physical assembly, PCB etching, and bench calibration remain pending component procurement.
          All schematics and parts are marked <strong>DESIGN PROPOSED / DOCUMENT REVIEWED</strong>.
        </p>
      </div>

      {/* Cost Summary Cards */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: 14,
          marginBottom: 24,
        }}
      >
        <div className="hg-card" style={{ padding: '16px 20px' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>
            Core Functional Prototype
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--color-carbon)', marginTop: 4 }}>
            {formatCost(coreTotalInr - 420)}
          </div>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
            Items 01–05, 07–12 (Piezo, MQ-2, Moisture, OLED, ESP32-S3, LiPo)
          </div>
        </div>

        <div className="hg-card" style={{ padding: '16px 20px', borderLeft: '4px solid var(--color-burnt-orange)' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>
            With IR Pyrometer (Item 06)
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--color-burnt-orange)', marginTop: 4 }}>
            {formatCost(coreTotalInr)}
          </div>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
            Fitted MLX90614 Contactless Pyrometer
          </div>
        </div>

        <div className="hg-card" style={{ padding: '16px 20px' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>
            Single Prototype + 15% Buffer
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--color-carbon)', marginTop: 4 }}>
            {formatCost(grandTotalInr)}
          </div>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
            Includes 15% shipping &amp; prototype contingency
          </div>
        </div>

        <div className="hg-card" style={{ padding: '16px 20px' }}>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', textTransform: 'uppercase' }}>
            Volume Batch Target (@ 100 Units)
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#16a34a', marginTop: 4 }}>
            {formatCost(1480)}
          </div>
          <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 4 }}>
            Custom PCBA + SMT pick-and-place batch tooling
          </div>
        </div>
      </div>

      {/* Itemized BOM Table */}
      <div className="hg-card" style={{ padding: 0, overflow: 'hidden', marginBottom: 24 }}>
        <div style={{ padding: '14px 20px', borderBottom: '1px solid var(--color-warm-stone)' }}>
          <h2 style={{ fontSize: 15, fontWeight: 700, color: 'var(--color-carbon)', margin: 0 }}>
            Itemized Component Breakdown (Core Rig &amp; Optional Additions)
          </h2>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table className="hg-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Subsystem</th>
                <th>Component Description &amp; Specification</th>
                <th>Qty</th>
                <th>Electrical Interface</th>
                <th>Operating Voltage</th>
                <th>Unit Cost ({currency})</th>
                <th>Engineering Status</th>
              </tr>
            </thead>
            <tbody>
              {BOM_ITEMS.map((item) => (
                <tr key={item.id} style={{ opacity: item.engineeringStatus === 'OPTIONAL ADDITION' ? 0.75 : 1 }}>
                  <td>
                    <span className="hg-code">{item.id}</span>
                  </td>
                  <td>
                    <strong>{item.subsystem}</strong>
                  </td>
                  <td>
                    <div style={{ fontWeight: 600, color: 'var(--color-carbon)' }}>{item.description}</div>
                    <div style={{ fontSize: 11, color: 'var(--color-warm-graphite)', marginTop: 2 }}>{item.partSpec}</div>
                  </td>
                  <td style={{ fontFamily: 'var(--font-mono)' }}>{item.qty}</td>
                  <td style={{ fontSize: 11, fontFamily: 'var(--font-mono)' }}>{item.interface}</td>
                  <td style={{ fontSize: 11, fontFamily: 'var(--font-mono)' }}>{item.voltage}</td>
                  <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 700 }}>
                    {formatCost(item.unitCostInr)}
                  </td>
                  <td>
                    {item.engineeringStatus === 'OPTIONAL ADDITION' ? (
                      <span className="hg-badge hg-badge-neutral" style={{ fontSize: 10 }}>OPTIONAL</span>
                    ) : item.engineeringStatus === 'CAD REVIEWED' ? (
                      <span className="hg-badge hg-badge-caution" style={{ fontSize: 10 }}>CAD REVIEWED</span>
                    ) : (
                      <span className="hg-badge hg-badge-ok" style={{ fontSize: 10 }}>SCHEMATIC AUDITED</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Engineering Sourcing Rationales */}
      <div className="hg-card" style={{ padding: 20 }}>
        <h2 style={{ fontSize: 16, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 16 }}>
          Engineering Audit &amp; Hardware Sourcing Rationale
        </h2>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16 }}>
          {/* 1. Op-Amp Selection */}
          <div style={{ background: 'var(--color-ivory)', padding: 16, borderRadius: 6 }}>
            <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 6 }}>
              1. Rejection of TL072 on 3.3V Single Supply
            </h3>
            <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.5 }}>
              The classic TL072 JFET operational amplifier specifies an absolute minimum supply of <strong>7.0V (±3.5V)</strong>.
              On a 3.3V single-supply rail, internal biasing current mirrors cannot turn on. LM358 has an output high limit of{' '}
              V_OH &le; V_CC - 1.5V = 1.8V, leaving only 150mV of positive dynamic range above a 1.65V mid-rail bias.
              We selected the <strong>Microchip MCP6002</strong> with Rail-to-Rail Input and Output (RRIO, 1.8V–6.0V), swinging within 25mV of rails
              and 1pA CMOS input bias that prevents loading high-impedance piezo crystals.
            </p>
          </div>

          {/* 2. Anti-Aliasing Filter */}
          <div style={{ background: 'var(--color-ivory)', padding: 16, borderRadius: 6 }}>
            <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 6 }}>
              2. Sallen-Key 2nd-Order Anti-Aliasing Filter
            </h3>
            <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.5 }}>
              Active 2nd-order Sallen-Key low-pass filter (R1 = R2 = 10 kΩ, C1 = 15 nF, C2 = 6.8 nF) yields
              cutoff f0 = 1576 Hz and Q = 0.7425. Passband 0 - 1150 Hz (&le; -0.75 dB); down -5.18 dB at Nyquist (fN = 2000 Hz);
              down -16.16 dB at sampling frequency fs = 4000 Hz. If workshop noise creates aliasing, firmware sampling will be raised to 8 kHz with digital decimation.
            </p>
          </div>

          {/* 3. MQ-2 Precision Divider */}
          <div style={{ background: 'var(--color-ivory)', padding: 16, borderRadius: 6 }}>
            <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 6 }}>
              3. MQ-2 5V Heater &amp; Precision ADC Divider
            </h3>
            <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.5 }}>
              MQ-2 requires a dedicated <strong>5.0V heater supply</strong> (VH = 5.0V &plusmn; 0.1V, consuming ~805 mW / 161 mA)
              drawn from the MT3608 boost converter. Precision <strong>15kΩ / 10kΩ 1% divider</strong> scales the 0–5.25V sensor module output
              down to &le; 2.125V, safely inside the linear window of ESP32 ADC (150mV - 2.45V) with +325mV margin, protected by a BAT54S dual Schottky clamp.
            </p>
          </div>

          {/* 4. Pulsed Gated Moisture */}
          <div style={{ background: 'var(--color-ivory)', padding: 16, borderRadius: 6 }}>
            <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 6 }}>
              4. Pulsed Gated Conduction (Corrosion Prevention)
            </h3>
            <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.5 }}>
              Continuous DC excitation on liquid sensing probes causes rapid electrolytic oxidation and copper trace erosion within hours.
              NAADYANTRA implements pulsed gating: GPIO 10 activates probe excitation for only <strong>50ms</strong> immediately prior to ADC sampling,
              then pulls low. This extends probe electrode lifespan indefinitely and eliminates replacement consumable costs.
            </p>
          </div>

          {/* 5. Power Topology */}
          <div style={{ background: 'var(--color-ivory)', padding: 16, borderRadius: 6 }}>
            <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 6 }}>
              5. Power Topology &amp; Battery Autonomy
            </h3>
            <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.5 }}>
              MT3608 asynchronous step-up boost converter (&eta; &asymp; 85%) feeds the 5V heater rail.
              TP4056 Type-C module handles 1S LiPo charging. Nominal system draw at 3.7V is 433.4 mA (1.60 W), with peak 455 mA during haptic vibration.
              A 1200mAh LiPo cell (usable 85% ~ 1020 mAh) yields &asymp; 2.24 hours continuous runtime in active sniffing mode (provisional pending bench discharge tests).
            </p>
          </div>

          {/* 6. Zero Vendor Cloud Lock-In */}
          <div style={{ background: 'var(--color-ivory)', padding: 16, borderRadius: 6 }}>
            <h3 style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-carbon)', marginBottom: 6 }}>
              6. Open-Source Ecosystem &amp; Zero Cloud Licensing
            </h3>
            <p style={{ fontSize: 12, color: 'var(--color-warm-graphite)', lineHeight: 1.5 }}>
              Zero proprietary recurring licensing costs. Built with open-source firmware (ESP-IDF / Arduino C++),
              FastAPI backend deployable on low-cost Linux containers, and standard SQLite / PostgreSQL databases.
              Designed specifically for deployment in Government ITIs and vocational skill institutes across India.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
