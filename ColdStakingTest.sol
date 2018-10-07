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

contract ColdStaking {    
    using SafeMath for uint;
    event Staking(address addr, uint value, uint amount, uint time);
    event WithdrawStake(address staker, uint amount);
    event Claim(address staker, uint reward);

    struct Staker {
        uint stake;
        uint reward;        
        uint lastClaim;
        //-------------------- start test only ------------------ //
        uint lastBlock;
        //-------------------- end test only ------------------ //
        uint lastWeightedBlockReward;
    }
    
    mapping(address => Staker) public staker;
    
    uint public staked_amount;
    uint public weightedBlockReward;
    
    uint public totalClaimedReward;
    // unclaimed rewards can be redistributed, however they are not in this version. 
    // it can be done durring marketing compaign were to amount of the reward per block will doubeled for example.
    uint public totalUnClaimedReward;
    // same as totalUnClaimedReward, totalTreasuryBalance can follow the same schema
    uint public totalTreasuryBalance;
    uint public lastTotalReward;
    uint public lastStakingUpdate;
    
    uint public claim_delay = 30 days;
    
    //--------------------- test only  start------------------------//
    constructor() public payable {
        lastStakingUpdate = block.number;
    }
    //--------------------- test only end ------------------------//
    
    modifier only_staker {
        require(staker[msg.sender].stake > 0);
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
        staker[msg.sender].lastClaim = now;
        //-------------------- start test only ------------------ //
        staker[msg.sender].lastBlock = block.number;
        //-------------------- end test only ------------------ //
        emit Staking(msg.sender,msg.value,staker[msg.sender].stake,now);
    }


    function staking_update(uint _value, bool _sign) internal {
            
        // Computing the total block reward (20% of the mining reward) that have been 
        // to the contract since the last call of staking_update.
        // the smart contract now is independent from any change of the monetary policy.
        // As highlighted by yuriy77k, msg.value should be also deducted from the total.
        
        uint intervalReward;
        //--------------------- start only after HF --------------------------//
        
        // uint _total_sub_ = totalTreasuryBalance.add(staked_amount).add(msg.value);
        // uint _total_add_ = totalClaimedReward;
        // uint newTotalReward = address(this).balance.add(_total_add_).sub(_total_sub_);
        // intervalReward = newTotalReward - lastTotalReward;
        // lastTotalReward = lastTotalReward + intervalReward;
        
        //--------------------- start only after HF --------------------------//
        
        //--------------------- test only  start------------------------//
        intervalReward = (block.number - lastStakingUpdate) * 100 ether;
        //--------------------- end only  start------------------------//
        
        lastStakingUpdate = block.number;
        

        if (staked_amount!=0) {
            weightedBlockReward = weightedBlockReward.add(intervalReward.mul(1 ether).div(staked_amount));
        } else {
            totalUnClaimedReward = totalUnClaimedReward.add(intervalReward);
        }
        
        if(_sign ) staked_amount = staked_amount.add(_value);
        else staked_amount = staked_amount.sub(_value);
    }
    
    function staker_reward_update() internal {
        uint stakerIntervalWeightedBlockReward = weightedBlockReward.sub(staker[msg.sender].lastWeightedBlockReward);
        uint _reward = staker[msg.sender].stake.mul(stakerIntervalWeightedBlockReward).div(1 ether);
        
        staker[msg.sender].reward = staker[msg.sender].reward.add(_reward);
        staker[msg.sender].lastWeightedBlockReward = weightedBlockReward;
    }


    function withdraw_stake() public only_staker {
        staking_update(staker[msg.sender].stake,false);
        staker_reward_update();
        
        uint _stake = staker[msg.sender].stake;
        staker[msg.sender].stake = 0;
        msg.sender.transfer(_stake);
        
        if(staker[msg.sender].lastClaim + claim_delay > now) {
            uint _reward = staker[msg.sender].reward;
            staker[msg.sender].reward = 0;
            totalUnClaimedReward = totalUnClaimedReward.add(_reward);
        }
        
        emit WithdrawStake(msg.sender,_stake);
    }

    function claim() public only_rewarded {
        if(staker[msg.sender].lastClaim + claim_delay <= now) {
            
            staking_update(0,true);
            staker_reward_update();
        
            staker[msg.sender].lastClaim = now;
            uint _reward = staker[msg.sender].reward;
            staker[msg.sender].reward = 0;
            msg.sender.transfer(_reward);
        
            emit Claim(msg.sender, _reward);
        }
    }
    
    function claim_and_withdraw() public only_rewarded {
        claim();
        withdraw_stake();
    }
    
    function treasury_deposit() public payable {
        totalTreasuryBalance = totalTreasuryBalance.add(msg.value);
    }
    
    function staker_info() public view returns(uint256 weight, uint256 init, uint256 actual_block,uint256 _reward)
    {
        uint _intervalReward;
        //------------------start only live-----------------------//
        // uint _total_sub_ = totalTreasuryBalance.add(staked_amount).add(msg.value);
        // uint _total_add_ = totalClaimedReward;
        // uint newTotalReward = address(this).balance.add(_total_add_).sub(_total_sub_);
        // _intervalReward = newTotalReward - lastTotalReward;
        //------------------end only live-----------------------//
        
        //--------------------- test only  start------------------------//
         _intervalReward = (block.number - lastStakingUpdate) * 100 ether;
        //--------------------- test only  end------------------------//
        if(staked_amount!=0) {
            uint _weightedBlockReward = weightedBlockReward.add(_intervalReward.mul(1 ether).div(staked_amount));
            uint stakerIntervalWeightedBlockReward = _weightedBlockReward.sub(staker[msg.sender].lastWeightedBlockReward);
            _reward = staker[msg.sender].stake.mul(stakerIntervalWeightedBlockReward).div(1 ether);
        }
    
        return (
        staker[msg.sender].stake,
        staker[msg.sender].lastBlock,
        block.number,
        _reward = staker[msg.sender].reward + _reward
        );
    }
    //--------------------- test only start ------------------------//
    // send ether to contract
    function deposit() public payable {
    }
    
    //--------------------- test only end ------------------------//
}

