pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 public constant Airline_REGISTRATION_FEE = 10 ether;
    uint256 public constant Passenger_MAX_INSURANCE_FEE = 1 ether;

    address private contractOwner;          // Account used to deploy contract
    bool private operational = true;        // Blocks all state changes throughout the contract if false


    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    FlightSuretyProxy flightSuretyData;

    mapping (address => address[]) private airlineVotes;



 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address _flightSuretyData ) public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyProxy(_flightSuretyData);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool) {
        return operational;  // Modify to call data contract's status
    }
    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus ( bool mode ) external requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline (address _airline) external requireIsOperational returns(bool success, uint256 votes) 
    {
        require(!flightSuretyData.isRegisteredAirline(_airline), 'the airline has been already registered');
        require(flightSuretyData.isRegisteredAirline(msg.sender), 'caller must be a registered airline');
        require(flightSuretyData.isFundedAirline(msg.sender), 'caller must be a funded airline');

        bool isDuplicate = false;
        for(uint c = 0; c < airlineVotes[_airline].length; c++) {
            if (airlineVotes[_airline][c] == msg.sender) {
                isDuplicate = true;
                break;
            }
        }
        
        
        require(!isDuplicate, "Airline already voted on this member");

        airlineVotes[_airline].push(msg.sender);

        uint totAirlines = flightSuretyData.totAirlines();
        votes = airlineVotes[_airline].length;
        if (( totAirlines<= 3) || ( votes >=  (totAirlines/2))) {
            flightSuretyData.registerAirline(_airline);
            delete airlineVotes[_airline];
            return (true,votes);
        }
        else {
            return (false,0);
        }        



    }

    function fund() public payable{
        require(msg.value >= Airline_REGISTRATION_FEE, "Airline didn't send enough money");
        flightSuretyData.fund(msg.sender);
        //send fund to DATA contract
        address(flightSuretyData).transfer(msg.value);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(bytes32 flightnumber, uint256 timestamp) public requireIsOperational {
        flightSuretyData.registerFlight(flightnumber, timestamp, msg.sender);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function buy(bytes32 _flightnumber) public payable requireIsOperational {
        require( msg.value > 0 && msg.value <= Passenger_MAX_INSURANCE_FEE , "Sent invalid amount for insurance");

        flightSuretyData.buy(_flightnumber, msg.sender, msg.value);
        //send fund to DATA contract
        address(flightSuretyData).transfer(msg.value);
    }


    function creditInsurees(bytes32 _flightnumber) public requireIsOperational {
        flightSuretyData.creditInsurees(_flightnumber);
    }

    function pay ()  public  requireIsOperational{
        flightSuretyData.pay(msg.sender);
    }
    function withDraw (bytes32 _flightnumber)  public  requireIsOperational{
        flightSuretyData.withDraw(_flightnumber,msg.sender);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus ( address airline, bytes32 flight, uint256 timestamp ) public
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);


    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, bytes32 flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, bytes32 flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, bytes32 flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle ( ) external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        uint8[3] memory indexes = generateIndexes(msg.sender);
        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
        //send fund to DATA contract
        address(flightSuretyData).transfer(msg.value);
    }

    function getMyIndexes ( ) view external returns(uint8[3]) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");
        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            bytes32 flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            flightSuretyData.processFlightStatus(flight, timestamp, statusCode);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

contract FlightSuretyProxy{
    function registerAirline(address _airline) public;
    function isRegisteredAirline(address _airline) public view returns(bool);
    function isFundedAirline(address _airline) public view returns(bool);
    function buy(bytes32 _flightnumber, address _passenger, uint256 _amount) public;
    function creditInsurees(bytes32 _flightnumber) public;
    function pay(address _passenger) public;
    function withDraw(bytes32 _flightnumber, address _passenger) public;
    function fund(address _airline) public;
    function registerFlight(bytes32 flightnumber, uint256 timestamp, address sender) public;
    function processFlightStatus (bytes32 _flightnumber, uint256 _timestamp, uint8 _statusCode) public;
    uint public totAirlines;
}
