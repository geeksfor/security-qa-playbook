// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockAMMXYK} from "src/mocks/MockAMMXYK.sol";
import {MockOracle} from "src/mocks/MockOracle.sol";

contract SpotBasedLending {
    uint256 public constant WAD = 1e18;

    MockAMMXYK public amm; // spot source (vuln)
    MockOracle public oracle; // reference (for protection)
    uint256 public ltv;
    uint256 public maxDeviationBps; // e.g. 500 = 5%

    mapping(address => uint256) public collateral0; // token0 amount (WAD)
    mapping(address => uint256) public debtUsd; // USD debt (WAD)

    error DeviationTooHigh(uint256 spot, uint256 ref);

    constructor(
        MockAMMXYK _amm,
        MockOracle _oracle,
        uint256 _ltv,
        uint256 _maxDevBps
    ) {
        amm = _amm;
        oracle = _oracle;
        ltv = _ltv;
        maxDeviationBps = _maxDevBps;
    }

    function deposit(uint256 amt0) external {
        collateral0[msg.sender] += amt0;
    }

    function _refPrice() internal view returns (uint256) {
        (int256 p, ) = oracle.getPrice();
        require(p > 0, "BAD_REF");
        return uint256(p);
    }

    function _spotPrice() internal view returns (uint256) {
        return amm.spotPrice0In1Wad();
    }

    // protection: circuit breaker on spot vs oracle
    function _checkDeviation(uint256 spot, uint256 ref) internal view {
        // |spot-ref|/ref <= maxDevBps/10000
        uint256 diff = spot > ref ? spot - ref : ref - spot;
        uint256 bps = (diff * 10000) / ref;
        if (bps > maxDeviationBps) revert DeviationTooHigh(spot, ref);
    }

    function maxBorrowUsd(
        address u,
        bool useProtection
    ) public view returns (uint256) {
        uint256 price = _spotPrice();
        if (useProtection) _checkDeviation(price, _refPrice());
        uint256 value = (collateral0[u] * price) / WAD;
        return (value * ltv) / WAD;
    }

    function borrow(uint256 amtUsd, bool useProtection) external {
        uint256 newDebt = debtUsd[msg.sender] + amtUsd;
        uint256 maxDebt = maxBorrowUsd(msg.sender, useProtection);
        require(newDebt <= maxDebt, "EXCEEDS");
        debtUsd[msg.sender] = newDebt;
    }
}
