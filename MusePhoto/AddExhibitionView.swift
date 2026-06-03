//
//  AddExhibitionView.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI
import PhotosUI
import ImageIO

/// 写真のカメラ情報です。
struct CameraInfo: Codable {
    var cameraModel = ""
    var lensModel = ""
    var aperture = ""
    var shutterSpeed = ""
    var iso = ""
    var shotDate = ""
}

/// 展示作成中の写真データです。
struct PhotoDraft: Identifiable {
    let id = UUID()
    let uiImage: UIImage
    let image: Image
    var title: String
    var cameraInfo: CameraInfo
}

/// 背景候補のデータです。
struct GalleryBackgroundOption: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
}

/// 展示追加の最初の画面です。
struct AddExhibitionView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoDrafts: [PhotoDraft] = []
    @State private var showEditor = false

    let onSave: (String, String, Int, UIImage?, [ExhibitionPhoto], String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Text("まず写真を選びます")
                .font(.title3.weight(.semibold))

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: nil,
                selectionBehavior: .ordered,
                matching: .images
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("写真を複数選択")
                }
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.brown.opacity(0.35), lineWidth: 1)
                )
            }

            Text("選択後、自動で編集ページに移動します")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(red: 0.95, green: 0.89, blue: 0.86).ignoresSafeArea())
        .navigationTitle("展示を追加")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItems) {
            Task {
                await loadDraftsAndMoveNext()
            }
        }
        .navigationDestination(isPresented: $showEditor) {
            PhotoCardsEditorView(photoDrafts: $photoDrafts) { exhibitionTitle, exhibitionComment, backgroundImageName in
                let coverImage = photoDrafts.first?.uiImage
                let photos = photoDrafts.map {
                    ExhibitionPhoto(
                        image: $0.uiImage,
                        title: $0.title,
                        cameraInfo: $0.cameraInfo
                    )
                }
                onSave(exhibitionTitle, exhibitionComment, photoDrafts.count, coverImage, photos, backgroundImageName)
            }
        }
    }

    /// 選択した写真を読み込み、編集ページへ進みます。
    private func loadDraftsAndMoveNext() async {
        var drafts: [PhotoDraft] = []

        for item in selectedItems {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard let uiImage = UIImage(data: data) else { continue }

            let info = extractCameraInfo(from: data)
            let draft = PhotoDraft(
                uiImage: uiImage,
                image: Image(uiImage: uiImage),
                title: "",
                cameraInfo: info
            )
            drafts.append(draft)
        }

        await MainActor.run {
            photoDrafts = drafts
            showEditor = !drafts.isEmpty
        }
    }

    /// 写真のメタデータからカメラ情報を取り出します。
    private func extractCameraInfo(from data: Data) -> CameraInfo {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return CameraInfo() }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return CameraInfo() }

        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]

        var info = CameraInfo()
        info.cameraModel = (tiff?[kCGImagePropertyTIFFModel as String] as? String) ?? ""
        info.lensModel = (exif?[kCGImagePropertyExifLensModel as String] as? String) ?? ""

        if let fNumber = exif?[kCGImagePropertyExifFNumber as String] as? Double {
            info.aperture = "f/\(String(format: "%.1f", fNumber))"
        }

        if let exposure = exif?[kCGImagePropertyExifExposureTime as String] as? Double, exposure > 0 {
            info.shutterSpeed = "1/\(Int((1 / exposure).rounded()))"
        }

        if let isoValues = exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let iso = isoValues.first {
            info.iso = "\(iso)"
        }

        info.shotDate = (exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String) ?? ""
        return info
    }
}

/// 写真カードを縦に並べて編集する画面です。
struct PhotoCardsEditorView: View {
    @Binding var photoDrafts: [PhotoDraft]
    @State private var editingCameraInfoIndex: Int?
    @State private var showBackgroundSelector = false
    let onSave: (String, String, String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            TabView {
                ForEach(photoDrafts.indices, id: \.self) { index in
                    PhotoDraftCardView(
                        number: index + 1,
                        draft: $photoDrafts[index],
                        onOpenCameraInfo: {
                            editingCameraInfoIndex = index
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .background(Color(red: 0.95, green: 0.89, blue: 0.86).ignoresSafeArea())
        .navigationTitle("写真の確認")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    showBackgroundSelector = true
                }
                .disabled(photoDrafts.isEmpty)
            }
        }
        .navigationDestination(isPresented: $showBackgroundSelector) {
            BackgroundSelectionView { exhibitionTitle, comment, backgroundImageName in
                let safeTitle = exhibitionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalTitle = safeTitle.isEmpty ? "新しい展示" : safeTitle
                onSave(finalTitle, comment, backgroundImageName)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingCameraInfoIndex != nil },
            set: { isPresented in
                if !isPresented {
                    editingCameraInfoIndex = nil
                }
            }
        )) {
            if let index = editingCameraInfoIndex, photoDrafts.indices.contains(index) {
                CameraInfoModalView(cameraInfo: $photoDrafts[index].cameraInfo)
            }
        }
    }

}

