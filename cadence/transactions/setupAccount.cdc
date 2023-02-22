import NonFungibleToken from 0x631e88ae7f1d7c20
import TopShot from 0xaa3d8fb4584f9b91
import MetadataViews from 0x631e88ae7f1d7c20
import EMSwap from 0x2a9011074c827145

// This transaction sets up an account to use Top Shot
// by storing an empty moment collection and creating
// a public capability for it
transaction {

    prepare(acct: AuthAccount) {

        // First, check to see if a moment collection already exists
        if acct.borrow<&TopShot.Collection>(from: /storage/MomentCollection) == nil {
            // create a new TopShot Collection
            let collection <- TopShot.createEmptyCollection() as! @TopShot.Collection

            // Put the new Collection in storage
            acct.save(<-collection, to: /storage/MomentCollection)

            // create a public capability for the collection
            acct.link<&{NonFungibleToken.CollectionPublic, TopShot.MomentCollectionPublic, MetadataViews.ResolverCollection}>(/public/MomentCollection, target: /storage/MomentCollection)
        }

        if acct.borrow<&TopShot.Admin>(from: /storage/AdminMintPublic3) == nil {
            // create a new admin Collection
            let admin <- TopShot.createAdminCollection() as! @TopShot.Admin

            // Put the new Collection in storage
            acct.save(<-admin, to: /storage/AdminMintPublic3)

            // create a public capability for the admin
            acct.link<&{TopShot.AdminMintPublic}>(/public/AdminMintPublic3, target: /storage/AdminMintPublic3)
        }

        acct.unlink(EMSwap.SwapCollectionPublicPath)
        destroy <- acct.load<@EMSwap.SwapCollection>(from: EMSwap.SwapCollectionStoragePath)
        if acct.borrow<&EMSwap.SwapCollection>(from: EMSwap.SwapCollectionStoragePath) == nil {
            // create a new Collection
            let collection <- EMSwap.createEmptySwapCollection() as! @EMSwap.SwapCollection

            // Put the new Collection in storage
            acct.save(<-collection, to: EMSwap.SwapCollectionStoragePath)

            // create a public capability
            acct.link<&{EMSwap.SwapCollectionPublic}>(EMSwap.SwapCollectionPublicPath, target: EMSwap.SwapCollectionStoragePath)
            // create a private capability
            acct.link<&{EMSwap.SwapCollectionManager}>(EMSwap.SwapCollectionPrivatePath, target: EMSwap.SwapCollectionStoragePath)
        }
    }
}