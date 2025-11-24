// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {BlockDAGLightAccount} from "./BlockDAGLightAccount.sol";

/// @title BlockDAG Account Factory
/// @notice Factory for deploying BlockDAG Light Accounts
/// @dev Uses CREATE2 for deterministic addresses
contract BlockDAGLightAccountFactory {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice The implementation contract
    BlockDAGLightAccount public immutable accountImplementation;

    /// @notice The EntryPoint contract
    IEntryPoint public immutable entryPoint;

    // ============================================
    // EVENTS
    // ============================================

    event AccountCreated(
        address indexed account,
        address indexed owner,
        uint256 salt
    );

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor(IEntryPoint entryPoint_) {
        entryPoint = entryPoint_;
        accountImplementation = new BlockDAGLightAccount(entryPoint_);
    }

    // ============================================
    // ACCOUNT CREATION
    // ============================================

    /// @notice Create a new account (or return existing)
    /// @param owner The owner of the account
    /// @param salt A salt for deterministic address generation
    /// @return account The created or existing account
    function createAccount(
        address owner,
        uint256 salt
    ) external returns (BlockDAGLightAccount account) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;

        if (codeSize > 0) {
            // Account already exists
            return BlockDAGLightAccount(payable(addr));
        }

        // Deploy new account
        bytes memory initData = abi.encodeCall(
            BlockDAGLightAccount.initialize,
            (owner)
        );

        ERC1967Proxy proxy = new ERC1967Proxy{
            salt: bytes32(_getSalt(owner, salt))
        }(address(accountImplementation), initData);

        account = BlockDAGLightAccount(payable(address(proxy)));

        emit AccountCreated(address(account), owner, salt);
    }

    /// @notice Get the counterfactual address of an account
    /// @param owner The owner of the account
    /// @param salt The salt used for address generation
    /// @return The address where the account would be deployed
    function getAddress(
        address owner,
        uint256 salt
    ) public view returns (address) {
        bytes memory initData = abi.encodeCall(
            BlockDAGLightAccount.initialize,
            (owner)
        );

        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(accountImplementation), initData)
        );

        return
            Create2.computeAddress(
                bytes32(_getSalt(owner, salt)),
                keccak256(proxyBytecode)
            );
    }

    // ============================================
    // INTERNAL HELPERS
    // ============================================

    /// @notice Combine owner and salt into a single salt value
    /// @param owner The account owner
    /// @param salt The user-provided salt
    /// @return The combined salt
    function _getSalt(
        address owner,
        uint256 salt
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(owner, salt)));
    }
}
