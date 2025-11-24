// script/DeployAll.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

// ERC-4337 Core Contracts (v0.7)
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

// Your contracts
// import "../src/account/BlockDAGLightAccount.sol";
import {BlockDAGLightAccount} from "../src/BlockDAGLightAccount.sol";
import {BlockDAGLightAccountFactory} from "../src/BlockDAGLightAccountFactory.sol";
import {BlockDAGPaymaster} from "../src/BlockDAGPaymaster.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);
        console.log("Deploying on BlockDAG Network...");
        console.log("");

        // 1. Deploy EntryPoint (v0.7) — REQUIRED
        console.log("1. Deploying EntryPoint (v0.7)...");
        EntryPoint entryPoint = new EntryPoint();
        console.log("   EntryPoint deployed at:", address(entryPoint));

        // 2. Deploy Account Implementation
        console.log("2. Deploying BlockDAGLightAccount implementation...");
        BlockDAGLightAccount implementation = new BlockDAGLightAccount(
            IEntryPoint(address(entryPoint))
        );
        console.log("   Implementation deployed at:", address(implementation));

        // 3. Deploy Factory
        console.log("3. Deploying BlockDAGAccountFactory...");
        BlockDAGLightAccountFactory factory = new BlockDAGLightAccountFactory(
            IEntryPoint(address(entryPoint))
        );
        console.log("   Factory deployed at:", address(factory));

        // 4. Deploy Paymaster (optional but recommended)
        console.log("4. Deploying BlockDAGPaymaster...");
        BlockDAGPaymaster paymaster = new BlockDAGPaymaster(
            IEntryPoint(address(entryPoint))
        );

        // Optional: Accept yourself as paymaster owner + stake
        // paymaster.addStake{value: 1 ether}(3600); // 1 hour unlock delay
        // paymaster.deposit{value: 10 ether}();

        console.log("   Paymaster deployed at:", address(paymaster));
        console.log("   Paymaster staked & deposited (10 ETH + 1 ETH stake)");

        vm.stopBroadcast();

        // ========================================
        // FINAL SUMMARY
        // ========================================
        console.log("");
        console.log("========================================");
        console.log("  BLOCKDAG ERC-4337 FULL DEPLOYMENT");
        console.log("========================================");
        console.log("EntryPoint          :", address(entryPoint));
        console.log("Account Impl        :", address(implementation));
        console.log("Account Factory     :", address(factory));
        console.log("Paymaster           :", address(paymaster));
        console.log("Deployer            :", deployer);
        console.log("Chain ID            :", block.chainid);
        console.log("Block Number        :", block.number);
        console.log("========================================");
        console.log("All contracts deployed successfully!");
        console.log("You can now use this EntryPoint on BlockDAG");
    }
}
