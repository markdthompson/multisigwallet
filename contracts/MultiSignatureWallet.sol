pragma solidity ^0.4.15;

contract MultiSignatureWallet {
    /**
     * events
     * */
     
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revocation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    
    /**
     * fields
     * */
     
    address[] public owners;
    uint public required;
    mapping (address => bool) public isOwner;
    
    uint public transactionCount;
    mapping (uint => Transaction) public transactions;

    struct Transaction {
        bool executed;
        address destination;
        uint value;
        bytes data;
    }
    
    mapping (uint => mapping (address => bool)) public confirmations;
    
    /**
     * methods
     * */
     
    /// @dev Fallback function, which accepts ether when sent to contract
    function() external payable {}
    
    modifier validRequirement(uint ownerCount, uint _required) {
        if ( _required > ownerCount || _required == 0 || ownerCount == 0)
            revert("required number of confirmations must be less than or equal to the number of owners, required confirmations and ownerCount must be greater than 0.");
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) 
        public 
        validRequirement(_owners.length, _required) 
    {
        for (uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;        
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data) public returns (uint transactionId) {
        require(isOwner[msg.sender], "owner must be sender");
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);        
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) 
        public 
    {
        require(isOwner[msg.sender], "owner must be sender");
        require(transactions[transactionId].destination != 0, "destination must not be 0");
        require(confirmations[transactionId][msg.sender] == false, "confirmation must not already exist");
        
        confirmations[transactionId][msg.sender] = true;
        
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) 
        public {
        require(isOwner[msg.sender], "owner must be sender");
        require(transactions[transactionId].destination != 0, "destination must not be 0");
        require(confirmations[transactionId][msg.sender] == true, "confirmation must already exist");
        require(transactions[transactionId].executed == false, "transaction can't already have executed");
        
        confirmations[transactionId][msg.sender] = false;
        
        emit Revocation(msg.sender, transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) 
        public {
        require(transactions[transactionId].executed == false, "transaction can't already have executed");
        
        if (isConfirmed(transactionId)) {
            Transaction storage trx = transactions[transactionId];
            trx.executed = true;
            if (trx.destination.call.value(trx.value)(trx.data))
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                trx.executed = false;
            }
        }
        
    }

	/*
	* (Possible) Helper Functions
	*/
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) 
        public 
        view 
        returns (bool)
    {
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]])
                count += 1;
            if (count == required)
                return true;
        }
    }

    
    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes memory data) 
        internal 
        returns (uint transactionId) 
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);        
    }
}