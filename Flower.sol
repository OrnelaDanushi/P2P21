pragma solidity 0.8.4;

contract Flower{
    
    address owner;
    string flowerType;
    
    constructor(string memory newFlowerType) public{
        owner = msg.sender;
        flowerType = newFlowerType;
    }
    
    function water() public pure returns(string memory){
        return "Oh, thank, I love";
    }
}

contract Rose is Flower("Rose"){
    function pick() public pure returns(string memory){
        return "ouch";
    }
}


contract Jasmine is Flower("Jasmine"){
    function smell() public pure returns(string memory){
        return "Mmmm, smells good!";
    }
}
