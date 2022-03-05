/*
an early Bitcoin gambling service, blockchain based betting game, operating since 2012
how to play?
send a transaction to one of the address operated by the service, each address has a different payout
the service determines if the wager wins or loses then sends a transaction in response with 
the payout to a winning bet, a tiny fraction of the house's gain to a losing bet 
responsible for half the transactions on the Bitcoin network, in the first period 
many alternate implementations exist today

implementations
submit a transaction with a number from 0 to 65535 (2^16=65536) as an amount of ether 
the game generates a random number in the same range using a secret seed 
if the generated number is below the submitted number then the user wins mony 
the amount of money won is dependent on the submitted number 
the lower the number, the higher the multiplier and payout (32000=circa 2x, 16000=circa 4x)
in the real implementations, periodically publish the hash of the old seeds 
together the betting addresses to provide auditability
*/

pragma solidity 0.8.4;

contract SatoshiDice{
    
    struct Bet{
        address user; 
        uint block; 
        uint cap;
        uint amount;
    }

    uint public constant FEE_NUMERATOR = 1; 
    uint public constant FEE_DENOMINATOR = 100; 
    uint public constant MAXIMUM_NUM = 100000; 
    uint public constant MAXIMUM_BET_SIZE = 1e18; 

    address payable owner;
    address payable temp;

    uint public counter;

    mapping(uint => Bet) public bets;
    
    // for wager placed
    event BetPlaced(uint id, address user, uint cap, uint amount);
    
    // for wager resolved
    event Roll(uint id, uint rolled);

    constructor() public{
        owner = payable(msg.sender);
    }
    
    
    // accpeting wagers
    function wager(uint cap) public payable{
        require(cap <= MAXIMUM_NUM);
        require(msg.value <= MAXIMUM_BET_SIZE);
        
        // generate a new ID (counter) for this bet
        counter++;

        // the gambler can read the ID paired with his/her bet querying the blockchains
        // can later use the ID in the request to roll function
        bets[counter] = Bet(msg.sender, block.number + 3, cap, msg.value); 

        // the ID is registered as an event on the blockchain
        emit BetPlaced(counter, msg.sender, cap, msg.value);
        
        // locks the block number for the generation of random numbers 
        // set a time forward of 3 blocks in the future, user 
        // must wait 3 blocks after wagering and cannot guess 
        // the hashblock of 3 blocks in the future
    }
    
    // it simulates the dice roll
    function roll(uint id) public{
        Bet storage bet = bets[id];
        
        require(msg.sender == bet.user);
        require(block.number >= bet.block + 3);
        
        // the user must trigger the roll within 255 blocks of the bet block 
        // otherwise stop and throw an error
        // solidity stores only the 256 most recent blockhashes, 
        // waiting longer will lead to blockchash of 0x0
        require(block.number <= bet.block + 255);

        // X = block.blockhash(bet.block||id)
        // this is a high level concatenation, not actual code
        
        bytes32 random = keccak256(X);
        
        uint rolled = uint(random) % MAXIMUM_NUM;
        if(rolled < bet.num){
            uint payout = bet.amount * MAXIMUM_NUM / bet.num; 
            uint fee = payout * FEE_NUMERATOR / FEE_DENOMINATOR;
            payout -= fee; 
            temp = payable(msg.sender);
            temp.transfer(payout);
        }
        emit Roll(id, rolled);
        delete bets[id];
    }
    
    // before starting fee gathering, the contract has to be founded 
    // an initial amount collected by function fund() to allow starting bets payoit
    fallback () payable external{}

    function kill() public{
        require(msg.sender == owner);
        
        // takes as input the recipient address
        // destroys the contract
        // remaining balance, sent to the address passed as arguments
        selfdestruct(owner);
    }
    

}