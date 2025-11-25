# BlockDAG Smart Account

A lightweight ERC-4337 smart account implementation optimized for the BlockDAG network, enabling gas-efficient account abstraction with support for parallel execution and mining rewards.

## Overview

This repository contains a complete smart account infrastructure built on the ERC-4337 Account Abstraction standard. It allows users to interact with BlockDAG without holding ETH, using alternative mechanisms like mining rewards to pay for gas.

### Key Components

- **BlockDAGLightAccount**: Core smart account contract supporting single or batch execution
- **BlockDAGLightAccountFactory**: Factory for deterministic account deployment via CREATE2
- **BlockDAGPaymaster**: Gas sponsorship contract supporting whitelists and mining rewards

## Features

### Core Functionality

- **Single & Batch Execution**: Execute one or multiple transactions in a single UserOperation
- **ERC-4337 Compatible**: Fully compliant with the ERC-4337 account abstraction standard
- **Deterministic Addresses**: CREATE2-based deployment ensures accounts can be predicted before creation
- **ERC-1271 Signature Validation**: Standard signature validation for smart contract wallets

### BlockDAG-Specific Features

- **Mining Rewards Support**: Accounts can accumulate mining rewards to sponsor gas fees
- **Parallel Execution**: Nonce structure supports parallel transaction execution on BlockDAG's DAG-based consensus
- **Optimized for DAG Networks**: Designed to leverage BlockDAG's high throughput and low latency

### Deployed Contracts

