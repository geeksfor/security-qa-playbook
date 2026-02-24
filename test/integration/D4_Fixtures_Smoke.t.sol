// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../helpers/Fixtures.t.sol";

contract D4_Fixtures_Smoke_Test is Fixtures {
    function test_fixture_supply_matches_balances() public {
        _assertSupplyMatchesSeed();
    }
}
