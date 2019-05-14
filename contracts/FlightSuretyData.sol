pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping (address => bool) private flightSuretyApps;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        uint256 credits;
        address[] buyerAddresses;
        mapping (address => uint256) buyers;
    }
    mapping(bytes32 => Flight) private flights;


    mapping(address => uint256) private passengerCredits;



    struct Airline {
        bool funded;
        bool registered;
    }

    mapping(address => Airline) private airlines;
    uint public totAirlines;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event RegisteredAirline(address airline);
    event CreditAvailable(address passenger, uint256 amount);
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor (address _genesysAirline ) public 
    {
        contractOwner = msg.sender;
        airlines[_genesysAirline] = Airline(false, true);
        totAirlines=1;
    }

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

    /**
    * @dev Modifier that requires the consumer application is registered
    */
    modifier requireAppRegistered()
    {
        require(flightSuretyApps[msg.sender], "Caller is not contract owner");
        _;
    }



    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus ( bool mode ) public requireContractOwner 
    {
        operational = mode;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function authorizeCaller ( address _consumerApp ) external requireContractOwner {
        flightSuretyApps[_consumerApp] = true;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function deAuthorizeCaller ( address _consumerApp ) external requireContractOwner {
        flightSuretyApps[_consumerApp] = false;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline (address _airline ) external requireIsOperational requireAppRegistered  {
        airlines[_airline] = Airline(false, true);
        totAirlines++;
        emit RegisteredAirline(_airline);
     }
    function isRegisteredAirline (address _airline ) external view  returns (bool){
        return airlines[_airline].registered;
    }
    function isFundedAirline (address _airline ) external view  returns (bool){
        return airlines[_airline].funded;
    }
   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(bytes32 _flightNumber, address _passenger, uint256 _amount ) external
    {
        require(flights[_flightNumber].isRegistered, "Flight unknown");
        require(flights[_flightNumber].statusCode == 0, "Flight has taken off");
        require(flights[_flightNumber].buyers[_passenger] == 0, "Passenger already bought insurance for this flight");
        flights[_flightNumber].buyers[_passenger] = _amount;
        flights[_flightNumber].buyerAddresses.push(_passenger);
        flights[_flightNumber].credits = flights[_flightNumber].credits.add((_amount.mul(15)).div(10));
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(bytes32 _flightNumber) external requireIsOperational()  requireAppRegistered returns(uint256) {
        require(flights[_flightNumber].isRegistered, "Flight unknown");
        require(flights[_flightNumber].statusCode == 20, 'That flight was not late!');
        require(flights[_flightNumber].credits > 0, 'Insurees already credited');

        for(uint256 c = 0; c < flights[_flightNumber].buyerAddresses.length; c++) {
            uint256 credit = (flights[_flightNumber].buyers[flights[_flightNumber].buyerAddresses[c]].mul(15)).div(10);
            flights[_flightNumber].credits = flights[_flightNumber].credits.sub(credit);
            passengerCredits[flights[_flightNumber].buyerAddresses[c]] = passengerCredits[flights[_flightNumber].buyerAddresses[c]].add(credit);
            emit CreditAvailable(flights[_flightNumber].buyerAddresses[c], credit);
        }
    }
    
    /**
     *  @dev Allow insurees to avoid bougth insurance getting back funds
     *
    */
    function withDraw(bytes32 _flightNumber, address _passenger)  external requireIsOperational()  requireAppRegistered
    {
        require(flights[_flightNumber].isRegistered, "Flight unknown");
        require(flights[_flightNumber].statusCode == 0, "Flight has taken off. Not rembursable.");
        require(flights[_flightNumber].buyers[_passenger] > 0, 'No fund to withdraw');
        uint256 amount = flights[_flightNumber].buyers[_passenger];
        flights[_flightNumber].credits = flights[_flightNumber].credits.sub(amount);
        flights[_flightNumber].buyers[_passenger] = 0;

        // Remove buyer address from buyers' list
        uint indexToBeDeleted;
        for (uint i=0; i<flights[_flightNumber].buyerAddresses.length; i++) {
            if (flights[_flightNumber].buyerAddresses[i] == _passenger) {
                indexToBeDeleted = i;
                break;
            }
        }
        if (indexToBeDeleted < flights[_flightNumber].buyerAddresses.length-1) {
            flights[_flightNumber].buyerAddresses[indexToBeDeleted] = flights[_flightNumber].buyerAddresses[flights[_flightNumber].buyerAddresses.length-1];
        }
        flights[_flightNumber].buyerAddresses.length--;

        //Transfer funds back
        _passenger.transfer(amount);
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay (address  _passenger)  external requireIsOperational()  requireAppRegistered
    {
        require(passengerCredits[_passenger] > 0,"No credit available");
        uint256 amount = passengerCredits[_passenger];
        passengerCredits[_passenger] = 0;
        _passenger.transfer(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund (address _airline) external requireAppRegistered requireIsOperational {
        require(airlines[_airline].registered, "Airline is not registered");
        airlines[_airline].funded = true;
    }


    function registerFlight(bytes32 flightnumber, uint256 timestamp, address sender) external requireIsOperational {
        require((airlines[sender].registered && airlines[sender].funded) || contractOwner == sender, "Caller must be a registered funded airline");
        flights[flightnumber] = Flight(true, 0, timestamp, sender, 0 ether, new address[](0));
    }

    function processFlightStatus(bytes32 _flightnumber, uint256 _timestamp, uint8 _statusCode) external requireIsOperational {
        require(flights[_flightnumber].isRegistered, "Flight not registered");
        flights[_flightnumber].statusCode = _statusCode;
        flights[_flightnumber].updatedTimestamp = _timestamp;
    }
    /**

    * @dev Fallback function for funding smart contract.
    *
    */
    function () external payable requireIsOperational() {
        
    }
  
}

