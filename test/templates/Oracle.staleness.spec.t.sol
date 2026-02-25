// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockOracle} from "src/mocks/MockOracle.sol";

contract PriceConsumer {
    MockOracle public oracle;
    uint256 public maxAge; // seconds

    error StalePrice(uint256 updatedAt, uint256 nowTs);

    constructor(MockOracle _oracle, uint256 _maxAge) {
        oracle = _oracle;
        maxAge = _maxAge;
    }

    function readPriceStrict() external view returns (int256) {
        (int256 p, uint256 u) = oracle.getPrice();
        if (block.timestamp > u + maxAge) revert StalePrice(u, block.timestamp);
        // optional: p must be positive
        return p;
    }

    // sentinel mode: return (valid, price)
    function readPriceSentinel() external view returns (bool ok, int256 p) {
        (int256 p, uint256 u) = oracle.getPrice();
        if (block.timestamp > u + maxAge) return (false, p);
        return (true, p);
    }
}

contract Oracle_Staleness_Spec is Test {
    MockOracle oracle;
    PriceConsumer consumer;

    uint256 constant MAX_AGE = 1 hours;

    function setUp() external {
        oracle = new MockOracle(2000e8, 1000); // pretend 1e8 decimals
        consumer = new PriceConsumer(oracle, MAX_AGE);
    }

    function test_strict_notStale_ok() external {
        vm.warp(2000);
        oracle.setPriceWithTime(2000e8, 2000);
        int256 p = consumer.readPriceStrict();
        assertEq(p, 2000e8);
    }

    function test_strict_justStale_reverts() external {
        vm.warp(2000);
        oracle.setPriceWithTime(2000e8, 2000);

        // move to exactly stale boundary + 1
        vm.warp(2000 + MAX_AGE + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                PriceConsumer.StalePrice.selector,
                2000,
                2000 + MAX_AGE + 1
            )
        );
        consumer.readPriceStrict();
    }

    function test_sentinel_stale_returns_false() external {
        vm.warp(3000);
        oracle.setPriceWithTime(2000e8, 3000);

        vm.warp(3000 + MAX_AGE + 123);

        (bool ok, ) = consumer.readPriceSentinel();
        assertFalse(ok);
    }
}
