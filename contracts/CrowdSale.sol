pragma solidity ^0.4.18;

import "./Moderated.sol";
import "./SafeMath.sol";
import "./RefundVault.sol";

contract CrowdSale is Moderated {
	using SafeMath for uint256;
	
	// LEON ERC20 smart contract
	Token public tokenContract;
	
    // crowdsale starts 1 March 2018, 00h00 PDT
    uint256 public constant startDate = 1519891200;
    // crowdsale ends 31 December 2018, 23h59 PDT
    uint256 public constant endDate = 1546243140;
    
    // crowdsale aims to sell at least 100 000 LEONS
    uint256 public constant crowdsaleTarget = 100000 * 10**18;
    uint256 public constant margin = 1000 * 10**18;
    // running total of tokens sold
    uint256 public tokensSold;
    
    // ethereum to US Dollar exchange rate
    uint256 public etherToUSDRate;
    
    // address to receive accumulated ether given a successful crowdsale
	address public constant etherVault = 0xD8d97E3B5dB13891e082F00ED3fe9A0BC6B7eA01;    
	// vault contract escrows ether and facilitates refunds given unsuccesful crowdsale
	RefundVault public refundVault;
    
    // minimum of 0.005 ether to participate in crowdsale
	uint256 constant purchaseThreshold = 5 finney;

    // boolean to indicate crowdsale finalized state	
	bool public isFinalized = false;
	
	bool public active = false;
	
	// finalization event
	event Finalized();
	
	// purchase event
	event Purchased(address indexed purchaser, uint256 indexed tokens);
    
    // checks that crowd sale is live	
    modifier onlyWhileActive {
        require(now >= startDate && now <= endDate && active);
        _;
    }	
	
    function CrowdSale(address _tokenAddr, uint256 price) public {
        // the LEON token contract
        tokenContract = Token(_tokenAddr);
        // initiate new refund vault to escrow ether from purchasers
        refundVault = new RefundVault(etherVault);
        
        etherToUSDRate = price;
    }	
	function setRate(uint256 _rate) public onlyModerator returns (bool) {
	    etherToUSDRate = _rate;
	}
	// fallback function invokes buyTokens method
	function() external payable {
	    buyTokens(msg.sender);
	}
	
	// forwards ether received to refund vault and generates tokens for purchaser
	function buyTokens(address _purchaser) public payable ifUnrestricted onlyWhileActive returns (bool) {
	    require(!targetReached());
	    require(msg.value > purchaseThreshold);
	    refundVault.deposit.value(msg.value)(_purchaser);
	    // 1 LEON is priced at 1 USD
	    // etherToUSDRate is stored in cents, /100 to get USD quantity
	    // crowdsale offers 100% bonus, purchaser receives (tokens before bonus) * 2
	    // tokens = (ether * etherToUSDRate in cents) * 2 / 100
		uint256 _tokens = (msg.value).mul(etherToUSDRate).div(50);		
		require(tokenContract.transferFrom(moderator,_purchaser, _tokens));
        tokensSold = tokensSold.add(_tokens);
        Purchased(_purchaser, _tokens);
        return true;
	}	
	
	function initialize() public onlyModerator returns (bool) {
	    require(!active && !isFinalized);
	    require(tokenContract.allowance(moderator,address(this)) == crowdsaleTarget + margin);
	    active = true;
	}
	
	// activates end of crowdsale state
    function finalize() public onlyModerator {
        // cannot have been invoked before
        require(!isFinalized);
        // can only be invoked after end date or if target has been reached
        require(hasEnded() || targetReached());
        
        // if crowdsale has been successful
        if(targetReached()) {
            // close refund vault and forward ether to etherVault
            refundVault.close();

        // if the sale was unsuccessful    
        } else {
            // activate refund vault
            refundVault.enableRefunds();
        }
        // emit Finalized event
        Finalized();
        // set isFinalized boolean to true
        isFinalized = true;
        
        active = false;

    }
    
	// checks if end date of crowdsale is passed    
    function hasEnded() internal view returns (bool) {
        return (now > endDate);
    }
    
    // checks if crowdsale target is reached
    function targetReached() internal view returns (bool) {
        return (tokensSold >= crowdsaleTarget);
    }
    
    // refunds ether to investors if crowdsale is unsuccessful 
    function claimRefund() public {
        // can only be invoked after sale is finalized
        require(isFinalized);
        // can only be invoked if sale target was not reached
        require(!targetReached());
        // if msg.sender invested ether during crowdsale - refund them of their contribution
        refundVault.refund(msg.sender);
    }
}	