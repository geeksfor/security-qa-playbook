// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../helpers/BaseTest.t.sol";
import "../helpers/Asserts.t.sol";

contract D3_Asserts_Smoke_Test is BaseTest, Asserts {
    function test_absApprox_zero() public {
        assertApproxAbs(0, 0, 0, "abs approx should pass for 0");
    }

    function test_absApprox_tiny() public {
        // 1 wei difference allowed
        assertApproxAbs(100, 101, 1, "abs approx tiny diff");
    }

    function test_relApprox_huge() public {
        // huge numbers, allow 1 bps (0.01%)
        uint256 a = 1_000_000_000_000_000_000_000_000;
        uint256 b = a + (a / 20_000); // 0.005% (0.5 bps)
        assertApproxRelBps(a, b, 1, "rel approx huge within 1 bps");
    }

    function test_inRange_basic() public {
        assertInRange(10, 0, 10, "range should include upper bound");
        assertInRange(0, 0, 10, "range should include lower bound");
    }
}
