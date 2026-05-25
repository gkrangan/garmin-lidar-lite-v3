// LidarMapper.pde — adaptive-precision LIDAR radar display
//
// Close objects (< OUTLINE_CM) get:
//   · Larger dots (size scales inversely with distance)
//   · Outline lines connecting adjacent readings
//   · Longer persistence
//   · Stronger glow
//
// Set PORT_NAME to your Arduino's serial port before running.
// Run once without it set — available ports print to the console.

import processing.serial.*;

// ── CONFIG ────────────────────────────────────────────────────────
final String PORT_NAME = "/dev/cu.usbmodem14101";  // ← change this
final int    BAUD      = 115200;

final int   ANG_MIN    = 15;
final int   ANG_MAX    = 165;
final float DIST_MAX   = 400;   // cm — beyond this is clipped
final float RADAR_R    = 295;   // pixels — arc radius
final float OUTLINE_CM = 150;   // cm — objects closer than this get outlines
final float MAX_GAP_CM = 35;    // cm — max diff between adjacent readings to draw outline

// ── STATE ─────────────────────────────────────────────────────────
Serial  port;
float[] distances = new float[181];
int[]   frameAge  = new int[181];
int     sweepAngle = ANG_MIN;
int     sweepDir   = 1;
float   latestDist = 0;
float   cx, cy;

// ── SETUP ─────────────────────────────────────────────────────────
void setup() {
  size(900, 720);
  cx = width  / 2.0;
  cy = height - 60.0;
  for (int i = 0; i <= 180; i++) { distances[i] = 0; frameAge[i] = 9999; }

  println("Available serial ports:");
  printArray(Serial.list());
  try {
    port = new Serial(this, PORT_NAME, BAUD);
    port.bufferUntil('\n');
  } catch (Exception e) {
    println("Could not open: " + PORT_NAME);
  }
}

// ── DRAW ──────────────────────────────────────────────────────────
void draw() {
  background(0, 8, 0);
  drawGrid();
  drawOutlines();   // object outlines beneath the dots
  drawPoints();
  drawSweepGlow();
  drawSweepLine();
  drawHUD();
  for (int i = 0; i <= 180; i++) frameAge[i]++;
}

// ── COORDINATE HELPERS ────────────────────────────────────────────
float sx(int a, float r) { return cx + cos(-radians(a)) * r; }
float sy(int a, float r) { return cy + sin(-radians(a)) * r; }

// ── GRID ──────────────────────────────────────────────────────────
void drawGrid() {
  strokeWeight(1);
  noFill();

  int[] rings = { 50, 100, 150, 200, 300, 400 };
  for (int rm : rings) {
    if (rm > DIST_MAX) continue;
    float sr = map(rm, 0, DIST_MAX, 0, RADAR_R);
    // Highlight the CLOSE_CM ring
    if (rm == (int)OUTLINE_CM) {
      stroke(60, 100, 30, 200);
      strokeWeight(1.5);
    } else {
      stroke(0, 55, 0, 200);
      strokeWeight(1);
    }
    beginShape();
    for (int a = ANG_MIN; a <= ANG_MAX; a++) vertex(sx(a, sr), sy(a, sr));
    endShape();

    noStroke();
    fill(rm == (int)OUTLINE_CM ? color(90, 160, 50) : color(0, 100, 0), 200);
    textAlign(LEFT, BOTTOM);
    textSize(10);
    text(rm + " cm", sx(ANG_MIN, sr) + 5, sy(ANG_MIN, sr) - 2);
    noFill();
    strokeWeight(1);
  }

  // Angle spokes
  for (int a = ANG_MIN; a <= ANG_MAX; a += 15) {
    stroke(0, 45, 0, 180);
    line(cx, cy, sx(a, RADAR_R), sy(a, RADAR_R));
    noStroke();
    fill(0, 110, 0, 200);
    textAlign(CENTER, CENTER);
    textSize(10);
    text(a + "°", sx(a, RADAR_R + 18), sy(a, RADAR_R + 18));
    noFill();
  }

  // Outer arc
  stroke(0, 35, 0, 140);
  beginShape();
  for (int a = ANG_MIN; a <= ANG_MAX; a++) vertex(sx(a, RADAR_R), sy(a, RADAR_R));
  endShape();

  // Origin dot
  noStroke();
  fill(0, 180, 0);
  ellipse(cx, cy, 7, 7);
}

// ── OBJECT OUTLINES (close range) ────────────────────────────────
void drawOutlines() {
  for (int a = ANG_MIN; a < ANG_MAX; a++) {
    float d1 = distances[a];
    float d2 = distances[a + 1];
    if (d1 <= 0 || d2 <= 0)             continue;
    if (d1 >= OUTLINE_CM || d2 >= OUTLINE_CM) continue;
    if (abs(d1 - d2) > MAX_GAP_CM)      continue;

    int avgAge = (frameAge[a] + frameAge[a + 1]) / 2;
    // Close objects persist longer (600 frames ≈ 10 s at 60 fps)
    int alpha = (int) map(avgAge, 0, 600, 180, 0);
    if (alpha <= 0) continue;

    float sr1 = map(d1, 0, DIST_MAX, 0, RADAR_R);
    float sr2 = map(d2, 0, DIST_MAX, 0, RADAR_R);
    color c = distColor((d1 + d2) / 2);
    stroke(red(c), green(c), blue(c), alpha * 0.7);
    strokeWeight(1.5);
    noFill();
    line(sx(a, sr1), sy(a, sr1), sx(a + 1, sr2), sy(a + 1, sr2));
  }
}

