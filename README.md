# Notes

ERC4626.sol is minimal ready implementation for token specific Vault. Should be deployed as-is on per token basis. You can interact with ERC4626.sol (Vault for token) by creating interface in your Strategy contract and then calling ERC4626.sol functions from there. ERC4626.sol should have more logic than what is currently provided, ie. calculations for underlying. VaultFun could be for example an Strategy, using funds from the Vault.

fmulUp lib is not in solmate npm! wrong calcs

## calculateShares

totalSupply == all ever minted (through deposit into underlying)
totalUnderlying == total amount of underlying in vault (deposits+fees)
totalSupply / totalUnderlying = 

## Notes on working and implementing interfaces

`contract Vault is IERC4626 {}` - Then, you implement all defined interface functions

`contract Vault is ERC4626 {}` - This import ALREADY IMPLEMENTED functions. Only `.super`

## What you can do with this interface?

1. This is Vault contract. Vault is suppose to provide logic for accounting of shares from deposited underlying tokens.
2. Offered minimal implementation provides logic for flow of funds from user to the Vault, providing an interface for additional extensions as to how to use funds. Can be used in similar fashion to:
    - Yield Bearing Tokens like xSushi
    - DeFi strategies like Yearn
    - Lending/Borrowing pools like AAVE
3. Developer is expected to inherit or implement directly defined functions and override in child contract. For example:
    - Change how shares are calculated. xSushi will allow users to withdraw more based on transfers made to the vault. Override calculateShare/Underlying to influence such behavior. Those are used to define amount of fee-generated income received by Vault.
    - Define strategyBase to 4626, following yearn principles. 

## xSushi

Just enter/leave and simple share calculation logic. Vault function should be only limited to share accounting and making funds available for use to other contracts (like Strategy contract). Therefore, Vault design can only be progressed as to accounting and nothing else. What other Vaults are doing? 

https://etherscan.io/address/0x8798249c2e607446efb7ad49ec89dd1865ff4272#code

## Yearn 

Crucial to understanding yVault / Yearn V2: https://medium.com/iearn/yearn-finance-explained-what-are-vaults-and-strategies-96970560432
- harvest call to reinvest in vault, which manages the funds. moves funds to controller which calls earn on new fund.
- this vault is highly manual, requires scripts to call functions for state changes.
- yearn provides baseStrategy template to create strategy compatible with yearn Vaults

[Yearn Vault Ecosystem overview. Explains different parts of Yearn Vault functionality, which is split between Vault, Strategy, Router contracts & interfaces](https://github.com/yearn/yearn-devdocs/blob/master/docs/developers/v2/SPECIFICATION.md)

In V2 Vaults, Vault holds funds, Controller is responsible for pulling and managing funds, it holds Strategy address.
In V3, there is no Controller. Guardian and strategist took this role.

### Task 1

Compare functionalities of different protocol Vaults:
    - Yearn, Ribbon, AAVE, Balancer, xSushi

Copy whole Yearn Infra?
    - Vault <=> Strategy
        - Where strategy is copy of DAI-Curve without any performance fees, simplified. 
        - Or ibEUR strategy suggested in Yearn Gov. (Prob not, share withdraw too complex)

### Found Problems

Doesn't compile in 0.8.5 with decimals
Imported contract with all implementations (removed abstract)

### Links

Yearn Strategy descriptions: https://vaults.yearn.finance/ethereum/stables

Yearn Strategy Contracts: https://yearn.watch/

https://ethereum-magicians.org/t/eip-4626-yield-bearing-vault-standard/7900/12

ERC4626Router is just an extension of ERC4626.sol implemented functions (which is minimal implementation of EIP, look at IERC4626 for reference). It mirrors same scheme of names, EIP specifies deposit/withdraw, Router has exactly those functions with additional logic.

https://github.com/fei-protocol/ERC4626/blob/7a947f2507b760ae470578cfb106f71ff5b1a14b/src/ERC4626Router.sol#L139

https://eips.ethereum.org/EIPS/eip-4626

https://www.youtube.com/watch?v=L8dijE5qhTg&t=393s


# Solidity Template

Uses

- [Hardhat](https://github.com/nomiclabs/hardhat): compile and run the smart contracts on a local development network
- [TypeChain](https://github.com/ethereum-ts/TypeChain): generate TypeScript types for smart contracts
- [Ethers](https://github.com/ethers-io/ethers.js/): renowned Ethereum library and wallet implementation
- [Waffle](https://github.com/EthWorks/Waffle): tooling for writing comprehensive smart contract tests
- [Solhint](https://github.com/protofire/solhint): linter
- [Prettier Plugin Solidity](https://github.com/prettier-solidity/prettier-plugin-solidity): code formatter

This is a GitHub template, which means you can reuse it as many times as you want. You can do that by clicking the "Use this
template" button at the top of the page.

## Usage

### Pre Requisites

Before running any command, make sure to install dependencies:

```sh
$ yarn install
```

### Compile

Compile the smart contracts with Hardhat:

```sh
$ yarn compile
```

### Test

Run the Mocha tests:

```sh
$ yarn test
```

### Deploy contract to netowrk (requires Mnemonic and infura API key)

```
npx hardhat run --network rinkeby ./scripts/deploy.ts
```

### Validate a contract with etherscan (requires API ke)

```
npx hardhat verify --network <network> <DEPLOYED_CONTRACT_ADDRESS> "Constructor argument 1"
```

### Added plugins

- Gas reporter [hardhat-gas-reporter](https://hardhat.org/plugins/hardhat-gas-reporter.html)
- Etherscan [hardhat-etherscan](https://hardhat.org/plugins/nomiclabs-hardhat-etherscan.html)

## Thanks

If you like it than you soulda put a start ⭐ on it 