- **[BlockDAGLightAccount](https://awakening.bdagscan.com/contractOverview/0x2ED79ab4046801dAF8EF03cF16647fd61Aa7c804)**
- **[BlockDAGFactoryLightAccount](https://awakening.bdagscan.com/contractOverview/0xDE8b6382ED9C32Ca1711ab9C8B1fC9090C66112C)**
- **[Paymaster](https://awakening.bdagscan.com/contractOverview/0x2ED79ab4046801dAF8EF03cF16647fd61Aa7c804)**

## Installation

```bash
git clone <repository>
cd blockdag-smart-account
forge install
```

### Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Account Abstraction (eth-infinitism)](https://github.com/eth-infinitism/account-abstraction)
- [Foundry](https://book.getfoundry.sh/) (for testing)

## Usage

### Creating an Account

```solidity
// Deploy factory
BlockDAGLightAccountFactory factory = new BlockDAGLightAccountFactory(entryPoint);

// Create account for user
address owner = 0x...;
BlockDAGLightAccount account = factory.createAccount(owner, 0);
```

### Predicting Account Address

Get a counterfactual address before deployment:

```solidity
address predictedAddress = factory.getAddress(owner, salt);
// Account can be funded at this address before creation
```

### Executing Transactions

```solidity
// Single transaction
account.execute(recipient, 1 ether, "");

// Batch transactions
address[] memory targets = [target1, target2];
uint256[] memory values = [1 ether, 2 ether];
bytes[] memory data = [calldata1, calldata2];
account.executeBatch(targets, values, data);
```

### Using Mining Rewards

```solidity
// Deposit mining rewards
account.depositMiningRewards{value: 10 ether}();

// Check balance
uint256 rewards = account.miningRewardsBalance();
```

### Ownership Transfer

```solidity
address newOwner = 0x...;
account.transferOwnership(newOwner);
```

## Architecture

### Account Model

Each user owns a single contract that acts as their smart account. The account:

- Holds assets (ETH and tokens)
- Validates and executes UserOperations from the EntryPoint
- Manages ownership and access control

### Factory Pattern

The factory uses ERC-1967 proxies pointing to a shared implementation contract:

- Reduces deployment costs
- Enables deterministic address computation via CREATE2
- Allows upgrades through proxy mechanism

### Paymaster Integration

The BlockDAGPaymaster can sponsor gas fees via:

- **Whitelist**: Pre-approved addresses get free gas
- **Mining Rewards**: Accounts with sufficient mining rewards
- **Policy-Based**: Custom sponsorship logic

## Testing

Run the full test suite:

```bash
forge test
```

Run specific test file:

```bash
forge test --match-path "test/BlockDAGLightAccountFactory.t.sol"
```

Run integration tests:

```bash
forge test --match-path "test/Integration.t.sol"
```

### Test Coverage

- ✅ Factory initialization and account creation
- ✅ Deterministic address computation
- ✅ Single and batch execution
- ✅ Ownership transfers
- ✅ Mining rewards functionality
- ✅ Integration scenarios (onboarding, recovery, batch transfers)

## Security Considerations

### Key Design Decisions

1. **Single Owner Model**: Simplicity over multi-sig complexity
2. **Separate Initialization Flag**: Prevents initialization attacks
3. **EntryPoint Delegation**: Only EntryPoint and owner can execute transactions
4. **Immutable EntryPoint**: Ensures accounts cannot be compromised by EntryPoint changes

### Audit Notes

- Implementation uses standard OpenZeppelin patterns
- Follows ERC-4337 security guidelines
- Access control via `onlyOwnerOrEntryPoint` modifier
- Proper input validation on ownership transfers

## Gas Optimization

- Batch execution reduces per-call overhead
- Proxy pattern reduces deployment gas
- Mining rewards bypass ETH requirements
- Parallel execution utilizes BlockDAG's DAG structure

## Contract Functions

### BlockDAGLightAccount

| Function                                                    | Description                      |
| ----------------------------------------------------------- | -------------------------------- |
| `initialize(address owner_)`                                | Initialize account with owner    |
| `execute(address dest, uint256 value, bytes calldata func)` | Execute single transaction       |
| `executeBatch(address[], uint256[], bytes[])`               | Execute multiple transactions    |
| `transferOwnership(address newOwner)`                       | Transfer account ownership       |
| `depositMiningRewards()`                                    | Deposit mining rewards           |
| `getNonce(uint192 key)`                                     | Get nonce for parallel execution |

### BlockDAGLightAccountFactory

| Function                                     | Description                       |
| -------------------------------------------- | --------------------------------- |
| `createAccount(address owner, uint256 salt)` | Create or return existing account |
| `getAddress(address owner, uint256 salt)`    | Compute counterfactual address    |

### BlockDAGPaymaster

| Function                          | Description                             |
| --------------------------------- | --------------------------------------- |
| `validatePaymasterUserOp(...)`    | Determine if UserOp should be sponsored |
| `addToWhitelist(address account)` | Add address to sponsorship whitelist    |
| `deposit()`                       | Deposit funds for sponsorship           |

## Deployment

### Supported Networks

- BlockDAG Mainnet
- BlockDAG Testnet

### Deployment Steps

1. Deploy factory with EntryPoint address
2. Factory automatically deploys implementation contract
3. Create accounts via factory as needed

Example:

```bash
forge script script/Deploy.s.sol --rpc-url <blockdag-rpc> --broadcast
```

## Examples

### New User Onboarding

```solidity
// 1. Predict account address
address accountAddr = factory.getAddress(newUser, 0);

// 2. Transfer mining rewards to predicted address
sendMiningRewards(accountAddr, 100);

// 3. Create account
BlockDAGLightAccount account = factory.createAccount(newUser, 0);

// 4. Use account immediately
account.depositMiningRewards{value: 100}();
```

### Account Recovery

```solidity
// User loses old key, creates new account with same owner
BlockDAGLightAccount oldAccount = BlockDAGLightAccount(payable(oldAddr));

// Transfer ownership to new key
oldAccount.transferOwnership(newKeyAddress);

// New key now controls the account
```

## Contributing

Contributions are welcome! Please:

1. Write tests for new functionality
2. Ensure all tests pass
3. Follow Solidity style guide
4. Add documentation for new features

## License

MIT License - See LICENSE file for details

## References

- [ERC-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [ERC-1271: Signature Validation](https://eips.ethereum.org/EIPS/eip-1271)
- [Account Abstraction Documentation](https://docs.alchemy.com/account-abstraction/)
- [BlockDAG Network](https://blockdag.network/)

## Support

For issues, questions, or suggestions, please open an issue on GitHub.
