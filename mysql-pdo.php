<?php
try {
    $pdo = new PDO("mysql:host=mysql-host;dbname=test;charset=utf8", "root", "010203");
}catch(PDOException $e){
    echo $e->getMessage();
    die();
}

$stmt = $pdo->prepare("select 'OK' from dual");
$stmt->execute();
$rs = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo '<pre>';
print_r($rs);
