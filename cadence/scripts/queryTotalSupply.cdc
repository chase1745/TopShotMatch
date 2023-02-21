import TopShot from 0xaa3d8fb4584f9b91

// This script reads the current number of moments that have been minted
// from the TopShot contract and returns that number to the caller
// Returns: UInt64
// Number of moments minted from TopShot contract
pub fun main(): UInt64 {

    return TopShot.totalSupply
}