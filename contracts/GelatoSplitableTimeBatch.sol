// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
//import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IGelatoSplitableTimeBatchTarget.sol";

// Custom resolver for gelato that has following functionalities :
//
// /!\ /!\ /!\ THIS CONTRACT IS NOT FULLY TESTED AND MAY CONTAINS VULNERABILITIES, DO NOT USE IT IN PRODUCTION ENVIRONMENT UNLESS YOU FULLY REVIEWED IT AND FIXED ALL POSSIBLE BUGS. /!\ /!\ /!\ 
//
// AccessControl through openzeppelin contracts
//
// 1) trigger on a date basis, with a repeat and a timewindow defined. example : 27 MAR 2023 01:00 GMT , every 30 min, activation possible during a time windows of 5 min (callable 0-5 min, not callable 5-30min)
// 2) trigger only if gas cost is less than defined value _maxGasPrice : /!\ Seems not working during my testing on mumbai (it always allow trigger)
// 3) trigger only if there are items to process (call the target contract to get the information)
// 4) if the batch cannot be completed in one run (due to gas limit), this contract will keep the information and be activated again to run a second (or more) time to (hopefully) complete
//
// This Resolver contract must be deployed with your batch contract that hold state and logic. Resolver only hold resume and trigger logic.
// The resolver will call (in a while loop) the target contract to process a part of items and check gasleft() as an exit condition.
//
// Resolver parameters (in contructor) :
// _nextRunTimestamp : hold the date of next execution (epoc), the startTimestamp will be modified to match a valid _nextRunTimestamp at construction
// _repeatDelay : hold the interval between two runs (sec)
// _allowedTimeWindow : hold the valid time interval (sec) to launch the batch (or subsequent resume) after _nextRunTimestamp is expired
// _maxGasPrice : maximum acceptable to launch batch (in wei : 1 gwei = 1e9 wei) 
// _minGasLeft : exit condition in the process loop (ie : we stop processing if gasleft reach this value : example : 30000 gas)
//
// Resolver parameters (others) :
// _targetContract : hold the address of target contract : use bindTargetContract(addr) to set
// _needResume : keep the information on current run : true means previous job did not finished and another must be launched in the same timewindow
//
// Resolver functions :
// bindTargetContract => bind resolver to the target contract
// checker => gelato entry point to detect a activation is needed (to set in gelato UI)
// splitableBatch => gelato entry point for the activation (to set in gelato UI) : /!\ The call to the target contract is done here 
// changeTimewindow, changeMinGasLeft, changeMaxGasPrice, changeRepeatDelay : if you need to tune the resolver parameters
//
// Your target contract must implement 2 external function listed in interface IGelatoSplitableTimeBatchTarget :
// 1) _targetContract.mybatch : batch logic : process your items, update the information to be sure a resume won't process them again. Return true if everything was processed, false if another run is needed 
// 2) _targetContract.mybatchNeedTrigger : checker helper : return true if items to process exists, false if no run is needed
//
contract GelatoSplitableTimeBatch is AccessControl {

    // See https://www.epochconverter.com/ : those approximate values will make job run time drift very slowly with time ... see you in year 3000 to issue a bug \m/
    /* Use those value in your constructor according to your needs
    uint256 private constant AVERAGE_MINUTE_LENGHT = 60;
    uint256 private constant AVERAGE_HOUR_LENGHT = AVERAGE_MINUTE_LENGHT*60;
    uint256 private constant AVERAGE_DAY_LENGHT = AVERAGE_HOUR_LENGHT*24;
    uint256 private constant AVERAGE_WEEK_LENGHT = AVERAGE_DAY_LENGHT*7;
    uint256 private constant AVERAGE_MONTH_LENGHT = 2629743;    // Average month length on long term, be warned using this won't guarantee a run on a fixed date every mont, just that in 1000+ years there will be one batch per month  
    uint256 private constant AVERAGE_YEAR_LENGHT = 31556926;    // Average year length on long term, be warned using this won't guarantee a run on a fixed date every mont, just that in 1000+ years there will be one batch per year
    */

    // Time infos (all in seconds)
    uint256 _nextRunTimestamp;     // Next run date (epoc)
    uint256 _repeatDelay;          // Repeat (seconds between 2 jobs)
    uint256 _allowedTimeWindow;    // Allowed timewindow to launch batch if run date is expired (skip it if not fullfilled, 0 if disabled). Initiate job or resume should be in this time windows [ run date , run date + timewindow ] 

    uint256 _maxGasPrice;          // Maximum gas price in wei /1 gwei == 1e9/ (the multiprocess batch will not start if gas price above this limit, 0 if disabled, note _allowedTimeWindow should be not set to 0 if enabled -it may skip batch running too often-)
    uint256 _minGasLeft;           // Minimum gas left (the multiprocess batch will stop when remaining gas reach this limit ex: 50000, 30000 seems the minimal acceptable value)

    address _targetContract;       // target contract with batch logic implemented
    bool _needResume;              // multiprocessing ongoing indicator : true means the time initiated batch has been called but did not finished all items (a new run is needed)
      
    bytes32 private constant GELATO_WHITELIST = keccak256("GELATO_WHITELIST");    

    constructor(uint256 startTimestamp,uint256 repeatDelay,uint256 allowedTimeWindow,uint256 minGasLeft,uint256 maxGasPrice) {
        require(repeatDelay >= 1800,"Repeat delay too short < 1800 s");
        _repeatDelay = repeatDelay;
        _allowedTimeWindow = allowedTimeWindow;
        _minGasLeft = minGasLeft;
        _maxGasPrice = maxGasPrice;
        _nextRunTimestamp = startTimestamp;
        incNextRunTimestamp(block.timestamp);  // compute valid timestamp ( > )
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Update _nextRunTimestamp to the closest matching time in future matching parameters
    function incNextRunTimestamp(uint256 currentTimestamp) internal {
        if (currentTimestamp > _nextRunTimestamp) {
            _nextRunTimestamp += (((currentTimestamp - _nextRunTimestamp)/_repeatDelay)+1)*_repeatDelay;
        }
    }

    // Returns closest valid run regarding current time :
    // if current time below _nextRunTimestamp+_allowedTimeWindow  : returns _nextRunTimestamp
    // else : returns _nextRunTimestamp + N*_repeatDelay with lowest valid N (next valid run)
    function getClosestValidRunTimestamp(uint256 currentTimestamp) internal view returns(uint256){
        return _nextRunTimestamp + ((currentTimestamp > (_nextRunTimestamp + _allowedTimeWindow)) ? ((currentTimestamp - _nextRunTimestamp)/_repeatDelay)*_repeatDelay : 0);
    }

    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        if (!IGelatoSplitableTimeBatchTarget(_targetContract).mybatchNeedTrigger()) {   // TODO NAME TO TUNE : Call the target contract to know if anything to process
            canExec = false;
            execPayload = bytes("Nothing to process");
        }
        else if(_maxGasPrice != 0 && (tx.gasprice > _maxGasPrice)) {
            canExec = false;
            execPayload = bytes("Gas price too high");
        } 
        else {
            uint256 timeNow = block.timestamp;
            uint256 validRunTimestamp = getClosestValidRunTimestamp(timeNow);  // Get closest valid run timestamp 
            // Cases to activate batch :
            // 1) Need resume enabled
            //    => regular case when we need to run batch several time in a row to complete job
            // 2a) validRunTimestamp match _nextRunTimestamp AND time belong to validRunTimestamp timewindow
            //    => regular case when entering timewindow
            // 2b) validRunTimestamp does match _nextRunTimestamp AND time belong to validRunTimestamp timewindow
            //    => rare case when _nextRunTimestamp is invalid -batch has not been previously ran so _nextRunTimestamp was not updated-
            if (_needResume || ((timeNow > validRunTimestamp) && (timeNow < (validRunTimestamp + _allowedTimeWindow)))) {
                canExec = true;
                execPayload = abi.encodeCall(this.splitableBatch,());
            }
            else {
                canExec = false;
                execPayload = bytes("Waiting timewindow");
            }
        }
    }

    function changeTimewindow(uint256 allowedTimeWindow) public onlyRole(DEFAULT_ADMIN_ROLE) { 
        _allowedTimeWindow = allowedTimeWindow;
    }

    function changeMinGasLeft(uint256 minGasLeft) public onlyRole(DEFAULT_ADMIN_ROLE) { 
        _minGasLeft = minGasLeft;
    }

    function changeMaxGasPrice(uint256 maxGasPrice) public onlyRole(DEFAULT_ADMIN_ROLE) { 
        _maxGasPrice = maxGasPrice;
    }

    function changeRepeatDelay(uint256 repeatDelay) public onlyRole(DEFAULT_ADMIN_ROLE) { 
        _repeatDelay = repeatDelay;
    }

    function bindTargetContract(address targetContract) public onlyRole(DEFAULT_ADMIN_ROLE) { 
        _targetContract = targetContract;
    }    

    function splitableBatch() external onlyRole(GELATO_WHITELIST) {
        bool needResume = true;
        while (gasleft() > _minGasLeft) {
            if (IGelatoSplitableTimeBatchTarget(_targetContract).mybatch()) {   // TODO NAME TO TUNE : Call the target contract to process batch
                needResume = false;
                incNextRunTimestamp(block.timestamp);
                break;
            }
        }
        _needResume = needResume;
    }

}
