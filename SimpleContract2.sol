pragma solidity 0.8.4;

contract SimpleContract2{
    address public owner;
    
    uint public state; //256 bit assigned
    event new_value(uint s);

    constructor() public{
        owner = msg.sender;
    }

    function set_state(uint _s) public{
        //if(msg.sender != owner) revert("Sender not the owner); is equal ot the next
        require(msg.sender == owner, "Sender not the owner");
        state = _s;

        emit new_value(state);
    }
    
    
    function get_owner() public view returns(address){
        return owner;
    }
    
    function get_balance() public view returns(uint256){
        return owner.balance;
    }
}