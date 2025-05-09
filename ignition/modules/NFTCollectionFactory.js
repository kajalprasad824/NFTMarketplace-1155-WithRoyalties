const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("NFTCollectionFactoryModule", (m) => {

    const nftcollectionfactory = m.contract("NFTCollectionFactory");

    return { nftcollectionfactory };
});