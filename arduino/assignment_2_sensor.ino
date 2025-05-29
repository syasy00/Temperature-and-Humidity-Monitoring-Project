#include <WiFi.h>
#include <WebServer.h>
#include <EEPROM.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DNSServer.h>
#include <DHT.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

#define API_KEY "AIzaSyAMRK7-TlLQazCEymcxB91v158M300sKno"
#define DATABASE_URL "https://sensorbased-fc27e-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define USER_EMAIL "nursyasya.aina03@gmail.com"
#define USER_PASSWORD "123456789"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

#define SSID_ADDR 0
#define PASS_ADDR 64
#define USER_ADDR 128
#define LED_PIN 2
#define DHTPIN 4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);
String ssid, pass, username;
String scrollingText = "", temperature = "", humidity = "";
int scrollX = SCREEN_WIDTH;
WebServer server(80);
DNSServer dnsServer;
bool inAPMode = false;

void showOLED(String line1, String line2 = "", String line3 = "") {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println(line1);
  display.println(line2);
  display.println(line3);
  display.display();
}

void writeToEEPROM(int addr, const String &data) {
  for (int i = 0; i < 64; i++) EEPROM.write(addr + i, i < data.length() ? data[i] : 0);
  EEPROM.commit();
}

String readFromEEPROM(int addr) {
  char buf[65];
  for (int i = 0; i < 64; i++) buf[i] = EEPROM.read(addr + i);
  buf[64] = '\0';
  return String(buf);
}

void blinkConnected() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(300);
    digitalWrite(LED_PIN, LOW);
    delay(300);
  }
}

