// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PromiseBond} from "../src/PromiseBond.sol";
import {MockAgentID} from "../test/mocks/MockAgentID.sol";

/// @dev Testnet deploy. The real SPACE ID Agent ID registry exists only on
///      BSC mainnet, so we deploy a MockAgentID (open mint) as the gate
///      stand-in — anyone can `mint(theirAddress)` to act as a holder.
///      forge script script/DeployTestnet.s.sol --rpc-url bsc_testnet --broadcast
contract DeployTestnet is Script {
    function run() external returns (MockAgentID registry, PromiseBond bond) {
        vm.startBroadcast();
        registry = new MockAgentID();
        bond = new PromiseBond(address(registry));
        vm.stopBroadcast();

        console2.log("MockAgentID (testnet stand-in):", address(registry));
        console2.log("PromiseBond:                   ", address(bond));
        console2.log("AgentReputation:               ", address(bond.reputation()));
        console2.log("NOTE: mock has open mint() - testnet only, real registry is mainnet-only");
    }
}
