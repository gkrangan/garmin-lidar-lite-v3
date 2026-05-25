// LidarSweep.ino
// Sweeps a LIDAR-Lite v3 (I2C) on a servo and streams angle,distance over Serial.
// Pair with LidarMapper.pde in Processing.
//
// Wiring additions to your existing I2C setup:
//   Servo signal (orange) → D9
//   Servo VCC             → 5V  (use external 5V supply if servo stalls)
//   Servo GND             → GND

#include <Wire.h>
#include <LIDARLite.h>
#include <Servo.h>

// ── Pin ──────────────────────────────────────────────────────────────────────
const int SERVO_PIN = 9;

// ── Sweep config ─────────────────────────────────────────────────────────────
const int ANGLE_MIN = 15;   // stay away from mechanical limits
const int ANGLE_MAX = 165;
const int STEP      = 1;    // degrees per step — reduce to 2 if sweep is too slow
const int SETTLE_MS = 20;   // ms for servo to settle before reading

// ── Globals ───────────────────────────────────────────────────────────────────
LIDARLite lidar;
Servo     sweepServo;
int       angle = ANGLE_MIN;
int       dir   = 1;   // +1 increasing, -1 decreasing

// Average n distance readings to reduce noise
int avgDist(int n) {
  long sum = 0;
  for (int i = 0; i < n; i++) sum += lidar.distance();
  return (int)(sum / n);
}

void setup() {
  Serial.begin(115200);
  sweepServo.attach(SERVO_PIN);
  lidar.begin(0, true);
  lidar.configure(0);          // 0 = balanced performance
  sweepServo.write(ANGLE_MIN);
  delay(1000);                 // let servo reach start and sensor stabilise
  Serial.println("READY");
}

void loop() {
  sweepServo.write(angle);
  delay(SETTLE_MS);

  int d = avgDist(2);

  Serial.print(angle);
  Serial.print(',');
  Serial.println(d);

  angle += dir * STEP;

  if (angle >= ANGLE_MAX) {
    angle = ANGLE_MAX;
    dir   = -1;
    Serial.println("SWEEP_END");
  } else if (angle <= ANGLE_MIN) {
    angle = ANGLE_MIN;
    dir   = 1;
    Serial.println("SWEEP_END");
  }
}
