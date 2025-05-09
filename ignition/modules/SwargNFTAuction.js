const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("SwargNFTAuctionModule", (m) => {

    const swargnftauction = m.contract("SwargNFTAuction", ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "600","500", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"], {
    });

    return { swargnftauction };
});