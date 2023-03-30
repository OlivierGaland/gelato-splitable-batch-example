// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
//import "hardhat/console.sol";
import "./IGelatoSplitableTimeBatchTarget.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GelatoSplitableTimeBatch is AccessControl {

    // See https://www.epochconverter.com/ : those approximate values will make job run time drift very slowly with time ... see you in year 3000 to issue a bug
    /*
    uint256 private constant AVERAGE_MINUTE_LENGHT = 60;
    uint256 private constant AVERAGE_HOUR_LENGHT = AVERAGE_MINUTE_LENGHT*60;
    uint256 private constant AVERAGE_DAY_LENGHT = AVERAGE_HOUR_LENGHT*24;
    uint256 private constant AVERAGE_WEEK_LENGHT = AVERAGE_DAY_LENGHT*7;
    uint256 private constant AVERAGE_MONTH_LENGHT = 2629743;
    uint256 private constant AVERAGE_YEAR_LENGHT = 31556926;
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
        if (!IGelatoSplitableTimeBatchTarget(_targetContract).mybatchNeedTrigger()) {
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
            if (IGelatoSplitableTimeBatchTarget(_targetContract).mybatch()) {   // NAME TO TUNE : Call the target contract to process batch
                needResume = false;
                incNextRunTimestamp(block.timestamp);
                break;
            }
        }
        _needResume = needResume;
    }

}
