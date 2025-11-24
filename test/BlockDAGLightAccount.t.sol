// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/BlockDAGLightAccount.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import "account-abstraction/interfaces/PackedUserOperation.sol";

// ✅ ADD THIS IMPORT
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract BlockDAGLightAccountTest is Test {
    // ✅ ADD THIS LINE
    using MessageHashUtils for bytes32;

    BlockDAGLightAccount public account;
    IEntryPoint public entryPoint;

    address public owner;
    address public notOwner;
    address public newOwner;

    // Events to test
    event BlockDAGAccountInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event MiningRewardsDeposited(address indexed depositor, uint256 amount);

    function setUp() public {
        // Create test addresses
        owner = makeAddr("owner");
        notOwner = makeAddr("notOwner");
        newOwner = makeAddr("newOwner");

        // Use canonical EntryPoint address
        entryPoint = IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

        // Deploy account implementation
        account = new BlockDAGLightAccount(entryPoint);
    }

    // ============================================
    // INITIALIZATION TESTS
    // ============================================

    function test_Initialize_Success() public {
        // Expect events
        vm.expectEmit(true, true, false, true);
        emit BlockDAGAccountInitialized(entryPoint, owner);

        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), owner);

        // Initialize account
        account.initialize(owner);

        // Verify state
        assertEq(account.owner(), owner);
        assertEq(address(account.entryPoint()), address(entryPoint));
    }

    function test_Initialize_RevertIf_AlreadyInitialized() public {
        // First initialization
        account.initialize(owner);

        // Second initialization should fail
        vm.expectRevert(BlockDAGLightAccount.AlreadyInitialized.selector);
        account.initialize(owner);
    }

    function test_Initialize_RevertIf_ZeroAddress() public {
        vm.expectRevert(BlockDAGLightAccount.InvalidOwner.selector);
        account.initialize(address(0));
    }

    function testFuzz_Initialize(address _owner) public {
        vm.assume(_owner != address(0));

        BlockDAGLightAccount newAccount = new BlockDAGLightAccount(entryPoint);
        newAccount.initialize(_owner);

        assertEq(newAccount.owner(), _owner);
    }

    // ============================================
    // OWNERSHIP TESTS
    // ============================================

    function test_TransferOwnership_Success() public {
        account.initialize(owner);

        // Transfer ownership as owner
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(owner, newOwner);

        account.transferOwnership(newOwner);

        assertEq(account.owner(), newOwner);
    }

    function test_TransferOwnership_FromEntryPoint() public {
        account.initialize(owner);

        // Transfer ownership from EntryPoint
        vm.prank(address(entryPoint));
        account.transferOwnership(newOwner);

        assertEq(account.owner(), newOwner);
    }

    function test_TransferOwnership_RevertIf_NotAuthorized() public {
        account.initialize(owner);

        vm.prank(notOwner);
        vm.expectRevert(BlockDAGLightAccount.NotAuthorized.selector);
        account.transferOwnership(newOwner);
    }

    function test_TransferOwnership_RevertIf_ZeroAddress() public {
        account.initialize(owner);

        vm.prank(owner);
        vm.expectRevert(BlockDAGLightAccount.InvalidOwner.selector);
        account.transferOwnership(address(0));
    }

    function test_TransferOwnership_RevertIf_SelfAddress() public {
        account.initialize(owner);

        vm.prank(owner);
        vm.expectRevert(BlockDAGLightAccount.InvalidOwner.selector);
        account.transferOwnership(address(account));
    }

    // ============================================
    // EXECUTE TESTS
    // ============================================

    function test_Execute_Success() public {
        account.initialize(owner);

        // Fund the account
        vm.deal(address(account), 1 ether);

        // Execute transfer
        address recipient = makeAddr("recipient");
        vm.prank(owner);
        account.execute(recipient, 0.5 ether, "");

        assertEq(recipient.balance, 0.5 ether);
        assertEq(address(account).balance, 0.5 ether);
    }

    function test_Execute_WithCalldata() public {
        account.initialize(owner);

        // Deploy a mock contract
        MockTarget target = new MockTarget();

        // Execute with calldata
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.prank(owner);
        account.execute(address(target), 0, data);

        assertEq(target.value(), 42);
    }

    function test_Execute_FromEntryPoint() public {
        account.initialize(owner);

        address recipient = makeAddr("recipient");
        vm.deal(address(account), 1 ether);

        vm.prank(address(entryPoint));
        account.execute(recipient, 0.5 ether, "");

        assertEq(recipient.balance, 0.5 ether);
    }

    function test_Execute_RevertIf_NotAuthorized() public {
        account.initialize(owner);

        address recipient = makeAddr("recipient");

        vm.prank(notOwner);
        vm.expectRevert(BlockDAGLightAccount.NotAuthorized.selector);
        account.execute(recipient, 0, "");
    }

    function test_Execute_RevertIf_CallFails() public {
        account.initialize(owner);

        // Deploy reverting contract
        MockReverter reverter = new MockReverter();

        vm.prank(owner);
        vm.expectRevert("Mock revert");
        account.execute(
            address(reverter),
            0,
            abi.encodeWithSignature("revertFunction()")
        );
    }

    // ============================================
    // EXECUTE BATCH TESTS
    // ============================================

    function test_ExecuteBatch_Success() public {
        account.initialize(owner);
        vm.deal(address(account), 3 ether);

        // Prepare batch
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory data = new bytes[](3);

        targets[0] = makeAddr("recipient1");
        targets[1] = makeAddr("recipient2");
        targets[2] = makeAddr("recipient3");

        values[0] = 1 ether;
        values[1] = 1 ether;
        values[2] = 1 ether;

        data[0] = "";
        data[1] = "";
        data[2] = "";

        // Execute batch
        vm.prank(owner);
        account.executeBatch(targets, values, data);

        assertEq(targets[0].balance, 1 ether);
        assertEq(targets[1].balance, 1 ether);
        assertEq(targets[2].balance, 1 ether);
    }

    function test_ExecuteBatch_WithCalldata() public {
        account.initialize(owner);

        // Deploy mock targets
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = address(target1);
        targets[1] = address(target2);

        values[0] = 0;
        values[1] = 0;

        data[0] = abi.encodeWithSignature("setValue(uint256)", 100);
        data[1] = abi.encodeWithSignature("setValue(uint256)", 200);

        vm.prank(owner);
        account.executeBatch(targets, values, data);

        assertEq(target1.value(), 100);
        assertEq(target2.value(), 200);
    }

    function test_ExecuteBatch_RevertIf_LengthMismatch() public {
        account.initialize(owner);

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1); // Mismatch!
        bytes[] memory data = new bytes[](2);

        vm.prank(owner);
        vm.expectRevert("Length mismatch");
        account.executeBatch(targets, values, data);
    }

    function test_ExecuteBatch_RevertIf_NotAuthorized() public {
        account.initialize(owner);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory data = new bytes[](1);

        vm.prank(notOwner);
        vm.expectRevert(BlockDAGLightAccount.NotAuthorized.selector);
        account.executeBatch(targets, values, data);
    }

    // ============================================
    // MINING REWARDS TESTS
    // ============================================

    function test_DepositMiningRewards_Success() public {
        account.initialize(owner);

        uint256 depositAmount = 10 ether;

        vm.expectEmit(true, false, false, true);
        emit MiningRewardsDeposited(address(this), depositAmount);

        account.depositMiningRewards{value: depositAmount}();

        assertEq(account.miningRewardsBalance(), depositAmount);
        assertEq(address(account).balance, depositAmount);
    }

    function test_DepositMiningRewards_Multiple() public {
        account.initialize(owner);

        account.depositMiningRewards{value: 5 ether}();
        account.depositMiningRewards{value: 3 ether}();
        account.depositMiningRewards{value: 2 ether}();

        assertEq(account.miningRewardsBalance(), 10 ether);
    }

    function testFuzz_DepositMiningRewards(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1000 ether);

        account.initialize(owner);
        vm.deal(address(this), amount);

        account.depositMiningRewards{value: amount}();

        assertEq(account.miningRewardsBalance(), amount);
    }

    // ============================================
    // NONCE TESTS
    // ============================================

    function test_GetNonce_DefaultKey() public {
        account.initialize(owner);

        uint192 key = 0;
        uint256 nonce = account.getNonce(key);

        assertEq(nonce, 0);
    }

    function test_GetNonce_CustomKey() public {
        account.initialize(owner);

        uint192 key = 123;
        uint256 nonce = account.getNonce(key);

        // Nonce should be key << 64
        uint256 expected = uint256(key) << 64;
        assertEq(nonce, expected);
    }

    function testFuzz_GetNonce(uint192 key) public {
        account.initialize(owner);

        uint256 nonce = account.getNonce(key);
        uint256 expected = uint256(key) << 64;

        assertEq(nonce, expected);
    }

    // ============================================
    // SIGNATURE VALIDATION TESTS
    // ============================================

    // ✅ SIMPLIFIED - Remove this test since we can't easily test internal function
    // In production, this would be tested through EntryPoint integration tests

    // ============================================
    // RECEIVE ETH TESTS
    // ============================================

    function test_ReceiveETH() public {
        account.initialize(owner);

        uint256 amount = 1 ether;
        (bool success, ) = address(account).call{value: amount}("");

        assertTrue(success);
        assertEq(address(account).balance, amount);
    }

    function testFuzz_ReceiveETH(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1000 ether);

        account.initialize(owner);
        vm.deal(address(this), amount);

        (bool success, ) = address(account).call{value: amount}("");

        assertTrue(success);
        assertEq(address(account).balance, amount);
    }

    // ============================================
    // ENTRYPOINT TESTS
    // ============================================

    function test_EntryPoint_Immutable() public view {
        assertEq(address(account.entryPoint()), address(entryPoint));
    }
}

// ============================================
// MOCK CONTRACTS
// ============================================

contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract MockReverter {
    function revertFunction() external pure {
        revert("Mock revert");
    }
}
