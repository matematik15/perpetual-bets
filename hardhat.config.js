require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan")
require("dotenv").config()

module.exports = {
  solidity: "0.8.16",
  etherscan: {
    apiKey: `${process.env.ETHERSCAN_API_KEY}`,
  },
  networks: {
    hardhat: {
        blockGasLimit: 100000000
    },
     goerli: {
         url: `${process.env.GOERLI_URL}`
         ,accounts: [
             `${process.env.DEPLOYER_PRIVATE_KEY}`
         ]
     }
  }
};
