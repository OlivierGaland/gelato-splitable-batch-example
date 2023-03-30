// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// resolver entry point in target contract :
// function <mybatch>() external returns(bool) =>  return code : true if everything is processed, false if items remains 
// function <mybatchNeedTrigger>() external view returns(bool) => return code : true if items to process, false if nothing to be done
// 
// /!\  It is target contract responsibility to store information on batch state (if resume is needed or not)
//      Example : store a queue that discard on the fly processed elements to allow next call to resume correctly 
//
// 
interface IGelatoSplitableTimeBatchTarget {
    function mybatchNeedTrigger() external view returns(bool);    // NAME TO TUNE : return true if there is items to process (this is called by checker() resolver)
    function mybatch() external returns(bool);                    // NAME TO TUNE : process items (this is called by the batch process)
}

