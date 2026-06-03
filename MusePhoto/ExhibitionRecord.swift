//
//  ExhibitionRecord.swift
//  MusePhoto
//
//  Created by machu on 2026/06/01.
//

import Foundation
import SwiftData

/// 1枚分の保存用写真情報です。
struct StoredPhoto: Codable {
    let imageData: Data
    let title: String
    let cameraInfo: CameraInfo
}

/// 写真展を永続化するSwiftDataモデルです。
@Model
final class ExhibitionRecord {
    var title: String
    var comment: String
    var photoCount: Int
    var backgroundImageName: String
    var publishedAt: Date
    var coverImageData: Data?
    var photosData: Data

    init(
        title: String,
        comment: String,
        photoCount: Int,
        backgroundImageName: String,
        publishedAt: Date,
        coverImageData: Data?,
        photosData: Data
    ) {
        self.title = title
        self.comment = comment
        self.photoCount = photoCount
        self.backgroundImageName = backgroundImageName
        self.publishedAt = publishedAt
        self.coverImageData = coverImageData
        self.photosData = photosData
    }
}
