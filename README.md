# Cold staking protocol for EVM-compatible blockchain projects

Proposed implementation of cold staking protocol forked from https://github.com/EthereumCommonwealth/Cold-staking.
https://github.com/RideSolo/Cold-staking/blob/master/proposal.pdf

# Callisto  ColdStakingTest.sol contract is deployed on Callisto Testnet 3.0 

To be able to claim, a deposit with a value higher than the calculated reward should be deposited, use `deposit` function (since the contract do not receive 20% of the block mining reward)

[0x3d85cef155b18a1aa71ba3d3d87af745d075c462](https://explorer-testnet.callisto.network/addr/0x3d85cef155b18a1aa71ba3d3d87af745d075c462)

For testing purpose the block reward is set to be 100 clo.
