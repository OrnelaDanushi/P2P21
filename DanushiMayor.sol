// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract Mayor {

    using SafeMath for uint32;
    using SafeMath for uint;
    

    // Structs, events, and modifiers
    
    // Store refund data
    struct Refund {
        uint soul;
        bool doblon;
        bool isValid;  // new field to understand if the struct is not empty
    }
    
    // Data to manage the confirmation
    struct Conditions {
        uint32 quorum;
        uint32 envelopes_casted;
        uint32 envelopes_opened;
    }
    
    event NewMayor(address _candidate);
    event Sayonara(address _escrow);
    event EnvelopeCast(address _voter);
    event EnvelopeOpen(address _voter, uint _soul, bool _doblon);
    

    // Someone can vote as long as the quorum is not reached
    modifier canVote() {
        require(voting_condition.envelopes_casted < voting_condition.quorum, "Cannot vote now, voting quorum has been reached");
        _;   
    }
    
    // Envelopes can be opened only after receiving the quorum
    modifier canOpen() {
        require(voting_condition.envelopes_casted == voting_condition.quorum, "Cannot open an envelope, voting quorum not reached yet");
        _;
    }
    
    // The outcome of the confirmation can be computed as soon as all the casted envelopes have been opened
    modifier canCheckOutcome() {
        require(voting_condition.envelopes_opened == voting_condition.quorum, "Cannot check the winner, need to open all the sent envelopes");
        _;
    }
    
    // State attributes
    
    // Initialization variables
    address payable public candidate;
    address payable public escrow;
    
    // Voting phase variables
    mapping(address => bytes32) envelopes;

    Conditions voting_condition;

    uint public naySoul;
    uint public yaySoul;

    // Refund phase variables
    mapping(address => Refund) souls;
    address[] voters;

    /// @notice The constructor only initializes internal variables
    /// @param _candidate (address) The address of the mayor candidate
    /// @param _escrow (address) The address of the escrow account
    /// @param _quorum (address) The number of voters required to finalize the confirmation
    constructor(address payable _candidate, address payable _escrow, uint32 _quorum) public payable{ //added payable construct
        candidate = _candidate;
        escrow = _escrow;
        voting_condition = Conditions({quorum: _quorum, envelopes_casted: 0, envelopes_opened: 0});
    }


    /// @notice Store a received voting envelope
    /// @param _envelope The envelope represented as the keccak256 hash of (sigil, doblon, soul) 
    function cast_envelope(bytes32 _envelope) canVote public {
        
        if(envelopes[msg.sender] == 0x0) // => NEW, update on 17/05/2021
            //voting_condition.envelopes_casted++;
            voting_condition.envelopes_casted = uint32(voting_condition.envelopes_casted.add(1));

        envelopes[msg.sender] = _envelope;
        emit EnvelopeCast(msg.sender);
    }
    
    
    
    // to receive ethers
    receive() external payable{ //fallback() payable external{
        //souls[msg.sender].soul += msg.value;
        souls[msg.sender].soul = uint(souls[msg.sender].soul.add(msg.value));
        
        souls[msg.sender].isValid = true;
    } 

    
    /// @notice Open an envelope and store the vote information
    /// @param _sigil (uint) The secret sigil of a voter
    /// @param _doblon (bool) The voting preference
    /// @dev The soul is sent as crypto
    /// @dev Need to recompute the hash to validate the envelope previously casted
    function open_envelope(uint _sigil, bool _doblon) canOpen public payable {
        
        // TODO Complete this function

            // emit EnvelopeOpen() event at the end

        require(envelopes[msg.sender] != 0x0, "The sender has not casted any votes");
        bytes32 _casted_envelope = envelopes[msg.sender];
        bytes32 _sent_envelope = 0x0;
        // ...

        /* since the debugging during the deploy fails because none is sending really ethers
        I manually put the check varaiables to act in such a way that the ethers are received
        _casted_envelope=_sent_envelope;
        souls[msg.sender].isValid=true;
        souls[msg.sender].doblon=_doblon;
        souls[msg.sender].soul=1;
        */
        
        require(_casted_envelope == _sent_envelope, "Sent envelope does not correspond to the one casted");
        require(souls[msg.sender].isValid == true, "Not correctly voted");
        require(souls[msg.sender].doblon == _doblon, "The search is done not for the correct voting preference");


        //_casted_envelope=0x525876128d9eb0ad1b9e0d64c9c51b1cd33790861c401ad2e3df0f670ce6a2a4;
       
        bytes32 result = compute_envelope(_sigil, _doblon, souls[msg.sender].soul);
        require(result == _casted_envelope, "You have not provided the correct sigil");
        
        if(_doblon == true){
            //yaySoul++;
            yaySoul = uint(yaySoul.add(1));
        }
        else{
            //naySoul++;
            naySoul = uint(naySoul.add(1));
        }
        
        //voting_condition.envelopes_opened++;
        voting_condition.envelopes_opened = uint32(voting_condition.envelopes_opened.add(1));

        voters.push(msg.sender);
        
        emit EnvelopeOpen(msg.sender, souls[msg.sender].soul, _doblon);


    }
    
    
    /// @notice Either confirm or kick out the candidate. Refund the electors who voted for the losing outcome
    function mayor_or_sayonara() canCheckOutcome public {

        // TODO Complete this function
            
            // emit the NewMayor() event if the candidate is confirmed as mayor
            // emit the Sayonara() event if the candidate is NOT confirmed as mayor        
        

        if(yaySoul > naySoul){  

            uint posSoul; // pay candidate with yay 
            bool success;

            // refund voters who expressed nay
            for(uint i; i<voters.length; i++){
                Refund memory rf = souls[voters[i]];
                require(rf.isValid == true, "Something strange is stored in souls");
                if(rf.doblon == false && rf.soul > 0){
                    
                    //payable(voters[i]).transfer(rf.soul);
                    (success, ) = payable(voters[i]).call{value: rf.soul}("");
                    require(success, "Failed to transfer the funds, aborting.");
                    
                    // the balance is zeroed after ether transfer for rentrance issues
                    rf.soul = 0;
                    souls[voters[i]].soul = 0;
                }
                else{
                    //posSoul += rf.soul;
                    posSoul = uint(posSoul.add(rf.soul));
                }
            }
            
            //candidate.transfer(posSoul);
            (success, ) = candidate.call{value: posSoul}("");
            require(success, "Failed to transfer the funds, aborting.");
            
            posSoul = 0;
            
            emit NewMayor(candidate);
        }
        else{
            uint negSoul; // pay escrow with nay 
            bool success;

            // refund voters who expressed yay
            for(uint i; i<voters.length; i++){
                Refund memory rf = souls[voters[i]];
                require(rf.isValid == true, "Something strange is stored in souls");
                if(rf.doblon == true && rf.soul > 0){
                    
                    //payable(voters[i]).transfer(rf.soul);
                    (success, ) = payable(voters[i]).call{value: rf.soul}("");
                    require(success, "Failed to transfer the funds, aborting.");
                    
                    rf.soul = 0;
                    souls[voters[i]].soul = 0;
                }
                else{
                    //negSoul += rf.soul;  
                    negSoul = uint(negSoul.add(rf.soul));
                }
            }
            
            //escrow.transfer(negSoul);
            (success, ) = escrow.call{value: negSoul}("");
            require(success, "Failed to transfer the funds, aborting.");
            
            negSoul = 0;

            emit Sayonara(escrow);
        }

    }
 
 
    /// @notice Compute a voting envelope
    /// @param _sigil (uint) The secret sigil of a voter
    /// @param _doblon (bool) The voting preference
    /// @param _soul (uint) The soul associated to the vote
    function compute_envelope(uint _sigil, bool _doblon, uint _soul) public pure returns(bytes32) {
        return keccak256(abi.encode(_sigil, _doblon, _soul));
    }
    
}