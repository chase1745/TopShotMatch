import TopShot from 0xaa3d8fb4584f9b91
import MetadataViews from 0x631e88ae7f1d7c20
import NonFungibleToken from 0x631e88ae7f1d7c20

pub fun main(address: Address): Bool {
    let account = getAccount(address)
    return account
        .getCapability<&{
            NonFungibleToken.CollectionPublic,
            TopShot.MomentCollectionPublic,
            MetadataViews.ResolverCollection
        }>(/public/MomentCollection)
        .check()
}