// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/BlockDAGLightAccount.sol";
import "../src/BlockDAGLightAccountFactory.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

contract BlockDAGLightAccountFactoryTest is Test {
    BlockDAGLightAccountFactory public factory;
    IEntryPoint public entryPoint;

    address public owner1;
    address public owner2;
    uint256 public salt1;
    uint256 public salt2;

    event AccountCreated(
        address indexed account,
        address indexed owner,
        uint256 salt
    );

    function setUp() public {
        // Create test addresses
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        salt1 = 0;
        salt2 = 12345;

        // Use canonical EntryPoint
        entryPoint = IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

        // Deploy factory
        factory = new BlockDAGLightAccountFactory(entryPoint);
    }

    // ============================================
    // FACTORY INITIALIZATION TESTS
    // ============================================

    function test_Factory_Deployment() public {
        assertEq(address(factory.entryPoint()), address(entryPoint));
        assertTrue(address(factory.accountImplementation()) != address(0));
    }

    function test_Factory_ImplementationInitialized() public {
        // Implementation should be initialized (disabled)
        BlockDAGLightAccount impl = factory.accountImplementation();
        assertEq(impl.owner(), address(1)); // Disabled marker
    }

    // ============================================
    // CREATE ACCOUNT TESTS
    // ============================================

    function test_CreateAccount_Success() public {
        vm.expectEmit(false, true, false, true);
        emit AccountCreated(address(0), owner1, salt1);

        BlockDAGLightAccount account = factory.createAccount(owner1, salt1);

        // Verify account state
        assertEq(account.owner(), owner1);
        assertEq(address(account.entryPoint()), address(entryPoint));
        assertTrue(address(account).code.length > 0);
    }

    function test_CreateAccount_Idempotent() public {
        // First creation
        BlockDAGLightAccount account1 = factory.createAccount(owner1, salt1);
        address addr1 = address(account1);

        // Second creation with same parameters
        BlockDAGLightAccount account2 = factory.createAccount(owner1, salt1);
        address addr2 = address(account2);

        // Should return same address
        assertEq(addr1, addr2);
    }

    function test_CreateAccount_DifferentSalts() public {
        BlockDAGLightAccount account1 = factory.createAccount(owner1, salt1);
        BlockDAGLightAccount account2 = factory.createAccount(owner1, salt2);

        // Different salts should produce different addresses
        assertTrue(address(account1) != address(account2));

        // But both should be valid accounts
        assertEq(account1.owner(), owner1);
        assertEq(account2.owner(), owner1);
    }

    function test_CreateAccount_DifferentOwners() public {
        BlockDAGLightAccount account1 = factory.createAccount(owner1, salt1);
        BlockDAGLightAccount account2 = factory.createAccount(owner2, salt1);

        // Different owners should produce different addresses
        assertTrue(address(account1) != address(account2));

        // Each should have correct owner
        assertEq(account1.owner(), owner1);
        assertEq(account2.owner(), owner2);
    }

    function testFuzz_CreateAccount(address _owner, uint256 _salt) public {
        vm.assume(_owner != address(0));
        vm.assume(_owner != address(1));

        BlockDAGLightAccount account = factory.createAccount(_owner, _salt);

        assertEq(account.owner(), _owner);
        assertTrue(address(account).code.length > 0);
    }

    // ============================================
    // GET ADDRESS TESTS
    // ============================================

    function test_GetAddress_MatchesActual() public {
        // Get counterfactual address
        address predicted = factory.getAddress(owner1, salt1);

        // Create account
        BlockDAGLightAccount account = factory.createAccount(owner1, salt1);

        // Addresses should match
        assertEq(predicted, address(account));
    }

    function test_GetAddress_BeforeDeployment() public {
        address predicted = factory.getAddress(owner1, salt1);

        // Address should be computed even before deployment
        assertTrue(predicted != address(0));

        // Code should not exist yet
        assertEq(predicted.code.length, 0);
    }

    function test_GetAddress_Deterministic() public {
        address addr1 = factory.getAddress(owner1, salt1);
        address addr2 = factory.getAddress(owner1, salt1);

        // Same parameters should give same address
        assertEq(addr1, addr2);
    }

    function test_GetAddress_DifferentParams() public {
        address addr1 = factory.getAddress(owner1, salt1);
        address addr2 = factory.getAddress(owner1, salt2);
        address addr3 = factory.getAddress(owner2, salt1);

        // Different parameters should give different addresses
        assertTrue(addr1 != addr2);
        assertTrue(addr1 != addr3);
        assertTrue(addr2 != addr3);
    }

    function testFuzz_GetAddress(address _owner, uint256 _salt) public {
        vm.assume(_owner != address(0));

        address predicted = factory.getAddress(_owner, _salt);
        assertTrue(predicted != address(0));
    }

    // ============================================
    // INTEGRATION TESTS
    // ============================================

    function test_Integration_CreateAndUseAccount() public {
        // Create account
        BlockDAGLightAccount account = factory.createAccount(owner1, salt1);

        // Fund account
        vm.deal(address(account), 10 ether);

        // Use account to transfer
        address recipient = makeAddr("recipient");
        vm.prank(owner1);
        account.execute(recipient, 5 ether, "");

        assertEq(recipient.balance, 5 ether);
        assertEq(address(account).balance, 5 ether);
    }

    function test_Integration_MultipleAccounts() public {
        // Create multiple accounts for same owner
        BlockDAGLightAccount account1 = factory.createAccount(owner1, 0);
        BlockDAGLightAccount account2 = factory.createAccount(owner1, 1);
        BlockDAGLightAccount account3 = factory.createAccount(owner1, 2);

        // All should be valid and different
        assertTrue(address(account1) != address(account2));
        assertTrue(address(account1) != address(account3));
        assertTrue(address(account2) != address(account3));

        assertEq(account1.owner(), owner1);
        assertEq(account2.owner(), owner1);
        assertEq(account3.owner(), owner1);
    }

    function test_Integration_CreateTransferOwnership() public {
        // Create account
        BlockDAGLightAccount account = factory.createAccount(owner1, salt1);

        // Transfer ownership
        address newOwner = makeAddr("newOwner");
        vm.prank(owner1);
        account.transferOwnership(newOwner);

        assertEq(account.owner(), newOwner);

        // Old owner can't execute
        vm.prank(owner1);
        vm.expectRevert(BlockDAGLightAccount.NotAuthorized.selector);
        account.execute(address(0), 0, "");

        // New owner can execute
        vm.prank(newOwner);
        account.execute(address(0), 0, "");
    }

    // ============================================
    // SALT COMPUTATION TESTS
    // ============================================

    function test_SaltComputation_Consistent() public {
        // Create same account twice (second should return existing)
        address addr1 = address(factory.createAccount(owner1, salt1));
        address addr2 = address(factory.createAccount(owner1, salt1));

        assertEq(addr1, addr2);
    }

    function test_SaltComputation_Collision() public {
        // Try to find collision (should be impossible)
        address addr1 = address(factory.createAccount(owner1, 0));
        address addr2 = address(factory.createAccount(owner1, 1));

        assertTrue(addr1 != addr2);
    }
}
