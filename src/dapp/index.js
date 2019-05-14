
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;
    let flights_list = [{number: "UD456", text:"UD456 departure time 09:20"},
                                {number: "AB123", text:"AB123 departure time 10:05"}, 
                                {number: "BC777", text:"BC777 departure time 10:30"}, 
                                {number: "CD987", text:"CD987 departure time 10:45"}];
    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
            displayFlights(flights_list);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
        let flight = DOM.elid('flight-number').value;
        // Write transaction
        contract.fetchFlightStatus(flight, (error, result) => {
            display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
        });
        });

        DOM.elid('buy-flight-insurance').addEventListener('click', () => {
            let flight = DOM.elid('buy-flight-number').value;
            let amount = DOM.elid('buy-insurance-amount').value
            // Write transaction
            contract.buy(flight, amount, (error, result) => {
                display('Insurance', 'Buy insurance', [ { label: '', error: error, value: 'Buy ' + flight + ' insurance succeed. Paid: ' + amount + ' ether'} ]);
            });
        });

    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));

        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value text-left'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}

function displayFlights(flights) {
    let displayDiv = DOM.elid("display-wrapper");
    let FlightList = DOM.section();
    FlightList.appendChild(DOM.h2("Flight List"));
    FlightList.appendChild(DOM.h5("Available flights:"));
    flights.map((flight) => {
        let row = FlightList.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, flight.number));
        FlightList.appendChild(row);
    })
    displayDiv.append(FlightList);
    let FlightSelect = DOM.elid("flight-number")
    flights.map((flight) => {
        FlightSelect.appendChild(DOM.option({value:flight.number, text:flight.text }));
       
    })
    FlightSelect = DOM.elid("buy-flight-number")
    flights.map((flight) => {
        FlightSelect.appendChild(DOM.option({value:flight.number, text:flight.text }));
       
    })
}
  






