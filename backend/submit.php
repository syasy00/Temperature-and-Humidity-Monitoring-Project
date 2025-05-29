<?php
header('Content-Type: application/json');
include 'dbconnect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Get POST data (use raw POST for ESP32/JSON, or form)
    $data = json_decode(file_get_contents('php://input'), true);
    $temperature = isset($data['temperature']) ? floatval($data['temperature']) : null;
    $humidity = isset($data['humidity']) ? floatval($data['humidity']) : null;

    if ($temperature !== null && $humidity !== null) {
        $stmt = $conn->prepare("INSERT INTO dht_readings (temperature, humidity) VALUES (?, ?)");
        $stmt->bind_param("dd", $temperature, $humidity);
        if ($stmt->execute()) {
            echo json_encode(["success" => true]);
        } else {
            echo json_encode(["success" => false, "error" => $stmt->error]);
        }
        $stmt->close();
    } else {
        echo json_encode(["success" => false, "error" => "Missing temperature or humidity"]);
    }
} else {
    echo json_encode(["success" => false, "error" => "Invalid method"]);
}
$conn->close();
?>
