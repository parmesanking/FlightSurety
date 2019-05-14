var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "erupt join detect solution black vendor smile sniff bring scrap glow resource";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*',
      gas: 5000000
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};