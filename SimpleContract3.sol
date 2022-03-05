pragma solidity 0.8.4;

contract SimpleContract3{
    
    address public owner;
    
    uint public totalSupply;
    mapping(address => uint) public balances;
    event Sent(address from, address to, uint amount);

    constructor(uint _initialSupply) public{
        owner = msg.sender;
        
        //balances[msg.sender] = 1000000;
        
        // to apply the arithmetic over/under flow
        balances[msg.sender] = totalSupply = _initialSupply;
    }

    function mint(address receiver, uint amount) public{
        if(msg.sender != owner) return;
        balances[receiver] += amount;
    }
    
    function send(address receiver, uint amount) public{
        if(balances[msg.sender] < amount) return;
        balances[msg.sender] -= amount;
        balances[receiver] += amount;
        emit Sent(msg.sender, receiver, amount);
    }
    
    // abstracting the notion of executing account must have a balance of at least some 
    // particular amount
    // avoid to mix pre condition logic with state transition logic
    // reuse the same modifier in different contexts
    modifier only_with_at_least(uint x){
        require(balances[msg.sender] >= x);
        _; // it represents the function body
    }
    
    /*
    function transfer(uint amount, address dest) public only_with_at_least(100){
        balances[msg.sender] -= amount;
        balances[dest] += amount;
    }
    */
    
    
    
    // to apply the arithmetic over/under flow
    function transfer(uint amount, address dest) public returns(bool){
        require(balances[msg.sender] - amount >= 0);
        balances[msg.sender] -= balances[msg.sender] - amount; //?
        balances[dest] = balances[msg.sender] + amount;
        return true;
        
        /* an attacker may exploit this vulnerability:
        the attacker has a 0 balance 
        call the transfer function with a non 0 amount and pass the requirement
        an underflow is generated so the resulting value is positive
        his/her balance, that was 0, will be credited a positive number
        
        prevention: do not use solidity arithmetic directly! 
        use SafeMath library always
        */
    }
    function balanceOf(address _owner) public view returns(uint balance){
        return balances[_owner];
    }
    
}


/* find this hash game, vulnerability
A realizes that the solution is "Hello!" and calls
FindThisHash("Hello!") to receive 1000 ether 
B, the attacker, may be clever enough to watch the transaction pool 
looking for anyone submitting a solution 
he/she sees the transaction and validates it 
submits an equivalent transaction with a much higher gas_price 
most likely miners will order B transaction before A's transaction
the attacker will take the 1000 ether 
A who solved the problem will get nothing
*/
contract FindThisHash{
    bytes32 constant public hash = 0xb5b5b97fafd9855eec9b41f74dfb6c38f5951141f9a3ecd7f44d5479b630ee0a;
    constructor() payable{} // load with ether 
    function solve(string memory solution) public{
        // if you can find the preimage of the hash then receive 1000 ether
        require(hash == keccak256(abi.encode(solution)));
        address payable ap = payable(msg.sender);
        ap.transfer(1000 ether);
    }
}


/*
the owner of the phishableContract convince the victim to send some amount of ether 
the victim, unless careful, may not notice that there is code at the attacker's address
*/
contract Phishable{
    address payable public owner;
    constructor(address payable _owner){
        owner = _owner;
    }
    
    fallback() external payable{} // collect ether
    function withdrawAll(address payable _recipient) public{
        
        /* the phishing attack may be performed by exploiting the global variable 
        tx.origin = address of the account that generated the transaction 
        refers to the original external account that started the transaction
        
        msg.sender = refers to the immediate account, external or contract account 
        that invokes the function
        
        do not use tx.origin for authentication!
        */
        require(tx.origin == owner);
        _recipient.transfer(address(this).balance);
        
    }
}

/*
the attacker deploys the AttackContract, convince the owner of the phishableContract
to send the AttackContract some amount of ether 
the fallback function is invoked 
in turn, the withdrawAll of the victim is invoked

the victim receives a call to withdrawAll
the address that first initialised the call was the victim, that is the owner of the 
phishableContract
therefore, tx.origin will be equal to owner and the require of the phishableContract 
will pass 
the victim sends all the funds to the attacker
*/
contract AttackContract{
    Phishable phishableContract;
    address payable attacker; // the attacker's address to receive funds  
    constructor(Phishable _phishableContract, address payable _attackerAddress){
        phishableContract = _phishableContract;
        attacker = _attackerAddress;
    }
    
    fallback() external payable{
        phishableContract.withdrawAll(attacker);
    }
}

/* block.timestamp manipulation attack 
like a simple lottery, one transaction per block can bet 10 ether, for a 
chance to win all the balance of the contract

basic assumptions: 
block.timestamp's last 2 digits are uniformly distributed 
there would be a 1 in 15 chances of winning this lottery 

the attack:
the miners can adjust the timestamp 
choose a timestamp s.t. block.timestamp % 15 is 0 
in doing so they may win both the ether locked in this contract and the block reward

in practice, miners cannot choose arbitrary block timestamps 
they are monotonically increasing 
block times cannot be set too far in the future 
otherwise the block will likely be rejected by the network
*/
contract Roulette{
    uint public pastBlockTime; // forces one bet per block 
    constructor() payable{} // initially fund contract 
    
    // used to make a bet 
    fallback() external payable{
        require(msg.value == 10 ether); // must send 10 ether to play
        require(block.timestamp != pastBlockTime);
        // only 1 transaction per block 
        pastBlockTime = block.timestamp; 
        if(block.timestamp % 15 == 0){ // winner
            address payable ap = payable(msg.sender);
            ap.transfer(address(this).balance);
        }
    }
}