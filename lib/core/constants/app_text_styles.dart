import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle h1(Color color) =>
      GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: color);

  static TextStyle h2(Color color) =>
      GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w600, color: color);

  static TextStyle h3(Color color) =>
      GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: color);

  static TextStyle body(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle bodyBold(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle caption(Color color) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
  );
}
