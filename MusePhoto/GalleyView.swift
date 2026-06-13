//
//  GalleyView.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI
import Photos

/// 展示写真を手動スライドで鑑賞する画面です。
struct GalleyView: View {
    @Environment(\.dismiss) private var dismiss

    let ticket: ExhibitionTicket
    let onExitToHome: () -> Void

    @State private var currentIndex = 0
    @State private var nextIndex: Int?
    @State private var transitionProgress: CGFloat = 0
    @State private var transitionDirection: CGFloat = -1
    @State private var endingBlackoutOpacity = 0.0
    @State private var isTransitioning = false
    @State private var isShowingEnding = false
    @State private var isShowingPhotoInfo = false
    @State private var isShowingPrintSelection = false

    var body: some View {
        ZStack {
            Image(ticket.backgroundImageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.38)
                .ignoresSafeArea()

            // 画面の空いている場所をタップしても、次の作品へ進めます。
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isTransitioning, !isShowingPhotoInfo else { return }
                    moveToNextPhoto()
                }

            VStack(spacing: 14) {
                Spacer(minLength: 30)

                if isShowingEnding {
                    endingView
                        .transition(
                            .move(edge: .trailing)
                                .combined(with: .opacity)
                        )
                } else if ticket.photos.indices.contains(currentIndex) {
                    WalkingArtworkTransitionView(
                        currentPhoto: ticket.photos[currentIndex].image,
                        nextPhoto: nextPhoto,
                        direction: transitionDirection,
                        progress: transitionProgress
                    )
                    // 写真が内側の余白ではなく、実際の画面端で消えるようにします。
                    .padding(.horizontal, -24)
                    .onTapGesture {
                        guard !isTransitioning else { return }
                        moveToNextPhoto()
                    }
                }

                if !isShowingEnding {
                    ZStack(alignment: .bottomTrailing) {
                        ExhibitionProgressIndicator(
                            totalCount: ticket.photos.count,
                            currentIndex: currentIndex
                        )

                        Button {
                            isShowingPhotoInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 25, weight: .regular))
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        // 背後の「次へ」タップより、作品情報ボタンを優先します。
                        .contentShape(Circle())
                        .offset(x: 48)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 70)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard !isTransitioning else { return }
                        if value.translation.width < -45 {
                            moveToNextPhoto()
                        } else if value.translation.width > 45 {
                            moveToPreviousPhoto()
                        }
                    }
            )

            // 最後の作品から展示終了画面へ移るときだけ、落ち着いた暗転を使います。
            Color.black
                .opacity(endingBlackoutOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPhotoInfo) {
            if ticket.photos.indices.contains(currentIndex) {
                PhotoInfoSheetView(photo: ticket.photos[currentIndex])
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $isShowingPrintSelection) {
            ExhibitionPrintSelectionView(ticket: ticket)
        }
    }

    /// 右方向スワイプで前の写真へ移動します。
    private func moveToPreviousPhoto() {
        guard currentIndex > 0 else { return }
        transition(to: currentIndex - 1)
    }

    /// 左方向スワイプで次の写真へ移動します。
    private func moveToNextPhoto() {
        guard currentIndex < ticket.photos.count - 1 else {
            showEndingScene()
            return
        }
        transition(to: currentIndex + 1)
    }

