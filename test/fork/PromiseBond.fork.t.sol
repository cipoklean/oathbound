// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PromiseBond, IAgentIDRegistry} from "../../src/PromiseBond.sol";
import {AgentReputation} from "../../src/AgentReputation.sol";

/// @dev Fork test against BSC mainnet and the live SPACE ID Agent ID registry.
///      Runs only when BSC_RPC_URL is set:
///      BSC_RPC_URL=https://bsc.publicnode.com forge test --match-path "test/fork/*" -vvv
contract PromiseBondForkTest is Test {
    address constant REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    // Real Agent ID holders (recent minters, verified balanceOf == 1).
    address constant HOLDER_A = 0xfEf9B24BC04c9F7308B47d62DAa95aa7Dcfdc7bF;
    address constant HOLDER_B = 0xff0Db1546133af8EbA6272A09D3D397675F6f0d2;
    address constant NON_HOLDER = address(0xBEEF);

    PromiseBond bond;
    AgentReputation rep;

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc);

        bond = new PromiseBond(REGISTRY);
        rep = bond.reputation();
        vm.deal(HOLDER_A, 10 ether);
        vm.deal(HOLDER_B, 10 ether);
    }

    function test_RegistryIsLiveAgentIdErc721() public {
        // ERC-721 interface id.
        (bool ok, bytes memory data) =
            REGISTRY.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0x80ac58cd)));
        assertTrue(ok);
        assertTrue(abi.decode(data, (bool)));
        assertEq(IAgentIDRegistry(REGISTRY).balanceOf(HOLDER_A), 1);
        assertEq(IAgentIDRegistry(REGISTRY).balanceOf(NON_HOLDER), 0);
    }

    function test_FullCycleOnRealRegistry() public {
        vm.prank(HOLDER_A);
        uint256 id =
            bond.declarePromise{value: 0.001 ether}(keccak256("fork task"), HOLDER_B, uint64(block.timestamp + 1 days));

        vm.prank(HOLDER_B);
        bond.attest(id);

        (uint256 kept,, uint256 bondedKept, uint256 scoreBps) = rep.scoreOf(HOLDER_A);
        assertEq(kept, 1);
        assertEq(bondedKept, 1);
        assertEq(scoreBps, 10000);
    }

    function test_ExpireCycleOnRealRegistry() public {
        vm.prank(HOLDER_A);
        uint256 id = bond.declarePromise(keccak256("fork task"), HOLDER_B, uint64(block.timestamp + 1 days));

        vm.warp(block.timestamp + 2 days);
        bond.expire(id);

        (, uint256 broken,,) = rep.scoreOf(HOLDER_A);
        assertEq(broken, 1);
    }

    function test_NonHolderCannotDeclare() public {
        vm.deal(NON_HOLDER, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.NotAgentIdHolder.selector, NON_HOLDER));
        vm.prank(NON_HOLDER);
        bond.declarePromise(keccak256("x"), HOLDER_B, uint64(block.timestamp + 1 days));
    }
}
