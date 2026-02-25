// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockOracle} from "src/mocks/MockOracle.sol";
import {SimpleLending} from "src/examples/lending/SimpleLending.sol";

contract Lending_Liquidation_Boundary_Test is Test {
    uint256 constant WAD = 1e18;

    address alice = address(0xA11CE);
    address liq = address(0xB0B);

    MockOracle oracle;
    SimpleLending lending;

    function setUp() external {
        // oracle returns WAD price: e.g. 2000 USD per collateral token
        oracle = new MockOracle(int256(2000 * WAD), block.timestamp);

        lending = new SimpleLending(
            oracle,
            0.75e18, // ltv
            0.85e18, // liqThreshold
            1 hours, // maxOracleAge
            0.05e18 // liquidation bonus
        );

        // Alice deposits 1 collateral token (WAD)
        vm.prank(alice);
        lending.depositCollateral(1 * WAD);
    }

    function test_boundary_hf_eq_1_cannot_liquidate() external {
        // Choose debt so that HF == 1 at current price
        // HF = collateralValue * liqThreshold / debt
        // debt = collateralValue * liqThreshold
        // collateralValue = 1 * 2000 = 2000
        uint256 collateralValue = 2000 * WAD;
        uint256 debt = (collateralValue * 0.85e18) / WAD; // = 1700

        vm.prank(alice);
        lending.borrowUsd(debt);

        uint256 hf = lending.healthFactorWad(alice);
        assertEq(hf, WAD);

        vm.expectRevert(); // NotLiquidatable(...)
        vm.prank(liq);
        lending.liquidate(alice, 1 * WAD);
    }

    function test_boundary_hf_just_below_1_can_liquidate_and_updates_state()
        external
    {
        // Borrow slightly more so HF just below 1
        uint256 collateralValue = 2000 * WAD;
        uint256 debtAtEq1 = (collateralValue * 0.85e18) / WAD; // 1700
        uint256 debt = debtAtEq1 + 1; // 1 wei more => HF < 1

        vm.prank(alice);
        lending.borrowUsd(debt);

        uint256 hf = lending.healthFactorWad(alice);
        assertLt(hf, WAD);

        uint256 repay = 100 * WAD; // liquidator repays 100 USD

        uint256 beforeDebt = lending.debtUsd(alice);
        uint256 beforeCol = lending.collateral(alice);

        vm.prank(liq);
        uint256 seized = lending.liquidate(alice, repay);

        uint256 afterDebt = lending.debtUsd(alice);
        uint256 afterCol = lending.collateral(alice);

        assertEq(afterDebt, beforeDebt - repay);
        assertEq(afterCol, beforeCol - seized);

        // verify seize formula (no cap case expected here):
        // seized = repay*(1+bonus)/price
        uint256 price = 2000 * WAD;
        uint256 expected = (((repay * (WAD + 0.05e18)) / WAD) * WAD) / price;
        assertEq(seized, expected);
    }
}
