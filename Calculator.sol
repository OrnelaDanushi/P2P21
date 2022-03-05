pragma solidity 0.8.4;

interface Calculator{
    function getResult() external view returns(uint);
}

contract Test is Calculator{
    
    constructor() public{}
    
    function getResult() override external view returns(uint){
        uint a=1;
        uint b=2;
        uint result= a+b;
        return result;
    }
}

interface A{
    function f1(bool arg1, uint arg2) external returns(uint);
}

contract myC{
    function doYourThing(address AddressOfA) public returns(uint){
        A myA = A(AddressOfA);
        return myA.f1(true, 3);
    }
}



// factory contract that encapsulates an integer counter
// creates a Counter contract on behalf of external entities requiring it
// invokes the functions of the Counter contract of behalf of the owner of the contract
// use modifers in the contract definition
contract Counter{
    uint256 private _count;
    address private _owner;
    address private _factory;
    
    modifier onlyOwner(address caller){
        require(caller == _owner, "You're not the owner of the contract");
        _;
    }
    
    modifier onlyFactory(){
        require(msg.sender == _factory, "You need to use the factory");
        _;
    }
    
    constructor(address owner) public{
        _owner = owner;
        _factory = msg.sender;
    }
    
    // queries the value of the counter
    function getCount() public view returns(uint256){
        return _count;
    }
    
    // increases the counter
    function increment(address caller) public onlyFactory onlyOwner(caller){
        _count++;
    }
}