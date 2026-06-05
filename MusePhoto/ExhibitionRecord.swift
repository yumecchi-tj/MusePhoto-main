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
    let comment: String
    let cameraInfo: CameraInfo

    init(imageData: Data, title: String, comment: String, cameraInfo: CameraInfo) {
        self.imageData = imageData
        self.title = title
        self.comment = comment
        self.cameraInfo = cameraInfo
    }

    private enum CodingKeys: String, CodingKey {
        case imageData
        case title
        case comment
        case cameraInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageData = try container.decode(Data.self, forKey: .imageData)
        title = try container.decode(String.self, forKey: .title)
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        cameraInfo = try container.decode(CameraInfo.self, forKey: .cameraInfo)
    }
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
