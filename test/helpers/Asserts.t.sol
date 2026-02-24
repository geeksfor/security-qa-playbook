// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

abstract contract Asserts is Test {
    // --- Absolute error: |a-b| <= maxAbsDiff ---
    function assertApproxAbs(
        uint256 a,
        uint256 b,
        uint256 maxAbsDiff,
        string memory err
    ) internal {
        uint256 diff = a > b ? a - b : b - a;
        assertLe(diff, maxAbsDiff, err);
    }

    // --- Relative error (bps): |a-b| / max(a,b) <= maxRelBps/10000 ---
    // maxRelBps: 100 = 1%, 10 = 0.1%
    // 判断 a 和 b “相对误差”是否足够小
    function assertApproxRelBps(
        uint256 a,
        uint256 b,
        uint256 maxRelBps,
        string memory err
    ) internal {
        if (a == b) return;

        uint256 hi = a > b ? a : b;
        uint256 lo = a > b ? b : a;

        // diff/hi <= bps/10000  => diff*10000 <= hi*bps
        uint256 diff = hi - lo;
        assertLe(diff * 10_000, hi * maxRelBps, err);
    }

    // --- Interval: min <= x <= max ---
    function assertInRange(
        uint256 x,
        uint256 minIncl,
        uint256 maxIncl,
        string memory err
    ) internal {
        assertGe(x, minIncl, string(abi.encodePacked(err, " (below min)")));
        assertLe(x, maxIncl, string(abi.encodePacked(err, " (above max)")));
    }
}
