import 'package:flutter/material.dart';

class TemplateWidget extends StatelessWidget {
  const TemplateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9).withOpacity(0.98), // subtle paper softness
      body: SafeArea(
        child: Column(
          children: [

            // ───────────────── HEADER (8%) ─────────────────
            SizedBox(
              height: size.height * 0.08,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Form Name',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800, // printed ink title
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),

            // ❌ HEADER DIVIDER REMOVED (important for sticker feel)

            // ──────────────── SCROLLABLE CONTENT ────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    10,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400, // ✏️ pencil feel
                          color: Color(0xFF111827),
                        ),
                        decoration: _dec('Field ${index + 1}'),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            _softDivider(), // footer boundary only

            // ───────────────── FOOTER (8%) ─────────────────
            SizedBox(
              height: size.height * 0.08,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 32, // 👈 slight inward offset (less rigid)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _pillButton(
                      label: 'Close',
                      background: const Color(0xFFE5E7EB),
                      foreground: const Color(0xFF111827),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 12),
                    _pillButton(
                      label: 'Save',
                      background: const Color(0xFF111827),
                      foreground: Colors.white,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── STICKER HELPERS ─────────────────

  static Divider _softDivider() => const Divider(
        height: 1,
        thickness: 0.6,
        color: Color(0xFFEDEFF2), // whisper-soft
      );

  static InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF9FAFB), // softer than pure white
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

        // ❌ NO BORDERS — EVER
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  // ───────────────── PILL BUTTON (INK STYLE) ─────────────────
  static Widget _pillButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      splashColor: Colors.black12, // ink splash, not glow
      highlightColor: Colors.transparent,
      onTap: onPressed,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}