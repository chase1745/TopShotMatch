//
//  MomentId.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import Foundation

class MomentId: Decodable {
    let globalId: UInt64
    let playId: UInt32
    let address: String
}
