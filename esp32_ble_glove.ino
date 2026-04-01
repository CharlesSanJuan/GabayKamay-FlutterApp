#include <Wire.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <MPU6050.h>

MPU6050 mpu;

BLEServer *pServer;
BLECharacteristic *pCharacteristic;

/* ============================================ */
/* BLE CONNECTION TRACKING */
/* ============================================ */
bool deviceConnected = false;
bool oldDeviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected");
    }
};

/* ============================================ */
/* CHANGE THIS FOR EACH GLOVE */
/* ============================================ */
#define DEVICE_NAME "GLOVE_LEFT"
//#define DEVICE_NAME "GLOVE_RIGHT"

/* ============================================ */
/* BLE UUIDs - MUST MATCH FLUTTER APP */
/* ============================================ */
#define SERVICE_UUID "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "abcd1234-5678-1234-5678-abcdef123456"

/* ============================================ */
/* FLEX SENSOR PINS */
/* ============================================ */
#define FLEX_T 33
#define FLEX_I 32
#define FLEX_M 35
#define FLEX_R 34
#define FLEX_P 36

/* ============================================ */
/* FLEX SENSOR CALIBRATION (now app-driven) */
/* ============================================ */
/* We send raw flex ADC values to the app, and the app maps
   0-100 per user with calibration steps. Inline mapping is
   still available if needed for compatibility. */
#define FLEX_MIN 2200   // Fully extended (fallback)
#define FLEX_MAX 2400   // Fully bent (fallback)

#define SEND_FLEX_AS_RAW 1   // 1 = raw ADC chain to app, 0 = send normalized 0-100

/* ============================================ */
/* MPU6050 CALIBRATION OFFSETS */
/* ============================================ */
int16_t ax_offset = 0;
int16_t ay_offset = 0;
int16_t az_offset = 0;
int16_t gx_offset = 0;
int16_t gy_offset = 0;
int16_t gz_offset = 0;

unsigned long lastSend = 0;
unsigned long nextSendAt = 0;
unsigned long packetCount = 0;

/* ============================================ */
/* TRANSMISSION TIMING OFFSET */
/* ============================================ */
/* 
 * To prevent BLE collisions between two ESP32s without reducing
 * the packet rate:
 * - LEFT glove: phase = 0ms
 * - RIGHT glove: phase = 10ms
 *
 * Both gloves still use the same SEND_INTERVAL_MS. Only their
 * starting phase differs.
 */
#define TRANSMISSION_PHASE_MS 0  // Change to 10 for RIGHT glove
#define SEND_INTERVAL_MS 25
#define DEBUG_EVERY_N_PACKETS 10
#define SEND_BINARY_PACKET 1

/* ============================================ */
/* TEST MODE SETUP */
/* ============================================ */
/* 
 * To enable test mode at compile time, uncomment the line below:
 * #define TEST_MODE true
 * 
 * To toggle test mode at runtime, send 't' or 'T' via serial monitor.
 * Test mode sends dummy sensor data to verify BLE transmission.
 */
bool testModeEnabled = false;

/* ======================== */
/* SENSOR SCALE CONSTANTS */
/* ======================== */
/* MPU6050 at ±2g range: 1 LSB = 1/16384 g */
#define ACCEL_SCALE 16384.0

/* MPU6050 at ±250°/s range: 1 LSB = 1/131 °/s */
#define GYRO_SCALE 131.0

/* ======================== */
/* HELPER: NORMALIZE FLEX */
/* ======================== */
float normalizeFlex(int rawValue) {
  /* Map from ADC range to 0-100 (percentage) */
  float normalized = map(rawValue, FLEX_MIN, FLEX_MAX, 0, 100);
  /* Clamp to 0-100 */
  return constrain(normalized, 0.0, 100.0);
}

/* ======================== */
/* HELPER: FORMAT FLOAT */
/* ======================== */
String formatFloat(float value, int decimals) {
  return String(value, decimals);
}

