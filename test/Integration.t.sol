// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/BlockDAGLightAccount.sol";
import "../src/BlockDAGLightAccountFactory.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";

/// @title Integration Tests
/// @notice End-to-end tests simulating real usage
contract IntegrationTest is Test {
    BlockDAGLightAccountFactory public factory;
    IEntryPoint public entryPoint;

    address public alice;
    address public bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        entryPoint = IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
        factory = new BlockDAGLightAccountFactory(entryPoint);
    }

    function test_Scenario_NewUserOnboarding() public {
        // Alice creates her first account
        BlockDAGLightAccount aliceAccount = factory.createAccount(alice, 0);

        // Alice funds her account with mining rewards
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        aliceAccount.depositMiningRewards{value: 50 ether}();

        assertEq(aliceAccount.miningRewardsBalance(), 50 ether);
        assertEq(alice.balance, 50 ether);
    }

    function test_Scenario_MultipleAccountsPerUser() public {
        // Alice creates multiple accounts
        BlockDAGLightAccount personal = factory.createAccount(alice, 0);
        BlockDAGLightAccount savings = factory.createAccount(alice, 1);
        BlockDAGLightAccount trading = factory.createAccount(alice, 2);

        // All accounts should be different
        assertTrue(address(personal) != address(savings));
        assertTrue(address(personal) != address(trading));
        assertTrue(address(savings) != address(trading));

        // All owned by Alice
        assertEq(personal.owner(), alice);
        assertEq(savings.owner(), alice);
        assertEq(trading.owner(), alice);
    }

    function test_Scenario_BatchTransfer() public {
        BlockDAGLightAccount account = factory.createAccount(alice, 0);
        vm.deal(address(account), 10 ether);

        // Prepare batch transfer to multiple recipients
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("recipient1");
        recipients[1] = makeAddr("recipient2");
        recipients[2] = makeAddr("recipient3");

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2 ether;
        amounts[1] = 3 ether;
        amounts[2] = 4 ether;

        bytes[] memory data = new bytes[](3);
        data[0] = "";
        data[1] = "";
        data[2] = "";

        // Execute batch
        vm.prank(alice);
        account.executeBatch(recipients, amounts, data);

        assertEq(recipients[0].balance, 2 ether);
        assertEq(recipients[1].balance, 3 ether);
        assertEq(recipients[2].balance, 4 ether);
        assertEq(address(account).balance, 1 ether);
    }

    function test_Scenario_AccountRecovery() public {
        // Alice creates account
        BlockDAGLightAccount account = factory.createAccount(alice, 0);
        vm.deal(address(account), 10 ether);

        // Alice loses her key, needs to transfer to new address
        address aliceNewAddress = makeAddr("aliceNew");

        vm.prank(alice);
        account.transferOwnership(aliceNewAddress);

        // New address can now control the account
        vm.prank(aliceNewAddress);
        account.execute(bob, 5 ether, "");

        assertEq(bob.balance, 5 ether);
    }
}
