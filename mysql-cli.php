<?php
$conn = mysqli_connect('mysql-host', 'php', '010203', 'test');

if (!$conn) {
    die("Connection failed: " . mysqli_connect_error());
}

$sql = "SELECT 'OK' AS result";
$result = mysqli_query($conn, $sql);

if (!$result) {
    die("Query error: " . mysqli_error($conn));
}

while ($row = mysqli_fetch_assoc($result)) {
    print_r($row);
}

mysqli_free_result($result);
mysqli_close($conn);
