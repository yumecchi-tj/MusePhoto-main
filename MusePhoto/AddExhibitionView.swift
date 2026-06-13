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
    var focalLength = ""
    var shotDate = ""
    var location = ""
}

/// 展示作成中の写真データです。
struct PhotoDraft: Identifiable {
    let id = UUID()
    let uiImage: UIImage
    let image: Image
    var title: String
    var comment: String
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
            PhotoCardsEditorView(photoDrafts: $photoDrafts) { exhibitionTitle, exhibitionComment, backgroundImageName, selectedCoverImage in
                let coverImage = selectedCoverImage ?? photoDrafts.first?.uiImage
                let photos = photoDrafts.map {
                    ExhibitionPhoto(
                        image: $0.uiImage,
                        title: $0.title,
                        comment: "",
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
                comment: "",
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

        if let focalLength = exif?[kCGImagePropertyExifFocalLength as String] as? Double {
            info.focalLength = "\(Int(focalLength.rounded()))mm"
        }

        info.shotDate = (exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String) ?? ""
        return info
    }
}

/// 作品ごとの写真・タイトル・撮影情報を入力する画面です。
struct PhotoCardsEditorView: View {
    @Binding var photoDrafts: [PhotoDraft]
    @State private var selectedIndex = 0
    @State private var selectedCarouselIndex: Int? = 0
    @State private var editingCameraInfoIndex: Int?
    @State private var showBackgroundSelector = false
    let onSave: (String, String, String, UIImage?) -> Void

    private let pageBackground = Color(red: 0.96, green: 0.94, blue: 0.92)
    private let textBrown = Color(red: 0.22, green: 0.12, blue: 0.07)
    private let borderBrown = Color(red: 0.46, green: 0.30, blue: 0.19)
    private let buttonBrown = Color(red: 0.18, green: 0.11, blue: 0.07)

    var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    carouselArea
                        .frame(height: proxy.size.height * 0.52)

                    inputArea
                        .frame(height: proxy.size.height * 0.48)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            doneButton
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(pageBackground)
        }
        .navigationTitle("作品を追加")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedCarouselIndex = selectedIndex
        }
        .onChange(of: selectedCarouselIndex) {
            guard let newIndex = selectedCarouselIndex else { return }
            selectedIndex = safeIndex(newIndex)
        }
        .onChange(of: photoDrafts.count) {
            selectedIndex = safeIndex(selectedIndex)
            selectedCarouselIndex = selectedIndex
        }
        .navigationDestination(isPresented: $showBackgroundSelector) {
            BackgroundSelectionView(photoDrafts: photoDrafts) { exhibitionTitle, comment, backgroundImageName, selectedCoverImage in
                let safeTitle = exhibitionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalTitle = safeTitle.isEmpty ? "新しい展示" : safeTitle
                onSave(finalTitle, comment, backgroundImageName, selectedCoverImage)
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

    /// 上半分の横スワイプできるカルーセルです。
    private var carouselArea: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width * 0.68
            let sidePadding = max((proxy.size.width - cardWidth) / 2, 24)
            let cardHeight = min(proxy.size.height - 88, 286)

            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        ForEach(photoDrafts.indices, id: \.self) { index in
                            ArtworkCarouselCard(
                                number: index + 1,
                                image: photoDrafts[index].image,
                                isSelected: index == currentIndex
                            )
                            .frame(width: cardWidth)
                            .frame(height: cardHeight)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.56)
                            }
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, sidePadding)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selectedCarouselIndex)

                PageDotsView(count: photoDrafts.count, selectedIndex: currentIndex)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 下半分の固定入力エリアです。写真を切り替えると、この中身も同じ番号の作品に切り替わります。
    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            if photoDrafts.indices.contains(currentIndex) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("タイトル")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textBrown)

                    TextField("光と波の記憶", text: titleBinding)
                        .font(.body.weight(.medium))
                        .foregroundStyle(textBrown)
                        .tint(textBrown)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(.white.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(borderBrown.opacity(0.34), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("撮影情報（オプション）")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textBrown)

                    Button {
                        editingCameraInfoIndex = currentIndex
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.title3)
                                .foregroundStyle(textBrown)

                            Text(cameraSummary(photoDrafts[currentIndex].cameraInfo))
                                .font(.body)
                                .foregroundStyle(textBrown)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(textBrown.opacity(0.78))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(.white.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(borderBrown.opacity(0.34), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 14)
    }

    /// 作品入力を終えて、次の展示設定画面へ進むボタンです。
    private var doneButton: some View {
        Button {
            showBackgroundSelector = true
        } label: {
            Text("完了")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            buttonBrown,
                            Color(red: 0.08, green: 0.05, blue: 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(photoDrafts.isEmpty)
        .opacity(photoDrafts.isEmpty ? 0.45 : 1)
    }

    /// 今選ばれている写真番号を、安全な範囲に丸めます。
    private var currentIndex: Int {
        safeIndex(selectedIndex)
    }

    /// タイトル入力を現在選択中の作品データにつなぎます。
    private var titleBinding: Binding<String> {
        Binding(
            get: {
                guard photoDrafts.indices.contains(currentIndex) else { return "" }
                return photoDrafts[currentIndex].title
            },
            set: { newValue in
                guard photoDrafts.indices.contains(currentIndex) else { return }
                photoDrafts[currentIndex].title = newValue
            }
        )
    }

    /// カルーセルの番号が配列の外へ出ないようにします。
    private func safeIndex(_ index: Int) -> Int {
        guard !photoDrafts.isEmpty else { return 0 }
        return min(max(index, 0), photoDrafts.count - 1)
    }

    /// 撮影情報セルに出す短い説明文を作ります。
    private func cameraSummary(_ info: CameraInfo) -> String {
        let camera = info.cameraModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let lens = info.lensModel.trimmingCharacters(in: .whitespacesAndNewlines)

        if camera.isEmpty && lens.isEmpty {
            return "撮影情報を入力"
        }

        return [camera, lens]
            .filter { !$0.isEmpty }
            .joined(separator: " ・ ")
    }
}

/// カルーセルに表示する1枚分の作品カードです。
struct ArtworkCarouselCard: View {
    let number: Int
    let image: Image
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("#\(String(format: "%02d", number))")
                .font(.system(size: 27, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.26, green: 0.13, blue: 0.08))

            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(isSelected ? 0.98 : 0.82),
                    Color(red: 0.98, green: 0.96, blue: 0.93).opacity(isSelected ? 0.98 : 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(red: 0.46, green: 0.30, blue: 0.19).opacity(isSelected ? 0.58 : 0.34), lineWidth: 1.1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.06), radius: isSelected ? 22 : 9, y: isSelected ? 12 : 5)
    }
}

