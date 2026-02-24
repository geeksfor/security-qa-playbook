// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../helpers/BaseTest.t.sol";

contract D2_BaseTest_Accounts_Test is BaseTest {
    function test_alice_not_attacker_and_labels_readable() public {
        assertTrue(alice != attacker, "alice should != attacker");

        // 这里不直接“断言 label”，因为 label 是给 trace 用的。
        // 用 log 把地址打出来，跑 -vvv 时你能看到标注过的名字。
        emit log_named_address("alice", alice);
        emit log_named_address("attacker", attacker);
    }
}