    /// 現在の作品と次の作品を一定速度で横移動させます。
    private func transition(to destinationIndex: Int) {
        guard ticket.photos.indices.contains(destinationIndex) else { return }

        isTransitioning = true
        nextIndex = destinationIndex
        transitionDirection = destinationIndex > currentIndex ? -1 : 1
        transitionProgress = 0

        // スワイプの速さに関係なく、毎回同じ時間で作品を入れ替えます。
        withAnimation(.easeInOut(duration: 2.0)) {
            transitionProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                currentIndex = destinationIndex
                nextIndex = nil
                transitionProgress = 0
            }

            isTransitioning = false
        }
    }

    /// 最終写真の次で、展示終了メッセージに切り替えます。
    private func showEndingScene() {
        isTransitioning = true

        // 最後の写真を暗転で包み、完全に暗くなってから終了画面へ切り替えます。
        withAnimation(.easeInOut(duration: 0.35)) {
            endingBlackoutOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            isShowingEnding = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.25)) {
                endingBlackoutOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                isTransitioning = false
            }
        }
    }

    /// 横から入ってくる次の作品を返します。
    private var nextPhoto: UIImage? {
        guard let nextIndex, ticket.photos.indices.contains(nextIndex) else { return nil }
        return ticket.photos[nextIndex].image
    }

    /// 展示終了後に表示する案内UIです。
    private var endingView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            Text("この展示は終了しました")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("新たな作品との出会いをお楽しみください")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                isShowingPrintSelection = true
            } label: {
                Label("展示の記録を保存", systemImage: "square.and.arrow.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.24))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                isShowingEnding = false
                currentIndex = 0
                transitionProgress = 0
                endingBlackoutOpacity = 0
            } label: {
                Text("もう一度鑑賞する")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.24))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
                onExitToHome()
            } label: {
                Text("次の展示を探す")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 保存する作品を1枚選び、4:5の展示画像を写真アプリへ保存します。
struct ExhibitionPrintSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let ticket: ExhibitionTicket

    @State private var selectedIndex = 0
    @State private var isSaving = false
    @State private var saveMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let selectedPhoto {
                    ExhibitionPrintView(
                        photo: selectedPhoto.image,
                        backgroundImageName: printBackgroundImageName
                    )
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
                    .padding(.horizontal, 44)
                }

                Text("保存する作品を1枚選んでください")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(ticket.photos.indices, id: \.self) { index in
                            Button {
                                selectedIndex = index
                            } label: {
                                GeometryReader { proxy in
                                    Image(uiImage: ticket.photos[index].image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: proxy.size.width, height: proxy.size.width)
                                        .clipped()
                                }
                                .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        if selectedIndex == index {
                                            ZStack {
                                                Color.black.opacity(0.22)

                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    saveSelectedPrint()
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(isSaving ? "保存しています…" : "写真に保存")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(red: 0.20, green: 0.12, blue: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || selectedPhoto == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .padding(.top, 18)
            .background(Color(red: 0.96, green: 0.94, blue: 0.92).ignoresSafeArea())
            .navigationTitle("展示の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("保存結果", isPresented: saveMessageBinding) {
                Button("OK") {
                    saveMessage = nil
                }
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }

    /// 現在選択している作品を安全に返します。
    private var selectedPhoto: ExhibitionPhoto? {
        guard ticket.photos.indices.contains(selectedIndex) else { return nil }
        return ticket.photos[selectedIndex]
    }

    /// 展示背景名から、保存画像用の背景名へ変換します。
    private var printBackgroundImageName: String {
        ticket.backgroundImageName.replacingOccurrences(
            of: "gallery_background_",
            with: "gallery_print_"
        )
    }

    /// 保存結果の文章とアラート表示を連動させます。
    private var saveMessageBinding: Binding<Bool> {
        Binding(
            get: { saveMessage != nil },
            set: { isPresented in
                if !isPresented {
                    saveMessage = nil
                }
            }
        )
    }

    /// 1080×1350の展示画像を作り、写真アプリへ保存します。
    private func saveSelectedPrint() {
        guard let selectedPhoto else { return }
        isSaving = true

        let printView = ExhibitionPrintView(
            photo: selectedPhoto.image,
            backgroundImageName: printBackgroundImageName
        )
        .frame(width: 1080, height: 1350)

        let renderer = ImageRenderer(content: printView)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1350)
        renderer.scale = 1

        guard let image = renderer.uiImage else {
            isSaving = false
            saveMessage = "画像を作成できませんでした"
            return
        }

        requestPhotoAccessAndSave(image)
    }

    /// 写真追加の許可を確認して、生成画像を写真アプリへ保存します。
    private func requestPhotoAccessAndSave(_ image: UIImage) {
        // Xcode側の説明文が未設定でも、権限要求でアプリが終了しないようにします。
        guard Bundle.main.object(
            forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription"
        ) != nil else {
            isSaving = false
            saveMessage = "写真保存の権限設定が必要です"
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    isSaving = false
                    saveMessage = "写真への保存が許可されていません"
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { didSave, _ in
                DispatchQueue.main.async {
                    isSaving = false
                    saveMessage = didSave
                        ? "写真アプリに保存しました"
                        : "写真を保存できませんでした"
                }
            }
        }
    }
}

/// 4:5の背景中央に、余白を広く取った額装作品を配置します。
struct ExhibitionPrintView: View {
    let photo: UIImage
    let backgroundImageName: String

    var body: some View {
        GeometryReader { proxy in
            let frameSize = fittedFrameSize(in: proxy.size)

            ZStack {
                Image(backgroundImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frameSize.width, height: frameSize.height)
                    .padding(proxy.size.width * 0.025)
                    .background(Color.white)
                    .shadow(
                        color: .black.opacity(0.34),
                        radius: proxy.size.width * 0.018,
                        y: proxy.size.width * 0.012
                    )
            }
        }
    }

    /// 写真の縦横比を保ちながら、背景に余裕が残る額縁サイズを計算します。
    private func fittedFrameSize(in canvasSize: CGSize) -> CGSize {
        let imageAspect = photo.size.width / max(photo.size.height, 1)
        let isPortraitPhoto = imageAspect < 0.9
        let maxWidth = canvasSize.width * (isPortraitPhoto ? 0.70 : 0.64)
        // 縦写真は高さを広く使い、背景の中で小さく見えすぎないようにします。
        let maxHeight = canvasSize.height * (isPortraitPhoto ? 0.54 : 0.40)

        if maxWidth / imageAspect <= maxHeight {
            return CGSize(width: maxWidth, height: maxWidth / imageAspect)
        }

        return CGSize(width: maxHeight * imageAspect, height: maxHeight)
    }
}

/// 展示の進行状況を、固定幅の細いバーと数字で表示します。
struct ExhibitionProgressIndicator: View {
    let totalCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))

                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: proxy.size.width * progress)
                }
            }
            // 作品数に関係なく、進行バーの長さは一定です。
            .frame(width: 132, height: 2)

            Text("\(displayedIndex) / \(max(totalCount, 0))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.82))
                .frame(minWidth: 36, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    /// 配列の番号を、ユーザー向けの1始まりの番号に変換します。
    private var displayedIndex: Int {
        guard totalCount > 0 else { return 0 }
        return min(max(currentIndex + 1, 1), totalCount)
    }

    /// 現在位置を0〜1の割合へ変換します。
    private var progress: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(displayedIndex) / CGFloat(totalCount)
    }
}