void handleRoot() {
  String currentSSID = readFromEEPROM(SSID_ADDR);
  String currentPass = readFromEEPROM(PASS_ADDR);
  String currentUser = readFromEEPROM(USER_ADDR);

  String html = R"rawliteral(
<!DOCTYPE html><html><head><meta charset='UTF-8'><title>WiFi Setup</title>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<style>
  body { font-family: Segoe UI, sans-serif; background: #f4f6fa; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
  .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 6px 20px rgba(0,0,0,0.08); width: 90%; max-width: 360px; }
  h2 { text-align: center; margin-bottom: 20px; }
  label { display: block; margin-bottom: 6px; font-weight: 500; font-size: 14px; }
  input { width: 100%; padding: 10px; margin-bottom: 14px; border: 1px solid #ccc; border-radius: 8px; font-size: 14px; }
  button { width: 100%; padding: 10px; margin-top: 8px; background: #007BFF; color: white; border: none; border-radius: 8px; font-size: 15px; cursor: pointer; }
  button:hover { background: #0056b3; }
  .note { font-size: 13px; color: #555; margin-top: 20px; text-align: center; }
</style>
</head><body>
<div class='card'>
  <h2>WiFi Setup</h2>
  <form action='/save' method='POST'>
    <label for='ssid'>WiFi SSID</label>
    <input name='ssid' id='ssid' placeholder='SSID' value=")rawliteral" + currentSSID + R"rawliteral(" required>
    <label for='pass'>WiFi Password</label>
    <input name='pass' id='pass' type='password' placeholder='Password' value=")rawliteral" + currentPass + R"rawliteral(" required>
    <label for='user'>Username</label>
    <input name='user' id='user' placeholder='Username' value=")rawliteral" + currentUser + R"rawliteral(" required>
    <button type='submit'>🔒 Save & Connect</button>
  </form>
  <form action='/clear' method='POST'>
    <button type='submit'>🧹 Reset</button>
  </form>
  <form action='/' method='GET'>
  <button type='submit'>🔄 Reload</button>
</form>

  <div class='note'>
    Current SSID: <b>)rawliteral" + currentSSID + R"rawliteral(</b><br>
    Username: <b>)rawliteral" + currentUser + R"rawliteral(</b>
  </div>
</div>
</body></html>)rawliteral";

  server.send(200, "text/html", html);
}

void handleSave() {
  ssid = server.arg("ssid");
  pass = server.arg("pass");
  username = server.arg("user");

  writeToEEPROM(SSID_ADDR, ssid);
  writeToEEPROM(PASS_ADDR, pass);
  writeToEEPROM(USER_ADDR, username);

  showOLED("Saved!", "Restarting...", "");
  delay(1000);

  server.sendHeader("Location", "/", true);
  server.send(302, "text/plain", "Updated, rebooting...");
  delay(1000);
  ESP.restart();
}

void handleClear() {
  writeToEEPROM(SSID_ADDR, "");
  writeToEEPROM(PASS_ADDR, "");
  writeToEEPROM(USER_ADDR, "");

  ssid = pass = username = "";
  scrollingText = temperature = humidity = "";

  WiFi.disconnect(true, true);
  delay(500);

  showOLED("WiFi Cleared", "Restarting AP...", "");
  delay(1000);
  startCaptivePortal();
}

void startCaptivePortal() {
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_OFF);
  delay(100);
  WiFi.mode(WIFI_AP);
  delay(100);

  WiFi.softAP("ESP32_Config", "");
  delay(1000);

  IPAddress IP = WiFi.softAPIP();
  dnsServer.start(53, "*", IP);

  server.on("/", handleRoot);
  server.on("/generate_204", handleRoot);
  server.on("/redirect", handleRoot);
  server.on("/hotspot-detect.html", handleRoot);
  server.on("/ncsi.txt", handleRoot);
  server.on("/fwlink", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.on("/clear", HTTP_POST, handleClear);
  server.onNotFound([]() {
    server.sendHeader("Location", "/", true);
    server.send(302, "Redirecting...");
  });

  server.begin();
  inAPMode = true;
  showOLED("AP Mode Active", "ESP32_Config", IP.toString());
}

void setup() {
  Serial.begin(115200);
  EEPROM.begin(256);
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  pinMode(LED_PIN, OUTPUT);
  dht.begin();

  ssid = readFromEEPROM(SSID_ADDR);
  pass = readFromEEPROM(PASS_ADDR);
  username = readFromEEPROM(USER_ADDR);

  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP("ESP32_Config", "");
  delay(1000);

  IPAddress IP = WiFi.softAPIP();
  dnsServer.start(53, "*", IP);

  server.on("/", handleRoot);
  server.on("/generate_204", handleRoot);
  server.on("/redirect", handleRoot);
  server.on("/hotspot-detect.html", handleRoot);
  server.on("/ncsi.txt", handleRoot);
  server.on("/fwlink", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.on("/clear", HTTP_POST, handleClear);
  server.onNotFound([]() {
    server.sendHeader("Location", "/", true);
    server.send(302, "Redirecting...");
  });
  server.begin();
  
  if (ssid.length() > 0 && pass.length() > 0) {
    showOLED("Connecting WiFi...", ssid);
    WiFi.begin(ssid.c_str(), pass.c_str());
    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 20) {
      delay(500);
      retries++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      blinkConnected();
      showOLED("WiFi Connected", "Welcome" + username);
      config.api_key = API_KEY;
      config.database_url = DATABASE_URL;
      config.token_status_callback = tokenStatusCallback;
      auth.user.email = USER_EMAIL;
      auth.user.password = USER_PASSWORD;

      Firebase.begin(&config, &auth);
      Firebase.reconnectWiFi(true);
    } else {
      showOLED("WiFi Failed", "Check Credentials", "");
      delay(2000);
    }
  } else {
    showOLED("AP Mode", "SSID: ESP32_Config", IP.toString());
  }
}


void loop() {
  dnsServer.processNextRequest();
  server.handleClient();

  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate > 5000 && Firebase.ready()) {
    lastUpdate = millis();

    float temp = dht.readTemperature();
    float hum = dht.readHumidity();

    if (isnan(temp) || isnan(hum)) {
      Serial.println("❌ Failed to read from DHT sensor!");
      showOLED("DHT11 Error", "Check wiring", "");
      return;
    }

    temperature = String(temp, 1);
    humidity = String(hum, 0);

    Firebase.RTDB.setString(&fbdo, "/dht/temperature", temperature);
    Firebase.RTDB.setString(&fbdo, "/dht/humidity", humidity);

    bool fbError = false;
    String fbErrorMsg = "";

    if (!Firebase.RTDB.getString(&fbdo, "/display/text")) {
      Serial.println("[Firebase] Failed to read /display/text: " + fbdo.errorReason());
      fbError = true;
      fbErrorMsg = "Text Err";
    } else {
      scrollingText = fbdo.stringData();
    }

    if (fbError) {
      showOLED("FB Error:", fbErrorMsg, "");
      delay(2000);
    }
  }

 
  if (WiFi.status() == WL_CONNECTED) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.print("User: "); display.print(username);
    display.setCursor(64, 0); display.print("WiFi: OK");
    display.setCursor(0, 10);
    display.print("T: "); display.print(temperature); display.print((char)247); display.print("C");
    display.setCursor(64, 10);
    display.print("H: "); display.print(humidity); display.print("%");
    display.setCursor(scrollX, 20);
    display.print("Text: "); display.print(scrollingText);
    display.display();

    scrollX--;
    int textWidth = (5 + scrollingText.length()) * 6;
    if (scrollX + textWidth < 0) scrollX = SCREEN_WIDTH;
  }

  delay(50);
}

