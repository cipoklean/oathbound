// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PromiseBond, IAgentIDRegistry} from "../src/PromiseBond.sol";
import {AgentReputation} from "../src/AgentReputation.sol";
import {MockAgentID} from "./mocks/MockAgentID.sol";

contract RejectingReceiver {
    receive() external payable {
        revert("no thanks");
    }
}

contract PromiseBondTest is Test {
    PromiseBond bond;
    AgentReputation rep;
    MockAgentID registry;

    address alice = makeAddr("alice"); // Agent ID holder
    address bob = makeAddr("bob"); // Agent ID holder
    address carol = makeAddr("carol"); // not a holder

    bytes32 constant TASK = keccak256("deliver the thing");

    function setUp() public {
        registry = new MockAgentID();
        bond = new PromiseBond(address(registry));
        rep = bond.reputation();
        registry.mint(alice);
        registry.mint(bob);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _declare(address promiser, address counterparty, uint256 stake, uint64 deadline)
        internal
        returns (uint256)
    {
        vm.prank(promiser);
        return bond.declarePromise{value: stake}(TASK, counterparty, deadline);
    }

    function _deadline() internal view returns (uint64) {
        return uint64(block.timestamp + 1 days);
    }

    // ---- declarePromise ----

    function test_DeclareNoStake() public {
        vm.expectEmit(true, true, true, true);
        emit PromiseBond.PromiseDeclared(0, alice, bob, TASK, _deadline(), 0);
        uint256 id = _declare(alice, bob, 0, _deadline());
        assertEq(id, 0);
        assertEq(bond.promiseCount(), 1);

        PromiseBond.Promise memory p = bond.getPromise(0);
        assertEq(p.promiser, alice);
        assertEq(p.counterparty, bob);
        assertEq(p.taskHash, TASK);
        assertEq(p.stake, 0);
        assertEq(uint8(p.status), uint8(PromiseBond.Status.Open));
    }

    function test_DeclareWithStake() public {
        uint256 id = _declare(alice, bob, 1 ether, _deadline());
        assertEq(bond.getPromise(id).stake, 1 ether);
        assertEq(address(bond).balance, 1 ether);
    }

    function test_RevertDeclareNonHolderPromiser() public {
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.NotAgentIdHolder.selector, carol));
        _declare(carol, bob, 0, _deadline());
    }

    function test_RevertDeclareNonHolderCounterparty() public {
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.CounterpartyNotAgentIdHolder.selector, carol));
        _declare(alice, carol, 0, _deadline());
    }

    function test_RevertDeclareSelfPromise() public {
        vm.expectRevert(PromiseBond.SelfPromise.selector);
        _declare(alice, alice, 0, _deadline());
    }

    function test_RevertDeclareDeadlineInPast() public {
        vm.expectRevert(PromiseBond.DeadlineInPast.selector);
        _declare(alice, bob, 0, uint64(block.timestamp));

        vm.expectRevert(PromiseBond.DeadlineInPast.selector);
        _declare(alice, bob, 0, uint64(block.timestamp - 1));
    }

    // ---- attest ----

    function test_Attest() public {
        uint256 id = _declare(alice, bob, 0, _deadline());
        vm.prank(bob);
        bond.attest(id);

        assertEq(uint8(bond.getPromise(id).status), uint8(PromiseBond.Status.Kept));
        (uint256 kept, uint256 broken, uint256 bondedKept, uint256 scoreBps) = rep.scoreOf(alice);
        assertEq(kept, 1);
        assertEq(broken, 0);
        assertEq(bondedKept, 0);
        assertEq(scoreBps, 10000);
    }

    function test_AttestReturnsStakeAndCountsBonded() public {
        uint256 id = _declare(alice, bob, 1 ether, _deadline());
        uint256 before = alice.balance;
        vm.prank(bob);
        bond.attest(id);

        assertEq(alice.balance, before + 1 ether);
        assertEq(address(bond).balance, 0);
        (,, uint256 bondedKept,) = rep.scoreOf(alice);
        assertEq(bondedKept, 1);
    }

    function test_RevertAttestNotCounterparty() public {
        uint256 id = _declare(alice, bob, 0, _deadline());
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.NotCounterparty.selector, alice));
        vm.prank(alice);
        bond.attest(id);
    }

    function test_RevertAttestAfterDeadline() public {
        uint256 id = _declare(alice, bob, 0, _deadline());
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.DeadlinePassed.selector, id));
        vm.prank(bob);
        bond.attest(id);
    }

    function test_AttestAtExactDeadline() public {
        uint256 id = _declare(alice, bob, 0, _deadline());
        vm.warp(_deadline());
        vm.prank(bob);
        bond.attest(id);
        assertEq(uint8(bond.getPromise(id).status), uint8(PromiseBond.Status.Kept));
    }

    // ---- expire ----

    function test_ExpireBurnsStake() public {
        address dead = 0x000000000000000000000000000000000000dEaD;
        uint256 id = _declare(alice, bob, 1 ether, _deadline());
        uint256 deadBefore = dead.balance;

        vm.warp(block.timestamp + 2 days);
        bond.expire(id); // permissionless: called by an unrelated EOA

        assertEq(uint8(bond.getPromise(id).status), uint8(PromiseBond.Status.Broken));
        assertEq(dead.balance, deadBefore + 1 ether);
        assertEq(address(bond).balance, 0);

        (uint256 kept, uint256 broken, uint256 bondedKept, uint256 scoreBps) = rep.scoreOf(alice);
        assertEq(kept, 0);
        assertEq(broken, 1);
        assertEq(bondedKept, 0);
        assertEq(scoreBps, 0);
    }

    function test_ExpireNoStake() public {
        uint256 id = _declare(alice, bob, 0, _deadline());
        vm.warp(block.timestamp + 2 days);
        bond.expire(id);
        assertEq(uint8(bond.getPromise(id).status), uint8(PromiseBond.Status.Broken));
    }

    function test_RevertExpireBeforeDeadline() public {
        uint256 id = _declare(alice, bob, 0, _deadline());
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.DeadlineNotPassed.selector, id));
        bond.expire(id);
    }

    // ---- resolution is final ----

    function test_RevertDoubleResolve() public {
        uint256 id = _declare(alice, bob, 0, _deadline());
        vm.prank(bob);
        bond.attest(id);

        vm.expectRevert(abi.encodeWithSelector(PromiseBond.PromiseNotOpen.selector, id));
        bond.expire(id);

        vm.expectRevert(abi.encodeWithSelector(PromiseBond.PromiseNotOpen.selector, id));
        vm.prank(bob);
        bond.attest(id);
    }

    function test_RevertInvalidPromiseId() public {
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.InvalidPromise.selector, 0));
        bond.attest(0);
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.InvalidPromise.selector, 0));
        bond.expire(0);
        vm.expectRevert(abi.encodeWithSelector(PromiseBond.InvalidPromise.selector, 0));
        bond.getPromise(0);
    }

    // ---- reputation ----

    function test_ScoreEmptyIsZero() public view {
        (uint256 kept, uint256 broken, uint256 bondedKept, uint256 scoreBps) = rep.scoreOf(carol);
        assertEq(kept, 0);
        assertEq(broken, 0);
        assertEq(bondedKept, 0);
        assertEq(scoreBps, 0);
    }

    function test_ScoreRatioBasisPoints() public {
        // one kept + one broken => 5000 bps
        uint256 kept = _declare(alice, bob, 0, _deadline());
        uint256 broke = _declare(alice, bob, 0, _deadline());
        vm.prank(bob);
        bond.attest(kept);
        vm.warp(block.timestamp + 2 days);
        bond.expire(broke);

        (,,, uint256 scoreBps) = rep.scoreOf(alice);
        assertEq(scoreBps, 5000);
    }

    function test_RevertDirectReputationWrite() public {
        vm.expectRevert(AgentReputation.OnlyBondContract.selector);
        rep.recordKept(alice, false);
        vm.expectRevert(AgentReputation.OnlyBondContract.selector);
        rep.recordBroken(alice);
    }

    // ---- promiser can't receive -> only expire is left ----

    function test_PromiserRejectsReceive_AttestReverts_ExpireBurns() public {
        RejectingReceiver r = new RejectingReceiver();
        registry.mint(address(r)); // the contract is an Agent ID holder
        vm.deal(address(r), 1 ether);

        vm.prank(address(r));
        uint256 id = bond.declarePromise{value: 1 ether}(TASK, bob, _deadline());

        vm.expectRevert(PromiseBond.TransferFailed.selector);
        vm.prank(bob);
        bond.attest(id);

        // Stake stays locked until expiry, then burns — never stranded.
        assertEq(address(bond).balance, 1 ether);
        vm.warp(block.timestamp + 2 days);
        bond.expire(id);
        assertEq(address(bond).balance, 0);
    }
}
