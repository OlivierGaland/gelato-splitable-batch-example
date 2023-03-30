# Splitable batch example

This project shows how to create a job activated by gelato that is able to detect the run will not complete (due to gas cunsumption) and able to launch subsequent jobs until it is completed.

![image](https://user-images.githubusercontent.com/26048157/228724390-b4130fd2-1102-4d67-b019-0bc2f4584779.png)

See contracts/GelatoSplitableTimeBatch.sol for a detailed description and technicals informations

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
