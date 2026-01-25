import 'package:intl/intl.dart';

class DateUtilsX {
  static String formatShort(DateTime date) => DateFormat('dd/MM').format(date);
  static String weekdayShort(DateTime date) => DateFormat('E', 'da').format(date);
  static String formatLong(DateTime date) => DateFormat('d. MMMM yyyy', 'da').format(date);
} 