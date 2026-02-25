// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockAMMXYK} from "src/mocks/MockAMMXYK.sol";
import {MockOracle} from "src/mocks/MockOracle.sol";
import {SpotBasedLending} from "src/examples/lending/SpotBasedLending.sol";

contract SpotManipulation_Regression_Test is Test {
    uint256 constant WAD = 1e18;

    address attacker = address(0xBEEF);

    MockAMMXYK amm;
    MockOracle refOracle;
    SpotBasedLending lending;

    function setUp() external {
        amm = new MockAMMXYK(1000 * WAD, 2_000_000 * WAD); // r1/r0 = 2000

        refOracle = new MockOracle(int256(2000 * WAD), block.timestamp);

        lending = new SpotBasedLending(amm, refOracle, 0.75e18, 500); // 75% LTV, 5% max deviation

        vm.prank(attacker);
        lending.deposit(1 * WAD); // 1 token0 as collateral
    }

    function test_vuln_spot_manipulation_allows_overborrow() external {
        // attacker manipulates spot up by swapping in lots of USD (token1)
        // price increases => maxBorrow increases => can borrow more than ref allows
        amm.swap1For0(1_000_000 * WAD); // huge token1 in, drives price up

        uint256 spotMax = lending.maxBorrowUsd(attacker, false); // no protection
        uint256 refMax = (((1 * WAD * 2000 * WAD) / WAD) * 0.75e18) / WAD; // 1500 USD

        assertGt(spotMax, refMax);

        vm.prank(attacker);
        lending.borrow(spotMax, false); // succeeds in vuln mode
        assertEq(lending.debtUsd(attacker), spotMax);
    }

    function test_fixed_with_maxDeviation_reverts_attack_flow() external {
        amm.swap1For0(1_000_000 * WAD);

        // With protection on, deviation should trigger
        vm.expectRevert(SpotBasedLending.DeviationTooHigh.selector);
        vm.prank(attacker);
        lending.borrow(2000 * WAD, true);
    }
}
