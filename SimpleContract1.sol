/* a contract oriented high level language for the EVM
static type system, syntax very similar to javascript
is a deterministic language: all the validators/miners must return 
the same result, cannot use a built in source of entropy
to generate random numbers
*/

/* the pragma directive
is the first line of code, it specifies the compiler version
very useful for languages in high evolution like solidity

if used ^ before the number it defines a range of versions, last version is the 0.8.4 
future versions might introduce incompatible changes
if not used ^ means all the versions newer than the one referred are ok 
more complex expressions can be specified to define versions ranges
*/
pragma solidity 0.8.4;

contract SimpleContract1{   // similar to a Java class
    /* various data types 
    
    of length
    fixed as bool, (u)int, bytes32 address
    variable as bytes, string
    
    array, 
    fixed or dynamic length, can be iterated over
    removing an element requires 
    either to leave a blank hole, replace it with last element but breaks ordering
    or shift elements but is expensive    
    
    mapping(key_type => value_type),
    support random access, it is not possible to iterate over the keys
    unless you keep a separate list of all the keys with significant value
    like hash tables, provide lookups and writes, i.e. keccak256 of key_type
    when the map is declared (before having actually written anything to it)
    all possible addresses exist, every key implicitly bound to all 0 value, 
    binding is always defined
    
    integer types: int(signed), uint(unsigned)
    keywords: uint8 = int8 t- uint256 = int256 in step of 8
    various size to minimize gas consumption and storage space
    uint = unsigned integer of 8 bits, non negative numbers 
    i.e. uint8 x=0; uint8 y=x-1; // y=255
    subtracting 1 from x results in an underflow, wraps around and gives as result 255
    how can be this exploited by an attacker?

    operations as usual: comparison, arithmetic, bitwise, shift
    division always results in an integer and rounds towards 0 (i.e. 5/2=2)
    fixed point number not yet fully supported

    all non assigned values are false for bool, 0 for uint ...
    a default value is defined for each type

    structs, similar to those of C, 
    define a complex data type that has other data types as members
    any data type can appear in a struct and nesting structs is permitted
    declaring a struct creates a constructor that can be used to instantiate 
    instances of that struct
    struct members are accessed with the . notation

    data location
    - memory, local available to every function within a contract,
    temporary variables, like the RAM, cleared after the function execution,
    cheap and should be used whenever possible
    - storage, variables are stored permanently on the blockchain, like the hard disk
    stored in the state tree (Patricia Merkle trie) of the block
    expensive and should be used only when necessary
    */

    /* declarations
    any entity/account has associated 
    - an address, if payable means that it receives ether from this contract
    represents the public address of an EOA or of a SmartContract
    20 byte value represented in hexadecimal prefixed with 0x
    i.e.
    address myAddress = 0xE0f5..       assign a fixed value
    address sender = msg.sender        assign address of the issuer of the transaction/message
    address emptyAddress = address(0)  sets the address to 0x0 
    address current = address(this)    assign the contract current address
    it has several properties which can be queried as
    address.balance
    address.code    is the code at that address (may be empty)
    address payable is an address you can send ether to
    
    3 ways to send ether
    - address.transfer(value), transfer ether units in wei, throws an error if transfer fails,
    or other exceptions occur, like out of gas, is the most secure one
    - address.send(value), returns false if some failure happens, less secure since it gives
    responsability to the users to manage the failure
    both of them trigger the receiving contract's fallback function
    the called function is only given a limited amount of 2300 gas
    to avoid improper use of these functions which have been the first source 
    of solidity bugs as the DAO attack to Ethereum
    - address.call.value(value)()
    
    - a balance in ether, or wei,  >= 0
    uint current = address(this).balance; the current balance of the contract
    if the contract has balance >0 then it can send ether as well
    */
    
    // a state (attributes/variables)
    uint public public_state; 
    uint private private_state; 


    /* events
    are declared in the same way a function is
    the sintax is simlar to the struct
    can be fired with the emit keyword
    are placed in the transaction log, useful for client apps
    event logs are registered on the blockchain
    any javascript app in the frontend can listen for events as callbacks
    events can be indexed: search for specific events in the log
    */
    event sent(uint amount);


    /* a list of functions (methods), function is like a method
    the compose the code, have labels that declare how they interact with the state
    
    - view = only reads the state, do not modify the state
    
    - pure = does not read or modify/write the state, 
    only uses the parameters of the function
    
    - otherwise, it writes (and reads) the state
    the state modification will be placed in a transaction
    it will be written on the blockchain
    therefore, it costs a fee to the user
    the fee is proportional to the required amoun of computation 
    (EVM opcodes, each has a cost named gas)
    before each transaction an user can set in their wallet
    - the gas_price = how much ether he will pay for each unit of gas
    - the gas_limit = how many units of gas he will consume for that transaction
    
    - payable, if it expects to receive ether
    one received the ether the contract's balance is automatically increased,
    unless the transaction does not revert
    msg.value stores the received ether in uint
    - if it receives plain ether, i.e. a transaction to the contract 
    does not invoke a function then trigger the receive function (>= solidity 0.6.*)
    - if a transaction invokes a function that does not match any of the functions 
    exposed by the contract, or as before but receive is not implemented
    then trigger the fallback function
    - as before, but neither receive nor fallback are implemented then throws exception
    to execute, it requires a payment in the transaction
    the amount sent is taken from the msg.value field in units of wei 
    cryptocurrency sent is stored in the contract's account 
    if wei are sent to a not payable function, the transaction is rejected
    
    receive(), fallback() .. have in their body at most 2300 units of gas of 
    available computation called by 
    - address.send(amount) to send amount to address, returns True if everything goes well, otherwise false 
    - address.transfer(amount) to throw exception if it fails
    a fixed gas_limit prevents the receiver to execute too much code sinche it may consume
    too much gas to the original transaction sender or the receiver can execute malicious code,
    attempting an attack, i.e. the reentrancy attack
    however, with future updates to the gas associated to opcodes, i.e. Istanbul fork, may break
    contracts already deployed working with limits of 2300 units of gas

    there are also solutions with customizable gas_limit
    address.call{options}(data bytes) return True or false
    i.e. (bool result, ) = address.call{gas:123123, value:msg.value}("");

    fallback() is a unnamed function, at most one for each contract, no arguments, no returned value
    acts as a default function to be executed when 
    no other functions match the function referred in the call 
    if marked payable, when a transaction payment is sent to the contract, without an explicit
    function call by the sender
    useful for contracts with a single type of payment
    when an user sends money to the contract, the fallback function is invoked
    
    from solidity 0.6 is defined also
    receive() public payable{} to receive ethers

    */
    constructor(uint _public, uint _private) public{
        public_state = _public;
        private_state = _private +1;
    }

    function forward(address payable _receiver) public payable{
        _receiver.transfer(msg.value);
        emit sent(msg.value);
    }

    function get_private_state() public view returns(uint){
        return private_state;
    }
 
    /* states and functions 
    
    can have different visibilities
    - private, is exposed (can be called) only to the contract itself, 
    accessible only from the contract where they are defined, and not by derived contracts
    - public, is exposed to other contracts, internally and from externally owned accounts
    no restrictions
    a public state is a shortcut that creates a getter function with 
    the name of the variable
    - internal, is exposed to child constract (inheriting from it) and the current contract itself
    - external, (only functions), is exposed only to other contracts,
    triggered only by a transaction or by external contract message
    they are more efficient with large inputs
    i.e. foo() does not work, this.foo() does
    
    the terms internal and private are somewhat misleading
    any function or data inside a contract is always visible on the public blockchain
    anyone can see the code or data 
    the keywords only affect how and when a function can be called 
    
    why both public and external?
    external are sometimes more efficientwhen they receive large arrays of data
    
    global variables and functions, which are predefined
    they provide information on the transaction that has invoked a function
    the access to them is possible even if are not declared within contracts
    - ether units as wei, gwei, szabo ..
    - time units as seconds, minuts ..
    - functions as keccak256, abi.encode, abi.decode ..
    - transaction data as msg with
    msg.sender = the transaction sender address
    msg.value = the transaction associated ether in uint
    msg.gas = unused gas after the execution of the transaction
    msg.data = complete call data (bytes)
    the transaction is like an envelope
    contents of the letter are function parameters
    adding a value to the transaction is like putting cash inside the envelope
    
    contracts cannot access the ledger directly, it is maintained by miners only
    however are provided some information about the current transaction 
    and block to contracts so that they can use them
    - block related variables 
    block.timestamp, is the timestamp of the current block where the transaction is inserted,
    returns a UNIX timestamp: seconds after the epoch, makes it easy i.e. to create delayed actions
    used for randomness, escrowing funds, time dependent state changes
    do not use them for entropy since it is dangerous to generate random numbers 
    avoid time sensitive decisions based on small timestamp differences, enforcing expire dates 
    for time sensitive logic use something like (block.number x avg(block.time))
    10 seconds block time, 1 week corresponds to 60480 blocks
    block.number, is the current block number
    block.gaslimit 
    block.difficulty
    block.coinbase
    - transaction related variables
    tx.gasprice = the gas price caller is ready to pay for each gas unit 
    tx.origin = the first caller of the transaction
    
    the contract abi Application Binary Interface functions is the standard
    contract-to-contract communication in Ethereum
    to encode and decode functions, parameters .. known data, in bytes, to
    - call a function of an external contract, pass input arguments, ..
    
    calling contract functions, how to call a function of another SmartContract?
    if you have the source code then you can import it on your solidity file
    therefore, you have visibility of the contract's type and functions, and 
    the compiler understands them
    if you do not have the source code then you can use a low level call to 
    a function of a SmartContract with the function's selector as input
    the selector are the firt 4 bytes of the hash of the function signature
    i.e. functionName(param1, param2, ..)
    

    contract inheritance between SmartContracts
    both single and multiple
    multiple contracts are related by a parent_child relationship
    internal variables and functions are available to derived contract, 
    according to the visibility rule

    for a contract to interact with another one on the blockchain 
    import the contract code OR use an abstract contract/interface 
    an interface is like a contract skeleton, simalr to Java interfaces
    only functions declaration, no body and do not define the function bodies
    take the interface of another contract to know the functions that can be invoked 
    to invoke the functions: get an intance of the contract implementing the 
    interface by passing the address of the instance


    a factory contract 
    

    
    require, is for testing conditions on function arguments or transaction fields
    throws an error and stops execution if some condition is not true 
    reverts all the changes made, consumes the gas up to the point of failure
    refunds the remaining gas
    */
    
}