/// 写真の情報シートを表示します。
struct PhotoInfoSheetView: View {
    let photo: ExhibitionPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            Text(photo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "タイトル未設定" : photo.title)
                .font(.title2.weight(.bold))

            Divider()

            InfoRow(label: "カメラ", value: displayValue(photo.cameraInfo.cameraModel))
            InfoRow(label: "レンズ", value: displayValue(photo.cameraInfo.lensModel))
            InfoRow(label: "絞り", value: displayValue(photo.cameraInfo.aperture))
            InfoRow(label: "シャッタースピード", value: displayValue(photo.cameraInfo.shutterSpeed))
            InfoRow(label: "ISO", value: displayValue(photo.cameraInfo.iso))
            InfoRow(label: "焦点距離", value: displayValue(photo.cameraInfo.focalLength))
            InfoRow(label: "撮影日時", value: displayValue(photo.cameraInfo.shotDate))
            InfoRow(label: "撮影場所", value: displayValue(photo.cameraInfo.location))

            Spacer()
        }
        .padding(20)
        .background(Color.white)
    }

    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未設定" : trimmed
    }
}

/// 情報シートの1行です。
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.black.opacity(0.75))
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(.black)
            Spacer()
        }
    }
}

/// 2枚の作品を左右からすれ違わせ、展示室内を歩くように見せます。
struct WalkingArtworkTransitionView: View {
    let currentPhoto: UIImage
    let nextPhoto: UIImage?
    let direction: CGFloat
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            // 写真同士の間に約1画面分の展示室が見える間隔を作ります。
            let travelDistance = proxy.size.width * 2

            ZStack {
                FramedSlidePhotoView(photo: currentPhoto)
                    .padding(.horizontal, 24)
                    .offset(x: direction * travelDistance * progress)
                    .opacity(1 - (progress * 0.24))

                if let nextPhoto {
                    FramedSlidePhotoView(photo: nextPhoto)
                        .padding(.horizontal, 24)
                        .offset(x: -direction * travelDistance * (1 - progress))
                        .opacity(0.76 + (progress * 0.24))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 470)
    }
}

/// 写真サイズにぴったり合わせて白い縁をつける表示です。
struct FramedSlidePhotoView: View {
    let photo: UIImage

    private let maxHeight: CGFloat = 470
    private let frameLineWidth: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width - (frameLineWidth * 2), 1)
            let availableHeight = max(maxHeight - (frameLineWidth * 2), 1)
            let imageAspect = photo.size.width / max(photo.size.height, 1)
            let fittedWidth = min(availableWidth, availableHeight * imageAspect)
            let fittedHeight = fittedWidth / imageAspect

            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: fittedWidth, height: fittedHeight)
                .clipped()
                // strokeではなく外側に均等な余白を付け、縦写真でも四辺を同じ太さにします。
                .padding(frameLineWidth)
                .background(Color.white)
                .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight)
    }
}

#Preview {
    NavigationStack {
        GalleyView(
            ticket: ExhibitionTicket(
                id: "preview",
                exhibitionNumber: 1,
                title: "海辺の休日",
                comment: "サンプル",
                photoCount: 2,
                coverImage: nil,
                photos: [],
                photosData: Data(),
                backgroundImageName: "gallery_background_white",
                publishedAt: Date()
            ),
            onExitToHome: {}
        )
    }
}
