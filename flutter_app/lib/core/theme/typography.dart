import 'package:flutter/material.dart';

class AppTextStyles {
  static const _fontFamily = 'Arial';

  static const headline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  static const title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(fontFamily: _fontFamily, fontSize: 16);
  static const caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    color: Colors.grey,
  );
}
