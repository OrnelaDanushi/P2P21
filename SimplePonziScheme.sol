/* 
take investments from investors, give back the return to the early investors
with the money received from new investors
needs a constant flux of new investors
the crash, eventually there are not enough funds from 
new investors to support the scheme, causing it to crash

some famous PonziSchemes: CharlesPonzi, BernieMadoff in 2008

a simplified PonziScheme is the first, naive solidity program
for each new investment, take the money and send it to the previous investor
each investment must be larger than the previous one: check if this is true
otherwise discard the investment
each investor, except the last one, will get a return on their investment
*/

pragma solidity 0.8.4;

contract SimplePonziScheme{
    // is the address of the most recent investor
    // the only one that has not yet received a return on the investment
    // the sucker which will lose his/her investment if no other one
    // will make an investment
    address payable currentInvestor;

    // amount of the investment that will be lost by the last investor 
    // if there will be no further investments
    uint public currentInvestment = 0; 

    bool notFirst;
    
    
    function investment() public payable{
        // new investments must be 10 % > current 
        // to guarantee a juicy return to the investors, otherwise it will be rejected
        // no decimals admitted so need to multiply by 11 and then divide by 10
        uint minimumInvestment = currentInvestment * 11/10;
        
        // for test conditions
        require(msg.value > minimumInvestment);

        // onboarding the new sucker
        // keep a reference to the previousInvestor so to pay out 
        // him/her with the new next investment
        address payable previousInvestor = currentInvestor;
        currentInvestor = msg.sender;
        currentInvestment = msg.value;
        
        // payout previous investor
        if(notFirst)
            previousInvestor.transfer(msg.value);
            notFirst = true;
    }
    
    // a single transfer of money, for the investment
    fallback () payable external{
        investment();
    }
}