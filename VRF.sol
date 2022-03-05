pragma solidity 0.8.4;

import "vrf-solidity/contracts/VRF.sol";

contract MyContract is VRF{
    

    function functionUsingVRF(
            uint256[2] memory _pk, 
            uint256[4] memory _proof,
            bytes memory _message) 
        public returns(bool){

        bool isValid = verify(_pk, _proof, _message);
        
        // do something ..
        return isValid;
    }
    
}