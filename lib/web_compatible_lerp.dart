
double lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return 0.0;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}