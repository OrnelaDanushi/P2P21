/*
new investments are distributed evenly between all previous investors
after the distribution is complete, the newest investor is added to the list of investors
avoid adding the complexity of tracking investor shares
but, no incentive to send more than the minimum payment

as the number of investors in the PonziScheme increases, 
the return for an investor from each new investment decreases

added a minimum investment, prevent freeloaders from sending a 0 value transaction
to become an investor 
the creator gets the privilege of joining the Ponzi without having to send any ether

1 wei = 1
1 szabo = 1e12 
1 finney = 1e15
1 ether = 1e18
*/

pragma solidity 0.8.4;

contract RealisticPonziScheme{
    
    // dynamically sized array
    // push to append a new element to the last position of the array, length property
    address[] public investors;
    
    mappping(address => uint) public balances;
    uint public constant MINIMUM_INVESTMENT = 1e15;

    constructor() public{
        investors.push(msg.sender);
    }

    function investment() public payable{
        require(msg.value > MINIMUM_INVESTMENT);
        
        uint eachInvestorGets = msg.value / investors.length;
        for(uint i=0; i<investors.length; i++)
            balances[investors[i]] += eachInvestorGets;
        investors.push(msg.sender);
    }
    
    function withdraw() public{
        uint payout = balances[msg.sender];
        balances[msg.sender] = 0;
        msg.sender.transfer(payout);
    }
    
    fallback () payable external{
        investment();
    }
}