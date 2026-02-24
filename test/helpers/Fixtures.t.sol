// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./BaseTest.t.sol";
import "../../src/mocks/MockERC20.sol";

abstract contract Fixtures is BaseTest {
    MockERC20 internal token;

    // 统一初始资金（示例：18 decimals）
    uint256 internal constant ALICE_INIT = 1_000 ether;
    uint256 internal constant BOB_INIT = 2_000 ether;
    uint256 internal constant ATTACKER_INIT = 3_000 ether;

    function setUp() public virtual override {
        super.setUp();
        _deployTokens();
        _seedBalances();
    }

    function _deployTokens() internal {
        token = new MockERC20("Mock Token", "MOCK", 18);
        vm.label(address(token), "MOCK_TOKEN");
    }

    function _seedBalances() internal {
        token.mint(alice, ALICE_INIT);
        token.mint(bob, BOB_INIT);
        token.mint(attacker, ATTACKER_INIT);
    }

    // ✅ D4 断言点：totalSupply == sum(balances)（至少一组）
    function _assertSupplyMatchesSeed() internal {
        uint256 sum = token.balanceOf(alice) +
            token.balanceOf(bob) +
            token.balanceOf(attacker);
        assertEq(
            token.totalSupply(),
            sum,
            "totalSupply should equal seeded balances sum"
        );
    }
}
