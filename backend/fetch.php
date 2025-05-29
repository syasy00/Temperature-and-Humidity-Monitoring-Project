<?php
header('Content-Type: application/json');
include 'dbconnect.php';

$sql = "SELECT temperature, humidity, timestamp FROM dht_readings ORDER BY timestamp DESC LIMIT 50";
$result = $conn->query($sql);

$data = [];
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
    echo json_encode($data);
} else {
    echo json_encode(["status" => "fail", "message" => "No data found"]);
}

$conn->close();
?>