/// 背景を選ぶ画面です。
struct BackgroundSelectionView: View {
    @State private var selectedBackgroundImageName = "gallery_background_white"
    @State private var showDetailInput = false

    private let backgrounds: [GalleryBackgroundOption] = [
        GalleryBackgroundOption(name: "ミニマル", imageName: "gallery_background_white"),
        GalleryBackgroundOption(name: "ダーク", imageName: "gallery_background_black"),
        GalleryBackgroundOption(name: "ウッド", imageName: "gallery_background_wood"),
        GalleryBackgroundOption(name: "クラシック", imageName: "gallery_background_light"),
        GalleryBackgroundOption(name: "コンクリート", imageName: "gallery_background_concrete")
    ]

    let onSave: (String, String, String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("展示する空間を選んでください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Image(selectedBackgroundImageName)
                .resizable()
                .scaledToFill()
                .frame(height: 430)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(backgrounds) { background in
                        Button {
                            selectedBackgroundImageName = background.imageName
                        } label: {
                            VStack(spacing: 6) {
                                Image(background.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                selectedBackgroundImageName == background.imageName
                                                ? Color.black
                                                : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                Text(background.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Color(red: 0.95, green: 0.89, blue: 0.86).ignoresSafeArea())
        .navigationTitle("空間を選ぶ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    showDetailInput = true
                }
            }
        }
        .navigationDestination(isPresented: $showDetailInput) {
            ExhibitionInfoInputView { title, comment in
                onSave(title, comment, selectedBackgroundImageName)
            }
        }
    }
}

/// 写真展のタイトルとコメントを入力する画面です。
struct ExhibitionInfoInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exhibitionTitle = ""
    @State private var exhibitionComment = ""

    let onSave: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("写真展の情報を入力してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("写真展タイトル")
                    .font(.subheadline.weight(.semibold))
                TextField("例: 光の記憶", text: $exhibitionTitle)
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("コメント")
                    .font(.subheadline.weight(.semibold))
                TextField("例: 日常の光を集めた展示です", text: $exhibitionComment, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
            }

            Spacer()
        }
        .padding(16)
        .background(Color(red: 0.95, green: 0.89, blue: 0.86).ignoresSafeArea())
        .navigationTitle("展示情報")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    onSave(exhibitionTitle, exhibitionComment)
                    dismiss()
                    dismiss()
                    dismiss()
                }
                .disabled(exhibitionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

/// 1枚分の写真カードです。
struct PhotoDraftCardView: View {
    let number: Int
    @Binding var draft: PhotoDraft
    let onOpenCameraInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("写真\(number)")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.35, green: 0.16, blue: 0.05))

                Spacer()
            }

            draft.image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(Color.gray.opacity(0.5))

            TextField("タイトル入力", text: $draft.title)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(height: 54)
                .background(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.45), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button(action: onOpenCameraInfo) {
                Text("カメラ情報を入力")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(red: 0.88, green: 0.82, blue: 0.78))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// カメラ情報を入力するモーダルです。
struct CameraInfoModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cameraInfo: CameraInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CameraInfoInputRow(label: "カメラ", text: $cameraInfo.cameraModel, placeholder: "例: FUJIFILM X-T30")
                    CameraInfoInputRow(label: "レンズ", text: $cameraInfo.lensModel, placeholder: "例: XF 35mm F1.4 R")
                    CameraInfoInputRow(label: "絞り", text: $cameraInfo.aperture, placeholder: "例: f/2.0")
                    CameraInfoInputRow(label: "シャッター", text: $cameraInfo.shutterSpeed, placeholder: "例: 1/250")
                    CameraInfoInputRow(label: "ISO", text: $cameraInfo.iso, placeholder: "例: 200")
                    CameraInfoInputRow(label: "撮影日時", text: $cameraInfo.shotDate, placeholder: "例: 2026:05:27 16:03:00")
                }
                .padding(16)
            }
            .navigationTitle("カメラ情報入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// カメラ情報の1項目分の入力UIです。
struct CameraInfoInputRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            TextField(placeholder, text: $text)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        AddExhibitionView { _, _, _, _, _, _ in }
    }
}
