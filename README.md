# OnchainIndex
ETH Global Brussels 2024

Dexin is a protocol enabling the creation of on-chain structured products following automated strategies triggered by Uniswap v4 hooks.

## Setup
```
forge install
forge test
```

## How does it work ?
### Hook Contract 
The Hook contract performs a No OP swap using the beforeSwap hook to take the users input token and calls the vault to mint shares then sends them to the user when the input is the underlying token. On the other hand when the input is the share of the vault, the hook calls the vault to burn the shares and withdraw underlying token.

### Vault (Strategy)
The vault is a ERC 4626 extended to manage multiple assets. 
