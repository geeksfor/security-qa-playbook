// SPDX-License-Identifier: MIT
/**
 * @dev 守恒：A 转给 B，A+B 总和不变（不含 fee token）
        allowance：transferFrom 后 allowance 正确扣减
        approve 竞态演示：先 approve(spender, old)，再想改成 new，
        中间 spender 抢跑用 transferFrom（模拟“先花掉 old，再花掉 new”的风险）
 *
 * */

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MintableERC20 is ERC20 {
    constructor() ERC20("T", "T") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ERC20_Spec_Template is Test {
    MintableERC20 token;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address spender = makeAddr("spender");

    function setUp() public {
        token = new MintableERC20();
        token.mint(alice, 1_000 ether);
    }

    function test_transfer_conserves_sum() public {
        uint256 a0 = token.balanceOf(alice);
        uint256 b0 = token.balanceOf(bob);

        vm.prank(alice);
        token.transfer(bob, 123 ether);

        uint256 a1 = token.balanceOf(alice);
        uint256 b1 = token.balanceOf(bob);

        assertEq(a0 + b0, a1 + b1, "sum must conserve for standard ERC20");
        assertEq(b1 - b0, 123 ether);
        assertEq(a0 - a1, 123 ether);
    }

    function test_transferFrom_decreases_allowance() public {
        vm.prank(alice);
        token.approve(spender, 200 ether);

        vm.prank(spender);
        token.transferFrom(alice, bob, 50 ether);

        assertEq(
            token.allowance(alice, spender),
            150 ether,
            "allowance should decrease"
        );
        assertEq(token.balanceOf(bob), 50 ether);
    }

    /// @notice Approve race demonstration: spender can spend old allowance before new approval is mined.
    /// This is a "spec warning test" — it should show the problem, not "fix" ERC20.
    function test_approve_race_demonstration() public {
        // Alice approves 100
        vm.prank(alice);
        token.approve(spender, 100 ether);

        // Alice wants to change allowance to 10 (dangerous pattern!)
        // Spender front-runs and spends 100 first
        vm.prank(spender);
        token.transferFrom(alice, bob, 100 ether);

        // Now Alice's "change to 10" tx lands (still succeeds)
        vm.prank(alice);
        token.approve(spender, 10 ether);

        // Spender can spend again (the new 10)
        vm.prank(spender);
        token.transferFrom(alice, bob, 10 ether);

        assertEq(
            token.balanceOf(bob),
            110 ether,
            "spender spent both old and new allowances"
        );
    }

    /// @notice Safer pattern: set to 0 then set to new (or use increase/decreaseAllowance).
    function test_safe_allowance_change_pattern() public {
        vm.prank(alice);
        token.approve(spender, 100 ether);

        vm.prank(alice);
        token.approve(spender, 0);

        vm.prank(alice);
        token.approve(spender, 10 ether);

        assertEq(token.allowance(alice, spender), 10 ether);
    }
}
