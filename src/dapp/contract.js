import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }
            counter = 15
            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            // ADDING test flights
            this.flightSuretyApp.methods.registerFlight(this.web3.utils.fromAscii('UD456'), Math.floor(Date.now() / 1000))
                .send({from: this.owner, gas:650000}, (error, result) => {
                    console.log('UD456 registered');
                });
            
                
            this.flightSuretyApp.methods.registerFlight(this.web3.utils.fromAscii('AB123'), Math.floor(Date.now() / 1000))
                .send({from: this.owner, gas:650000}, (error, result) => {
                    console.log('AB123 registered');
                });

            this.flightSuretyApp.methods.registerFlight(this.web3.utils.fromAscii('CD987'), Math.floor(Date.now() / 1000))
                .send({from: this.owner, gas:650000}, (error, result) => {
                    console.log('CD987 registered');
                });
            this.flightSuretyApp.methods.registerFlight(this.web3.utils.fromAscii('BC777'), Math.floor(Date.now() / 1000))
                .send({from: this.owner, gas:650000}, (error, result) => {
                    console.log('BC777 registered');
                });
            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 

        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, self.web3.utils.fromAscii(payload.flight), payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }
    buy(flight, amount,  callback) {
        let self = this;
        let payload = {
            flight: flight,
            amount: amount
        } 
        self.flightSuretyApp.methods
            .buy( self.web3.utils.fromAscii(payload.flight))
            .send({from:self.passengers[0], value:self.web3.utils.toWei(payload.amount, "ether"), gas:500000}, (error, result) => {
                callback(error, payload);
            });
    }
}