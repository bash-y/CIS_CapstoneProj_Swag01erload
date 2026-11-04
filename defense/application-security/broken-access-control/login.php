<?php
// login.php
// Establishes a trusted server-side session for the fixture. Identity and role
// are stored in $_SESSION so the secure endpoint can derive them from the server,
// never from client-submitted parameters.

session_start();
require __DIR__ . '/fixture_data.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo "POST username and password\n";
    exit;
}

$u = isset($_POST['username']) ? (string) $_POST['username'] : '';
$p = isset($_POST['password']) ? (string) $_POST['password'] : '';

if (isset($USERS[$u]) && hash_equals($USERS[$u]['password'], $p)) {
    session_regenerate_id(true);
    $_SESSION['user'] = $u;
    $_SESSION['role'] = $USERS[$u]['role'];
    http_response_code(200);
    echo "LOGIN_OK user={$u} role={$USERS[$u]['role']}\n";
} else {
    http_response_code(401);
    echo "LOGIN_FAILED\n";
}
