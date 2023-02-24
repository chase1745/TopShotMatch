//
//  ReadableSwapProposal.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/22/23.
//

import Foundation

class MomentProposal: Decodable {
    let id: String
    let leftMoment: [String: String]
    let rightMoment: [String: String]
}
