import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      // no account (hardhat)
      chainId: 31337
    },
    ganache: {
      url: "http://127.0.0.1:7545"
      // no account and chainId (hardhat)
    },
    //polygon: {
    //},
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY!]
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17"
      }
    ]
  }
};

export default config;
