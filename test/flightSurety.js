
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');


contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          console.log (e)
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) register new flights from not funded airline', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
    let accessDenied = false;

    // ACT
    try {
        await config.flightSuretyApp.registerFlight(web3.utils.fromAscii("ND139"), Math.floor(Date.now() / 1000)); 
    }
    catch(e) {
        accessDenied = true
    }

    // ASSERT
    assert.equal(accessDenied, false, "Airline should not be able to register a fligth if it hasn't provided funding");

  });
  it('(airline) fund airline registration', async () => {

    // ACT
    try {
        await config.flightSuretyApp.fund( {from: config.firstAirline, value: web3.utils.toWei("10",'ether')});
    }
    catch(e) {
        console.log(e)
    }
    let result = await config.flightSuretyData.isFundedAirline.call(config.firstAirline); 

    // ASSERT
    assert.equal(result, true, "Airline should not be able to fund its registration");

  })
  it('(airline) register new flights from funded airline', async () => {
    
    // ARRANGE
    let newAirline = accounts[3];
    let accessDenied = false;

    await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    await config.flightSuretyApp.fund({from: newAirline, value: web3.utils.toWei("10",'ether')})
    // ACT
    try {
        await config.flightSuretyApp.registerFlight(web3.utils.fromAscii("ND139"), Math.floor(Date.now() / 1000), {from: newAirline}); 
    }
    catch(e) {
        accessDenied = true
    }

    // ASSERT
    assert.equal(accessDenied, false, "Airline should be able to register a flight if it has provided funding");

  });
  it('(airline) Only existing airline may register a new airline until there are at least four airlines registered', async () => {
    
    // ARRANGE
    let airline1 = accounts[5]
    let airline2 = accounts[6]
    let airline3 = accounts[7]
    let fee = web3.utils.toWei("10",'ether')
    await config.flightSuretyApp.fund({from: config.firstAirline, value: fee});
    await config.flightSuretyApp.registerAirline(airline1, {from: config.firstAirline});
    await config.flightSuretyApp.fund({from: airline1, value: fee});
    await config.flightSuretyApp.registerAirline(airline2, {from: config.firstAirline});
    await config.flightSuretyApp.fund({from: airline2, value: fee});
    await config.flightSuretyApp.registerAirline(airline3, {from: config.firstAirline});
    let errOnFunding=false
    try{

      await config.flightSuretyApp.fund({from: airline3, value: fee});
    }catch(e){
      errOnFunding=true
    }

    // ASSERT
    assert.equal(errOnFunding, true, "there are not enough votes and airline is not registered yet");

  });



  it('(airline) airline funding should be of 10 ETHER at least', async () => {
    
    // ARRANGE
    let newAirline = accounts[4];
    let accessDenied = false;

    await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    // ACT
    try {
        await config.flightSuretyApp.fund({from: newAirline ,value: web3.utils.toWei("5",'ether')})
    }
    catch(e) {
        accessDenied = true
    }

    // ASSERT
    assert.equal(accessDenied, true, "Airline shouldn't be able to partecipate with less than 10 ETH");

  });

  

  it('(Passengers) Passengers may pay up to 1 ether for purchasing flight insurance.', async () => {

    let passenger1 = accounts[10];
    let passenger2 = accounts[11];

    let flight = web3.utils.fromAscii('AG123');

    let value1 = web3.utils.toWei('2', "ether");
    let value2 = web3.utils.toWei('1', "ether");

    let result1 = false;
    let result2 = false;

    await config.flightSuretyApp.registerFlight(flight, Math.floor(Date.now() /1000), {from: config.firstAirline});
    
    try {
      await config.flightSuretyApp.buy(flight, {from: passenger1, value: value1});
    }
    catch(e) {
      result1 = true;
    }

    try {
        await config.flightSuretyApp.buy(flight, {from: passenger2, value: value2});
      }
      catch(e) {
        console.log(e)
        result2 = true;
      }

    // ASSERT
    assert.equal(result1, true, "the payment should less than 1 ether");
    assert.equal(result2, false, "buy insurance has failed");
  });

  it('(Passengers) Passengers can withdraw a paid insurance.', async () => {

    let passenger1 = accounts[12];
  
    let flight = web3.utils.fromAscii('AG456');
  
    let value1 = await web3.utils.toWei('1', "ether");
  
    let result1 = false;
    let initialBalance =  await web3.eth.getBalance(passenger1)
    
    await config.flightSuretyApp.registerFlight(flight, Math.floor(Date.now() /1000), {from: config.firstAirline});
    
    try {
      await config.flightSuretyApp.buy(flight, {from: passenger1, value: value1});
    }
    catch(e) {
      result1 = true;
    }
  
    try {
        await config.flightSuretyApp.withDraw(flight, {from: passenger1});
      }
      catch(e) {
      }
  
      let newBalance = await web3.eth.getBalance(passenger1)

    //console.log("PRE", initialBalance)
    //console.log("POST",newBalance)
    // ASSERT
    assert.equal(result1, false, "the payment should less than 1 ether");
    assert.equal(parseInt(newBalance) > parseInt(initialBalance), false, "passenger didn't get money back");
  });
  it('(Passengers) Passengers are refunded from a late fligth', async () => {

    let passenger1 = accounts[13];
  
    let flight = web3.utils.fromAscii('AG789');
  
    let value1 = await web3.utils.toWei('1', "ether");
      let result1 = false;
    let initialBalance =  await web3.eth.getBalance(passenger1)
    //REGISTER FLIGHT
    await config.flightSuretyApp.registerFlight(flight, Math.floor(Date.now() /1000), {from: config.firstAirline});
    //BUY INSURANCE
    try {
      await config.flightSuretyApp.buy(flight, {from: passenger1, value: value1});
    }
    catch(e) {
      result1 = true;
    }
    //SET FLIGHT STATUS LATE
    await config.flightSuretyData.processFlightStatus(flight, Math.floor(Date.now() /1000),20, {from: config.firstAirline});

    
    //RELEASE CREDITS TO PASENGERS
    let errOnReleaseCredit = false
    try{
    await config.flightSuretyApp.creditInsurees(flight, {from: config.firstAirline});
    } catch(e) {
      console.log(e)
      errOnReleaseCredit=true
    }
    //PAY THE PASSENGER
    let errOnPay = false
    try {
      await config.flightSuretyApp.pay( {from: passenger1});
    } catch(e) {
      errOnPay=true
    }

    let newBalance = await web3.eth.getBalance(passenger1)

    //console.log("PRE", initialBalance)
    //console.log("POST",newBalance)
    // ASSERT
    assert.equal(result1, false, "the payment should less than 1 ether");
    assert.equal(errOnReleaseCredit, false, "credit has not been released to passengers");
    assert.equal(parseInt(newBalance) > parseInt(initialBalance), true, "passenger didn't get money back");
    assert.equal(errOnPay, false, "error on getting money");
  });
  it('(Passengers) Passengers cannot pay insurance twice for the same flight.', async () => {

    let passenger1 = accounts[13];

    let flight = web3.utils.fromAscii('ZZ999');

    let value1 = web3.utils.toWei('1', "ether");

    let result1 = false;

    await config.flightSuretyApp.registerFlight(flight, Math.floor(Date.now() /1000), {from: config.firstAirline});
    
    try {
      await config.flightSuretyApp.buy(flight, {from: passenger1, value: value1});
    }
    catch(e) {
      console.log(e)
      
    }
    try {
      await config.flightSuretyApp.buy(flight, {from: passenger1, value: value1});
    }
    catch(e) {
      result1 = true;
    }

    // ASSERT
    assert.equal(result1, true, "the passenger cannot pay the insurance twice");

  });
});



