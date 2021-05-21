const BigNumber = require('bignumber.js');
const truffleAssert = require('truffle-assertions');
const BurstToken = artifacts.require('BurstToken');
const B4000Token = artifacts.require('B4000Token');

contract('Burst Test', async accounts => {
  beforeEach(async () => {
    this.owner = accounts[0];
    this.user1 = accounts[1];
    this.user2 = accounts[2];
    this.user3 = accounts[3];
    this.admin = accounts[4];
    this.burstToken = await BurstToken.new();
    this.stakeCoinToken = await B4000Token.new(this.admin);
    await this.stakeCoinToken.mintTo(this.user1, '10000', {
      from: this.admin
    });

    this.b4kToken = await B4000Token.new(this.admin);
    await this.b4kToken.mintTo(this.user1, '10000', {
      from: this.admin
    });
  })
  it('burst buyCard', async () => {
    const nodePrice = await this.burstToken.NODE_PRICE.call()
    const cardIndex = 0;
    const owner = await this.burstToken.owner.call();
    assert.equal(owner, this.owner);

    const ret = await this.burstToken.buyCard(cardIndex, {
      from: this.user1,
      value: nodePrice.toString()
    });

    truffleAssert.eventEmitted(ret, 'onBRTOneNodeBuyed', ev => {
      return ev._buyer === this.user1
        && ev._nid.toString() === cardIndex.toString()
        && ev._currentPrice.toString() === nodePrice.toString()
        && ev._nextPrice.toString() === BigNumber(nodePrice).times(1.1).toString()
    });
  });

  it('burst stake Token', async () => {
    const approveCount = '10000000000'
    await this.stakeCoinToken.approve(this.burstToken.address, approveCount, {
      from: this.user1
    })
    const stakeCount = '100';
    await this.burstToken.stakeToken(this.stakeCoinToken.address, stakeCount, {
      from: this.user1
    });
    const stakeBalance = await this.burstToken.stakeBalanceOf.call(this.user1);
    assert.equal(stakeBalance.a, this.user1);
    assert.equal(stakeBalance.s, stakeCount);


    await this.burstToken.withdrawStake(this.stakeCoinToken.address, stakeCount, {
      from: this.user1
    });
    const stakeBalanceAfter = await this.burstToken.stakeBalanceOf.call(this.user1);
    assert.equal(stakeBalanceAfter.a, this.user1);
    assert.equal(stakeBalanceAfter.s, '0');
  });

  it('b4k set admin', async () => {
    const isAdmin = await this.b4kToken.isAdmin.call(this.admin);
    const isUserAdmin = await this.b4kToken.isAdmin.call(this.user1);
    assert.equal(isAdmin, true);
    assert.equal(isUserAdmin, false);

    const resultAdmin1 = await this.b4kToken.setAdmin(this.user1, {
      from: this.owner
    });
    const isUserAdminAfterSet = await this.b4kToken.isAdmin.call(this.user1);
    assert.equal(isUserAdminAfterSet, true);
    truffleAssert.eventEmitted(resultAdmin1, 'onAdminChanged', ev => {
      return ev.isAdmin === true && ev._addr === this.user1
    });

    const resultAdminRemove = await this.b4kToken.removeAdmin(this.user1, {
      from: this.owner
    });
    const isUserAdminAfterRemove = await this.b4kToken.isAdmin.call(this.user1);
    assert.equal(isUserAdminAfterRemove, false);
    truffleAssert.eventEmitted(resultAdminRemove, 'onAdminChanged', ev => {
      return ev.isAdmin === false && ev._addr === this.user1
    });
  });

  it('b4k setting mined', async () => {
    const isMining = await this.b4kToken.isMining.call();
    assert.equal(isMining, true);

    await this.b4kToken.stopMine({
      from: this.owner
    });
    const isMiningAfterStop = await this.b4kToken.isMining.call();
    assert.equal(isMiningAfterStop, false);
  });

  it('b4k stake', async () => {
    const stakeCount = '100';
    await this.b4kToken.stakeToken(stakeCount, {
      from: this.user1
    });
    const stakeData = await this.b4kToken.stakeBalanceOf.call(this.user1);
    assert.equal(stakeData.a, this.user1);
    assert.equal(stakeData.s, stakeCount);
  });

  it('b4k coin batch mint', async () => {
    const u2Mint = '100';
    const u3Mint = '1000';
    await this.b4kToken.batchMintCoin([this.user2, this.user3], [u2Mint, u3Mint], {
      from: this.admin
    });

    const u2Rewards = await this.b4kToken.coinBalanceOf.call(this.user2);
    assert.equal(u2Mint, u2Rewards.toString());
    const u3Rewards = await this.b4kToken.coinBalanceOf.call(this.user3);
    assert.equal(u3Mint, u3Rewards.toString());

    await this.b4kToken.compoundCoinRewards({
      from: this.user3
    });
    const u3RewardsAfter = await this.b4kToken.coinBalanceOf.call(this.user3);
    assert.equal('0', u3RewardsAfter.toString());

    await this.b4kToken.withdrawStake(u3Mint, {
      from: this.user3
    });
    const u3Balance = await this.b4kToken.balanceOf.call(this.user3);
    assert.equal(u3Mint, u3Balance.toString());

    await this.b4kToken.harvestCoinBalance({
      from: this.user2
    });
    const u2Balance = await this.b4kToken.balanceOf.call(this.user2);
    assert.equal(u2Mint, u2Balance.toString());
  });

  it('b4k LP batch mint', async () => {
    const u2Mint = '100';
    const u3Mint = '1000';
    await this.b4kToken.batchMintLP([this.user2, this.user3], [u2Mint, u3Mint], {
      from: this.admin
    });

    const u2Rewards = await this.b4kToken.LPBalanceOf.call(this.user2);
    assert.equal(u2Mint, u2Rewards.toString());
    const u3Rewards = await this.b4kToken.LPBalanceOf.call(this.user3);
    assert.equal(u3Mint, u3Rewards.toString());

    await this.b4kToken.harvestLPMineBalance({
      from: this.user2
    });
    const u2Balance = await this.b4kToken.balanceOf.call(this.user2);
    assert.equal(u2Mint, u2Balance.toString());
  });

  it('b4k nft batch mint', async () => {
    const u2Mint = '100';
    const u3Mint = '1000';
    await this.b4kToken.batchMintNft([this.user2, this.user3], [u2Mint, u3Mint], {
      from: this.admin
    });

    const u2Rewards = await this.b4kToken.nftBalanceOf.call(this.user2);
    assert.equal(u2Mint, u2Rewards.toString());
    const u3Rewards = await this.b4kToken.nftBalanceOf.call(this.user3);
    assert.equal(u3Mint, u3Rewards.toString());

    await this.b4kToken.harvestNftMineBalance({
      from: this.user2
    });
    const u2Balance = await this.b4kToken.balanceOf.call(this.user2);
    assert.equal(u2Mint, u2Balance.toString());
  });
});
