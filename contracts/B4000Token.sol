// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract B4000Token is ERC20, Ownable {
    using SafeMath for *;

    bool public isMining = true;

    mapping(address => bool) private adminMap;

    struct StakeItem {
        address a; // address
        uint256 s; // stake count
    }
    mapping(address => uint) private stakeIndex;
    StakeItem[] public stakePool;

    // NFT cards mine rewards
    mapping(address => uint256) public nftBalance;
    // LP stake mine data
    mapping(address => uint256) public LPBalance;
    // b4k stake mine data
    mapping(address => uint256) public coinBalance;
    // mapping(address => uint256) public _b4kBalance;

    event onMinedChanged(bool _status);
    event onAdminChanged(address _addr, bool isAdmin);

    constructor(address _admin) ERC20("B4000 Coin", "B4K") {
        adminMap[_admin] = true;
        stakeIndex[address(this)] = 0;
        stakePool.push(StakeItem({
            a: address(this),
            s: 0
        }));
    }

    modifier onlyOwnerAdmin() {
        address _sender = _msgSender();
        require(adminMap[_sender] || owner() == _sender, "B4K: caller is not owner or admin");
        _;
    }

    // ==================== NFT mine ====================
    function nftBalanceOf(address _addr) public view returns(uint256) {
        return nftBalance[_addr];
    }
    // harvest nft mine rewards
    function harvestNftMineBalance() public {
        address _sender = msg.sender;
        require(nftBalance[_sender] > 0, "B4K: Not enough NFT rewards to harvest");
        _mint(_sender, nftBalance[_sender]);
        nftBalance[_sender] = 0;
    }
    // mint b4k to nft owners
    function batchMintNft(address[] memory _addr, uint256[] memory _mineCount) public onlyOwnerAdmin {
        require(isMining, "B4K: has stoped mine");
        require(_addr.length == _mineCount.length, "B4K: _addr.length and _mineCount.length are not same");
        for (uint i = 0; i < _addr.length; i++) {
            nftBalance[_addr[i]] = nftBalance[_addr[i]].add(_mineCount[i]);
        }
    }
    // ==================== NFT mine ====================

    // ==================== LP stake mine ====================
    function LPBalanceOf(address _addr) public view returns(uint256) {
        return LPBalance[_addr];
    }
    // harvest LP stake mine rewards
    function harvestLPMineBalance() public {
        address _sender = msg.sender;
        require(LPBalance[_sender] > 0, "B4K: Not enough LP stake rewards to harvest");
        _mint(_sender, LPBalance[_sender]);
        LPBalance[_sender] = 0;
    }
    // mint b4k to LP stakers
    function batchMintLP(address[] memory _addr, uint256[] memory _mineCount) public onlyOwnerAdmin {
        require(isMining, "B4K: has stoped mine");
        require(_addr.length == _mineCount.length, "B4K: _addr.length and _mineCount.length are not same");
        for (uint i = 0; i < _addr.length; i++) {
            LPBalance[_addr[i]] = LPBalance[_addr[i]].add(_mineCount[i]);
        }
    }
    // ==================== LP stake mine ====================


    // ==================== B4k Coin stake mine ====================
    function coinBalanceOf(address _addr) public view returns(uint256) {
        return coinBalance[_addr];
    }
    // harvest b4k stake mine rewards
    function harvestCoinBalance() public {
        address _sender = msg.sender;
        require(coinBalance[_sender] > 0, "B4K: Not enough b4k rewards to harvest");
        _mint(_sender, coinBalance[_sender]);
        coinBalance[_sender] = 0;
    }
    function batchMintCoin(address[] memory _addr, uint256[] memory _mineCount) public onlyOwnerAdmin {
        require(isMining, "B4K: has stoped mine");
        require(_addr.length == _mineCount.length, "B4K: _addr.length and _mineCount.length are not same");
        for (uint i = 0; i < _addr.length; i++) {
            coinBalance[_addr[i]] = coinBalance[_addr[i]].add(_mineCount[i]);
        }
    }
    // ==================== B4k Coin stake mine ====================

    // ==================== stake B4K ====================
    function getStakeData() public view returns(StakeItem[] memory) {
        uint total = stakePool.length;
        StakeItem[] memory arr = new StakeItem[](total);
        // the (i == 0) is this contract placeholder, not used for users
        for (uint i = 1; i < stakePool.length; i++) {
            arr[i] = stakePool[i];
        }
        return arr;
    }

    function stakeIndexOf(address _addr) public view returns (uint) {
        return stakeIndex[_addr];
    }

    function stakeBalanceOf(address _addr) public view returns (StakeItem memory) {
        uint idx = stakeIndex[_addr];
        if(idx == 0) {
            // Not Found
            return StakeItem({
                a: address(_addr),
                s: 0
            });
        }
        return stakePool[idx];
    }

    function withdrawStake(uint256 _count) public {
        require(_count > 0, "B4K: withdrawn token counts should > 0");
        address _sender = msg.sender;
        uint idx = stakeIndex[_sender];
        require(idx > 0, "B4K: Not stake any token before");

        StakeItem memory st = stakePool[idx];
        uint256 balance = st.s;
        require(balance >= _count, "B4K: Not enough staked blance to withdraw");

        _transfer(address(this), _sender, _count);

        stakePool[idx] = StakeItem({
            a: _sender,
            s: st.s.sub(_count)
        });
    }

    // stake b4k token from user's wallet
    function stakeToken(uint256 _count) public {
        require(_count > 0, "B4K: staked token counts should > 0");
        address _sender = msg.sender;
        uint256 senderBallance = balanceOf(_sender);
        require(senderBallance >= _count, "B4K: Not enough ballance to stake");

        transfer(address(this), _count);
        increaseStakePool(_sender, _count);
    }

    // compound: stake user's all rewards from coinBalance
    function compoundCoinRewards() public {
        address _sender = msg.sender;
        uint256 ballance = coinBalance[_sender];
        require(ballance > 0, "B4K: Not enough b4k rewards to stake");

        coinBalance[_sender] = 0;
        increaseStakePool(_sender, ballance);
        _mint(address(this), ballance);
    }

    function increaseStakePool(address _addr, uint256 _count) internal {
        uint idx = stakeIndex[_addr];
        if(idx > 0) {
            stakePool[idx].s = stakePool[idx].s.add(_count);
        } else {
            stakePool.push(StakeItem({
                a: _addr,
                s: _count
            }));
            stakeIndex[_addr] = stakePool.length - 1;
        }
    }

    // ==================== stake B4K ====================

    function startMine() public onlyOwner {
        isMining = true;
        emit onMinedChanged(isMining);
    }
    function stopMine() public onlyOwner {
        isMining = false;
        emit onMinedChanged(isMining);
    }

    function setAdmin(address _addr) public onlyOwner {
        adminMap[_addr] = true;
        emit onAdminChanged(_addr, true);
    }
    function removeAdmin(address _addr) public onlyOwner {
        adminMap[_addr] = false;
        emit onAdminChanged(_addr, false);
    }
    function isAdmin(address _addr) public view returns (bool) {
        return adminMap[_addr];
    }

    function mintTo(address _addr, uint256 _mineCount) public onlyOwnerAdmin {
        require(isMining, "B4K: has stoped mine");
        _mint(_addr, _mineCount);
    }

}
