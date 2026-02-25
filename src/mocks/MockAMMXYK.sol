// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockAMMXYK {
    uint256 public constant WAD = 1e18;

    uint256 public reserve0; // token0
    uint256 public reserve1; // token1 (quote, e.g. USD)

    constructor(uint256 r0, uint256 r1) {
        reserve0 = r0;
        reserve1 = r1;
    }

    function spotPrice0In1Wad() public view returns (uint256) {
        // price of token0 in token1: reserve1/reserve0
        require(reserve0 != 0, "R0_ZERO");
        return (reserve1 * WAD) / reserve0;
    }

    // swap token1 in for token0 out (push price up for token0)
    function swap1For0(
        uint256 amount1In
    ) external returns (uint256 amount0Out) {
        // x*y=k, no fee, minimal
        uint256 x = reserve0;
        uint256 y = reserve1;

        uint256 newY = y + amount1In;
        uint256 k = x * y;
        uint256 newX = k / newY;

        amount0Out = x - newX;
        reserve0 = newX;
        reserve1 = newY;
    }
}