struct __attribute__((packed)) SensorPacket {
  int16_t flex_t;
  int16_t flex_i;
  int16_t flex_m;
  int16_t flex_r;
  int16_t flex_p;
  int16_t ax;
  int16_t ay;
  int16_t az;
  int16_t gx;
  int16_t gy;
  int16_t gz;
};

/* ======================== */
/* MPU CALIBRATION */
/* ======================== */
void calibrateMPU() {

  Serial.println("Calibrating MPU... Keep glove still for 2 seconds.");

  long ax_sum = 0;
  long ay_sum = 0;
  long az_sum = 0;
  long gx_sum = 0;
  long gy_sum = 0;
  long gz_sum = 0;

  int16_t ax, ay, az, gx_raw, gy_raw, gz_raw;

  /* Take 100 samples at 50Hz (~2 seconds) */
  for (int i = 0; i < 100; i++) {

    mpu.getMotion6(&ax, &ay, &az, &gx_raw, &gy_raw, &gz_raw);

    ax_sum += ax;
    ay_sum += ay;
    az_sum += az;
    gx_sum += gx_raw;
    gy_sum += gy_raw;
    gz_sum += gz_raw;

    delay(20);
  }

  ax_offset = ax_sum / 100;
  ay_offset = ay_sum / 100;
  az_offset = az_sum / 100;
  gx_offset = gx_sum / 100;
  gy_offset = gy_sum / 100;
  gz_offset = gz_sum / 100;

  Serial.print("Calibration complete. Offsets: ");
  Serial.print("ax="); Serial.print(ax_offset);
  Serial.print(" ay="); Serial.print(ay_offset);
  Serial.print(" az="); Serial.print(az_offset);
  Serial.print(" gx="); Serial.print(gx_offset);
  Serial.print(" gy="); Serial.print(gy_offset);
  Serial.print(" gz="); Serial.println(gz_offset);
}

/* ======================== */
/* SETUP */
/* ======================== */
void setup() {

  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n\n=== GABAY KAMAY BLE GLOVE ===");
  Serial.print("Device: "); Serial.println(DEVICE_NAME);

  /* ============================================ */
  /* FLEX INPUTS */
  /* ============================================ */
  pinMode(FLEX_T, INPUT);
  pinMode(FLEX_I, INPUT);
  pinMode(FLEX_M, INPUT);
  pinMode(FLEX_R, INPUT);
  pinMode(FLEX_P, INPUT);

  Serial.println("Flex sensors initialized.");

  /* ============================================ */
  /* MPU6050 INITIALIZATION */
  /* ============================================ */
  Wire.begin();
  mpu.initialize();

  if (!mpu.testConnection()) {
    Serial.println("ERROR: MPU6050 connection failed!");
    while (1);
  }

  Serial.println("MPU6050 connected successfully.");

  calibrateMPU();

  /* ============================================ */
  /* BLE INITIALIZATION */
  /* ============================================ */
  BLEDevice::init(DEVICE_NAME);

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  /* Add BLE2902 descriptor for notifications */
  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  /* Start advertising */
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x12);
  pAdvertising->start();

  Serial.println("BLE advertising started.");
  Serial.println("=== READY ===\n");
}

