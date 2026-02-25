// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Simple4626Vault} from "../../src/examples/vault/Simple4626Vault.sol";

contract MintableERC20 is ERC20 {
    constructor() ERC20("Asset", "AST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ERC4626_Rounding_Spec_Template is Test {
    MintableERC20 asset;
    Simple4626Vault vault;

    address alice = makeAddr("alice");
    address attacker = makeAddr("attacker");

    function setUp() public {
        asset = new MintableERC20();
        vault = new Simple4626Vault(asset);

        // seed liquidity to make rounding behavior realistic
        asset.mint(alice, 1_000 ether);
        vm.startPrank(alice);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(1_000 ether, alice);
        vm.stopPrank();

        asset.mint(attacker, 10 ether);
        vm.prank(attacker);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_small_loop_should_not_increase_attacker_net_assets() public {
        uint256 start = asset.balanceOf(attacker);

        // do many tiny cycles
        uint256 loops = 200;
        for (uint256 i = 0; i < loops; i++) {
            vm.startPrank(attacker);
            // deposit 1 wei worth of asset (smallest unit)
            vault.deposit(1, attacker);
            // withdraw 1 wei
            vault.withdraw(1, attacker, attacker);
            vm.stopPrank();
        }

        uint256 end = asset.balanceOf(attacker);

        // Tolerance: depends on your design. For a safe baseline, require no gain.
        assertLe(
            end,
            start,
            "attacker should not gain assets via rounding loop"
        );
    }

    function test_deposit_mint_withdraw_redeem_consistency_allow_small_error()
        public
    {
        // Compare deposit vs mint path around tiny amounts
        uint256 assetsIn = 1e6; // small but not 1 wei
        asset.mint(attacker, assetsIn);

        vm.startPrank(attacker);
        uint256 s1 = vault.deposit(assetsIn, attacker);
        uint256 out1 = vault.redeem(s1, attacker, attacker);
        vm.stopPrank();

        // Allow a tiny rounding loss, never a profit.
        assertLe(out1, assetsIn, "rounding may lose a bit, should not profit");
        assertLe(assetsIn - out1, 2, "loss should be within tiny dust");
    }
}
