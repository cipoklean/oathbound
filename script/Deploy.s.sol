// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PromiseBond} from "../src/PromiseBond.sol";

/// @dev Deploys PromiseBond (which deploys AgentReputation internally).
///      forge script script/Deploy.s.sol --rpc-url $BSC_RPC_URL --broadcast --verify
contract Deploy is Script {
    // SPACE ID Agent ID registry on BNB Chain mainnet (ERC-721, non-transferable).
    address constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external returns (PromiseBond bond) {
        vm.startBroadcast();
        bond = new PromiseBond(AGENT_ID_REGISTRY);
        vm.stopBroadcast();

        console2.log("PromiseBond:     ", address(bond));
        console2.log("AgentReputation: ", address(bond.reputation()));
    }
}
