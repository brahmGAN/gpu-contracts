# GPU Rental Marketplace Smart Contract

## Overview

The GPU Rental Marketplace is a decentralized application built on the Polygon Mainnet. It allows users to list and rent GPUs for computational tasks. The marketplace uses a native points system (Gpoints) for transactions and includes features such as user registration, machine listing, and rental management.

## Smart Contract Features

- **User Registration**: Users can register on the platform with a unique username, organization affiliation, and referral ID. Upon registration, users receive Gpoints as a referral reward.
- **Machine (GPU) Registration**: Providers can list their GPUs on the marketplace, specifying details such as CPU name, GPU name, VRAM, total RAM, storage, core count, IP address, open ports, region, and bid price in Gpoints.
- **Machine Rental**: Registered users can rent available GPUs for a specified duration, paying with Gpoints. The contract ensures that only available and listed GPUs can be rented and that the renter has sufficient Gpoints.
- **Order Management**: Orders can be completed or canceled, with Gpoints being held or refunded accordingly. Machines are marked as unavailable when rented and revert to available once the rental period ends or the order is canceled.
- **Gpoints Management**: Users can purchase Gpoints with USDC, an ERC20 token, or receive them through a Stripe payment gateway integration. The contract handles the transfer of USDC to a designated funds handler.
- **Administrative Functions**: The contract owner can set server keys, manage referral rewards, and update bundle information for Gpoints purchases.

## Contract Structure

### Structs

- `GPU`: Represents a GPU with its specifications and rental status.
- `User`: Represents a user with their personal and transactional information.
- `Order`: Represents a rental order with details about the renter, machine, duration, and payment.

### Enums

- `gPointsOrderType`: Represents different types of Gpoints transactions (Buy, Spend, ReferRewards, Earn).

### State Variables

- `machineId`, `userIdCount`, `orderId`: Counters for machines, users, and orders.
- `refIDHandler`, `gPerRefer`: Management of referral IDs and referral rewards.
- `USDC_ADDRESS`, `funds_handler`: Addresses for the USDC token and funds handler.
- `serverPublicAddress`: Address authorized to perform server-specific actions.

### Mappings

- Various mappings to keep track of machines, users, orders, and other necessary associations.

### Events

- Events for logging significant actions such as machine listing, machine rental, Gpoints updates, and user registration.

### Modifiers

- `onlyFromServer`: Ensures that certain functions can only be called by the server.

### Functions

- Functions for user and machine registration, machine rental, order completion and cancellation, Gpoints management, and administrative tasks.

## Deployment and Interaction

The contract is intended to be deployed on the Polygon mainnet and interacted with through a frontend interface or directly via blockchain transactions. It is designed to be upgradeable using the UUPS (Universal Upgradeable Proxy Standard) pattern for future improvements and fixes.

## Security Considerations

The contract includes checks for proper authorization, valid user input, and sufficient balances before performing state-changing operations. It also uses OpenZeppelin's `Ownable` and `ECDSA` libraries for ownership management and signature verification, respectively.

---

This README provides a high-level description of the GPU Rental Marketplace smart contract. For detailed information on deployment, testing, and interaction, please refer to the specific documentation sections at https://docs.gpu.net or contact the development team.