/// Apple純正UIのようなシンプルなページドットです。
struct PageDotsView: View {
    let count: Int
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == selectedIndex ? Color(red: 0.29, green: 0.16, blue: 0.09) : Color.black.opacity(0.12))
                    .frame(width: 8, height: 8)
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

    let photoDrafts: [PhotoDraft]
    let onSave: (String, String, String, UIImage?) -> Void

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
            ExhibitionInfoInputView(photoDrafts: photoDrafts) { title, comment, selectedCoverImage in
                onSave(title, comment, selectedBackgroundImageName, selectedCoverImage)
            }
        }
    }
}

/// 写真展のタイトルとコメントを入力する画面です。
struct ExhibitionInfoInputView: View {
    @State private var exhibitionTitle = ""
    @State private var exhibitionComment = ""
    @State private var selectedCoverItem: PhotosPickerItem?
    @State private var selectedCoverImage: UIImage?

    let photoDrafts: [PhotoDraft]
    let onSave: (String, String, UIImage?) -> Void

    private let pageBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    private let accentBeige = Color(red: 0.74, green: 0.68, blue: 0.61)
    private var coverImage: UIImage? {
        selectedCoverImage ?? photoDrafts.first?.uiImage
    }

    var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        coverSelectionButton

                        inputField(
                            title: "展示タイトル",
                            placeholder: "海辺の休日",
                            text: $exhibitionTitle,
                            height: 56
                        )

