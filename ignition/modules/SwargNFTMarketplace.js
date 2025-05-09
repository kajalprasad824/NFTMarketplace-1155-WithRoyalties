const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("SwargNFTMarketplaceModule ", (m) => {

    const swargnftmarketplace = m.contract("SwargNFTMarketplace", ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "600", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"], {
    });

    return { swargnftmarketplace };
});

//npx hardhat ignition deploy ./ignition/modules/SwargNFTMarketplace.js --network localhost