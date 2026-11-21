// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentReputation} from "./AgentReputation.sol";

/// @dev Minimal interface for the SPACE ID Agent ID registry
///      (ERC-721, non-transferable, one per user). Only `balanceOf` is used:
///      a balance > 0 means the address holds an Agent ID.
interface IAgentIDRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title PromiseBond
/// @notice Oathbound: an agent declares a promise on-chain; its counterparty
///         attests that it was kept; if the deadline lapses, anyone can expire
///         it — recording a broken promise and burning the attached bond.
/// @dev    Stake is OPTIONAL. A 0-stake promise affects reputation only;
///         an attached BNB bond is the upgrade.
///
///         Immutability: no owner, no admin functions, no pause, no upgrade
///         path. There is deliberately no cancellation: a declared promise
///         resolves exactly once, via `attest` or `expire`.
///
///         Funds move only (a) back to the promiser on attestation, or
///         (b) to the burn address on expiry. Nothing ever transfers
///         automatically to a third-party address, and no token approvals
///         are ever requested.
contract PromiseBond {
    /// @notice SPACE ID Agent ID registry used to gate participation.
    IAgentIDRegistry public immutable agentId;

    /// @notice Reputation ledger, deployed alongside this contract and
    ///         writable only by it.
    AgentReputation public immutable reputation;

    address private constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    enum Status {
        Open,
        Kept,
        Broken
    }

    struct Promise {
        address promiser; // slot 1: 20B + 8B deadline
        uint64 deadline; //
        address counterparty; // slot 2: 20B + 1B status
        Status status; //
        bytes32 taskHash; // slot 3
        uint256 stake; // slot 4
    }

    /// @notice All promises, indexed by promiseId.
    Promise[] public promises;

    uint256 private _locked = 1;

    event PromiseDeclared(
        uint256 indexed promiseId,
        address indexed promiser,
        address indexed counterparty,
        bytes32 taskHash,
        uint64 deadline,
        uint256 stake
    );
    event PromiseAttested(uint256 indexed promiseId, address indexed promiser, address indexed counterparty);
    event PromiseExpired(uint256 indexed promiseId, address indexed promiser, uint256 stakeBurned);

    error NotAgentIdHolder(address account);
    error CounterpartyNotAgentIdHolder(address account);
    error SelfPromise();
    error DeadlineInPast();
    error InvalidPromise(uint256 promiseId);
    error PromiseNotOpen(uint256 promiseId);
    error NotCounterparty(address account);
    error DeadlinePassed(uint256 promiseId);
    error DeadlineNotPassed(uint256 promiseId);
    error TransferFailed();
    error Reentrant();

    /// @param agentId_ Address of the Agent ID registry. Mainnet:
    ///        0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F (SPACE ID Agent ID,
    ///        ERC-721, non-transferable).
    constructor(address agentId_) {
        agentId = IAgentIDRegistry(agentId_);
        reputation = new AgentReputation();
    }

    modifier nonReentrant() {
        if (_locked == 2) revert Reentrant();
        _locked = 2;
        _;
        _locked = 1;
    }

    /// @notice Declare a promise. `taskHash` is a commitment to the promise
    ///         content (e.g. keccak256 of an off-chain task spec). Attach BNB
    ///         as an optional bond.
    /// @param counterparty The Agent ID holder who judges the promise. Must be
    ///        an Agent ID holder and different from the promiser.
    /// @param deadline Unix timestamp after which the promise can be expired.
    /// @return promiseId Index of the new promise.
    function declarePromise(bytes32 taskHash, address counterparty, uint64 deadline)
        external
        payable
        returns (uint256 promiseId)
    {
        if (agentId.balanceOf(msg.sender) == 0) revert NotAgentIdHolder(msg.sender);
        if (counterparty == msg.sender) revert SelfPromise();
        if (agentId.balanceOf(counterparty) == 0) {
            revert CounterpartyNotAgentIdHolder(counterparty);
        }
        if (deadline <= block.timestamp) revert DeadlineInPast();

        promiseId = promises.length;
        promises.push(
            Promise({
                promiser: msg.sender,
                deadline: deadline,
                counterparty: counterparty,
                status: Status.Open,
                taskHash: taskHash,
                stake: msg.value
            })
        );

        emit PromiseDeclared(promiseId, msg.sender, counterparty, taskHash, deadline, msg.value);
    }

    /// @notice Counterparty attests that the promise was kept. Releases the
    ///         stake back to the promiser and records a kept promise.
    /// @dev    Reverts after the deadline — `expire` is the only path then.
    function attest(uint256 promiseId) external nonReentrant {
        Promise storage p = _getOpen(promiseId);
        if (msg.sender != p.counterparty) revert NotCounterparty(msg.sender);
        if (block.timestamp > p.deadline) revert DeadlinePassed(promiseId);

        p.status = Status.Kept;
        reputation.recordKept(p.promiser, p.stake > 0);

        uint256 stake = p.stake;
        if (stake > 0) {
            (bool ok,) = p.promiser.call{value: stake}("");
            if (!ok) revert TransferFailed();
        }

        emit PromiseAttested(promiseId, p.promiser, p.counterparty);
    }

    /// @notice Anyone may expire an open promise once its deadline has
    ///         passed. Records a broken promise and burns any stake to
    ///         0x000000000000000000000000000000000000dEaD.
    function expire(uint256 promiseId) external nonReentrant {
        Promise storage p = _getOpen(promiseId);
        if (block.timestamp <= p.deadline) revert DeadlineNotPassed(promiseId);

        p.status = Status.Broken;
        reputation.recordBroken(p.promiser);

        uint256 stake = p.stake;
        if (stake > 0) {
            (bool ok,) = BURN_ADDRESS.call{value: stake}("");
            if (!ok) revert TransferFailed();
        }

        emit PromiseExpired(promiseId, p.promiser, stake);
    }

    /// @notice Number of declared promises.
    function promiseCount() external view returns (uint256) {
        return promises.length;
    }

    /// @notice Full promise record (same data as the `promises` getter).
    function getPromise(uint256 promiseId) external view returns (Promise memory) {
        if (promiseId >= promises.length) revert InvalidPromise(promiseId);
        return promises[promiseId];
    }

    function _getOpen(uint256 promiseId) internal view returns (Promise storage p) {
        if (promiseId >= promises.length) revert InvalidPromise(promiseId);
        p = promises[promiseId];
        if (p.status != Status.Open) revert PromiseNotOpen(promiseId);
    }
}
