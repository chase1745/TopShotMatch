import NonFungibleToken from 0x631e88ae7f1d7c20
import TopShot from 0xaa3d8fb4584f9b91
import MetadataViews from 0x631e88ae7f1d7c20
import NFTCatalog from 0x324c34e1c517e4db
import EMSwap from 0xaa3d8fb4584f9b91

// return {globalId: metadata}
pub fun main(account: Address): {UInt64: {String: String}?} {

    let acct = getAccount(account)

    let collectionRef = acct.getCapability(/public/MomentCollection)
                            .borrow<&{
                                NonFungibleToken.CollectionPublic,
                                TopShot.MomentCollectionPublic,
                                MetadataViews.ResolverCollection
                            }>()!

    var moments = collectionRef.borrowMoments()
    var metadatas: {UInt64: {String: String}?} = {}
    for moment in moments {
        var metadata = TopShot.getPlayMetaData(playID: UInt32(moment.data.playID))
        metadata?.insert(key: "playId", moment.data.playID.toString())
        metadatas.insert(key: moment.id, metadata)
    }
    return metadatas
}
