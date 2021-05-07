// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract B4000Token is ERC20, Ownable {
    using SafeMath for *;

    bool public isMining = true;

    mapping(address => bool) private adminMap;

    mapping(address => uint256) public _b4kBalance;

    mapping(address => uint) private stakeIndex;
    struct StakeItem {
        address a; // address
        uint256 s; // stake count
    }
    StakeItem[] public stakePool;

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
        address _sender = msg.sender;
        uint256 senderBallance = balanceOf(_sender);
        require(senderBallance >= _count, "B4K: Not enough ballance to stake");

        transfer(address(this), _count);
        increaseStakePool(_sender, _count);
    }

    // stake all user's rewards from _b4kBalance
    function stakeBalance() public {
        address _sender = msg.sender;
        uint256 ballance = _b4kBalance[_sender];
        require(ballance > 0, "B4K: Not enough _b4kBalance to stake");

        _b4kBalance[_sender] = 0;
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

    function startMine() public onlyOwner {
        isMining = true;
    }
    function stopMine() public onlyOwner {
        isMining = false;
    }

    function setAdmin(address _addr) public onlyOwner {
        adminMap[_addr] = true;
    }
    function removeAdmin(address _addr) public onlyOwner {
        adminMap[_addr] = false;
    }
    function isAdmin(address _addr) public view returns (bool) {
        return adminMap[_addr];
    }

    function batchUpdateBalance(address[] memory _addr, uint256[] memory _mineCount) public onlyOwnerAdmin {
        require(isMining, "B4K: has stoped mine");
        for (uint i = 0; i < _addr.length; i++) {
            _b4kBalance[_addr[i]] = _b4kBalance[_addr[i]].add(_mineCount[i]);
        }
    }
    function withdrawBalance() public {
        address _sender = msg.sender;
        require(_b4kBalance[_sender] > 0, "B4K: Not enough b4k balance to withdraw");
        _mint(_sender, _b4kBalance[_sender]);
        _b4kBalance[_sender] = 0;
    }

    function b4kBalanceOf(address _addr) public view returns(uint256) {
        return _b4kBalance[_addr];
    }

    function batchMint(address[] memory _addr, uint256[] memory _mineCount) public onlyOwnerAdmin {
        require(isMining, "B4K: has stoped mine");
        for (uint i = 0; i < _addr.length; i++) {
            _mint(_addr[i], _mineCount[i]);
        }
    }

    function mintTo(address _addr, uint256 _mineCount) public onlyOwnerAdmin {
        require(isMining, "B4K: has stoped mine");
        _mint(_addr, _mineCount);
    }

}