// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";
import {TokenCallbackHandler} from "account-abstraction/accounts/callback/TokenCallbackHandler.sol";

/// @title BlockDAG Light Account
/// @author Abstract Labs
/// @notice Signle ERC-4337 smart account optimized for BlockDAG Network
/// @dev Key features:
/// - Single owner
/// - Execute signle or batch calls
/// - ERC-1271 signature validation

contract BlockDagLightAccount is BaseAccount, TokenCallbackHandler {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ======================================
    //      STATE VARIABLES
    // ======================================

    IEntryPoint private immutable _entryPoint;
    address public owner;

    // BlockDAG-specific: Track mining rewards balance
    uint256 public miningRewardsBalance;

    mapping(uint192 => uint64) public nonceSequenceNumber;

    // ======================================
    // EVENTs
    // =====================================

    event BlockDAGAccountInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event MiningRewardsDeposited(address indexed depositor, uint256 amount);

    event MinigRewardsUsed(uint256 amount, bytes userOpHash);

    // ======================================
    // ERRORS
    // ======================================

    error NotAuthorized();
    error InvalidOwner();
    error CallFailed();

    // ======================================
    // MODIFIERS
    // ======================================

    modifier onlyOwnerOrEntryPoint() {
        if (msg.sender != owner && msg.sender != address(_entryPoint)) {
            revert NotAuthorized();
        }
        _;
    }

    // ======================================
    // CONSTRUCTOR
    // ======================================

    constructor(IEntryPoint entryPoint_) {
        _entryPoint = entryPoint_;
        _disableInitializers();
    }

    function initialize(address owner_) external {
        if (owner != address(0)) revert("Already initialized");
        if (owner_ == address(0)) revert InvalidOwner();

        owner = owner_;
        emit BlockDAGAccountInitialized(_entryPoint, owner_);
        emit OwnershipTransferred(address(0), owner_);
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external override onlyOwnerOrEntryPoint {
        _call(dest, value, func);
    }

    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external onlyOwnerOrEntryPoint {
        if (dest.length != func.length || dest.length != value.length) {
            revert("Length mismatch");
        }

        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[1], value[i], func[i]);
        }
    }

    function transferOwnership(
        address newOwner
    ) external onlyOwnerOrEntryPoint {
        if (newOwner == address(0) || newOwner == address(this)) {
            revert InvalidOwner();
        }

        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // ========================================
    // BLOCKDAG-SPECIFIC FEATURES
    // ========================================

    /// @notice Deposit mining rewards that can be used for gas
    function depositMiningRewards() external payable {
        miningRewardsBalance += msg.value;
        emit MiningRewardsDeposited(msg.sender, msg.value);
    }

    function getNonce(uint192 key) external view returns (uint256) {
        return nonceSequenceNumber[key] | (uint256(key) << 64);
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    /// @inheritdoc BaseAccount
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();

        address recovered = hash.recover(userOp.signature);

        return recovered == owner ? 0 : 1;
    }

    // ======================================
    // INTERNAL HELPERS
    // ======================================

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @notice Disable initializers for the implementation contract
    function _disableInitializers() internal {
        owner = address(1);
    }

    receive() external payable {}
}
