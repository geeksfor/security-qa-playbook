// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

abstract contract BaseTest is Test {
    // ✅ 统一角色账户
    address internal alice;
    address internal bob;
    address internal attacker;
    address internal admin;

    function setUp() public virtual {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");
        admin = makeAddr("admin");

        // ✅ label：trace 里可读
        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
        vm.label(attacker, "ATTACKER");
        vm.label(admin, "ADMIN");
    }
}
