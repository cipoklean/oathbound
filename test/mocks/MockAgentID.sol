// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentIDRegistry} from "../../src/PromiseBond.sol";

/// @dev Minimal stand-in for the Agent ID registry: `mint` grants a balance.
contract MockAgentID is IAgentIDRegistry {
    mapping(address => uint256) public balanceOf;

    function mint(address to) external {
        balanceOf[to] += 1;
    }
}
