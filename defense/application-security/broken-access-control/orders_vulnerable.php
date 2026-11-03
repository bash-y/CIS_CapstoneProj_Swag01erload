<?php
// orders_vulnerable.php
// VULNERABLE fixture — intentionally broken access control (US-10, #110 baseline).
// DO NOT copy this pattern. It performs NO server-side ownership or role check
// and trusts client-supplied input for both identity and privilege.

session_start();
require __DIR__ . '/fixture_data.php';

$action = isset($_GET['action']) ? $_GET['action'] : 'read';
$id     = isset($_GET['order_id']) ? (int) $_GET['order_id'] : 0;

if ($action === 'read') {
    // HORIZONTAL violation (IDOR): returns ANY order by id with no check that
    // the caller owns it. Any user — or none — can read another user's record,
    // leaking card_last4.
    if (isset($ORDERS[$id])) {
        header('Content-Type: application/json');
        echo json_encode($ORDERS[$id]);
    } else {
        http_response_code(404);
        echo "no such order\n";
    }
    exit;
}

if ($action === 'delete') {
    // VERTICAL violation: privilege is read from a CLIENT-SUPPLIED role param,
    // so a regular user simply sends role=admin to invoke the admin-only delete.
    $role = isset($_GET['role']) ? $_GET['role'] : 'staff';
    if ($role === 'admin') {
        if (isset($ORDERS[$id])) {
            unset($ORDERS[$id]); // in-memory; illustrative state change
        }
        echo "DELETED order {$id} as role={$role}\n";
    } else {
        http_response_code(403);
        echo "need admin\n";
    }
    exit;
}

http_response_code(400);
echo "bad action\n";
