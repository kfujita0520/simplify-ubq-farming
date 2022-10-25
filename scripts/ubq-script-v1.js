// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const {BigNumber} = require("ethers");
const {moveTime} = require("../scripts/utils/move-time");
const {moveBlocks} = require("../scripts/utils/move-blocks");

async function main() {

  const WETH = await hre.ethers.getContractAt("IWETH", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
  const USDT = await hre.ethers.getContractAt("IERC20", "0xdAC17F958D2ee523a2206206994597C13D831ec7");//decimal 6
  const CurveCryptoSwap = await hre.ethers.getContractAt("ICurveCryptoSwap", "0xD51a44d3FaE010294C616388b506AcdA1bfAAE46");
    //3Pool [BTC, ETH, USDT]
    //https://github.com/curvefi/curve-crypto-contract/blob/4ca95ab3efe2011950e2142a47f5768f020488f5/contracts/tricrypto/CurveCryptoSwap.vy
  const DepositZapUAD = await hre.ethers.getContractAt("IDepositZap", "0xA79828DF1850E8a3A3064576f380D90aECDD3359");
    //https://github.com/curvefi/curve-factory/blob/a6ce510b7fead69d70b67bab4012c6c924740608/contracts/zaps/DepositZapUSD.vy
  const UAD3CRVf = await hre.ethers.getContractAt("IERC20", "0x20955CB69Ae1515962177D164dfC9522feef567E");
  const UBQ = await hre.ethers.getContractAt("IERC20", "0x4e38D89362f7e5db0096CE44ebD021c3962aA9a0");
  const BondingV2 = await hre.ethers.getContractAt("IBondingV2", "0xC251eCD9f1bD5230823F9A0F99a44A87Ddd4CA38");
  const BondingShareV2 = await hre.ethers.getContractAt("IBondingShareV2", "0x2dA07859613C14F6f05c97eFE37B9B4F212b5eF5");
  const MasterChefV2 = await hre.ethers.getContractAt("IMasterChefV2", "0xdae807071b5AC7B6a2a343beaD19929426dBC998");
    //Needed when claiming UBQ token for staking reward.
  const SECONDS_IN_A_DAY = 86400

  const [deployer, user1] = await hre.ethers.getSigners();
  console.log("Deployer: ", deployer.address);

  const DirectUBQFarmerContract = await hre.ethers.getContractFactory("DirectUBQFarmerV1");
  const DirectUBQFamarer = await DirectUBQFarmerContract.deploy();
  await DirectUBQFamarer.deployed();
  console.log("DirectUBQFamarer deployed to: ", DirectUBQFamarer.address);


  console.log('initial ETH balance: ' + hre.ethers.utils.formatEther(await deployer.getBalance()));
  console.log('Exchange ETH to USDT');
  let amount = hre.ethers.utils.parseEther("1");
  await CurveCryptoSwap.exchange(2, 0, amount, 0, true, {from: deployer.address, value: amount});

  let amountUSDT =  await USDT.balanceOf(deployer.address);
  console.log('USDT balance: ' + hre.ethers.utils.formatUnits(await USDT.balanceOf(deployer.address), 6));
  console.log('ETH balance: ' + hre.ethers.utils.formatEther(await deployer.getBalance()));

  console.log('Deposit USDT to DirectUBQFarmer Contract');
  await USDT.approve(DirectUBQFamarer.address, amountUSDT);
  await DirectUBQFamarer.deposit(USDT.address, amountUSDT, 1);
  console.log('USDT balance: ' + hre.ethers.utils.formatUnits(await USDT.balanceOf(deployer.address), 6));
  console.log('UAD3CRVf balance: ', + hre.ethers.utils.formatEther(await UAD3CRVf.balanceOf(deployer.address)));
  console.log('UBQ balance: ', + hre.ethers.utils.formatEther(await UBQ.balanceOf(deployer.address)));

  let depositIds = await BondingShareV2.holderTokens(deployer.address);
  console.log("deposit NFT ID: ", depositIds.toString());
  let bond = await BondingShareV2.getBond(depositIds[0]);
  console.log('Bond info: ', bond.toString());
  console.log('Amount of LP token on given bond: ', bond[1].toString());
  let stakedLpAmount = bond[1];

  await moveTime(SECONDS_IN_A_DAY*30);
  await moveBlocks(46600);

  console.log('After 30 DAYS');
  console.log('Unstake UAD3CRVf from DirectUBQFarmer Contract');
  await BondingShareV2.setApprovalForAll(DirectUBQFamarer.address, true);
  await DirectUBQFamarer.withdraw(depositIds[0], USDT.address);
  await BondingShareV2.setApprovalForAll(DirectUBQFamarer.address, false);
  //TODO make approve false
  depositIds = await BondingShareV2.holderTokens(deployer.address);
  console.log("deposit NFT ID: ", depositIds.toString());
  console.log('USDT balance: ' + hre.ethers.utils.formatUnits(await USDT.balanceOf(deployer.address), 6));
  console.log('UAD3CRVf balance: ', + hre.ethers.utils.formatEther(await UAD3CRVf.balanceOf(deployer.address)));
  console.log('UBQ balance: ', + hre.ethers.utils.formatEther(await UBQ.balanceOf(deployer.address)));


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
