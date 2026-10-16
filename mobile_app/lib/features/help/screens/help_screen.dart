import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/backgrounds/animated_screen_background.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/widgets/industrial_card.dart';
import '../../../shared/widgets/status_pill.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int _selectedCategoryIndex = 0;

  final List<String> _categories = const [
    'ALL TOPICS',
    'HARDWARE & SENSORS',
    'METRICS & FORMULAS',
    'OFFLINE & SYNC',
    'SAFETY COMPLIANCE',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FIELD GUIDE & TROUBLESHOOTING'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'System Version',
            onPressed: () => _showAboutDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedScreenBackground(
        theme: ScreenBackgroundTheme.blueprintIso,
        intensity: 0.7,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Category Filter Pills
            StaggeredEntrance(
              index: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final title = entry.value;
                    final isSelected = _selectedCategoryIndex == idx;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isSelected
                                ? AppColors.pureWhite
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.warmGraphite),
                          ),
                        ),
                        selectedColor: AppColors.burntOrange,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.warmStone.withValues(alpha: 0.3),
                        checkmarkColor: AppColors.pureWhite,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.burntOrange
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.warmStone),
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategoryIndex = idx),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Safety Warning Banner
            StaggeredEntrance(
              index: 1,
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.darkBurntOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.darkBurntOrange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.darkBurntOrange,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VOCATIONAL TRAINING INSTRUMENT ONLY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.darkBurntOrange,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            AppConfig.safetyDisclaimer,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: AppColors.warmGraphite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Troubleshooting Sections
            if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) ...[
              StaggeredEntrance(
                index: 2,
                child: _buildHelpSection(
                  context,
                  title: 'ESP32 HARDWARE & SENSOR STATUS',
                  isDark: isDark,
                  items: [
                    _HelpItem(
                      question: 'How do I identify if the ESP32 node is online?',
                      answer:
                          'A device is ONLINE when the telemetry server receives an active HTTP packet '
                          'within the last 5 minutes. The status beacon will glow solid emerald. '
                          'If no telemetry arrives after 5 minutes, the node transitions to OFFLINE status.',
                      badge: 'HEARTBEAT',
                    ),
                    _HelpItem(
                      question: 'Why are Heat and UV sensors marked DISABLED?',
                      answer:
                          'In the standard NAADYANTRA pipeline acoustic inspection rig, thermal and UV '
                          'photodiodes are de-energized in firmware to maximize ADC sampling frequency '
                          'for the ultrasonic transducer. This is expected behavior and not a fault.',
                      badge: 'FIRMWARE RIG',
                    ),
                    _HelpItem(
                      question: 'Transducer placement on pipe valves',
                      answer:
                          'Mount the acoustic pickup flush against the valve flange or pipe weld seam. '
                          'Use acoustic coupling gel or firm physical pressure. Turbulent gas leak jets '
                          'generate high-frequency friction acoustic emission (38 kHz - 44 kHz).',
                      badge: 'TECHNIQUE',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 2) ...[
              StaggeredEntrance(
                index: 3,
                child: _buildHelpSection(
                  context,
                  title: 'DATA METRICS & MEASUREMENT UNITS',
                  isDark: isDark,
                  items: [
                    _HelpItem(
                      question: 'Acoustic RMS (Root Mean Square)',
                      answer:
                          'Calculated over 1,024 ultrasonic ADC samples. Nominal quiescent pipe '
                          'background RMS ranges from 150 to 400. Orifice pinhole leaks generate '
                          'RMS values exceeding 1,200 to 2,800 depending on line differential pressure.',
                      badge: 'ACOUSTICS',
                    ),
                    _HelpItem(
                      question: 'Gas Reading Semantics',
                      answer:
                          'Gas readings are raw ADC differential baseline counts relative to ambient '
                          'calibration. They are NOT certified ppm or percentage of Lower Explosive '
                          'Limit (%LEL). Always observe safety protocols.',
                      badge: 'GAS DELTA',
                    ),
                    _HelpItem(
                      question: 'Leak Probability Score',
                      answer:
                          'The leak indicator represents an algorithmic classifier score between 0.00 '
                          'and 1.00. Probabilities >= 0.70 trigger a CRITICAL leak alert and highlight '
                          'the incident for trainer rubric verification.',
                      badge: 'MODEL SCORE',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 3) ...[
              StaggeredEntrance(
                index: 4,
                child: _buildHelpSection(
                  context,
                  title: 'OFFLINE MODE & SYNC PROTOCOL',
                  isDark: isDark,
                  items: [
                    _HelpItem(
                      question: 'How does offline caching operate?',
                      answer:
                          'All sessions, device registry entries, and evaluation rubrics are persisted '
                          'locally inside an encrypted SQLite database on the mobile device. '
                          'When field cellular connectivity drops, the workstation continues to render '
                          'cached inspection telemetry.',
                      badge: 'SQLITE CACHE',
                    ),
                    _HelpItem(
                      question: 'How do I verify the server endpoint URL?',
                      answer:
                          'Navigate to the Settings tab to inspect or update the Backend API URL. '
                          'For local network emulator testing, configure http://10.0.2.2:8000. '
                          'For production cloud deployments, use https://naadyantra.onrender.com.',
                      badge: 'NETWORK',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 4) ...[
              StaggeredEntrance(
                index: 5,
                child: _buildHelpSection(
                  context,
                  title: 'SAFETY & COMPLIANCE DIRECTIVES',
                  isDark: isDark,
                  items: [
                    _HelpItem(
                      question: 'Hazardous area operations',
                      answer:
                          'NAADYANTRA experimental hardware is NOT intrinsically safe (IS) rated '
                          'for ATEX Zone 0 or Zone 1 combustible atmospheres. It is strictly designated '
                          'for vocational training rigs and cold non-flammable compressed air pipelines.',
                      badge: 'SAFETY RIG',
                    ),
                    _HelpItem(
                      question: 'Trainer rubric certification',
                      answer:
                          'Assessment scores recorded by the mobile app reflect automated sensor telemetry '
                          'evidence. Final competency certifications require physical inspection verification '
                          'by a designated NDT / Pipeline Maintenance Trainer.',
                      badge: 'EVALUATION',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection(
    BuildContext context, {
    required String title,
    required bool isDark,
    required List<_HelpItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.warmGraphite,
            ),
          ),
        ),
        IndustrialCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isLast = idx == items.length - 1;

              return Column(
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(
                        item.question,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: StatusPill(
                        label: item.badge,
                        type: StatusType.neutral,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.industrialIvory,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.warmStone,
                            ),
                          ),
                          child: Text(
                            item.answer,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.warmGraphite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : AppColors.warmStone,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('NAADYANTRA TECHNICAL SPEC'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart India Hackathon 2026 (PS SIH26244)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Acoustic Rig: ESP32-S3 Dual-Core @ 240MHz\n'
              'Sampling Window: 1024-sample FFT & RMS\n'
              'Mobile Platform: Flutter 3.47 / Clean Architecture\n'
              'Backend Gateway: FastAPI / SQLite / Alembic',
              style: TextStyle(fontSize: 11, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _HelpItem {
  final String question;
  final String answer;
  final String badge;

  const _HelpItem({
    required this.question,
    required this.answer,
    required this.badge,
  });
}
