// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentReputation
/// @notice Oathbound: immutable kept / broken / bondedKept promise counts per
///         agent address, plus a simple basis-points score.
/// @dev    Deployed by PromiseBond at construction time; `bondContract` is
///         fixed forever and is the only address allowed to write.
///         No owner, no admin functions, no pause, no upgradeability.
contract AgentReputation {
    /// @notice The only contract allowed to record outcomes — the PromiseBond
    ///         instance that deployed this contract.
    address public immutable bondContract;

    /// @notice Total kept promises per agent address.
    mapping(address => uint256) public kept;
    /// @notice Total broken (expired) promises per agent address.
    mapping(address => uint256) public broken;
    /// @notice Kept promises that carried a nonzero stake.
    mapping(address => uint256) public bondedKept;

    event KeptRecorded(address indexed agent, bool bonded);
    event BrokenRecorded(address indexed agent);

    error OnlyBondContract();

    constructor() {
        // When PromiseBond's constructor runs `new AgentReputation()`,
        // msg.sender here is the PromiseBond contract being deployed.
        bondContract = msg.sender;
    }

    /// @notice Record a kept promise for `agent`. Only callable by PromiseBond.
    function recordKept(address agent, bool bonded) external {
        if (msg.sender != bondContract) revert OnlyBondContract();
        unchecked {
            ++kept[agent];
        }
        if (bonded) {
            unchecked {
                ++bondedKept[agent];
            }
        }
        emit KeptRecorded(agent, bonded);
    }

    /// @notice Record a broken promise for `agent`. Only callable by PromiseBond.
    function recordBroken(address agent) external {
        if (msg.sender != bondContract) revert OnlyBondContract();
        unchecked {
            ++broken[agent];
        }
        emit BrokenRecorded(agent);
    }

    /// @notice Reputation summary for an agent address.
    /// @return kept_        kept promises
    /// @return broken_      broken promises
    /// @return bondedKept_  kept promises that had a stake attached
    /// @return scoreBps     kept / (kept + broken) in basis points, 0 if no history
    function scoreOf(address agent)
        external
        view
        returns (uint256 kept_, uint256 broken_, uint256 bondedKept_, uint256 scoreBps)
    {
        uint256 k = kept[agent];
        uint256 b = broken[agent];
        uint256 total = k + b;
        return (k, b, bondedKept[agent], total == 0 ? 0 : (k * 10000) / total);
    }
}
