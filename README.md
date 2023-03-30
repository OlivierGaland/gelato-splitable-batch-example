# Splitable batch example with gelato

This project shows how to create a job activated by gelato that is able to detect the run will not complete (due to gas consumption) and able to launch subsequent jobs until it is completed.

![image](https://user-images.githubusercontent.com/26048157/228724390-b4130fd2-1102-4d67-b019-0bc2f4584779.png)

See contracts/GelatoSplitableTimeBatch.sol for a detailed description and technicals informations

```quick steps :
Check IGelatoSplitableTimeBatchTarget.sol and TestGelato.sol for trigger/batch functions overview.
Check GelatoSplitableTimeBatch.sol for details 
```

```deployment :
deploy TestGelato
deploy GelatoSplitableTimeBatch
set access right (AccessControl from openzeppelin)
bind TestGelato to GelatoSplitableTimeBatch
set up job on app.gelato.network with GelatoSplitableTimeBatch (that is the resolver)
  checker() and splitableBatch() functions
use console and setQueueSize to fill manually TestGelato with items to process
  (that should be processed by your job at defined dates) 
```
