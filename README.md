# Simplify UBQ Farming

This project demonstrates the contract simplifying the UBQ farming process.
## Function 
1) Deposit  
Directly execute following process with given stable coin(uAD, USDT, USDC, DAI)  
 - Add liquidity into Curve-uAD meta pool. (Acquire uAD3CRV LP token.)
 - Stake uAD3CRV token to UBQ bonding contract for specific period.
 
2) Withdraw  
Directly execute following process with given staked token (bond sharing ID)
- Unstake uAD3CRV token from UBQ bonding contract. (Receive uAD3CRV and UBQ token)
- Remove liquidity from Curve-uAD meta pool and convert uAd3CUV to specified stable coin.

## Test Script
the basic test scenario can be executed and confirmed in forking main-net.  

```shell
npx hardhat run ./sccript/ubq-script.js
```
