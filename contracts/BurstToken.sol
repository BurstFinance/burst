// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BurstToken is ERC20, Ownable {
    using SafeMath for *;
    using SafeERC20 for IERC20;

    /* ========== DATA ========== */

    // unit price of each node
    uint public constant NODE_PRICE = 5e18 wei; // 5 HT
    // uint public constant NODE_PRICE = 0.01e18 wei; // 0.01 HT

    // total count of node
    uint public constant NODE_TOTAL = 4000;

    mapping(address => uint) private stakeIndex;
    struct StakeItem {
        address a; // address
        uint256 s; // stake count
    }
    // stake LP
    StakeItem[] public stakePool;

    // node info object
    struct NodeItem {
        address o; // owner address of this node
        uint256 p; // current price of this node
    }

    // array pool of each node
    NodeItem[NODE_TOTAL] public nodePool;

    /* ========== EVENTS ========== */

    // Emitted when one node is buyed
    event onBRTOneNodeBuyed(uint256 _nid, address _buyer, uint256 _currentPrice, uint256 _nextPrice);

    constructor() ERC20("Burst Token", "BRT") {
        stakeIndex[address(this)] = 0;
        stakePool.push(StakeItem({
            a: address(this),
            s: 0
        }));
    }

    function withdrawBalance() public onlyOwner {
        require(address(this).balance > 0, "BRT: Not enough ballance to withdraw");
        payable(owner()).transfer(address(this).balance);
    }

    function checkBalance(address addr) public view returns(uint256) {
        return address(addr).balance;
    }

    // get all nodepoll struct data
    function getNodeData() public view returns(NodeItem[] memory){
        NodeItem[] memory arr = new NodeItem[](NODE_TOTAL);
        for (uint i = 0; i < NODE_TOTAL; i++)
            arr[i] = nodePool[i];
        return arr;
    }

    function updateNodePool(uint256 _nid, address _owner, uint256 _price) internal {
        require(_nid < NODE_TOTAL, "BRT: Can not add more node");
        nodePool[_nid].o = _owner;
        nodePool[_nid].p = _price;
    }

    // ==================== stake LP ====================
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
            // Not Found return 0
            return StakeItem({
                a: address(_addr),
                s: 0
            });
        }
        return stakePool[idx];
    }

    function withdrawStake(IERC20 _token, uint256 _count) public {
        require(_count > 0, "BRT: withdrawn token counts should > 0");
        address _sender = msg.sender;
        uint idx = stakeIndex[_sender];
        require(idx > 0, "BRT: Not stake any token before");

        StakeItem memory st = stakePool[idx];
        uint256 balance = st.s;
        require(balance >= _count, "BRT: Not enough staked blance to withdraw");

        stakePool[idx] = StakeItem({
            a: _sender,
            s: st.s.sub(_count)
        });
        _token.safeTransfer(_sender, _count);
    }

    // stake LP token
    function stakeToken(IERC20 _token, uint256 _stakeAmount) public {
        address _sender = msg.sender;
        uint256 senderBallance = _token.balanceOf(_sender);

        require(_stakeAmount > 0, "BRT: staked token counts should > 0");
        require(senderBallance >= _stakeAmount, "BRT: Not enough ballance to stake");

        uint idx = stakeIndex[_sender];
        if(idx > 0) {
            stakePool[idx].s = stakePool[idx].s.add(_stakeAmount);
        } else {
            stakePool.push(StakeItem({
                a: _sender,
                s: _stakeAmount
            }));
            stakeIndex[_sender] = stakePool.length - 1;
        }
        _token.transferFrom(_sender, address(this), _stakeAmount);
    }
    // ==================== stake LP ====================

    // buy card
    function buyCard(uint256 _nid) public payable {
        require(_nid < NODE_TOTAL, "BRT: Illegal node item");

        NodeItem memory nodeItem = nodePool[_nid];
        address buyer = msg.sender;
        uint256 _in = msg.value;
        uint256 nodePrice = nodeItem.p;

        bool isOriginNode = false;
        // check this node whether is first bought
        if (nodeItem.p == 0) {
            isOriginNode = true;
            nodePrice = NODE_PRICE;
        }

        // 1. msg.value >= nodePrice
        require(_in >= nodePrice, "BRT: Not enough ballance to buy card");

        // 2. Not first buy
        if (!isOriginNode) {
            address nodeOwner = nodeItem.o;
            uint256 lastPrice = nodePrice.div(110).mul(100);
            uint256 serviceCharge = nodePrice.sub(lastPrice).div(2);
            payable(nodeOwner).transfer(lastPrice.add(serviceCharge)); // 105%
            // 5% to contract
        }

        // 3. change node owner to buyer and change price to  price*110%
        uint256 nextPrice = nodePrice.mul(110).div(100);
        updateNodePool(_nid, buyer, nextPrice);

        emit onBRTOneNodeBuyed(_nid, buyer, nodePrice, nextPrice);
    }
}
