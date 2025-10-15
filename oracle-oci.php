<?php
$conn = oci_connect('php', '010203', 'oracle-host/FREEPDB1');
if (!$conn){
    print_r(oci_error());
    exit;
}

$stid = oci_parse($conn, "select 'OK' from dual");
if (!$stid){
    print_r(oci_error($conn));
    exit;
}

$r = oci_execute($stid);
if (!$r) {
    print_r(oci_error($stid));
    exit;
}

while ($row = oci_fetch_array($stid, OCI_ASSOC + OCI_RETURN_NULLS)) {
    print_r($row);
}

oci_free_statement($stid);
oci_close($conn);
