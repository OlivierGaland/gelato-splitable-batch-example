// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
//import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IGelatoSplitableTimeBatchTarget.sol";

// Basic example of GelatoSplitableTimeBatch use : target contract holding batch logic and state
// read GelatoSplitableTimeBatch.sol contract for detailled infos
//
contract TestGelato is IGelatoSplitableTimeBatchTarget,AccessControl {

    uint256 _queueSize;  // Simulate a queue 

    bytes32 private constant BATCH_WHITELIST = keccak256("BATCH_WHITELIST");    

    constructor() {  
        _queueSize = 1000;  // 1000 item in queue
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }   

    function setQueueSize(uint256 queueSize) public onlyRole(DEFAULT_ADMIN_ROLE) {   // Refill our simulated queue
        _queueSize = queueSize;
    }

    function getQueueSize() public view returns(uint256) {  
        return _queueSize;
    }

    function mybatchNeedTrigger() external view returns(bool) {     // Batch trigger check : true if there is item queued
        return (_queueSize > 0); 
    }

    function mybatch() external onlyRole(BATCH_WHITELIST) returns(bool) {     // Batch loop run : here we process 10 items at once from the simulated queue
        if (_queueSize > 0) {  // check if items exists (security as checker() method in resolver will also call mybatchNeedTrigger)
            for(uint i = 0 ; i < 10 ; ++i) {            
                _queueSize -= 1;                        // Simulate queue pop
                if (_queueSize == 0) {                  // If queue is empty then return true (no need to resume)
                    return true;
                }
            }
            return false;       //batch is not finished : return false
        }
        return true; // Nothing to process
    }
}
