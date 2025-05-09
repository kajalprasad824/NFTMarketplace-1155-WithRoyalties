const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("SwargNFTModule ", (m) => {

    const swargnft = m.contract("SwargNFT", ["SwargNFT", "SNFT", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "600", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"], {
    });

    return { swargnft };
});