/*
run a lottery on the blockchain, no anchoring it in any single legal jurisdiction
problem: how to obtain a source of entropy in a deterministic environment?
sol: 
- an external oracle, add complexity and external dependencies
- data taken from the blockchain, the blockchash as a source of randomness,
be aware that miners can perform an attack, cheat and influence a value,
i.e. may change the timestamp of the block
- more complex, RanDAO, VRF
*/

pragma solidity 0.8.4;

contract SimpleLottery{
    uint public constant TICKET_PRICE = 1e15; //1 finney 
    address[] public tickets;
    address payable public winner;
    uint public ticketingCloses;

    // setting delayed actions in the initializator
    constructor(uint duration) public{
        
        // how long does the lottery goes on?
        ticketingCloses = block.timestamp + duration;
        
        // during this period, people can buy tickets, afterwards stop selling tickets
    }

    // checks that the price is ok and that the lottery has not been stopped
    // if both conditions are true then
    // the address of the sender is stored in the tickets array 
    // the balance of the contract is automatically increased by price of the sold 
    // ticket (implicit, is not seen in the code)
    function buy() public payable{
        require(msg.value == TICKET_PRICE);
        require(block.timestamp < ticketingCloses);

        // an user sends finneys to the contract without calling any function
        tickets.push(msg.sender);
    }
    
    function draw_winner() public{
        
        // set a time delay between the stopping of the ticket purchase period 
        // and the drawing of the winner
        // why a delay? the blockhash must be unguessable for the user when 
        // he/she buys a ticket, this guarantees that no one can know the 
        // blockchash, while buying a ticket, avoid attacks
        // it ensure also that the winner has not already been drawn, 
        // when invoked
        
        require(block.timestamp > ticketingCloses + 5 minutes);
        
        // the same as 0x0, an uninitialized address
        require(winner == address(0));
        
        // a limited source of entropy:
        // take the hash of the previous block and then apply the keccak256 function
        
        // gives the hash of a given block number, it only works for the 256 most recent blocks
        bytes32 bhash = blockhash(block.number -1);

        bytes memory bytesArray = new bytes(32);
        for(uint i; i<32; i++)
            bytesArray[i] = bhash[i];
        bytes32 rand = keccak256(bytesArray);
        winner = payable(tickets[uint(rand)% tickets.length]);
        
    }
    
    function withdraw() public{
        require(msg.sender == winner);
        winner.transfer(address(this).balance);
    }
    
    // activated when it invokes the function buy()
    fallback () payable external{
        buy();
    }
}