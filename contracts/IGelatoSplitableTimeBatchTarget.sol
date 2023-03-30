// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// batch entry point in target contract : function <mybatch>() external returns(bool);
// 
// /!\  It is target contract responsibility to store information on batch state (if resume is needed or not)
//      Example : store a queue that discard on the fly processed elements to allow next call to resume correctly 
//
//  return code : true if everything is processed, false if items remains 
interface IGelatoSplitableTimeBatchTarget {
    function mybatch() external returns(bool);                    // NAME TO TUNE
    function mybatchNeedTrigger() external view returns(bool);    // NAME TO TUNE
}
