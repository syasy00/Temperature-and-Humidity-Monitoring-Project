<?php
$host = "localhost";
$user = "humancmt_syusyi_IoT";
$pass = "hn+R3k-*f8zphKJf";
$dbname = "humancmt_syusyi_sensordb";

$conn = new mysqli($host, $user, $pass, $dbname);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
