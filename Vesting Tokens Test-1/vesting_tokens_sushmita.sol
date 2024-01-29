// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract VestingContract {
    using SafeMath for uint256;

    address public owner;
    ERC20 public token;

    struct VestingSchedule {
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 slicePeriod;
        uint256 totalAmount;
        bool revocable;
        uint256 vestedTokens;
        bool revoked;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 slicePeriod,
        uint256 totalAmount,
        bool revocable
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);

    event VestingRevoked(address indexed beneficiary);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyBeneficiary(address beneficiary) {
        require(
            msg.sender == beneficiary || msg.sender == owner,
            "Not the beneficiary"
        );
        _;
    }

    constructor(ERC20 _token) {
        owner = msg.sender;
        token = _token;
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 slicePeriod,
        uint256 totalAmount,
        bool revocable
    ) external onlyOwner {
        require(
            vestingSchedules[beneficiary].startTime == 0,
            "Vesting schedule already exists [in createVestingSchedule()]"
        );
        require(
            totalAmount > 0 && vestingDuration > 0,
            "Invalid vesting parameters [in createVestingSchedule()]"
        );

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        schedule.startTime = startTime;
        schedule.cliffDuration = cliffDuration;
        schedule.vestingDuration = vestingDuration;
        schedule.slicePeriod = slicePeriod;
        schedule.totalAmount = totalAmount;
        schedule.revocable = revocable;

        emit VestingScheduleCreated(
            beneficiary,
            startTime,
            cliffDuration,
            vestingDuration,
            slicePeriod,
            totalAmount,
            revocable
        );
    }

    function calculateReleasableTokens(address beneficiary)
        public
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0; // Tokens are not vested yet
        }

        uint256 elapsedSinceCliff = block.timestamp.sub(schedule.startTime).sub(
            schedule.cliffDuration
        );

        uint256 totalVestingPeriods = schedule.vestingDuration.div(
            schedule.slicePeriod
        );
        uint256 vestedPeriods = elapsedSinceCliff.div(schedule.slicePeriod);

        if (vestedPeriods >= totalVestingPeriods) {
            return schedule.totalAmount;
        }

        uint256 vestingSlice = schedule.totalAmount.div(totalVestingPeriods);
        return vestingSlice.mul(vestedPeriods);
    }

    function releaseTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.startTime > 0, "No vesting schedule found [in releaseTokens()]");
        require(!schedule.revoked, "Vesting schedule revoked [in releaseTokens()]");

        uint256 releasableAmount = calculateReleasableTokens(msg.sender);
        require(releasableAmount > 0, "No tokens are currently vested [in releaseTokens()]");

        schedule.vestedTokens = schedule.vestedTokens.add(releasableAmount);

        token.transfer(msg.sender, releasableAmount);

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVestingSchedule(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting schedule not revocable [in revokeVestingSchedule()]");
        require(!schedule.revoked, "Vesting schedule already revoked [in revokeVestingSchedule()]");

        schedule.revoked = true;

        uint256 remainingTokens = schedule.totalAmount.sub(
            schedule.vestedTokens
        );
        if (remainingTokens > 0) {
            token.transfer(owner, remainingTokens);
        }

        emit VestingRevoked(beneficiary);
    }

    function getTime() view external returns(uint256){
        return block.timestamp;
    }

    function getBalance(address beneficiary) view external returns(uint256){
        return token.balanceOf(beneficiary);
    }
}