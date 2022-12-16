<?php
require_once("SOAP/Client.php");

$client = new SoapClient("http://www.dneonline.com/calculator.asmx?wsdl", array("trace" => 1, "exception" => 0));

echo 'OK';