// ── DISTANCE POINTS ───────────────────────────────────────────────
color distColor(float d) {
  float t = constrain(d / DIST_MAX, 0, 1);
  return t < 0.5
    ? lerpColor(color(255, 30, 30), color(255, 210, 0), t * 2)
    : lerpColor(color(255, 210, 0), color(30, 255, 50), (t - 0.5) * 2);
}

void drawPoints() {
  noStroke();
  for (int a = ANG_MIN; a <= ANG_MAX; a++) {
    float d = distances[a];
    if (d <= 0 || d >= DIST_MAX) continue;

    // Close objects persist longer
    int maxAge = (d < OUTLINE_CM) ? 600 : 360;
    int alpha  = (int) map(frameAge[a], 0, maxAge, 255, 0);
    if (alpha <= 0) continue;

    float sr = map(d, 0, DIST_MAX, 0, RADAR_R);
    float px = sx(a, sr);
    float py = sy(a, sr);
    color c  = distColor(d);
    float r  = red(c), g = green(c), b = blue(c);

    // Dot scales with closeness: 4px at max range → 14px at 0
    float dotR = map(d, 0, DIST_MAX, 14, 4);
    // Stronger glow for close readings
    float glowMult = (d < OUTLINE_CM) ? 1.6 : 1.0;

    fill(r, g, b, alpha * 0.12 * glowMult); ellipse(px, py, dotR * 3.5, dotR * 3.5);
    fill(r, g, b, alpha * 0.35 * glowMult); ellipse(px, py, dotR * 2.0, dotR * 2.0);
    fill(r, g, b, alpha);                   ellipse(px, py, dotR,       dotR);
  }
}

// ── SWEEP GLOW ────────────────────────────────────────────────────
void drawSweepGlow() {
  final int TRAIL = 18;
  for (int t = TRAIL; t >= 1; t--) {
    int ta = constrain(sweepAngle - sweepDir * t, ANG_MIN, ANG_MAX);
    stroke(0, 220, 0, (int) map(t, TRAIL, 0, 0, 55));
    strokeWeight(1.5);
    noFill();
    line(cx, cy, sx(ta, RADAR_R), sy(ta, RADAR_R));
  }
}

// ── SWEEP LINE ────────────────────────────────────────────────────
void drawSweepLine() {
  float ex = sx(sweepAngle, RADAR_R);
  float ey = sy(sweepAngle, RADAR_R);
  noFill();
  stroke(0, 255, 0, 35);  strokeWeight(8);   line(cx, cy, ex, ey);
  stroke(0, 255, 0, 75);  strokeWeight(4);   line(cx, cy, ex, ey);
  stroke(0, 255, 0, 210); strokeWeight(1.5); line(cx, cy, ex, ey);
}

// ── HUD ───────────────────────────────────────────────────────────
void drawHUD() {
  noStroke();
  fill(0, 20, 0, 220);
  rect(0, height - 46, width, 46);

  fill(0, 210, 0);
  textSize(13);
  textAlign(LEFT, CENTER);
  text("LIDAR-Lite v3  ·  I²C  ·  Sweep " + ANG_MIN + "°–" + ANG_MAX
       + "°  ·  Refine < " + (int)OUTLINE_CM + " cm", 18, height - 23);

  textAlign(RIGHT, CENTER);
  text("Angle: " + sweepAngle + "°    Dist: " + nf(latestDist, 1, 1) + " cm",
       width - 18, height - 23);

  fill(0, 160, 0, 160);
  textSize(14);
  textAlign(LEFT, TOP);
  text("LIDAR SWEEP MAP", 16, 14);
}

// ── SERIAL ────────────────────────────────────────────────────────
void serialEvent(Serial p) {
  String raw = p.readStringUntil('\n');
  if (raw == null) return;
  raw = trim(raw);
  if (raw.equals("READY") || raw.equals("SWEEP_END") || raw.length() == 0) return;

  String[] parts = split(raw, ',');
  if (parts.length != 2) return;

  try {
    int   a = int(trim(parts[0]));
    float d = float(trim(parts[1]));
    if (a >= ANG_MIN && a <= ANG_MAX && d > 0 && d < 9998) {
      sweepDir     = (a > sweepAngle) ? 1 : (a < sweepAngle ? -1 : sweepDir);
      distances[a] = d;
      frameAge[a]  = 0;
      sweepAngle   = a;
      latestDist   = d;
    }
  } catch (Exception e) {}
}
