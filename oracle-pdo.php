<?php
try {
    $pdo = new PDO("oci:dbname=//oracle-host:1521/FREEPDB1", "php", "010203");
}catch(PDOException $e){
    echo $e->getMessage();
    die();
}

$stmt = $pdo->prepare("select 'OK' from dual");
$stmt->execute();
$rs = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo '<pre>';
print_r($rs);
