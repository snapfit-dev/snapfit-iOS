//
//  MakerProductResponse.swift
//  SnapFit
//
//  Created by SnapFit on 11/22/24.
//


import Foundation

struct MakerProductResponse: Codable {
    let offset: Int?
    let limit: Int?
    let data: [PostDetail]?
}

