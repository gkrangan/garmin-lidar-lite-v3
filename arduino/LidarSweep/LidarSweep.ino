// LidarSweep.ino — adaptive-precision LIDAR sweep
//
// Strategy:
//   1. Main sweep (1° steps): sample count scales with proximity
//      < 50 cm  → 6 samples averaged
//      < 100 cm → 4 samples
//      < 200 cm → 3 samples
//      else     → 2 samples
//   2. Refinement pass at end of each sweep: revisit any angle
//      where distance < CLOSE_CM and re-read with 6 samples.
//      This tightens up the close-range profile without slowing
//      the full sweep.

#include <Wire.h>
#include <LIDARLite.h>
#include <Servo.h>

// ── Pin ───────────────────────────────────────────────────────────
const int SERVO_PIN = 9;

// ── Sweep config ─────────────────────────────────────────────────
const int ANGLE_MIN  = 15;
const int ANGLE_MAX  = 165;
const int STEP       = 1;       // degrees per step
const int SETTLE_MS  = 20;      // servo settle time
const int CLOSE_CM   = 150;     // threshold for refinement pass

// ── State ─────────────────────────────────────────────────────────
LIDARLite lidar;
Servo     sweepServo;
int       lastDist[181];        // last reading per angle for adaptive sampling
int       angle = ANGLE_MIN;
int       dir   = 1;

// ── Helpers ───────────────────────────────────────────────────────
int samplesFor(int prevDist) {
  if (prevDist > 0 && prevDist <  50) return 6;
  if (prevDist > 0 && prevDist < 100) return 4;
  if (prevDist > 0 && prevDist < 200) return 3;
  return 2;
}

int avgDist(int n) {
  long sum = 0;
  for (int i = 0; i < n; i++) sum += lidar.distance();
  return (int)(sum / n);
}

// Revisit close angles with maximum averaging for best accuracy
void refinementPass() {
  for (int a = ANGLE_MIN; a <= ANGLE_MAX; a++) {
    if (lastDist[a] > 0 && lastDist[a] < CLOSE_CM) {
      sweepServo.write(a);
      delay(SETTLE_MS + 10);
      int d = avgDist(6);
      lastDist[a] = d;
      Serial.print(a);
      Serial.print(',');
      Serial.println(d);
    }
  }
}

// ── Setup ─────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  sweepServo.attach(SERVO_PIN);
  lidar.begin(0, true);
  lidar.configure(0);
  memset(lastDist, 0, sizeof(lastDist));
  sweepServo.write(ANGLE_MIN);
  delay(1000);
  Serial.println("READY");
}

// ── Loop ──────────────────────────────────────────────────────────
void loop() {
  sweepServo.write(angle);
  delay(SETTLE_MS);

  int n = samplesFor(lastDist[angle]);
  int d = avgDist(n);
  lastDist[angle] = d;

  Serial.print(angle);
  Serial.print(',');
  Serial.println(d);

  angle += dir * STEP;

  if (angle >= ANGLE_MAX) {
    angle = ANGLE_MAX;
    dir   = -1;
    refinementPass();
    Serial.println("SWEEP_END");
  } else if (angle <= ANGLE_MIN) {
    angle = ANGLE_MIN;
    dir   = 1;
    refinementPass();
    Serial.println("SWEEP_END");
  }
}
