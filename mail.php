<?php
$to = "test@example.com";
$subject = "docker-php-5.2 mail test";
$message = "If you received this, mail() is working.";
$headers = "From: php@docker-php-5.2";

if (!mail($to, $subject, $message, $headers)) {
    die("mail() failed");
}

echo 'OK';
