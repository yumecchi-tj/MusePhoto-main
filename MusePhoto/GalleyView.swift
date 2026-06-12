//
//  GalleyView.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI

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
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
                                )
                                .shadow(color: .white.opacity(0.25), radius: 8)
                        }
                        .buttonStyle(.plain)
                        // 背後の「次へ」タップより、作品情報ボタンを優先します。
                        .contentShape(Circle())
                        .offset(x: 54, y: 26)
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

/// 展示の進行状況を、●─○のような館内導線で表示します。
struct ExhibitionProgressIndicator: View {
    let totalCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<max(totalCount, 0), id: \.self) { index in
                let isCurrent = index == currentIndex

                Circle()
                    .fill(isCurrent ? Color.white : Color.clear)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isCurrent ? 0.95 : 0.65), lineWidth: 1)
                    )
                    .shadow(color: isCurrent ? .white.opacity(0.9) : .clear, radius: 8)

                if index < totalCount - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 28, height: 1)
                        .padding(.horizontal, 3)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.22))
        .clipShape(Capsule())
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

            if !photo.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()

                Text(photo.comment)
                    .font(.body)
                    .foregroundStyle(.black.opacity(0.82))
                    .lineSpacing(5)
            }

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
            let availableWidth = proxy.size.width
            let imageAspect = photo.size.width / max(photo.size.height, 1)
            let fittedWidth = min(availableWidth, maxHeight * imageAspect)
            let fittedHeight = fittedWidth / imageAspect

            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: fittedWidth, height: fittedHeight)
                .clipped()
                .overlay {
                    Rectangle()
                        .stroke(Color.white, lineWidth: frameLineWidth)
                }
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
