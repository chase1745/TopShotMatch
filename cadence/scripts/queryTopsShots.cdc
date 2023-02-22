import NonFungibleToken from 0x631e88ae7f1d7c20
import TopShot from 0xaa3d8fb4584f9b91
import MetadataViews from 0x631e88ae7f1d7c20
import NFTCatalog from 0x324c34e1c517e4db
import EMSwap from 0x2a9011074c827145

// return {globalId: metadata}
pub fun main(account: Address): Type {//{UInt64: {String: String}?} {

    let acct = getAccount(account)

    let collectionRef = acct.getCapability(/public/MomentCollection)
                            .borrow<&{
                                NonFungibleToken.CollectionPublic,
                                TopShot.MomentCollectionPublic,
                                MetadataViews.ResolverCollection
                            }>()!

    let nftCatalogCollections: {String: Bool}? = NFTCatalog.getCollectionsForType(nftTypeIdentifier: "A.aa3d8fb4584f9b91.TopShot.NFT")
    let catalogEntry = NFTCatalog.getCatalogEntry(collectionIdentifier: nftCatalogCollections!.keys[0])

    let publicCapability = acct.getCapability(catalogEntry!.collectionData.publicPath)

    let collectionPublicRef = publicCapability.borrow<&AnyResource{NonFungibleToken.CollectionPublic}>()!

    let ownedNftIds: [UInt64] = collectionPublicRef.getIDs()
    assert(ownedNftIds.contains(18), message: "error 1")

    let nftRef = collectionPublicRef.borrowNFT(id: 18)
    assert(nftRef.getType() == CompositeType("A.aa3d8fb4584f9b91.TopShot.NFT"), message: "errror 2")

    let leftUserProposal: EMSwap.UserOffer = EMSwap.UserOffer(
        userAddress: account,
        proposedNfts: [
            EMSwap.ProposedTradeAsset(
                nftID: 18,
                type: "A.aa3d8fb4584f9b91.TopShot.NFT"
            )
        ]
    )
    return leftUserProposal.proposedNfts[0].getType() == nftRef.getType()

    // return moment.getType()
    // var moments = collectionRef.borrowMoments()
    // var metadatas: {UInt64: {String: String}?} = {}
    // for moment in moments {
    //     var metadata = TopShot.getPlayMetaData(playID: UInt32(moment.data.playID))
    //     metadata?.insert(key: "playId", moment.data.playID.toString())
    //     metadatas.insert(key: moment.id, metadata)
    // }
    // return metadatas
}