                        commentInputField
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 120)
                }

                nextButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCoverItem) {
            Task {
                await loadSelectedCoverImage()
            }
        }
    }

    /// カバー写真を横長で表示し、アルバムから選び直せることを伝えるボタンです。
    private var coverSelectionButton: some View {
        PhotosPicker(
            selection: $selectedCoverItem,
            matching: .images
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accentBeige.opacity(0.28))

                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                
                LinearGradient(
                    colors: [
                        Color(red: 0.62, green: 0.56, blue: 0.50).opacity(coverImage == nil ? 0.92 : 0.18),
                        Color(red: 0.48, green: 0.42, blue: 0.36).opacity(coverImage == nil ? 0.92 : 0.32)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .medium))

                    Text(coverImage == nil ? "カバー画像を追加" : "カバー画像を変更")
                        .font(.headline.weight(.semibold))

                    Text("アルバムから代表作品を選択")
                        .font(.footnote.weight(.medium))
                        .opacity(0.82)
                }
                .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
            }
            .frame(height: 210)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    /// アルバムで選んだ写真をカバー画像として読み込みます。
    private func loadSelectedCoverImage() async {
        guard let data = try? await selectedCoverItem?.loadTransferable(type: Data.self) else { return }
        guard let uiImage = UIImage(data: data) else { return }

        await MainActor.run {
            selectedCoverImage = uiImage
        }
    }

    /// 1行入力欄を作ります。
    private func inputField(title: String, placeholder: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black.opacity(0.82))

            TextField(placeholder, text: text)
                .font(.body.weight(.medium))
                .foregroundStyle(.black)
                .tint(Color(red: 0.35, green: 0.16, blue: 0.05))
                .padding(.horizontal, 16)
                .frame(height: height)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }

    /// 写真展の紹介文を入力する複数行欄です。
    private var commentInputField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("展示コメント")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black.opacity(0.82))

            TextField(
                "海辺で撮影した写真をまとめました。\n静かな波の音や光の移ろいを感じながらご覧ください。",
                text: $exhibitionComment,
                axis: .vertical
            )
            .font(.body.weight(.medium))
            .foregroundStyle(.black)
            .tint(Color(red: 0.35, green: 0.16, blue: 0.05))
            .lineLimit(5, reservesSpace: true)
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
    }

    /// 入力内容を保存へ進める大きなボタンです。
    private var nextButton: some View {
        Button {
            onSave(exhibitionTitle, exhibitionComment, selectedCoverImage)
        } label: {
            Text("保存")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.96),
                            Color(red: 0.17, green: 0.14, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(exhibitionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(exhibitionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
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
                .foregroundStyle(.black)
                .tint(Color(red: 0.35, green: 0.16, blue: 0.05))
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
    private let sheetBackground = Color(red: 0.95, green: 0.89, blue: 0.86)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CameraInfoInputRow(label: "カメラ", text: $cameraInfo.cameraModel, placeholder: "例: FUJIFILM X-T30")
                    CameraInfoInputRow(label: "レンズ", text: $cameraInfo.lensModel, placeholder: "例: XF 35mm F1.4 R")
                    CameraInfoInputRow(label: "F値", text: $cameraInfo.aperture, placeholder: "例: f/2.0")
                    CameraInfoInputRow(label: "シャッタースピード", text: $cameraInfo.shutterSpeed, placeholder: "例: 1/250")
                    CameraInfoInputRow(label: "ISO", text: $cameraInfo.iso, placeholder: "例: 200")
                    CameraInfoInputRow(label: "焦点距離", text: $cameraInfo.focalLength, placeholder: "例: 35mm")
                    CameraInfoInputRow(label: "撮影日時", text: $cameraInfo.shotDate, placeholder: "例: 2026:05:27 16:03:00")
                    CameraInfoInputRow(label: "撮影場所", text: $cameraInfo.location, placeholder: "例: 湘南海岸")
                }
                .padding(16)
            }
            .background(sheetBackground.ignoresSafeArea())
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
        .preferredColorScheme(.light)
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
                .foregroundStyle(.black.opacity(0.82))
            TextField(placeholder, text: $text)
                .foregroundStyle(.black)
                .tint(Color(red: 0.35, green: 0.16, blue: 0.05))
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

#Preview("作品情報入力") {
    PhotoCardsEditorPreviewHost()
}

/// 作品情報入力画面だけをPreviewで確認するための入れ物です。
private struct PhotoCardsEditorPreviewHost: View {
    @State private var drafts = PhotoCardsEditorPreviewHost.makePreviewDrafts()

    var body: some View {
        NavigationStack {
            PhotoCardsEditorView(photoDrafts: $drafts) { _, _, _, _ in }
        }
    }

    /// Preview用のサンプル作品を作ります。
    private static func makePreviewDrafts() -> [PhotoDraft] {
        var info = CameraInfo()
        info.cameraModel = "FUJIFILM X-T30"
        info.lensModel = "XF35mm F1.4"
        info.aperture = "f/2.0"
        info.shutterSpeed = "1/250"
        info.iso = "200"
        info.focalLength = "35mm"
        info.location = "海辺"

        return [
            PhotoDraft(
                uiImage: UIImage(),
                image: Image(systemName: "photo"),
                title: "光と波の記憶",
                comment: "夕暮れの海辺を散歩したときの一枚。",
                cameraInfo: info
            ),
            PhotoDraft(
                uiImage: UIImage(),
                image: Image(systemName: "camera.aperture"),
                title: "静かな午後",
                comment: "",
                cameraInfo: CameraInfo()
            ),
            PhotoDraft(
                uiImage: UIImage(),
                image: Image(systemName: "sparkles"),
                title: "白い光",
                comment: "",
                cameraInfo: CameraInfo()
            )
        ]
    }
}
