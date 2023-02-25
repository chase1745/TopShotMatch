//
//  EMSwapProposal.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/23/23.
//

import Foundation

struct EMSwapProposal: Decodable {
    let id: String
    let fees: [[String: String]]
    let minutesRemainingBeforeExpiration: String
    let leftUserAddress: String
    let rightUserAddress: String
    let leftUserOffer: [String: [[String: String]]]
    let rightUserOffer: [String: [[String: String]]]
}
