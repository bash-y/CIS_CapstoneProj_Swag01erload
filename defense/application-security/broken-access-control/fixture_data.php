<?php
// fixture_data.php
// SYNTHETIC, lab-only data for the broken-access-control demo (US-10, #110).
// This is NOT real café data and holds no secret of value. It exists only so the
// vulnerable and secure endpoints have per-user records to protect.
//
// Why a fixture: the deployed DVWA image has no per-user authorization-bypass
// module with distinct user-A / user-B records, so (as issue #110 permits) this
// clearly labeled lab fixture represents the scenario instead of claiming DVWA
// functionality that does not exist.

$USERS = [
    'alice' => ['password' => 'alicepw', 'role' => 'staff'],
    'bob'   => ['password' => 'bobpw',   'role' => 'staff'],
    'admin' => ['password' => 'adminpw', 'role' => 'admin'],
];

// Each order is owned by exactly one staff user. The order record is the
// protected READ; deleting an order is the admin-only STATE-CHANGING operation.
$ORDERS = [
    1001 => ['owner' => 'alice', 'item' => 'Latte',     'card_last4' => '4321', 'total' => 4.50],
    1002 => ['owner' => 'bob',   'item' => 'Cold Brew', 'card_last4' => '9876', 'total' => 3.75],
];
