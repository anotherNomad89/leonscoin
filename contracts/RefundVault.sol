pragma solidity ^0.4.18;

import "./SafeMath.sol";

/**
 * @title Controlled
 * @dev Restricts execution of modified functions to the contract controller alone
 */
contract Controlled {
    address public controller;

    function Controlled() public {
        controller = msg.sender;
    }

    modifier onlyController {
        require(msg.sender == controller);
        _;
    }

    function transferControl(address newController) public onlyController{
        controller = newController;
    }
}

/**
 * @title RefundVault
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the money if crowdsale fails,
 * and forwarding it if crowdsale is successful.
 */
contract RefundVault is Controlled {
    using SafeMath for uint256;
    
    enum State { Active, Refunding, Closed }
    
    mapping (address => uint256) public deposited;
    address public wallet;
    State public state;
    
    event Closed();
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);
    
    function RefundVault(address _wallet) public {
        require(_wallet != address(0));
        wallet = _wallet;        
        state = State.Active;
    }

	function () external payable {
	    revert();
	}
    
    function deposit(address investor) onlyController public payable {
        require(state == State.Active);
        deposited[investor] = deposited[investor].add(msg.value);
    }
    
    function close() onlyController public {
        require(state == State.Active);
        state = State.Closed;
        Closed();
        wallet.transfer(this.balance);
    }
    
    function enableRefunds() onlyController public {
        require(state == State.Active);
        state = State.Refunding;
        RefundsEnabled();
    }
    
    function refund(address investor) public {
        require(state == State.Refunding);
        uint256 depositedValue = deposited[investor];
        deposited[investor] = 0;
        investor.transfer(depositedValue);
        Refunded(investor, depositedValue);
    }
}