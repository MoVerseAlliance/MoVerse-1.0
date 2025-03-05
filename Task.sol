// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MoToken.sol";

contract Task {
    struct TaskInfo {
        address employer;
        string description;
        uint256 budget;
        uint256 biddingEndTime;
        bool isOpen;
        address winner;
        bool completed;
        bool isUrgent;
        uint256 urgentFee;
    }

    struct Bid {
        uint256 amount;
        uint256 rating;
        address bidder;
    }

    mapping(uint256 => TaskInfo) public tasks;
    mapping(uint256 => Bid[]) private bids;
    uint256 public taskCount;

    MoToken public moToken;

    uint256 public constant DEFAULT_BIDDING_DURATION = 1 days;
    uint256 public constant MINIMUM_BIDDING_DURATION = 30 minutes;
    uint256 public constant URGENT_FEE_PERCENTAGE = 10;

    event TaskCreated(uint256 taskId, string description, uint256 budget, bool isUrgent);
    event BiddingEnded(uint256 taskId, address winner, uint256 amount);
    event TaskCompleted(uint256 taskId, address winner);

    constructor(MoToken _moToken) {
        moToken = _moToken;
        taskCount = 0;
    }

    function createTask(
        string memory description,
        uint256 budget,
        bool isUrgent,
        uint256 biddingDuration // 加急任务的竞价时间（分钟）
    ) public {
        require(budget > 0, "Budget must be greater than 0");

        // 计算竞价截止时间
        uint256 duration = isUrgent ? (biddingDuration * 1 minutes) : DEFAULT_BIDDING_DURATION;
        if (isUrgent) {
            require(duration >= MINIMUM_BIDDING_DURATION, "Bidding duration too short");
        }
        uint256 biddingEndTime = block.timestamp + duration;

        uint256 urgentFee = isUrgent ? (budget * URGENT_FEE_PERCENTAGE / 100) : 0;

        if (isUrgent) {
            require(moToken.transferFrom(msg.sender, address(this), urgentFee), "Urgent fee transfer failed");
        }

        taskCount++;
        tasks[taskCount] = TaskInfo({
            employer: msg.sender,
            description: description,
            budget: budget,
            biddingEndTime: biddingEndTime,
            isOpen: true,
            winner: address(0),
            completed: false,
            isUrgent: isUrgent,
            urgentFee: urgentFee
        });
        emit TaskCreated(taskCount, description, budget, isUrgent);
    }

    function placeBid(uint256 taskId, uint256 amount, uint256 rating) public {
        TaskInfo storage task = tasks[taskId];
        require(task.isOpen, "Task is not open");
        require(block.timestamp < task.biddingEndTime, "Bidding period has ended");
        require(amount <= task.budget, "Bid amount exceeds budget");

        bids[taskId].push(Bid({
            amount: amount,
            rating: rating,
            bidder: msg.sender
        }));
    }

    function endBidding(uint256 taskId) public {
        TaskInfo storage task = tasks[taskId];
        require(task.isOpen, "Task is already closed");
        //require(block.timestamp >= task.biddingEndTime, "Bidding period has not ended");

        task.isOpen = false;

        Bid[] storage taskBids = bids[taskId];
        if (taskBids.length == 0) {
            if (task.isUrgent && task.urgentFee > 0) {
                require(moToken.transfer(task.employer, task.urgentFee), "Refund failed");
            }
            return;
        }

        uint256 lowestAmount = type(uint256).max;
        uint256 highestRating = 0;
        address lowestBidder = address(0);

        for (uint256 i = 0; i < taskBids.length; i++) {
            if (taskBids[i].amount < lowestAmount || 
                (taskBids[i].amount == lowestAmount && taskBids[i].rating > highestRating)) {
                lowestAmount = taskBids[i].amount;
                highestRating = taskBids[i].rating;
                lowestBidder = taskBids[i].bidder;
            }
        }

        if (lowestBidder != address(0)) {
            task.winner = lowestBidder;
            emit BiddingEnded(taskId, lowestBidder, lowestAmount);
        }
    }

    function submitTask(uint256 taskId) public {
        TaskInfo storage task = tasks[taskId];
        require(task.isOpen == false, "Task is still open for bidding");
        require(msg.sender == task.winner, "Only the winner can submit the task");
        require(!task.completed, "Task is already completed");

        task.completed = true;
        if (task.isUrgent && task.urgentFee > 0) {
            require(moToken.transfer(msg.sender, task.urgentFee), "Urgent fee transfer failed");
        }
        emit TaskCompleted(taskId, task.winner);
    }

    function getWinner(uint256 taskId) public view returns (address) {
        TaskInfo storage task = tasks[taskId];
        require(msg.sender == task.employer, "Only employer can view winner");
        require(task.completed, "Task is not completed yet");
        return task.winner;
    }
}