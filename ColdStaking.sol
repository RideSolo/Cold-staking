pragma solidity ^0.4.24;

library SafeMath {
  function mul(uint a, uint b) internal pure returns (uint) {
    if (a == 0) {
      return 0;
    }
    uint c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint a, uint b) internal pure returns (uint) {
    uint c = a / b;
    return c;
  }

  function sub(uint a, uint b) internal pure returns (uint) {
    require(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    require(c >= a);
    return c;
  }
}

contract ColdStaking 
{
    using SafeMath for uint;
    event Staking(address addr, uint value, uint amount, uint time);
    event WithdrawStake(address staker, uint amount);
    event Claim(address staker, uint reward);
    event DonationDeposited(address _address, uint value);
    event VoterWithrawlDeadlineUpdate(address _voter,uint _time);
    event InactiveStaker(address _addr,uint value);

    struct Staker {
        uint stake;
        uint reward;        
        uint lastClaim;
        uint lastWeightedBlockReward;
        uint voteWithdrawalDeadline;
    }
    
    mapping(address => Staker) public staker;
    
    
    uint public staked_amount;
    uint public rewardToDistribute;
    uint public weightedBlockReward;
    uint public totalClaimedReward;
    uint public lastTotalReward;
    
    uint public claim_delay = 27 days;
    uint public max_delay = 365 * 2 days; // 2 years.
    
    address public governance_contract = 0x0; // address to be added either by setter or hardcoded

    modifier only_staker {
        require(staker[msg.sender].stake > 0);
        _;
    }
    
    modifier onlyGovernanceContract {
        require(msg.sender == governance_contract);
        _;
    }
    
    modifier only_rewarded {
        require(staker[msg.sender].stake > 0 || staker[msg.sender].reward > 0);
        _;
    }

    function() public payable {
        start_staking();
    }
    
    // the proposal allow the staker to stake more clo, at any given time without changing the basic description of the formula 
    function start_staking() public payable {
        require(msg.value > 0);
        
        staking_update(msg.value,true);
        staker_reward_update(); 
        staker[msg.sender].stake = staker[msg.sender].stake.add(msg.value); 
        staker[msg.sender].lastClaim = block.timestamp;
        
        emit Staking(msg.sender,msg.value,staker[msg.sender].stake,block.timestamp);
    }


    function staking_update(uint _value, bool _sign) internal {
    
        // Computing the total block reward (20% of the mining reward) that have been 
        // to the contract since the last call of staking_update.
        // the smart contract now is independent from any change of the monetary policy.
        // As highlighted by yuriy77k, msg.value should be also deducted from the total.
        
        uint _total_sub_ = staked_amount.add(msg.value);
        uint _total_add_ = totalClaimedReward;
        
        uint newTotalReward = address(this).balance.add(_total_add_).sub(_total_sub_);
        uint intervalReward = newTotalReward - lastTotalReward;
        lastTotalReward = lastTotalReward + intervalReward;
        
        if (staked_amount!=0) weightedBlockReward = weightedBlockReward.add(intervalReward.mul(1 ether).div(staked_amount));
        else rewardToDistribute = rewardToDistribute.add(intervalReward);
        
        if(_sign ) staked_amount = staked_amount.add(_value);
        else staked_amount = staked_amount.sub(_value);
    }
    
    function staker_reward_update() internal {
        uint stakerIntervalWeightedBlockReward = weightedBlockReward.sub(staker[msg.sender].lastWeightedBlockReward);
        uint _reward = staker[msg.sender].stake.mul(stakerIntervalWeightedBlockReward).div(1 ether);
        
        staker[msg.sender].reward = staker[msg.sender].reward.add(_reward);
        staker[msg.sender].lastWeightedBlockReward = weightedBlockReward;
    }


    function withdraw_stake() public only_staker 
    {
        require(staker[msg.sender].lastClaim + claim_delay < block.timestamp && staker[msg.sender].voteWithdrawalDeadline < block.timestamp );
            
        staking_update(staker[msg.sender].stake,false);
        staker_reward_update();
        
        uint _stake = staker[msg.sender].stake;
        staker[msg.sender].stake = 0;
        msg.sender.transfer(_stake);
        
        emit WithdrawStake(msg.sender,_stake);
    }

    function claim() public only_rewarded {
        if(staker[msg.sender].lastClaim + claim_delay <= block.timestamp) {
            
            staking_update(0,true);
            staker_reward_update();
        
            staker[msg.sender].lastClaim = block.timestamp;
            uint _reward = staker[msg.sender].reward;
            staker[msg.sender].reward = 0;
            msg.sender.transfer(_reward);
        
            emit Claim(msg.sender, _reward);
        }
    }
    
    function staker_info() public view returns(uint256 weight, uint256 init, uint256 actual_block,uint256 _reward)
    {
        uint _total_sub_ = staked_amount;
        uint _total_add_ = totalClaimedReward;
        uint newTotalReward = address(this).balance.add(_total_add_).sub(_total_sub_);
        uint _intervalReward = newTotalReward - lastTotalReward;
        
        if(staked_amount!=0) {
            uint _weightedBlockReward = weightedBlockReward.add(_intervalReward.mul(1 ether).div(staked_amount));
            uint stakerIntervalWeightedBlockReward = _weightedBlockReward.sub(staker[msg.sender].lastWeightedBlockReward);
            _reward = staker[msg.sender].stake.mul(stakerIntervalWeightedBlockReward).div(1 ether);
        }
    
        return (
        staker[msg.sender].stake,
        staker[msg.sender].lastClaim,
        block.number,
        _reward = staker[msg.sender].reward + _reward
        );
    }
    
    function report_abuse(address _addr) public only_staker
    {
        require(staker[_addr].stake > 0);
        require(staker[_addr].lastClaim.add(max_delay) < block.timestamp);
        
        uint _amount = staker[_addr].stake;
        
        staked_amount = staked_amount.sub(_amount);
        rewardToDistribute = rewardToDistribute.add(_amount);

        staker[_addr].stake = 0;
        _addr.transfer(_amount);
        
        emit InactiveStaker(_addr,_amount);
    }
    
    function set_voter_withdrawal_deadline(address voter, uint _voteWithdrawalDeadline) external onlyGovernanceContract
    {
        staker[voter].voteWithdrawalDeadline = _voteWithdrawalDeadline;
        emit VoterWithrawlDeadlineUpdate(voter,_voteWithdrawalDeadline);
    }
}
