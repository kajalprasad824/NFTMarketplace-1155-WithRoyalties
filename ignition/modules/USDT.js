const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("USDTModule", (m) => {

    const usdt = m.contract("USDT", ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"], {
    });

    return { usdt };
});