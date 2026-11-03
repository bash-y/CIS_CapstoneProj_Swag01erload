<?php
// orders_secure.php
// SECURE fixture — the fix for US-10 #110. Access control is enforced
// server-side with deny-by-default. Identity and role come ONLY from the
// trusted session, never from client-submitted user_id/role parameters.

session_start();
require __DIR__ . '/fixture_data.php';

// Record an authorization denial WITHOUT any secret (no card data, no password),
// then stop. Denied requests disclose no protected data and change no state.
function deny($code, $reason)
{
    http_response_code($code);
    $who    = isset($_SESSION['user']) ? $_SESSION['user'] : 'anonymous';
    $action = isset($_GET['action']) ? $_GET['action'] : '?';
    $order  = isset($_GET['order_id']) ? (int) $_GET['order_id'] : 0;
    error_log("[AUTHZ-DENY] user={$who} action={$action} order={$order} reason={$reason}");
    echo "{$code} {$reason}\n";
    exit;
}

// Deny-by-default: authentication is required for every path.
$user = isset($_SESSION['user']) ? $_SESSION['user'] : null;
$role = isset($_SESSION['role']) ? $_SESSION['role'] : null;
if ($user === null) {
    deny(401, 'authentication required');
}

$action = isset($_GET['action']) ? $_GET['action'] : 'read';
$id     = isset($_GET['order_id']) ? (int) $_GET['order_id'] : 0;

if (!isset($ORDERS[$id])) {
    deny(404, 'not found');
}

if ($action === 'read') {
    // Ownership check: staff may read only their own order; admin may read any.
    if ($role !== 'admin' && $ORDERS[$id]['owner'] !== $user) {
        deny(403, 'not owner');
    }
    header('Content-Type: application/json');
    echo json_encode($ORDERS[$id]);
    exit;
}

if ($action === 'delete') {
    // Role is taken from the SESSION, never from the request.
    if ($role !== 'admin') {
        deny(403, 'admin only');
    }
    unset($ORDERS[$id]);
    echo "DELETED order {$id} by admin {$user}\n";
    exit;
}

deny(400, 'bad action');
