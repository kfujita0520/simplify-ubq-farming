require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
//https://eth-mainnet.alchemyapi.io/v2/1vOJ2uSu9HQ_xgVqOzQlF9V311wWKmE9
module.exports = {
  solidity: "0.8.17",
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_ALCHEMY_URL,
        blockNumber: 15638626
      }
    },

    goerli: {
      url: process.env.GOERLI_ALCHEMY_URL,
      accounts: [process.env.PRIVATE_KEY]
    }

  },
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_KEY
    },
    customChains: [
      {
        network: "goerli",
        chainId: 5,
        urls: {
          apiURL: "https://api-goerli.etherscan.io/api",
          browserURL: "https://goerli.etherscan.io"
        }
      }
    ]
  }
};