/* ======================== */
/* MAIN LOOP */
/* ======================== */
void loop() {

  /* Check for serial commands to toggle test mode */
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 't' || cmd == 'T') {
      testModeEnabled = !testModeEnabled;
      Serial.print("Test mode ");
      Serial.println(testModeEnabled ? "ENABLED" : "DISABLED");
    }
  }

  /* Disconnecting and reconnecting */
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Give the bluetooth stack time to get ready
    pServer->startAdvertising(); // Restart advertising
    Serial.println("Start advertising");
    oldDeviceConnected = deviceConnected;
  }
  /* Connecting */
  if (deviceConnected && !oldDeviceConnected) {
    nextSendAt = millis() + TRANSMISSION_PHASE_MS;
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && ((long)(millis() - nextSendAt) >= 0)) {

    lastSend = millis();
    nextSendAt += SEND_INTERVAL_MS;

    if (testModeEnabled) {
    /* ============================================ */
    /* TEST MODE - Send dummy data */
    /* ============================================ */
    SensorPacket testPacket = {
      2500, 2500, 2500, 2500, 2500,
      8192, 8192, 8192,
      1310, 1310, 1310
    };

    pCharacteristic->setValue((uint8_t*)&testPacket, sizeof(testPacket));
    pCharacteristic->notify();

    packetCount++;
    if ((packetCount % DEBUG_EVERY_N_PACKETS) == 0) {
      Serial.print(DEVICE_NAME);
      Serial.print(" | TEST MODE | Packet #");
      Serial.println(packetCount);
    }

    } else {
    /* ============================================ */
    /* NORMAL MODE - Read sensors */
    /* ============================================ */

    /* ============================================ */
    /* READ FLEX SENSORS */
    /* ============================================ */
    int flex_t_raw = analogRead(FLEX_T);
    int flex_i_raw = analogRead(FLEX_I);
    int flex_m_raw = analogRead(FLEX_M);
    int flex_r_raw = analogRead(FLEX_R);
    int flex_p_raw = analogRead(FLEX_P);

    /* ============================================ */
    /* READ MPU6050 */
    /* ============================================ */
    int16_t ax_raw, ay_raw, az_raw;
    int16_t gx_raw, gy_raw, gz_raw;

    mpu.getMotion6(&ax_raw, &ay_raw, &az_raw, &gx_raw, &gy_raw, &gz_raw);

    #if SEND_BINARY_PACKET
      SensorPacket packet = {
        (int16_t)flex_t_raw,
        (int16_t)flex_i_raw,
        (int16_t)flex_m_raw,
        (int16_t)flex_r_raw,
        (int16_t)flex_p_raw,
        ax_raw,
        ay_raw,
        az_raw,
        gx_raw,
        gy_raw,
        gz_raw
      };
      pCharacteristic->setValue((uint8_t*)&packet, sizeof(packet));
    #else
      String packet;

      #if SEND_FLEX_AS_RAW
        packet = String(flex_t_raw) + "," +
                 String(flex_i_raw) + "," +
                 String(flex_m_raw) + "," +
                 String(flex_r_raw) + "," +
                 String(flex_p_raw) + "," +
                 String(ax_raw) + "," +
                 String(ay_raw) + "," +
                 String(az_raw) + "," +
                 String(gx_raw) + "," +
                 String(gy_raw) + "," +
                 String(gz_raw);
      #else
        float flex_t = normalizeFlex(flex_t_raw);
        float flex_i = normalizeFlex(flex_i_raw);
        float flex_m = normalizeFlex(flex_m_raw);
        float flex_r = normalizeFlex(flex_r_raw);
        float flex_p = normalizeFlex(flex_p_raw);

        float ax_g = ax_raw / ACCEL_SCALE;
        float ay_g = ay_raw / ACCEL_SCALE;
        float az_g = az_raw / ACCEL_SCALE;
        float gx_dps = (gx_raw - gx_offset) / GYRO_SCALE;
        float gy_dps = (gy_raw - gy_offset) / GYRO_SCALE;
        float gz_dps = (gz_raw - gz_offset) / GYRO_SCALE;

        packet = 
          formatFloat(flex_t, 1) + "," +
          formatFloat(flex_i, 1) + "," +
          formatFloat(flex_m, 1) + "," +
          formatFloat(flex_r, 1) + "," +
          formatFloat(flex_p, 1) + "," +
          formatFloat(ax_g, 2) + "," +
          formatFloat(ay_g, 2) + "," +
          formatFloat(az_g, 2) + "," +
          formatFloat(gx_dps, 1) + "," +
          formatFloat(gy_dps, 1) + "," +
          formatFloat(gz_dps, 1);
      #endif

      pCharacteristic->setValue(packet.c_str());
    #endif
    pCharacteristic->notify();

    /* ============================================ */
    /* DEBUG OUTPUT */
    /* ============================================ */
    packetCount++;
    if ((packetCount % DEBUG_EVERY_N_PACKETS) == 0) {
      Serial.print(DEVICE_NAME);
      Serial.print(" | Packet #");
      Serial.println(packetCount);
    }

    }
  }
}
