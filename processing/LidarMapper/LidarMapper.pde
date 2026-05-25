// LidarMapper.pde — LIDAR-Lite v3 Sweep Radar Display
// Pair with LidarSweep.ino on the Arduino.
//
// ── First run ────────────────────────────────────────────────────────────────
// Upload LidarSweep.ino, then run this sketch. The console will print all
// available serial ports — find your Arduino's port and set PORT_NAME below.
//
// Mac example:   /dev/cu.usbmodem14101
// Windows:       COM3  (check Device Manager)
// Linux:         /dev/ttyUSB0

import processing.serial.*;

// ── CONFIG — edit these ───────────────────────────────────────────────────────
final String PORT_NAME = "/dev/cu.usbmodem14101";
final int    BAUD      = 115200;

final int   ANG_MIN  = 15;    // must match Arduino sketch
final int   ANG_MAX  = 165;
final float DIST_MAX = 400;   // cm — readings beyond this are discarded
final float RADAR_R  = 295;   // pixels — radius of the sweep arc

// ── STATE ────────────────────────────────────────────────────────────────────
Serial  port;
float[] distances = new float[181];   // distances[angle] in cm, index = servo degree
int[]   frameAge  = new int[181];     // frames since each angle was last updated
int     sweepAngle = ANG_MIN;
int     sweepDir   = 1;
float   latestDist = 0;
float   cx, cy;                       // radar origin — bottom-centre of window

// ── SETUP ────────────────────────────────────────────────────────────────────
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
    println("\n⚠ Could not open: " + PORT_NAME);
    println("Set PORT_NAME to one of the ports listed above.");
  }
}

// ── MAIN LOOP ────────────────────────────────────────────────────────────────
void draw() {
  background(0, 8, 0);     // very dark green — cleared fresh each frame
  drawGrid();
  drawPoints();
  drawSweepGlow();
  drawSweepLine();
  drawHUD();
  for (int i = 0; i <= 180; i++) frameAge[i]++;
}

// ── COORDINATE HELPERS ────────────────────────────────────────────────────────
// Servo angle → screen position.  Centre at bottom; 90° = straight up.
float sx(int a, float r) { return cx + cos(-radians(a)) * r; }
float sy(int a, float r) { return cy + sin(-radians(a)) * r; }

// ── RADAR GRID ────────────────────────────────────────────────────────────────
void drawGrid() {
  strokeWeight(1);
  noFill();

  // Range arcs
  int[] rings = { 50, 100, 200, 300, 400 };
  for (int rm : rings) {
    if (rm > DIST_MAX) continue;
    float sr = map(rm, 0, DIST_MAX, 0, RADAR_R);
    stroke(0, 55, 0, 200);
    beginShape();
    for (int a = ANG_MIN; a <= ANG_MAX; a++) vertex(sx(a, sr), sy(a, sr));
    endShape();

    noStroke();
    fill(0, 100, 0, 200);
    textAlign(LEFT, BOTTOM);
    textSize(10);
    text(rm + " cm", sx(ANG_MIN, sr) + 5, sy(ANG_MIN, sr) - 2);
    noFill();
  }

  // Angle spokes + labels every 15°
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

  // Closing arc at full range
  stroke(0, 35, 0, 140);
  beginShape();
  for (int a = ANG_MIN; a <= ANG_MAX; a++) vertex(sx(a, RADAR_R), sy(a, RADAR_R));
  endShape();

  // Origin dot
  noStroke();
  fill(0, 180, 0);
  ellipse(cx, cy, 7, 7);
}

// ── SWEEP GLOW TRAIL ──────────────────────────────────────────────────────────
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

// ── SWEEP LINE ────────────────────────────────────────────────────────────────
void drawSweepLine() {
  float ex = sx(sweepAngle, RADAR_R);
  float ey = sy(sweepAngle, RADAR_R);
  noFill();
  stroke(0, 255, 0, 35);  strokeWeight(8);   line(cx, cy, ex, ey);
  stroke(0, 255, 0, 75);  strokeWeight(4);   line(cx, cy, ex, ey);
  stroke(0, 255, 0, 210); strokeWeight(1.5); line(cx, cy, ex, ey);
}

// ── DISTANCE POINTS ───────────────────────────────────────────────────────────
// Red = close, yellow = mid-range, green = far
color distColor(float d) {
  float t = constrain(d / DIST_MAX, 0, 1);
  return t < 0.5
    ? lerpColor(color(255, 30, 30), color(255, 210, 0), t * 2)
    : lerpColor(color(255, 210, 0), color(30, 255, 50), (t - 0.5) * 2);
}

void drawPoints() {
  noStroke();
  for (int a = ANG_MIN; a <= ANG_MAX; a++) {
    if (distances[a] <= 0 || distances[a] >= DIST_MAX) continue;
    int alpha = (int) map(frameAge[a], 0, 360, 255, 0);
    if (alpha <= 0) continue;

    float sr = map(distances[a], 0, DIST_MAX, 0, RADAR_R);
    float px = sx(a, sr);
    float py = sy(a, sr);
    color c  = distColor(distances[a]);
    float r  = red(c), g = green(c), b = blue(c);

    fill(r, g, b, alpha * 0.12); ellipse(px, py, 20, 20);  // outer glow
    fill(r, g, b, alpha * 0.38); ellipse(px, py, 11, 11);  // mid glow
    fill(r, g, b, alpha);        ellipse(px, py,  5,  5);  // core dot
  }
}

// ── HUD ───────────────────────────────────────────────────────────────────────
void drawHUD() {
  // Bottom bar
  noStroke();
  fill(0, 20, 0, 220);
  rect(0, height - 46, width, 46);

  fill(0, 210, 0);
  textSize(13);
  textAlign(LEFT, CENTER);
  text("LIDAR-Lite v3  ·  I²C  ·  Sweep " + ANG_MIN + "°–" + ANG_MAX + "°  ·  Max " + (int) DIST_MAX + " cm",
       18, height - 23);

  textAlign(RIGHT, CENTER);
  text("Angle: " + sweepAngle + "°    Dist: " + nf(latestDist, 1, 1) + " cm",
       width - 18, height - 23);

  // Title
  fill(0, 160, 0, 160);
  textSize(14);
  textAlign(LEFT, TOP);
  text("LIDAR SWEEP MAP", 16, 14);
}

// ── SERIAL INPUT ─────────────────────────────────────────────────────────────
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
