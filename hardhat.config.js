require("@nomicfoundation/hardhat-toolbox")
require('dotenv').config();

module.exports = {
 
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      }
    }   
  },
  defaultNetwork:"localhost",
  networks: {
    mumbai: {
       url: `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_KEY}`,
       accounts: [`0x${process.env.PRIVATE_KEY}`],
       chainId: 80001,
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      chainId: 137,
    }
 },
  etherscan: {
    apiKey: `${process.env.ETHERSCAN_KEY}`,
  },
  sourcify: {
    enabled: true
  }

};
