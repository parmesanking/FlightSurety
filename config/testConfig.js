
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');

var Config = async function(accounts) {
    
    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0xFe3A86cE9Eee63008417bA772ae0719E36e9EDb7",
        "0x4de5EF92a1f85dB578D6d9F11782d080159E7c69",
        "0x8e42eCD78331A4dA8949528190A1a72576c88eC4",
        "0x8D943ca32A194EB36Ee7E4d5de7c4249DcEfBE6B",
        "0x2FE33b13A72e40d979c8683D75cc28757cB631fF",
        "0xC82E3d5B4c84664e5E506FdE45AE1aB6Be427513",
        "0xf5E948F1ddc85D0F402c712cd2268bCb6fd79808",
        "0xa27e893D2B2352cd663d5eAB6C1086785858d28E",
        "0x519e1d1a48cDFf0f403ACE24B01B4ab014cBEF74"
    ];


    let owner = accounts[0];
    let firstAirline = accounts[1];

    let flightSuretyData = await FlightSuretyData.new(firstAirline);
    let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address);

    
    return {
        owner: owner,
        firstAirline: firstAirline,
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses,
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

module.exports = {
    Config: Config
};