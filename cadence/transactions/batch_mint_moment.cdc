import TopShot from 0xaa3d8fb4584f9b91
import MetadataViews from 0x631e88ae7f1d7c20
import NonFungibleToken from 0x631e88ae7f1d7c20

// This transaction mints multiple moments
// from a single set/play combination (otherwise known as edition)

// Parameters:
//
// setID: the ID of the set to be minted from
// playID: the ID of the Play from which the Moments are minted
// quantity: the quantity of Moments to be minted
// recipientAddr: the Flow address of the account receiving the collection of minted moments

transaction(setID: UInt32, playIDs: [UInt32], quantity: UInt64, recipientAddr: Address) {

    // Local variable for the topshot Admin object
    let adminRef: &TopShot.Admin

    prepare(acct: AuthAccount) {

        // borrow a reference to the Admin resource in storage
        self.adminRef = acct.borrow<&TopShot.Admin>(from: /storage/AdminMintPublic3)!
    }

    execute {

        // borrow a reference to the set to be minted from
        let setRef = self.adminRef.borrowSet(setID: setID)

        // Get the account object for the recipient of the minted tokens
        let recipient = getAccount(recipientAddr)

        // get the Collection reference for the receiver
        let receiverRef = recipient.getCapability(/public/MomentCollection).borrow<&{NonFungibleToken.CollectionPublic, TopShot.MomentCollectionPublic, MetadataViews.ResolverCollection}>()
            ?? panic("Cannot borrow a reference to the recipient's collection")

        // Mint all the new NFTs
        for id in playIDs {
            let collection <- setRef.batchMintMoment(playID: id, quantity: quantity)

            // deposit the NFT in the receivers collection
            receiverRef.batchDeposit(tokens: <-collection)
        }
    }
}