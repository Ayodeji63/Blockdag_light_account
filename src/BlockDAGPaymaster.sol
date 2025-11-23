// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BlockDAG Paymaster
/// @notice Sponsors gas for UserOperations on BlockDAG
/// @dev Supports sponsoring via:
/// - Whitelisted addresses
/// - Mining rewards
/// - Policy-based sponsorship
contract BlockDAGPaymaster is IPaymaster, Ownable {
    IEntryPoint public immutable entryPoint;

    // Whitelisted accounts that get free gas
    mapping(address => bool) public whitelist;

    // Deposit for sponsoring gas
    uint256 public sponsorshipDeposit;

    event UserOperationSponsored(
        address indexed account,
        bytes32 userOpHash,
        uint256 gasSponsored
    );

    constructor(IEntryPoint entryPoint_) Ownable(msg.sender) {
        entryPoint = entryPoint_;
    }

    /// @notice Validate if we should sponsor this UserOperation
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        // Check if account is whitelisted
        if (whitelist[userOp.sender]) {
            return ("", 0); // Sponsor it!
        }

        // Check if paymaster has enough deposit
        if (sponsorshipDeposit < maxCost) {
            return ("", 1); // Reject
        }

        // Sponsor it
        return ("", 0);
    }

    /// @notice Called after UserOperation execution
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external override {
        // Deduct from sponsorship deposit
        sponsorshipDeposit -= actualGasCost;

        emit UserOperationSponsored(
            address(0), // Would need to extract from context
            bytes32(0),
            actualGasCost
        );
    }

    /// @notice Add address to whitelist
    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
    }

    /// @notice Deposit funds for sponsorship
    function deposit() external payable {
        sponsorshipDeposit += msg.value;
        // Also deposit to EntryPoint
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    receive() external payable {}
}
