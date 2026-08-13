#!/usr/bin/awk -f
# Approximate sunrise/sunset (UTC minutes from midnight).
# Usage: awk -f sun.awk -- lat lon yyyy mm dd
# Prints: sunrise_min sunset_min
BEGIN {
  if (ARGC < 6) { print "0 0"; exit }
  lat = ARGV[1]+0; lon = ARGV[2]+0
  y = ARGV[3]+0; m = ARGV[4]+0; d = ARGV[5]+0
  PI = 3.14159265358979
  rad = PI/180
  # day of year
  N1 = floor(275*m/9)
  N2 = floor((m+9)/12)
  N3 = (1+floor((y-4*floor(y/4)+2)/3))
  N = N1-(N2*N3)+d-30
  # approx solar noon / declination (NOAA-ish simplified)
  lngHour = lon/15
  t_rise = N + ((6-lngHour)/24)
  t_set  = N + ((18-lngHour)/24)
  M_r = (0.9856*t_rise)-3.289
  M_s = (0.9856*t_set)-3.289
  L_r = M_r+(1.916*sin(M_r*rad))+(0.020*sin(2*M_r*rad))+282.634
  L_s = M_s+(1.916*sin(M_s*rad))+(0.020*sin(2*M_s*rad))+282.634
  while (L_r >= 360) L_r -= 360; while (L_r < 0) L_r += 360
  while (L_s >= 360) L_s -= 360; while (L_s < 0) L_s += 360
  # BusyBox 1.11.2 on mPower crashes in its built-in atan2().
  RA_r = atan2safe(0.91764*sin(L_r*rad), cos(L_r*rad))/rad
  RA_s = atan2safe(0.91764*sin(L_s*rad), cos(L_s*rad))/rad
  while (RA_r < 0) RA_r += 360; while (RA_s < 0) RA_s += 360
  Lq_r = floor(L_r/90)*90; RAq_r = floor(RA_r/90)*90; RA_r = RA_r + (Lq_r-RAq_r); RA_r /= 15
  Lq_s = floor(L_s/90)*90; RAq_s = floor(RA_s/90)*90; RA_s = RA_s + (Lq_s-RAq_s); RA_s /= 15
  sinDec_r = 0.39782*sin(L_r*rad); cosDec_r = cos(asin(sinDec_r))
  sinDec_s = 0.39782*sin(L_s*rad); cosDec_s = cos(asin(sinDec_s))
  cosH_r = (cos(90.833*rad)-sinDec_r*sin(lat*rad))/(cosDec_r*cos(lat*rad))
  cosH_s = (cos(90.833*rad)-sinDec_s*sin(lat*rad))/(cosDec_s*cos(lat*rad))
  if (cosH_r > 1 || cosH_r < -1 || cosH_s > 1 || cosH_s < -1) { print "0 0"; exit }
  H_r = 360 - (atan2safe(sqrt(1-cosH_r*cosH_r), cosH_r)/rad); H_r /= 15
  H_s = (atan2safe(sqrt(1-cosH_s*cosH_s), cosH_s)/rad); H_s /= 15
  T_r = H_r + RA_r - (0.06571*t_rise) - 6.622
  T_s = H_s + RA_s - (0.06571*t_set) - 6.622
  UT_r = T_r - lngHour; UT_s = T_s - lngHour
  while (UT_r < 0) UT_r += 24; while (UT_r >= 24) UT_r -= 24
  while (UT_s < 0) UT_s += 24; while (UT_s >= 24) UT_s -= 24
  printf "%d %d\n", int(UT_r*60+0.5), int(UT_s*60+0.5)
  # All positional arguments are numeric inputs, not files. BusyBox awk 1.11
  # can crash while trying to process them as filenames after BEGIN.
  exit
}
function floor(x){ return int(x) - (x<0 && x!=int(x)?1:0) }
function atanApprox(x, a, r) {
  a = x < 0 ? -x : x
  if (a > 1) {
    r = PI/2 - (1/a) * (PI/4 + 0.273 * (1 - 1/a))
  } else {
    r = a * (PI/4 + 0.273 * (1-a))
  }
  return x < 0 ? -r : r
}
function atan2safe(y, x) {
  if (x > 0) return atanApprox(y/x)
  if (x < 0) return y >= 0 ? atanApprox(y/x)+PI : atanApprox(y/x)-PI
  return y > 0 ? PI/2 : (y < 0 ? -PI/2 : 0)
}
function asin(x){ return atan2safe(x, sqrt(1-x*x)) }
