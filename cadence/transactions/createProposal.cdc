import EMSwap from 0x2a9011074c827145
import NonFungibleToken from 0x631e88ae7f1d7c20
import TopShot from 0xaa3d8fb4584f9b91

transaction(leftNftID: UInt64, rightNftID: UInt64, rightUserAddress: Address): String {
    let managerRef: &EMSwap.SwapCollection
    let userCapability: EMSwap.UserCapabilities
    let type: String
    let leftUserAddress: Address

    prepare(acct: AuthAccount) {
        self.type = "A.aa3d8fb4584f9b91.TopShot.NFT"
        self.leftUserAddress = acct.address

        // borrow a reference to the Admin resource in storage
        self.managerRef = acct.borrow<&EMSwap.SwapCollection>(from: EMSwap.SwapCollectionStoragePath)
            ?? panic("Could not borrow a reference to the SwapCollectionManager resource")

        self.userCapability = EMSwap.UserCapabilities(
            collectionReceiverCapabilities: {
                "A.aa3d8fb4584f9b91.TopShot.NFT" : acct.getCapability<&AnyResource{NonFungibleToken.Receiver}>(/public/MomentCollection)
            },
            collectionProviderCapabilities: {
                "A.aa3d8fb4584f9b91.TopShot.NFT" : acct.getCapability<&AnyResource{NonFungibleToken.Provider}>(/public/MomentCollection)
            },
            feeProviderCapabilities: nil
        )
    }

    execute {
        let leftUserProposal: EMSwap.UserOffer = EMSwap.UserOffer(
            userAddress: self.leftUserAddress,
            proposedNfts: [
                EMSwap.ProposedTradeAsset(
                    nftID: leftNftID,
                    type: self.type
                )
            ]
        )

        let rightUserProposal: EMSwap.UserOffer = EMSwap.UserOffer(
            userAddress: rightUserAddress,
            proposedNfts: [
                EMSwap.ProposedTradeAsset(
                    nftID: rightNftID,
                    type: self.type
                )
            ]
        )

        // Create a proposal and return the proposal id
        return self.managerRef.createProposal(
            leftUserOffer: leftUserProposal,
            rightUserOffer: rightUserProposal,
            leftUserCapabilities: self.userCapability,
            fees: nil,
            expirationOffsetMinutes: nil
        )
    }
}
