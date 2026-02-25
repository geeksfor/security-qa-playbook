// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

contract Simple4626Vault is ERC4626 {
    constructor(
        ERC20 asset_
    ) ERC20("SimpleVaultShare", "SVS") ERC4626(asset_) {}

    // no extra logic: pure ERC4626 baseline
}
